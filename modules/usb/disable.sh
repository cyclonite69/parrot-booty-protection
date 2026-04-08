#!/bin/bash
set -euo pipefail

RULES_FILE="/etc/usbguard/rules.conf"
RULES_BAK="/etc/usbguard/rules.conf.pbp.bak"
CONF_FILE="/etc/usbguard/usbguard-daemon.conf"
CONF_BAK="/etc/usbguard/usbguard-daemon.conf.pbp.bak"

echo "Disabling USBGuard allowlist policy..."

if command -v systemctl &>/dev/null; then
    systemctl stop usbguard 2>/dev/null || true
    systemctl disable usbguard 2>/dev/null || true
fi

if [[ -f "$RULES_BAK" ]]; then
    cp "$RULES_BAK" "$RULES_FILE"
fi

if [[ -f "$CONF_BAK" ]]; then
    cp "$CONF_BAK" "$CONF_FILE"
fi

echo "USBGuard module disabled"
