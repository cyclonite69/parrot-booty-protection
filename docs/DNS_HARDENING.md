# DNS HARDENING - ENHANCED PROTECTION

**Date**: 2026-02-26  
**Status**: Current system is secure; enhancements optional  
**Priority**: Medium (improvements, not fixes)

---

## EXECUTIVE SUMMARY

The current DNS configuration is **already secure**. This document provides **optional enhancements** for defense-in-depth.

**Current Protection Layers**:
1. ✅ Immutable `/etc/resolv.conf` (`chattr +i`)
2. ✅ NetworkManager DNS disabled (`dns=none`)
3. ✅ Unbound localhost-only binding
4. ✅ DNS-over-TLS upstream
5. ✅ DNSSEC validation
6. ✅ Periodic monitoring (cron)

**Proposed Enhancements**:
1. Real-time file integrity monitoring (inotify)
2. Automated recovery on tampering
3. Enhanced monitoring visibility
4. Systemd service hardening

---

## ENHANCEMENT 1: Real-Time File Integrity Monitoring

### Current State
- Monitoring runs every 30 minutes (cron)
- Detection window: up to 30 minutes

### Enhancement
- Real-time monitoring using `inotify`
- Instant detection and recovery

### Implementation

**Install inotify-tools**:
```bash
sudo apt-get install -y inotify-tools
```

**Create watcher script**:
```bash
sudo tee /usr/local/bin/dns_integrity_watch.sh << 'EOF'
#!/bin/bash
# Real-time DNS integrity watcher

LOG="/var/log/dns_integrity.log"
ALERT_SCRIPT="/usr/local/bin/dns_alert.sh"

log() {
    echo "[$(date -Iseconds)] $*" | tee -a "$LOG"
}

restore_resolv() {
    log "ALERT: Restoring /etc/resolv.conf"
    chattr -i /etc/resolv.conf 2>/dev/null
    cat > /etc/resolv.conf << 'RESOLV'
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
RESOLV
    chattr +i /etc/resolv.conf
    log "INFO: /etc/resolv.conf restored and locked"
    
    # Send alert
    if [ -x "$ALERT_SCRIPT" ]; then
        "$ALERT_SCRIPT" "DNS configuration was modified and has been restored"
    fi
}

check_integrity() {
    # Check content
    if ! grep -q "nameserver 127.0.0.1" /etc/resolv.conf; then
        log "CRITICAL: /etc/resolv.conf content compromised"
        restore_resolv
        return 1
    fi
    
    # Check immutability
    if ! lsattr /etc/resolv.conf 2>/dev/null | grep -q "i"; then
        log "WARNING: Immutable flag removed"
        chattr +i /etc/resolv.conf
        log "INFO: Immutable flag restored"
    fi
    
    return 0
}

log "INFO: DNS integrity watcher started"

# Initial check
check_integrity

# Watch for changes
inotifywait -m -e modify,attrib,delete,move /etc/resolv.conf 2>/dev/null | while read path action file; do
    log "ALERT: /etc/resolv.conf $action detected"
    check_integrity
done
EOF

sudo chmod +x /usr/local/bin/dns_integrity_watch.sh
```

**Create systemd service**:
```bash
sudo tee /etc/systemd/system/dns-integrity-watch.service << 'EOF'
[Unit]
Description=DNS Integrity Watcher
After=network.target
Documentation=file:///home/dbcooper/parrot-booty-protection/DNS_HARDENING.md

[Service]
Type=simple
ExecStart=/usr/local/bin/dns_integrity_watch.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/etc/resolv.conf /var/log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable dns-integrity-watch.service
sudo systemctl start dns-integrity-watch.service
```

**Verify**:
```bash
sudo systemctl status dns-integrity-watch
sudo journalctl -u dns-integrity-watch -f
```

**Benefits**:
- ✅ Instant detection (no 30-minute window)
- ✅ Automatic recovery
- ✅ Alert generation
- ✅ Complete audit trail

---

## ENHANCEMENT 2: DNS Reality Check Command

### Purpose
Distinguish between NetworkManager metadata and actual DNS usage.

### Implementation

```bash
sudo tee /usr/local/bin/dns-reality-check << 'EOF'
#!/bin/bash
# DNS Reality Check - Show actual DNS behavior vs metadata

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS REALITY CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "1. System DNS Configuration (/etc/resolv.conf):"
grep nameserver /etc/resolv.conf | head -3
echo

echo "2. Actual DNS Server Answering Queries:"
ACTUAL=$(dig +short +time=2 example.com @$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}') 2>/dev/null)
if [ -n "$ACTUAL" ]; then
    echo "   ✅ Resolving via: $(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')"
    dig example.com 2>/dev/null | grep "SERVER:" | sed 's/^/   /'
else
    echo "   ❌ DNS resolution failed"
fi
echo

echo "3. NetworkManager Metadata (DHCP-provided, may not be used):"
NM_DNS=$(nmcli dev show 2>/dev/null | grep "IP4.DNS" | head -2)
if [ -n "$NM_DNS" ]; then
    echo "$NM_DNS" | sed 's/^/   /'
    echo "   ℹ️  These are stored by NetworkManager but NOT used for resolution"
else
    echo "   (No DHCP DNS metadata)"
fi
echo

echo "4. NetworkManager DNS Management:"
if grep -q "dns=none" /etc/NetworkManager/conf.d/90-dns-hardening.conf 2>/dev/null; then
    echo "   ✅ DISABLED (correct - NetworkManager will not modify DNS)"
else
    echo "   ⚠️  ENABLED (NetworkManager may modify DNS)"
fi
echo

echo "5. File Immutability:"
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "i"; then
    echo "   ✅ ACTIVE (file cannot be modified)"
else
    echo "   ❌ INACTIVE (file can be modified - SECURITY RISK)"
fi
echo

echo "6. Unbound Status:"
if systemctl is-active --quiet unbound; then
    echo "   ✅ RUNNING"
    if ss -tlnp 2>/dev/null | grep -q ":53.*unbound"; then
        echo "   ✅ Listening on port 53"
    else
        echo "   ❌ Not listening on port 53"
    fi
else
    echo "   ❌ NOT RUNNING"
fi
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "VERDICT:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

RESOLV_NS=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')
ACTUAL_SERVER=$(dig example.com 2>/dev/null | grep "SERVER:" | awk '{print $3}' | cut -d'#' -f1)

if [[ "$RESOLV_NS" == "127.0.0.1" ]] && [[ "$ACTUAL_SERVER" == "127.0.0.1" ]]; then
    echo "✅ DNS is correctly using localhost (Unbound)"
    echo "✅ System is secure"
elif [[ "$RESOLV_NS" == "127.0.0.1" ]] && [[ -z "$ACTUAL_SERVER" ]]; then
    echo "⚠️  DNS configured for localhost but resolution failed"
    echo "   Check: systemctl status unbound"
else
    echo "❌ WARNING: DNS is NOT using localhost"
    echo "   Expected: 127.0.0.1"
    echo "   Actual: $ACTUAL_SERVER"
    echo "   ACTION REQUIRED: Run dns-hardening script"
fi
echo
EOF

sudo chmod +x /usr/local/bin/dns-reality-check
```

**Usage**:
```bash
dns-reality-check
```

**Benefits**:
- ✅ Clear distinction between metadata and reality
- ✅ Easy troubleshooting
- ✅ Operator education

---

## ENHANCEMENT 3: Monitoring Status Dashboard

### Purpose
Make monitoring visible and verifiable.

### Implementation

```bash
sudo tee /usr/local/bin/dns-monitoring-status << 'EOF'
#!/bin/bash
# DNS Monitoring Status Dashboard

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS MONITORING STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "1. Real-Time Integrity Watcher:"
if systemctl is-active --quiet dns-integrity-watch 2>/dev/null; then
    echo "   ✅ RUNNING"
    LAST_LOG=$(journalctl -u dns-integrity-watch -n 1 --no-pager 2>/dev/null | tail -1)
    echo "   Last activity: ${LAST_LOG:0:80}"
else
    echo "   ❌ NOT RUNNING"
    echo "   Install: See DNS_HARDENING.md Enhancement 1"
fi
echo

echo "2. Periodic DNS Monitor (cron):"
if crontab -l 2>/dev/null | grep -q dns_monitor.sh; then
    echo "   ✅ SCHEDULED"
    LAST_RUN=$(grep dns_monitor /var/log/syslog 2>/dev/null | tail -1 | awk '{print $1, $2, $3}')
    echo "   Last run: ${LAST_RUN:-Unknown}"
else
    echo "   ❌ NOT SCHEDULED"
fi
echo

echo "3. Periodic TLS Monitor (cron):"
if crontab -l 2>/dev/null | grep -q dns_tls_monitor.sh; then
    echo "   ✅ SCHEDULED"
    LAST_RUN=$(grep dns_tls_monitor /var/log/syslog 2>/dev/null | tail -1 | awk '{print $1, $2, $3}')
    echo "   Last run: ${LAST_RUN:-Unknown}"
else
    echo "   ❌ NOT SCHEDULED"
fi
echo

echo "4. File Immutability:"
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "i"; then
    echo "   ✅ ACTIVE"
else
    echo "   ❌ INACTIVE - CRITICAL SECURITY ISSUE"
fi
echo

echo "5. NetworkManager DNS Control:"
if grep -q "dns=none" /etc/NetworkManager/conf.d/90-dns-hardening.conf 2>/dev/null; then
    echo "   ✅ DISABLED (correct)"
else
    echo "   ❌ ENABLED - SECURITY RISK"
fi
echo

echo "6. Unbound Service:"
if systemctl is-active --quiet unbound; then
    echo "   ✅ RUNNING"
else
    echo "   ❌ NOT RUNNING - DNS BROKEN"
fi
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

sudo chmod +x /usr/local/bin/dns-monitoring-status
```

**Usage**:
```bash
dns-monitoring-status
```

---

## ENHANCEMENT 4: Systemd Service Hardening

### Purpose
Harden Unbound service with additional systemd protections.

### Implementation

```bash
sudo mkdir -p /etc/systemd/system/unbound.service.d

sudo tee /etc/systemd/system/unbound.service.d/hardening.conf << 'EOF'
[Service]
# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
LockPersonality=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateMounts=true

# Allow Unbound to write to necessary paths
ReadWritePaths=/var/lib/unbound

# Restart on failure
Restart=on-failure
RestartSec=5s
EOF

sudo systemctl daemon-reload
sudo systemctl restart unbound
```

**Verify**:
```bash
sudo systemctl status unbound
dig +short @127.0.0.1 example.com
```

---

## ENHANCEMENT 5: Automated Recovery Script

### Purpose
One-command restoration of DNS configuration.

### Implementation

```bash
sudo tee /usr/local/bin/dns-restore << 'EOF'
#!/bin/bash
# DNS Configuration Restoration Script

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS CONFIGURATION RESTORATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# 1. Restore resolv.conf
echo "1. Restoring /etc/resolv.conf..."
chattr -i /etc/resolv.conf 2>/dev/null || true
cat > /etc/resolv.conf << 'RESOLV'
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
RESOLV
chattr +i /etc/resolv.conf
echo "   ✅ resolv.conf restored and locked"

# 2. Ensure NetworkManager DNS disabled
echo "2. Configuring NetworkManager..."
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/90-dns-hardening.conf << 'NM'
[main]
dns=none
NM
systemctl reload NetworkManager 2>/dev/null || true
echo "   ✅ NetworkManager DNS disabled"

# 3. Restart Unbound
echo "3. Restarting Unbound..."
systemctl restart unbound
sleep 2
echo "   ✅ Unbound restarted"

# 4. Verify
echo "4. Verifying configuration..."
if dig +short +time=2 @127.0.0.1 example.com >/dev/null 2>&1; then
    echo "   ✅ DNS resolution working"
else
    echo "   ❌ DNS resolution failed"
    exit 1
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DNS configuration restored successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

sudo chmod +x /usr/local/bin/dns-restore
```

**Usage**:
```bash
sudo dns-restore
```

---

## IMPLEMENTATION PRIORITY

| Enhancement | Priority | Effort | Impact | Status |
|-------------|----------|--------|--------|--------|
| Real-time integrity monitoring | High | Medium | High | Optional |
| DNS reality check command | High | Low | High | Recommended |
| Monitoring status dashboard | Medium | Low | Medium | Recommended |
| Systemd service hardening | Medium | Low | Medium | Optional |
| Automated recovery script | High | Low | High | Recommended |

---

## INSTALLATION SCRIPT

```bash
#!/bin/bash
# Install DNS hardening enhancements

set -e

echo "Installing DNS hardening enhancements..."

# 1. Install inotify-tools
apt-get install -y inotify-tools

# 2. Install scripts (already created above)
# dns_integrity_watch.sh
# dns-reality-check
# dns-monitoring-status
# dns-restore

# 3. Install systemd service
# dns-integrity-watch.service

# 4. Enable services
systemctl daemon-reload
systemctl enable dns-integrity-watch.service
systemctl start dns-integrity-watch.service

echo "✅ DNS hardening enhancements installed"
echo
echo "Available commands:"
echo "  dns-reality-check      - Check actual DNS behavior"
echo "  dns-monitoring-status  - View monitoring status"
echo "  dns-restore            - Restore DNS configuration"
echo
echo "Services:"
echo "  systemctl status dns-integrity-watch"
```

---

## TESTING

### Test Real-Time Monitoring

```bash
# 1. Start monitoring
sudo systemctl start dns-integrity-watch
sudo journalctl -u dns-integrity-watch -f &

# 2. Trigger change
sudo chattr -i /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 3. Verify instant recovery
# Should see immediate alert and restoration in journal

# 4. Verify restored
cat /etc/resolv.conf
lsattr /etc/resolv.conf
```

### Test Recovery Script

```bash
# 1. Break DNS
sudo chattr -i /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# 2. Run recovery
sudo dns-restore

# 3. Verify fixed
dns-reality-check
```

---

## CONCLUSION

**Current system is secure. Enhancements are optional but recommended.**

### Recommended Implementation Order

1. ✅ **dns-reality-check** (5 minutes)
   - Immediate value
   - No risk
   - Helps operator understanding

2. ✅ **dns-monitoring-status** (5 minutes)
   - Visibility into monitoring
   - No risk
   - Useful for troubleshooting

3. ✅ **dns-restore** (5 minutes)
   - Emergency recovery tool
   - No risk
   - Peace of mind

4. ⏳ **Real-time integrity monitoring** (30 minutes)
   - Significant improvement
   - Requires testing
   - Defense-in-depth

5. ⏳ **Systemd hardening** (10 minutes)
   - Additional security layer
   - Low risk
   - Best practices

---

**Document Date**: 2026-02-26  
**Status**: Enhancements documented  
**Action**: Optional implementation
