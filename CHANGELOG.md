# Changelog - DNS Hardening Updates

## 2026-02-06 - Major Update: Portmaster Protection & Monitoring

### New Features
- **Immutable file protection** - Prevents Portmaster/NetworkManager from modifying resolv.conf
- **Comprehensive monitoring** - Status checks, periodic monitoring, and alerts
- **Enhanced logging** - All scripts now log to timestamped files

### New Scripts
1. `scripts/dns_harden.sh` - Hardens resolv.conf with immutable flag
2. `scripts/dns_status.sh` - Manual status check with visual indicators
3. `scripts/dns_monitor.sh` - Periodic monitoring (logs changes only)
4. `scripts/dns_alert.sh` - Alert system for compromised hardening

### Updated Scripts
- `scripts/dns_restore.sh` - Now handles immutable flags automatically

### New Documentation
- `MONITORING.md` - Complete monitoring setup guide
- `TEST_RESULTS.md` - Initial test results and verification
- `DNS_Hardening_Complete_Guide.md` - Moved from home directory

### Updated Documentation
- `README.md` - Added hardening script, monitoring sections, updated all procedures
- `README_SHORT.md` - Added Portmaster protection info, monitoring quick reference
- `.gitignore` - Added new log file patterns

### Protection Against
- Portmaster DNS modifications
- NetworkManager dynamic DNS changes
- Any service attempting to modify resolv.conf (even as root)

### Monitoring Capabilities
- Manual status checks anytime
- Automatic monitoring every 5 minutes (logs changes)
- Alert system every minute (logs compromises)
- Complete audit trail in log files

### Log Files
- `/tmp/dns_harden_TIMESTAMP.log` - Hardening operations
- `/tmp/dns_restore_TIMESTAMP.log` - Restoration operations
- `/var/log/dns_hardening_monitor.log` - Status change monitoring
- `/var/log/dns_hardening_alerts.log` - Compromise alerts

### Backup System
- All operations create timestamped backups in `/root/dns_backups/`
- Backups include resolv.conf and NetworkManager configs

### Ready for Production
✅ All scripts tested and working
✅ Documentation complete
✅ Logging implemented
✅ Git ready (proper .gitignore)
