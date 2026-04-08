#!/bin/bash
set -euo pipefail

RULES_FILE="/etc/usbguard/rules.conf"
RULES_BAK="/etc/usbguard/rules.conf.pbp.bak"
CONF_FILE="/etc/usbguard/usbguard-daemon.conf"
CONF_BAK="/etc/usbguard/usbguard-daemon.conf.pbp.bak"

echo "Configuring USBGuard allowlist policy..."

mkdir -p /etc/usbguard

if [[ -f "$RULES_FILE" && ! -f "$RULES_BAK" ]]; then
    cp "$RULES_FILE" "$RULES_BAK"
fi

if [[ -f "$CONF_FILE" && ! -f "$CONF_BAK" ]]; then
    cp "$CONF_FILE" "$CONF_BAK"
fi

# Generate an allowlist from currently connected devices if rules are missing/empty.
if [[ ! -s "$RULES_FILE" ]]; then
    usbguard generate-policy > "$RULES_FILE"
fi

chmod 600 "$RULES_FILE"

if [[ -f "$CONF_FILE" ]]; then
    sed -i 's/^[#[:space:]]*ImplicitPolicyTarget=.*/ImplicitPolicyTarget=block/' "$CONF_FILE" || true
    if ! grep -q '^ImplicitPolicyTarget=' "$CONF_FILE"; then
        echo "ImplicitPolicyTarget=block" >> "$CONF_FILE"
    fi
fi

if command -v systemctl &>/dev/null; then
    systemctl enable usbguard
    systemctl restart usbguard
fi

echo "USBGuard allowlist enabled"
