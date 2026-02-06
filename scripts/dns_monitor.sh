#!/bin/bash

# DNS Hardening Monitor - Runs periodically to detect changes
# Logs only when hardening status changes

LOGFILE="/var/log/dns_hardening_monitor.log"
STATEFILE="/var/run/dns_hardening.state"

check_hardening() {
    if lsattr /etc/resolv.conf 2>/dev/null | grep -q -- '----i---------'; then
        echo "HARDENED"
    else
        echo "COMPROMISED"
    fi
}

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# Get current state
CURRENT=$(check_hardening)

# Get previous state
if [ -f "$STATEFILE" ]; then
    PREVIOUS=$(cat "$STATEFILE")
else
    PREVIOUS="UNKNOWN"
fi

# Log if state changed
if [ "$CURRENT" != "$PREVIOUS" ]; then
    if [ "$CURRENT" = "HARDENED" ]; then
        log_event "✓ DNS hardening RESTORED"
    else
        log_event "✗ DNS hardening COMPROMISED - immutable flag removed"
        log_event "  Resolv.conf content: $(head -1 /etc/resolv.conf)"
    fi
fi

# Save current state
echo "$CURRENT" > "$STATEFILE"

# Exit with status
[ "$CURRENT" = "HARDENED" ] && exit 0 || exit 1
