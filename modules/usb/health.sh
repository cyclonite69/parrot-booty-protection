#!/bin/bash
set -euo pipefail

RULES_FILE="/etc/usbguard/rules.conf"

is_active_service() {
    local svc="$1"
    if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
        return 0
    fi
    pgrep -x "$svc" &>/dev/null
}

if ! command -v usbguard &>/dev/null; then
    echo "usbguard command not found"
    exit 1
fi

if ! is_active_service usbguard-daemon && ! is_active_service usbguard; then
    echo "usbguard service not active"
    exit 1
fi

if [[ ! -s "$RULES_FILE" ]]; then
    echo "usbguard rules file missing or empty: $RULES_FILE"
    exit 1
fi

exit 0
