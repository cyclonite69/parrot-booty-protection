#!/bin/bash

# DNS Hardening Alert - Sends alert if hardening is compromised
# Usage: Run via cron or systemd timer

ALERT_LOG="/var/log/dns_hardening_alerts.log"

alert() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1"
    echo "$msg" >> "$ALERT_LOG"
    echo "$msg" >&2
    
    # Optional: Send desktop notification if available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "DNS Hardening Alert" "$1"
    fi
}

# Check immutable flag
if ! lsattr /etc/resolv.conf 2>/dev/null | grep -q -- '----i---------'; then
    alert "Immutable flag REMOVED from /etc/resolv.conf"
    alert "Current nameservers: $(grep nameserver /etc/resolv.conf | head -3)"
    exit 1
fi

# Check if localhost resolver is first
if ! head -1 /etc/resolv.conf | grep -q "127.0.0.1"; then
    alert "Resolv.conf modified - localhost resolver not primary"
    exit 1
fi

# Check Unbound status
if ! systemctl is-active unbound >/dev/null 2>&1; then
    alert "Unbound service is NOT running"
    exit 1
fi

exit 0
