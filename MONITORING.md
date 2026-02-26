# 📡 The Crow's Nest: DNS Monitoring Setup

Keep a sharp lookout for anyone trying to scuttle your DNS defenses.

## 🧭 Monitoring Tools

1. **`dns_status.sh`** - Manual inspection of the rigging.
2. **`dns_monitor.sh`** - Periodic lookout (logs state changes only).
3. **`dns_alert.sh`** - Sound the alarm if defenses are breached!
4. **`dns_tls_monitor.sh`** - Verify the encryption of our signal.

---

## 🏗️ Deployment (The War Room)

The recommended way to man the Crow's Nest is through **Module 40** in the dashboard:
```bash
sudo ./hardening-framework/hardenctl
# Choose '40_dns_monitoring' and 'Batten down the hatches (Enable)'
```

---

## 📜 The Captain's Ledger (Logs)

| Log File | Purpose | View Command |
|----------|---------|--------------|
| `/var/log/dns_hardening_monitor.log` | Status change history | `cat /var/log/dns_hardening_monitor.log` |
| `/var/log/dns_hardening_alerts.log` | **Security Alerts** | `tail -f /var/log/dns_hardening_alerts.log` |
| `/var/log/hardenctl.log` | Framework install logs | `tail /var/log/hardenctl.log` |

*Tip: Use **Module 90 (Log Explorer)** in `hardenctl` to browse all these logs in a single menu.*

---

## 🏴‍☠️ Manual Status Check

Inspect your defenses anytime with:
```bash
./scripts/dns_status.sh
```

**Expected Output:**
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

## 🚨 Alerts & Indicators

### Monitor Log (State Changes)
Logs only when the status of your "booty" protection changes.
```
[2026-02-06 12:47:18] ✓ DNS hardening RESTORED
[2026-02-06 14:23:45] ✗ DNS hardening COMPROMISED - immutable flag removed
[2026-02-06 14:30:00] ✓ DNS hardening RESTORED
```

### Alert Log (Immediate Threats)
Logs every time the alert script finds a vulnerability.
```
[2026-02-06 12:47:54] ALERT: Immutable flag REMOVED from /etc/resolv.conf
[2026-02-06 13:15:22] ALERT: Unbound service is NOT running
```

---

## 🛠️ Testing the Alarm

To ensure your lookout is awake:

1. **Simulate a breach**:
   ```bash
   sudo chattr -i /etc/resolv.conf
   ```

2. **Run the monitor manually**:
   ```bash
   sudo /usr/local/bin/dns_monitor.sh
   ```

3. **Check the Ledger**:
   ```bash
   sudo tail /var/log/dns_hardening_monitor.log
   ```

4. **Restore defenses**:
   ```bash
   sudo ./scripts/dns_harden.sh
   ```

---

## ⚓ Disabling the Lookout

If you must lower your guard:

**Option 1: Use the Dashboard (Recommended)**
Use **Module 40** and select **"Abandon defenses (Disable)"**.

**Option 2: Manual scuttling**
```bash
sudo ./scripts/dns_monitoring_uninstall.sh
```
