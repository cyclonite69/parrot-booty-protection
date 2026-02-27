# DNS Sovereignty Guard

**Purpose**: Continuous monitoring of DNS configuration integrity  
**Philosophy**: Observe and alert, never auto-fix  
**Status**: Production-ready

---

## Overview

DNS Sovereignty Guard is a lightweight daemon that continuously monitors DNS configuration and alerts on violations. It **never** makes autonomous changes - it observes and reports only.

### What It Monitors

1. **resolv.conf integrity** - SHA256 hash verification
2. **Immutable flag status** - `chattr +i` state
3. **Active DNS server** - Verifies 127.0.0.1
4. **Port 53 ownership** - Ensures Unbound owns the port
5. **NetworkManager DNS** - Checks `dns=none` setting
6. **Upstream configuration** - Monitors Unbound config changes

### What It Does NOT Do

- ❌ Auto-fix violations
- ❌ Modify configurations
- ❌ Override operator decisions
- ❌ Make autonomous changes

### What It DOES Do

- ✅ Detect violations within 30 seconds
- ✅ Generate alerts via multiple channels
- ✅ Log all events
- ✅ Preserve complete audit trail
- ✅ Request operator confirmation for remediation

---

## Installation

```bash
cd /home/dbcooper/parrot-booty-protection
sudo bash scripts/install_dns_guard.sh
```

**What gets installed**:
- `/opt/pbp/bin/dns-sovereignty-guard` - Guard daemon
- `/etc/systemd/system/dns-sovereignty-guard.service` - Systemd service
- `/var/lib/pbp/dns-guard/` - State directory
- `/var/log/pbp/dns-guard.log` - Activity log
- `/var/log/pbp/dns-alerts.log` - Alert log

---

## Usage

### View Status

```bash
systemctl status dns-sovereignty-guard
```

### View Live Logs

```bash
journalctl -u dns-sovereignty-guard -f
```

### View Alerts

```bash
tail -f /var/log/pbp/dns-alerts.log
```

### Manual Check

```bash
sudo /opt/pbp/bin/dns-sovereignty-guard check
```

### Reinitialize Baseline

```bash
sudo systemctl stop dns-sovereignty-guard
sudo /opt/pbp/bin/dns-sovereignty-guard init
sudo systemctl start dns-sovereignty-guard
```

---

## Alert Channels

### 1. Terminal Banner

When running interactively, alerts display as banners:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  PBP DNS SOVEREIGNTY ALERT [CRITICAL]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Time: 2026-02-26T15:30:00-05:00
Issue: resolv.conf has been modified
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Log Entry

All alerts written to `/var/log/pbp/dns-alerts.log`:

```
[2026-02-26T15:30:00-05:00] [CRITICAL] resolv.conf has been modified
```

### 3. JSON Events

Machine-readable events in `/var/lib/pbp/dns-guard/events.jsonl`:

```json
{"timestamp":"2026-02-26T15:30:00-05:00","severity":"CRITICAL","message":"resolv.conf has been modified","type":"dns_violation"}
```

### 4. Email (Optional)

Configure email alerts:

```bash
sudo tee /var/lib/pbp/dns-guard/email.conf << EOF
EMAIL_TO=admin@example.com
EOF
```

Requires `mail` command configured on system.

---

## Alert Severity Levels

| Level | Meaning | Examples |
|-------|---------|----------|
| **CRITICAL** | Immediate security concern | resolv.conf modified, immutable flag removed, DNS changed |
| **HIGH** | Significant configuration change | NetworkManager DNS enabled, Unbound config changed |
| **INFO** | Informational change | Immutable flag added |

---

## Monitoring Checks

### Check 1: resolv.conf Hash

**Frequency**: Every 30 seconds  
**Baseline**: SHA256 hash stored at initialization  
**Alert**: If file content changes

### Check 2: Immutable Flag

**Frequency**: Every 30 seconds  
**Baseline**: `lsattr` output stored at initialization  
**Alert**: If flag removed or added

### Check 3: DNS Server

**Frequency**: Every 30 seconds  
**Baseline**: Expected DNS (127.0.0.1)  
**Alert**: If nameserver changes

### Check 4: Port 53 Ownership

**Frequency**: Every 30 seconds  
**Check**: `ss -tlnp | grep :53`  
**Alert**: If not owned by Unbound

### Check 5: NetworkManager DNS

**Frequency**: Every 30 seconds  
**Check**: `/etc/NetworkManager/conf.d/90-dns-hardening.conf`  
**Alert**: If `dns=none` not present

### Check 6: Upstream Configuration

**Frequency**: Every 30 seconds  
**Baseline**: Unbound config hash  
**Alert**: If Unbound configuration changes

---

## Operator Workflow

### When Alert Occurs

1. **Review alert**:
   ```bash
   tail /var/log/pbp/dns-alerts.log
   ```

2. **Investigate cause**:
   ```bash
   journalctl -n 100 | grep -i dns
   ```

3. **Verify current state**:
   ```bash
   dns-reality-check  # If installed
   ```

4. **Decide action**:
   - If legitimate change: Reinitialize baseline
   - If unauthorized: Restore configuration

5. **Restore if needed**:
   ```bash
   sudo dns-restore  # If installed
   ```

6. **Reinitialize baseline**:
   ```bash
   sudo systemctl stop dns-sovereignty-guard
   sudo /opt/pbp/bin/dns-sovereignty-guard init
   sudo systemctl start dns-sovereignty-guard
   ```

---

## Configuration

### Check Interval

Default: 30 seconds

To change, edit `/etc/systemd/system/dns-sovereignty-guard.service`:

```ini
[Service]
Environment="CHECK_INTERVAL=60"
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart dns-sovereignty-guard
```

### Email Alerts

Create `/var/lib/pbp/dns-guard/email.conf`:

```bash
EMAIL_TO=admin@example.com
```

Requires working `mail` command.

---

## Integration with PBP

### Works With

- ✅ Existing DNS hardening scripts
- ✅ `dns-reality-check` command
- ✅ `dns-restore` command
- ✅ `dns-monitoring-status` command
- ✅ Unbound service
- ✅ NetworkManager hardening

### Does Not Conflict With

- ✅ Existing cron-based monitors
- ✅ Manual DNS changes (after baseline reinit)
- ✅ System updates
- ✅ Network reconnections

---

## Troubleshooting

### Service Won't Start

```bash
# Check logs
journalctl -u dns-sovereignty-guard -n 50

# Check permissions
ls -la /var/lib/pbp/dns-guard
ls -la /var/log/pbp

# Reinitialize
sudo /opt/pbp/bin/dns-sovereignty-guard init
```

### False Positives

If legitimate changes trigger alerts:

```bash
# Stop guard
sudo systemctl stop dns-sovereignty-guard

# Make your changes
# ...

# Reinitialize baseline
sudo /opt/pbp/bin/dns-sovereignty-guard init

# Restart guard
sudo systemctl start dns-sovereignty-guard
```

### No Alerts Appearing

```bash
# Check service is running
systemctl status dns-sovereignty-guard

# Check logs
tail -f /var/log/pbp/dns-guard.log

# Trigger test alert (modify resolv.conf)
sudo chattr -i /etc/resolv.conf
echo "# test" | sudo tee -a /etc/resolv.conf
# Should see alert within 30 seconds

# Restore
sudo dns-restore
```

---

## Uninstallation

```bash
sudo bash scripts/uninstall_dns_guard.sh
```

**Removes**:
- Systemd service
- Guard daemon
- Optionally: logs and state data

---

## Technical Details

### Architecture

```
dns-sovereignty-guard (daemon)
    ↓
Monitor Loop (30s interval)
    ↓
6 Checks → Violations?
    ↓ YES
Alert Channels:
    - Terminal
    - Log file
    - JSON events
    - Email (optional)
```

### State Files

```
/var/lib/pbp/dns-guard/
├── resolv.hash           # SHA256 of resolv.conf
├── immutable.state       # lsattr output
├── expected_dns.txt      # Expected nameserver
├── unbound.hash          # SHA256 of unbound.conf
├── events.jsonl          # JSON event log
└── email.conf            # Email config (optional)
```

### Log Files

```
/var/log/pbp/
├── dns-guard.log         # Activity log
└── dns-alerts.log        # Alert log
```

---

## Security Considerations

### What Guard Protects

- ✅ Detects unauthorized DNS changes
- ✅ Alerts on configuration tampering
- ✅ Monitors service integrity
- ✅ Tracks NetworkManager behavior

### What Guard Does NOT Protect

- ❌ Does not prevent changes (use immutability for that)
- ❌ Does not auto-remediate (operator decision required)
- ❌ Does not block network-level attacks

### Defense-in-Depth

Guard is **one layer** in DNS security:

1. **Prevention**: Immutable resolv.conf, NetworkManager disabled
2. **Detection**: DNS Sovereignty Guard (this tool)
3. **Response**: Operator-driven remediation

---

## Performance

- **CPU**: Negligible (sleeps 30s between checks)
- **Memory**: ~5MB
- **Disk**: Minimal (logs rotate via logrotate)
- **Network**: None (local checks only)

---

## Comparison with Existing Monitoring

| Feature | Cron Monitors | DNS Guard |
|---------|---------------|-----------|
| Check interval | 30 minutes | 30 seconds |
| Detection speed | Up to 30 min | Up to 30 sec |
| Alert channels | Log only | Terminal, log, JSON, email |
| Real-time | No | Yes |
| Systemd integration | No | Yes |
| JSON events | No | Yes |

**Recommendation**: Use both for defense-in-depth.

---

## Examples

### Normal Operation

```bash
$ sudo journalctl -u dns-sovereignty-guard -n 5
Feb 26 15:30:00 parrot dns-sovereignty-guard[1234]: [2026-02-26T15:30:00-05:00] DNS Sovereignty Guard started (check interval: 30s)
Feb 26 15:30:00 parrot dns-sovereignty-guard[1234]: [2026-02-26T15:30:00-05:00] Baseline created
```

### Alert Example

```bash
$ sudo tail -f /var/log/pbp/dns-alerts.log
[2026-02-26T15:30:45-05:00] [CRITICAL] resolv.conf has been modified
[2026-02-26T15:31:15-05:00] [CRITICAL] Immutable flag removed from resolv.conf
```

### JSON Events

```bash
$ sudo tail -f /var/lib/pbp/dns-guard/events.jsonl
{"timestamp":"2026-02-26T15:30:45-05:00","severity":"CRITICAL","message":"resolv.conf has been modified","type":"dns_violation"}
```

---

## Philosophy

**Operator Sovereignty First**

DNS Sovereignty Guard embodies PBP's core principle:

> **The system observes. The operator decides.**

- Never assumes it knows better than the operator
- Never makes autonomous changes
- Always provides information for informed decisions
- Always respects operator intent

**This is not automation. This is augmentation.**

---

## Support

- **Logs**: `/var/log/pbp/dns-guard.log`
- **Alerts**: `/var/log/pbp/dns-alerts.log`
- **Events**: `/var/lib/pbp/dns-guard/events.jsonl`
- **Status**: `systemctl status dns-sovereignty-guard`

---

**Version**: 1.0.0  
**Date**: 2026-02-26  
**Status**: Production-ready  
**Philosophy**: Observe, alert, never auto-fix
