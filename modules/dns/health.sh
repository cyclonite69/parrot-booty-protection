#!/bin/bash
set -euo pipefail

is_active_service() {
    local svc="$1"
    if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
        return 0
    fi
    if pgrep -x "$svc" &>/dev/null; then
        return 0
    fi
    return 1
}

check_unbound_resolution() {
    if command -v drill &>/dev/null; then
        drill @127.0.0.1 google.com &>/dev/null
        return $?
    fi
    if command -v dig &>/dev/null; then
        dig +short @127.0.0.1 google.com | grep -q .
        return $?
    fi
    getent ahosts google.com &>/dev/null
}

# Support both resolver models:
# - Unbound recursive/forwarding resolver
# - systemd-resolved local resolver
if is_active_service unbound; then
    if ! check_unbound_resolution; then
        echo "DNS resolution failed via unbound"
        exit 1
    fi
elif is_active_service systemd-resolved; then
    if command -v resolvectl &>/dev/null; then
        if ! resolvectl query google.com &>/dev/null; then
            echo "DNS resolution failed via systemd-resolved"
            exit 1
        fi
    elif ! getent ahosts google.com &>/dev/null; then
        echo "DNS resolution failed via system resolver fallback"
        exit 1
    fi
else
    echo "No supported DNS resolver active (expected: unbound or systemd-resolved)"
    exit 1
fi

exit 0
