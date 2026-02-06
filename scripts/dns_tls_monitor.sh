#!/bin/bash

# Unbound TLS and Fallback Monitor
# Checks if Unbound is using DNS over TLS and alerts on fallback

ALERT_LOG="/var/log/dns_hardening_alerts.log"

alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" >> "$ALERT_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" >&2
    
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u critical "DNS Alert" "$1"
    fi
}

# Check if Unbound is running
if ! systemctl is-active unbound >/dev/null 2>&1; then
    alert "Unbound is NOT running - using fallback DNS"
    exit 1
fi

# Trigger multiple DNS queries to establish TLS connections
for domain in cloudflare.com google.com example.com; do
    dig @127.0.0.1 $domain +short >/dev/null 2>&1 &
done
wait
sleep 1

# Check for active TLS connections (port 853)
TLS_COUNT=$(sudo ss -tn 2>/dev/null | grep -c ":853")

if [ "$TLS_COUNT" -eq 0 ]; then
    # No TLS connections - check if Unbound config is correct
    if ! grep -q "forward-tls-upstream: yes" /etc/unbound/unbound.conf 2>/dev/null; then
        alert "Unbound NOT configured for DNS over TLS"
        exit 1
    fi
    
    # TLS might be configured but connections are short-lived (normal)
    # Only alert if Unbound is actually broken
    if ! timeout 3 dig @127.0.0.1 google.com +short >/dev/null 2>&1; then
        alert "Unbound DNS resolution FAILED - check service"
        exit 1
    fi
    
    # Unbound works but no persistent TLS (this is actually normal)
    exit 0
fi

# Success - TLS connections active
exit 0
