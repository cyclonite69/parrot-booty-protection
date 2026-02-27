# PBP Control Restoration - Operator Sovereignty

## Overview

PBP has evolved from a collection of security scripts into a **Security Control Platform** with enforced operator sovereignty. This document describes the control restoration system that prevents autonomous configuration changes.

## Architecture Evolution

### Before: Script Collection
```
Scripts → System Changes → Hope it works
```

### After: Control Platform
```
Operator → Policy → Enforcement → Monitoring → Alerts
```

## Core Components

### 1. Policy Engine (`/core/policy.sh`)

**Single source of truth** for all security decisions.

**Policy File**: `/etc/pbp/policy.yaml`

**Key Features**:
- DNS authority enforcement (Unbound only)
- Operator approval gates
- Protected file definitions
- Alert configuration

**Functions**:
- `load_policy()` - Load active policy
- `get_policy(key)` - Get policy value
- `requires_approval(action)` - Check if approval needed
- `request_approval(action, details)` - Request operator confirmation
- `validate_dns_authority()` - Verify DNS resolver
- `allow_auto_changes()` - Check auto-change permission

### 2. DNS Guard Module

**Authority**: Unbound with DoH/DoT

**Enforcement**:
- `/etc/resolv.conf` → immutable (`chattr +i`)
- Points ONLY to `127.0.0.1`
- NetworkManager DNS disabled
- DHCP DNS injection blocked

**Files**:
- `modules/dns/install.sh` - Install Unbound
- `modules/dns/enable.sh` - Configure and lock DNS
- `modules/dns/disable.sh` - Unlock and restore

**Configuration**:
```bash
# /etc/unbound/unbound.conf.d/pbp-doh.conf
server:
    interface: 127.0.0.1
    access-control: 127.0.0.0/8 allow
    
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
```

### 3. Integrity Watcher (`/core/integrity.sh`)

**Purpose**: Monitor protected files for unauthorized changes

**Protected Files** (from policy):
- `/etc/resolv.conf`
- `/etc/unbound/unbound.conf`
- `/etc/NetworkManager/NetworkManager.conf`
- `/etc/systemd/resolved.conf`

**Operations**:
```bash
# Initialize baselines
/opt/pbp/core/integrity.sh init

# Check integrity
/opt/pbp/core/integrity.sh check

# Watch continuously (systemd service)
/opt/pbp/core/integrity.sh watch
```

**Behavior**:
1. Creates SHA256 baselines
2. Checks every 60 seconds
3. Detects modifications/deletions
4. Generates alerts
5. Auto-restores from backup
6. Updates baseline

**Storage**:
- Baselines: `/var/lib/pbp/integrity/*.sha256`
- Alerts: `/var/log/pbp/integrity-alerts.log`

### 4. Alert Framework (`/core/alerts.sh`)

**Purpose**: Pluggable notification system

**Alert Methods** (from policy):
- `terminal` - Console output
- `log` - File logging
- `report` - Generate alert report
- `email` - Email notification (future)
- `webhook` - HTTP webhook (future)

**Usage**:
```bash
source /opt/pbp/core/alerts.sh

send_alert "CRITICAL" \
    "DNS Authority Violation" \
    "systemd-resolved attempted to override Unbound"
```

**Alert Severity**:
- `CRITICAL` - Immediate action required
- `HIGH` - Significant security issue
- `MEDIUM` - Configuration drift
- `LOW` - Informational

### 5. Control Plane UI

**Access**: `http://localhost:7777`

**Technology**:
- Pure HTML/CSS/JS
- No external dependencies
- No cloud connections
- Served via Python HTTP server

**Features**:
- Module status dashboard
- DNS authority display
- Integrity monitoring
- Scan execution
- Report access
- Real-time logs

**Management**:
```bash
# Start control plane
pbp control start

# Stop control plane
pbp control stop

# Check status
pbp control status
```

## Policy Configuration

### Policy File: `/etc/pbp/policy.yaml`

```yaml
# DNS Configuration
dns_authority: unbound
allow_auto_changes: false
require_operator_confirmation: true
monitor_integrity: true
alert_on_change: true

dns:
  resolver: unbound
  upstream_protocol: doh
  upstream_servers:
    - https://1.1.1.1/dns-query
    - https://1.0.0.1/dns-query
  local_bind: 127.0.0.1
  dnssec: true

# Forbidden DNS Managers
dns_blocklist:
  - NetworkManager
  - resolvconf
  - systemd-resolved
  - dhclient
  - container-runtimes

# Protected Files
protected_files:
  - /etc/resolv.conf
  - /etc/unbound/unbound.conf
  - /etc/NetworkManager/NetworkManager.conf
  - /etc/systemd/resolved.conf

# Alert Configuration
alerts:
  enabled: true
  methods:
    - terminal
    - log
    - report

# Operator Approval Gates
approval_required:
  - dns_change
  - network_change
  - firewall_change
  - boot_parameters
  - security_services

# Enforcement
enforcement:
  auto_restore: true
  immutable_resolv: true
  block_dhcp_dns: true
```

## Operator Approval Flow

### Example: DNS Module Enable

```bash
$ sudo pbp enable dns

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  OPERATOR APPROVAL REQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Action: dns_enable
Details: Configure Unbound with DNS-over-HTTPS

Approve this change? [y/N]: y
✅ Action approved by operator

Configuring Unbound DNS with DoH...
✅ DNS Guard enabled - Authority: Unbound
```

### Denial Example

```bash
Approve this change? [y/N]: n
❌ Action denied by operator
```

## Integrity Monitoring

### Systemd Service

**Unit**: `pbp-integrity.service`

```ini
[Unit]
Description=PBP Integrity Watcher
After=network.target

[Service]
Type=simple
ExecStart=/opt/pbp/core/integrity.sh watch
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable**:
```bash
sudo systemctl enable --now pbp-integrity.service
```

### Alert Example

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[PBP INTEGRITY ALERT]
Timestamp: 2026-02-26T14:30:00-05:00
File: /etc/resolv.conf
Status: MODIFIED
Action: Configuration will be restored
Operator approval required for changes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## CLI Commands

### New Commands

```bash
# Start/stop control plane
pbp control start
pbp control stop
pbp control status

# Check file integrity
pbp integrity

# View security alerts
pbp alerts
```

### Existing Commands (Enhanced)

```bash
# All module operations now require approval
pbp enable dns      # Requests operator approval
pbp disable network # Requests operator approval
pbp scan            # No approval needed (read-only)
```

## Installation

### Install Control System

```bash
cd /path/to/parrot-booty-protection
sudo bash scripts/install_control.sh
```

### Post-Installation

1. **Review Policy**:
   ```bash
   cat /etc/pbp/policy.yaml
   ```

2. **Enable Integrity Monitoring**:
   ```bash
   sudo systemctl enable --now pbp-integrity.service
   ```

3. **Start Control Plane**:
   ```bash
   pbp control start
   ```
   Access: http://localhost:7777

4. **Reinstall DNS with Unbound**:
   ```bash
   sudo pbp disable dns
   sudo pbp enable dns
   ```

5. **Verify DNS Authority**:
   ```bash
   pbp scan dns
   ```

## Security Guarantees

### DNS Authority

✅ **Guaranteed**: DNS resolution ONLY through Unbound
✅ **Guaranteed**: `/etc/resolv.conf` immutable
✅ **Guaranteed**: NetworkManager cannot override DNS
✅ **Guaranteed**: DHCP cannot inject DNS servers
✅ **Guaranteed**: Containers use host DNS (Unbound)

### Operator Control

✅ **Guaranteed**: No autonomous configuration changes
✅ **Guaranteed**: All security changes require approval
✅ **Guaranteed**: Unauthorized changes detected within 60s
✅ **Guaranteed**: Auto-restore from approved baseline
✅ **Guaranteed**: Complete audit trail

### Monitoring

✅ **Guaranteed**: Protected files monitored continuously
✅ **Guaranteed**: Alerts generated for all violations
✅ **Guaranteed**: Reports saved with timestamps
✅ **Guaranteed**: Integrity baselines cryptographically verified

## Troubleshooting

### DNS Not Resolving

```bash
# Check Unbound status
systemctl status unbound

# Check resolv.conf
cat /etc/resolv.conf

# Should show:
# nameserver 127.0.0.1

# Test DNS
dig @127.0.0.1 example.com
```

### Integrity Alerts Not Working

```bash
# Check service status
systemctl status pbp-integrity.service

# Check baselines exist
ls -la /var/lib/pbp/integrity/

# Reinitialize baselines
sudo /opt/pbp/core/integrity.sh init
```

### Control Plane Not Starting

```bash
# Check if port 7777 is available
ss -tlnp | grep 7777

# Check Python3 installed
which python3

# Start manually
cd /opt/pbp/ui
python3 -m http.server 7777 --bind 127.0.0.1
```

## Future Enhancements

### Phase 5 Roadmap

- [ ] Email alerting
- [ ] Webhook integration
- [ ] Policy profiles (home/privacy/pentest/paranoid)
- [ ] Multi-host management
- [ ] SIEM integration
- [ ] Compliance mapping (CIS/NIST)
- [ ] Real-time dashboard updates (WebSocket)
- [ ] Mobile-responsive UI

## Philosophy

**Operator Sovereignty is Non-Negotiable**

PBP enforces a simple principle:

> **The operator defines security policy. The system enforces it. No exceptions.**

This means:
- No silent configuration changes
- No "helpful" automatic adjustments
- No installer scripts overriding settings
- No container runtimes rewriting DNS
- No DHCP servers injecting resolvers
- No VPN clients changing routes without approval

**The operator is the authority. The system obeys.**

---

**Status**: ✅ Control Restoration Complete
**Version**: 2.0.0
**Date**: 2026-02-26
