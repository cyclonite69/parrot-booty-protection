# DNS Hardening Monitoring Setup

## Scripts Created

1. **`dns_status.sh`** - Manual status check
2. **`dns_monitor.sh`** - Periodic monitoring (logs changes only)
3. **`dns_alert.sh`** - Alert on compromise

---

## 1. Manual Status Check

Check hardening status anytime:
```bash
./scripts/dns_status.sh
```

**Output:**
```
=== DNS Hardening Status Check ===
✓ Immutable flag: ACTIVE
✓ Resolv.conf: Using localhost resolver
✓ NetworkManager: DNS management disabled
✓ Unbound: Running
✓ DNS Resolution: Working
Status: HARDENED
```

---

## 2. Setup Periodic Monitoring

Monitors every 5 minutes, logs only when status changes:

```bash
# Install monitor
sudo cp scripts/dns_monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dns_monitor.sh

# Create cron job (runs every 5 minutes)
echo "*/5 * * * * /usr/local/bin/dns_monitor.sh" | sudo crontab -
```

**Log location:** `/var/log/dns_hardening_monitor.log`

**View logs:**
```bash
sudo tail -f /var/log/dns_hardening_monitor.log
```

---

## 3. Setup Alerts

Checks every minute, alerts if compromised:

```bash
# Install alert script
sudo cp scripts/dns_alert.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dns_alert.sh

# Create cron job (runs every minute)
(sudo crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/dns_alert.sh") | sudo crontab -
```

**Alert log:** `/var/log/dns_hardening_alerts.log`

**View alerts:**
```bash
sudo tail -f /var/log/dns_hardening_alerts.log
```

---

## Combined Setup (All Three)

**Option 1: Use installer (recommended)**
```bash
sudo ./scripts/dns_monitoring_install.sh
```
Interactive menu with interval options.

**Option 2: Manual setup**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Install monitoring and alerts
sudo cp scripts/dns_monitor.sh /usr/local/bin/
sudo cp scripts/dns_alert.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dns_*.sh

# Setup cron jobs (every 30 minutes)
(sudo crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/dns_monitor.sh"; echo "*/30 * * * * /usr/local/bin/dns_alert.sh") | sudo crontab -

# Verify cron jobs
sudo crontab -l
```

---

## Log Files

| Log File | Purpose | Update Frequency |
|----------|---------|------------------|
| `/tmp/dns_harden_*.log` | Hardening script runs | On-demand |
| `/var/log/dns_hardening_monitor.log` | Status changes | When changed |
| `/var/log/dns_hardening_alerts.log` | Compromise alerts | When compromised |

### Log Examples

#### Monitor Log (Only logs state changes)
```
[2026-02-06 12:47:18] ✓ DNS hardening RESTORED
[2026-02-06 14:23:45] ✗ DNS hardening COMPROMISED - immutable flag removed
  Resolv.conf content: nameserver 8.8.8.8
[2026-02-06 14:30:00] ✓ DNS hardening RESTORED
```

#### Alert Log (Only logs when compromised)
```
[2026-02-06 12:47:54] ALERT: Immutable flag REMOVED from /etc/resolv.conf
[2026-02-06 12:47:54] ALERT: Current nameservers: nameserver 8.8.8.8
[2026-02-06 13:15:22] ALERT: Unbound service is NOT running
```

#### Hardening Log (Created each run)
```
[12:48:03] DNS Hardening Script Started
[12:48:03] Logfile: /tmp/dns_harden_20260206_124803.log
[12:48:03] Backing up current configs
[12:48:03] Removing immutable flag if exists
[12:48:03] Creating hardened resolv.conf
[12:48:03] Setting immutable flag on resolv.conf
[12:48:04] DNS test PASSED

=== DNS HARDENING COMPLETE ===
Backup: /root/dns_backups/harden_20260206_124803
```

---

## Testing

### Test status check:
```bash
./scripts/dns_status.sh
```

### Test monitor (simulate compromise):
```bash
# Remove immutable flag
sudo chattr -i /etc/resolv.conf

# Wait 5 minutes or run manually
sudo /usr/local/bin/dns_monitor.sh

# Check log
sudo tail /var/log/dns_hardening_monitor.log

# Restore hardening
sudo ./scripts/dns_harden.sh
```

### Test alerts:
```bash
# Remove immutable flag
sudo chattr -i /etc/resolv.conf

# Run alert script
sudo /usr/local/bin/dns_alert.sh

# Check alert log
sudo tail /var/log/dns_hardening_alerts.log

# Restore
sudo ./scripts/dns_harden.sh
```

---

## Disable Monitoring

**Option 1: Use uninstaller (recommended)**
```bash
sudo ./scripts/dns_monitoring_uninstall.sh
```
Removes cron jobs, scripts, and optionally log files.

**Option 2: Manual removal**
```bash
# Remove cron jobs
sudo crontab -r

# Remove scripts
sudo rm /usr/local/bin/dns_monitor.sh
sudo rm /usr/local/bin/dns_alert.sh

# Optional: Remove logs
sudo rm /var/log/dns_hardening_*.log
sudo rm /var/run/dns_hardening.state
```

---

## Quick Reference

```bash
# Check status
./scripts/dns_status.sh

# View monitor log
sudo tail -f /var/log/dns_hardening_monitor.log

# View alerts
sudo tail -f /var/log/dns_hardening_alerts.log

# Re-harden if compromised
sudo ./scripts/dns_harden.sh
```
