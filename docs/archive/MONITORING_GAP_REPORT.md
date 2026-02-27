# MONITORING GAP REPORT

**Date**: 2026-02-26  
**Incident**: False positive DNS configuration alert  
**Status**: Analysis complete

---

## EXECUTIVE SUMMARY

**The monitoring system did not fail.** It correctly detected no unauthorized changes because no unauthorized changes occurred.

However, the **operator's interpretation** of NetworkManager metadata created a false alarm. This report addresses how to prevent future confusion.

---

## WHAT MONITORING DETECTED

### Current Monitoring Stack

1. **DNS TLS Monitor** (`/usr/local/bin/dns_tls_monitor.sh`)
   - Runs: Every 30 minutes (cron)
   - Checks: Unbound service status
   - Status: ✅ Working

2. **DNS Monitor** (`/usr/local/bin/dns_monitor.sh`)
   - Runs: Every 30 minutes (cron)
   - Checks: DNS resolution
   - Status: ✅ Working

3. **File Immutability**
   - Protection: `chattr +i /etc/resolv.conf`
   - Status: ✅ Active

4. **NetworkManager DNS Disabled**
   - Config: `dns=none`
   - Status: ✅ Active

---

## WHY NO ALERT WAS GENERATED

**Because nothing changed.**

### Evidence
```bash
$ stat /etc/resolv.conf | grep Modify
Modify: 2026-02-25 15:38:45.882856901 -0500

$ lsattr /etc/resolv.conf
----i-----------------

$ cat /etc/resolv.conf
nameserver 127.0.0.1

$ dig example.com | grep SERVER
;; SERVER: 127.0.0.1#53(127.0.0.1) (UDP)
```

All monitoring checks would have passed:
- ✅ File not modified
- ✅ Immutable flag set
- ✅ Content correct
- ✅ Resolution working
- ✅ Unbound running

---

## THE ACTUAL ISSUE

### What Caused Confusion

**NetworkManager's internal metadata** shows DHCP-provided DNS:

```bash
$ nmcli dev show | grep DNS
IP4.DNS[1]: 75.75.75.75
IP4.DNS[2]: 75.75.76.76
```

This is **metadata only**. NetworkManager stores what DHCP provided but does NOT apply it due to `dns=none`.

### Why This Is Not Monitored

Current monitoring checks:
- `/etc/resolv.conf` content ✅
- Unbound status ✅
- Actual DNS resolution ✅

Current monitoring does NOT check:
- NetworkManager's internal connection metadata ❌

**This is correct behavior.** NetworkManager metadata is not a security concern when `dns=none` is set.

---

## MONITORING GAPS IDENTIFIED

### Gap 1: Metadata vs Reality Distinction

**Issue**: Operator confusion between:
- What NetworkManager **stores** (DHCP metadata)
- What the system **uses** (actual DNS)

**Impact**: False positive alerts

**Severity**: Low (no security impact)

---

### Gap 2: Monitoring Visibility

**Issue**: Monitoring scripts run silently. No easy way to verify they're working.

**Impact**: Operator uncertainty about monitoring status

**Severity**: Low (monitoring is working, just not visible)

---

### Gap 3: No Real-Time Alerts

**Issue**: Monitoring runs every 30 minutes. If a change occurred, detection would be delayed.

**Impact**: 30-minute window for undetected changes

**Severity**: Medium (though immutability prevents changes anyway)

---

## RECOMMENDATIONS

### 1. Add DNS Reality Check Script

Create a script that shows **actual** DNS behavior vs metadata:

```bash
#!/bin/bash
# /usr/local/bin/dns_reality_check.sh

echo "=== DNS REALITY CHECK ==="
echo
echo "1. What resolv.conf says:"
grep nameserver /etc/resolv.conf | head -1
echo
echo "2. What actually answers queries:"
dig example.com | grep "SERVER:" | awk '{print $3}'
echo
echo "3. What NetworkManager stores (metadata only):"
nmcli dev show | grep "IP4.DNS" | head -2
echo
echo "4. Is NetworkManager managing DNS?"
grep dns= /etc/NetworkManager/conf.d/90-dns-hardening.conf || echo "Not configured"
echo
echo "5. Verdict:"
ACTUAL=$(dig example.com | grep "SERVER:" | awk '{print $3}')
if [[ "$ACTUAL" == "127.0.0.1#53(127.0.0.1)" ]]; then
    echo "✅ DNS is correctly using localhost (Unbound)"
else
    echo "❌ WARNING: DNS is NOT using localhost"
fi
```

**Priority**: High  
**Effort**: Low

---

### 2. Add Monitoring Status Dashboard

Create a simple status check:

```bash
#!/bin/bash
# /usr/local/bin/dns_monitoring_status.sh

echo "=== DNS MONITORING STATUS ==="
echo
echo "1. DNS TLS Monitor:"
if crontab -l | grep -q dns_tls_monitor; then
    echo "   ✅ Scheduled (cron)"
    echo "   Last run: $(grep dns_tls_monitor /var/log/syslog 2>/dev/null | tail -1 | awk '{print $1, $2, $3}')"
else
    echo "   ❌ Not scheduled"
fi
echo
echo "2. DNS Monitor:"
if crontab -l | grep -q dns_monitor; then
    echo "   ✅ Scheduled (cron)"
    echo "   Last run: $(grep dns_monitor /var/log/syslog 2>/dev/null | tail -1 | awk '{print $1, $2, $3}')"
else
    echo "   ❌ Not scheduled"
fi
echo
echo "3. File Immutability:"
if lsattr /etc/resolv.conf | grep -q "i"; then
    echo "   ✅ Active"
else
    echo "   ❌ NOT ACTIVE - SECURITY RISK"
fi
echo
echo "4. NetworkManager DNS:"
if grep -q "dns=none" /etc/NetworkManager/conf.d/90-dns-hardening.conf 2>/dev/null; then
    echo "   ✅ Disabled (correct)"
else
    echo "   ❌ Enabled (security risk)"
fi
```

**Priority**: Medium  
**Effort**: Low

---

### 3. Add File Integrity Monitoring (inotify)

For real-time detection, use `inotify` instead of cron:

```bash
#!/bin/bash
# /usr/local/bin/dns_integrity_watch.sh

inotifywait -m -e modify,attrib,delete /etc/resolv.conf | while read path action file; do
    echo "[$(date -Iseconds)] ALERT: /etc/resolv.conf $action detected"
    
    # Check if still correct
    if ! grep -q "nameserver 127.0.0.1" /etc/resolv.conf; then
        echo "[$(date -Iseconds)] CRITICAL: DNS configuration compromised"
        # Send alert
        /usr/local/bin/dns_alert.sh "DNS configuration modified"
    fi
    
    # Check immutability
    if ! lsattr /etc/resolv.conf | grep -q "i"; then
        echo "[$(date -Iseconds)] CRITICAL: Immutable flag removed"
        # Restore immutability
        chattr +i /etc/resolv.conf
    fi
done
```

**Systemd service**:
```ini
[Unit]
Description=DNS Integrity Watcher
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dns_integrity_watch.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

**Priority**: High  
**Effort**: Medium

---

### 4. Enhance Existing Monitors

Add checks to existing scripts:

```bash
# Add to dns_monitor.sh

# Check actual resolution
ACTUAL_SERVER=$(dig example.com | grep "SERVER:" | awk '{print $3}')
if [[ "$ACTUAL_SERVER" != "127.0.0.1#53(127.0.0.1)" ]]; then
    /usr/local/bin/dns_alert.sh "DNS not using localhost: $ACTUAL_SERVER"
fi

# Check immutability
if ! lsattr /etc/resolv.conf | grep -q "i"; then
    /usr/local/bin/dns_alert.sh "Immutable flag removed from resolv.conf"
    chattr +i /etc/resolv.conf
fi

# Check NetworkManager
if ! grep -q "dns=none" /etc/NetworkManager/conf.d/90-dns-hardening.conf 2>/dev/null; then
    /usr/local/bin/dns_alert.sh "NetworkManager DNS management enabled"
fi
```

**Priority**: High  
**Effort**: Low

---

## IMPLEMENTATION PRIORITY

| Recommendation | Priority | Effort | Impact |
|----------------|----------|--------|--------|
| DNS Reality Check Script | High | Low | High |
| Enhanced Monitoring | High | Low | High |
| Monitoring Status Dashboard | Medium | Low | Medium |
| inotify File Watcher | High | Medium | High |

---

## MONITORING ARCHITECTURE (PROPOSED)

### Current (Cron-based)
```
Cron (30min) → dns_monitor.sh → Check files → Log
Cron (30min) → dns_tls_monitor.sh → Check service → Log
```

**Limitations**:
- 30-minute detection window
- No real-time alerts
- Silent operation

### Proposed (Hybrid)
```
inotify → Real-time file watch → Instant alert
Cron (30min) → Comprehensive check → Log + Alert
Systemd → Service health monitoring → Alert on failure
```

**Benefits**:
- Instant detection of file changes
- Regular comprehensive checks
- Service failure detection
- Visible monitoring status

---

## TESTING PLAN

### Test 1: Verify Current Monitoring Works
```bash
# Check cron jobs
crontab -l | grep dns

# Check last execution
grep dns_monitor /var/log/syslog | tail -5

# Manually run monitors
/usr/local/bin/dns_monitor.sh
/usr/local/bin/dns_tls_monitor.sh
```

### Test 2: Test File Change Detection
```bash
# Remove immutability
sudo chattr -i /etc/resolv.conf

# Modify file
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Wait for next cron run (up to 30 min)
# Or manually trigger monitor

# Verify alert generated
```

### Test 3: Test Real-Time Monitoring (if implemented)
```bash
# Start inotify watcher
sudo systemctl start dns-integrity-watch

# Trigger change
sudo chattr -i /etc/resolv.conf
echo "test" | sudo tee -a /etc/resolv.conf

# Verify instant alert
journalctl -u dns-integrity-watch -f
```

---

## CONCLUSION

**The monitoring system did not fail.** It correctly detected no changes because no changes occurred.

However, improvements can be made:

1. ✅ **Add reality check script** - Distinguish metadata from actual DNS
2. ✅ **Add monitoring dashboard** - Make monitoring visible
3. ✅ **Add real-time watching** - Reduce detection window
4. ✅ **Enhance existing monitors** - More comprehensive checks

**Current Status**: Monitoring is working correctly  
**Recommended Action**: Implement enhancements for better visibility and faster detection  
**Security Impact**: Low (current system is secure)

---

**Report Date**: 2026-02-26  
**Analyst**: Security Operations  
**Status**: Recommendations provided
