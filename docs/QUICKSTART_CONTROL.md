# PBP Control Restoration - Quick Start

## Installation

```bash
cd /path/to/parrot-booty-protection
sudo bash scripts/install_control.sh
```

## Essential Commands

```bash
# Start control plane
pbp control start

# Check integrity
pbp integrity

# View alerts
pbp alerts

# Enable DNS Guard (Unbound)
sudo pbp enable dns

# Check DNS status
pbp scan dns
```

## Access Control Plane

Open browser: **http://localhost:7777**

## Policy Location

**File**: `/etc/pbp/policy.yaml`

**Key Settings**:
- `dns_authority: unbound` - DNS resolver
- `require_operator_confirmation: true` - Approval required
- `allow_auto_changes: false` - No autonomous changes
- `monitor_integrity: true` - File monitoring enabled

## Protected Files

- `/etc/resolv.conf` - DNS configuration (immutable)
- `/etc/unbound/unbound.conf` - Unbound config
- `/etc/NetworkManager/NetworkManager.conf` - Network manager
- `/etc/systemd/resolved.conf` - systemd-resolved

## Integrity Monitoring

```bash
# Enable monitoring service
sudo systemctl enable --now pbp-integrity.service

# Check status
systemctl status pbp-integrity.service

# View alerts
tail -f /var/log/pbp/integrity-alerts.log
```

## DNS Authority Verification

```bash
# Check resolver
cat /etc/resolv.conf
# Should show: nameserver 127.0.0.1

# Test DNS
dig @127.0.0.1 example.com

# Check Unbound
systemctl status unbound

# Verify DoT/DoH
pbp scan dns
```

## Operator Approval

All security changes require approval:

```bash
$ sudo pbp enable network

⚠️  OPERATOR APPROVAL REQUIRED
Action: network_enable
Details: Configure nftables firewall

Approve this change? [y/N]: y
✅ Action approved by operator
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Operator (You)                  │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      Policy Engine                      │
│  /etc/pbp/policy.yaml                   │
└─────────────┬───────────────────────────┘
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
┌────────┐ ┌────────┐ ┌────────┐
│  DNS   │ │Network │ │Rootkit │
│ Guard  │ │ Guard  │ │ Guard  │
└────────┘ └────────┘ └────────┘
    │         │         │
    └─────────┼─────────┘
              ▼
┌─────────────────────────────────────────┐
│     Integrity Watcher                   │
│  Monitors protected files               │
│  Auto-restores on violation             │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      Alert Framework                    │
│  Terminal | Log | Report | Email        │
└─────────────────────────────────────────┘
```

## Key Principles

1. **Single Source of Truth**: Policy file defines all behavior
2. **Operator Approval**: No autonomous changes
3. **Continuous Monitoring**: Protected files watched
4. **Auto-Restoration**: Violations corrected automatically
5. **Complete Audit Trail**: All actions logged

## Troubleshooting

### DNS not working
```bash
sudo systemctl restart unbound
sudo chattr -i /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
sudo chattr +i /etc/resolv.conf
```

### Integrity alerts not appearing
```bash
sudo systemctl restart pbp-integrity.service
sudo /opt/pbp/core/integrity.sh init
```

### Control plane won't start
```bash
# Check if port in use
ss -tlnp | grep 7777

# Kill existing process
sudo pkill -f "python3.*7777"

# Restart
pbp control restart
```

## Next Steps

1. ✅ Install control system
2. ✅ Enable integrity monitoring
3. ✅ Start control plane
4. ✅ Reinstall DNS with Unbound
5. ✅ Verify all modules
6. ✅ Review alerts regularly

---

**Documentation**: See `docs/CONTROL_RESTORATION.md` for complete details

**Support**: This is operator-first security. You are in control.
