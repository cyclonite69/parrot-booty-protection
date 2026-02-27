#!/bin/bash
# Install DNS Hardening Enhancements
# See: DNS_HARDENING.md

set -e

if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS HARDENING ENHANCEMENTS - INSTALLATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# 1. DNS Reality Check Command
echo "1. Installing dns-reality-check command..."
tee /usr/local/bin/dns-reality-check > /dev/null << 'REALITY'
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
    echo "   ACTION REQUIRED: Run dns-restore"
fi
echo
REALITY

chmod +x /usr/local/bin/dns-reality-check
echo "   ✅ Installed: dns-reality-check"

# 2. DNS Monitoring Status Command
echo "2. Installing dns-monitoring-status command..."
tee /usr/local/bin/dns-monitoring-status > /dev/null << 'STATUS'
#!/bin/bash
# DNS Monitoring Status Dashboard

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS MONITORING STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "1. Periodic DNS Monitor (cron):"
if crontab -l 2>/dev/null | grep -q dns_monitor.sh; then
    echo "   ✅ SCHEDULED"
    LAST_RUN=$(grep dns_monitor /var/log/syslog 2>/dev/null | tail -1 | awk '{print $1, $2, $3}')
    echo "   Last run: ${LAST_RUN:-Unknown}"
else
    echo "   ❌ NOT SCHEDULED"
fi
echo

echo "2. Periodic TLS Monitor (cron):"
if crontab -l 2>/dev/null | grep -q dns_tls_monitor.sh; then
    echo "   ✅ SCHEDULED"
    LAST_RUN=$(grep dns_tls_monitor /var/log/syslog 2>/dev/null | tail -1 | awk '{print $1, $2, $3}')
    echo "   Last run: ${LAST_RUN:-Unknown}"
else
    echo "   ❌ NOT SCHEDULED"
fi
echo

echo "3. File Immutability:"
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "i"; then
    echo "   ✅ ACTIVE"
else
    echo "   ❌ INACTIVE - CRITICAL SECURITY ISSUE"
fi
echo

echo "4. NetworkManager DNS Control:"
if grep -q "dns=none" /etc/NetworkManager/conf.d/90-dns-hardening.conf 2>/dev/null; then
    echo "   ✅ DISABLED (correct)"
else
    echo "   ❌ ENABLED - SECURITY RISK"
fi
echo

echo "5. Unbound Service:"
if systemctl is-active --quiet unbound; then
    echo "   ✅ RUNNING"
else
    echo "   ❌ NOT RUNNING - DNS BROKEN"
fi
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
STATUS

chmod +x /usr/local/bin/dns-monitoring-status
echo "   ✅ Installed: dns-monitoring-status"

# 3. DNS Restore Command
echo "3. Installing dns-restore command..."
tee /usr/local/bin/dns-restore > /dev/null << 'RESTORE'
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
RESTORE

chmod +x /usr/local/bin/dns-restore
echo "   ✅ Installed: dns-restore"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DNS HARDENING ENHANCEMENTS INSTALLED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Available commands:"
echo "  dns-reality-check      - Check actual DNS behavior vs metadata"
echo "  dns-monitoring-status  - View monitoring status"
echo "  dns-restore            - Restore DNS configuration"
echo
echo "Try them now:"
echo "  dns-reality-check"
echo
