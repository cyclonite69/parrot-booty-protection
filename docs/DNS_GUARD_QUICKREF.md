# DNS Sovereignty Guard - Quick Reference

## Installation

```bash
sudo bash scripts/install_dns_guard.sh
```

## Commands

```bash
# View status
systemctl status dns-sovereignty-guard

# View live logs
journalctl -u dns-sovereignty-guard -f

# View alerts
tail -f /var/log/pbp/dns-alerts.log

# Manual check
sudo /opt/pbp/bin/dns-sovereignty-guard check

# Reinitialize baseline (after legitimate changes)
sudo systemctl stop dns-sovereignty-guard
sudo /opt/pbp/bin/dns-sovereignty-guard init
sudo systemctl start dns-sovereignty-guard
```

## What It Monitors

- ✅ resolv.conf hash
- ✅ Immutable flag status
- ✅ Active DNS server (127.0.0.1)
- ✅ Port 53 ownership (Unbound)
- ✅ NetworkManager DNS setting
- ✅ Unbound configuration

## Alert Channels

- Terminal banner (if interactive)
- `/var/log/pbp/dns-alerts.log`
- `/var/lib/pbp/dns-guard/events.jsonl`
- Email (if configured)

## When Alert Occurs

1. Review: `tail /var/log/pbp/dns-alerts.log`
2. Investigate: `journalctl -n 100 | grep -i dns`
3. Verify: `dns-reality-check`
4. Restore: `sudo dns-restore` (if needed)
5. Reinitialize: See commands above

## Email Alerts (Optional)

```bash
echo 'EMAIL_TO=admin@example.com' | sudo tee /var/lib/pbp/dns-guard/email.conf
```

## Uninstall

```bash
sudo bash scripts/uninstall_dns_guard.sh
```

## Philosophy

**Observes and alerts. Never auto-fixes.**

---

**Check Interval**: 30 seconds  
**Detection Window**: ≤30 seconds  
**Auto-Fix**: NEVER  
**Operator Approval**: ALWAYS REQUIRED
