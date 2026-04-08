#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'
RULES_FILE="/etc/usbguard/rules.conf"

is_active_service() {
    local svc="$1"
    if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
        return 0
    fi
    pgrep -x "$svc" &>/dev/null
}

if ! command -v usbguard &>/dev/null; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "USB-001",
        "severity": "CRITICAL",
        "title": "USBGuard not installed",
        "description": "USB device policy enforcement tool is missing",
        "remediation": "Install usbguard package"
    }]')
else
    if ! is_active_service usbguard-daemon && ! is_active_service usbguard; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "USB-002",
            "severity": "HIGH",
            "title": "USBGuard service not active",
            "description": "USB device access policy is not currently enforced",
            "remediation": "Start and enable usbguard service"
        }]')
    fi

    if [[ ! -s "$RULES_FILE" ]]; then
        findings=$(echo "$findings" | jq --arg path "$RULES_FILE" '. += [{
            "id": "USB-003",
            "severity": "HIGH",
            "title": "USB allowlist rules missing",
            "description": ("Rules file missing or empty: " + $path),
            "remediation": "Generate and apply usbguard policy rules"
        }]')
    fi

    if [[ -s "$RULES_FILE" ]] && grep -Eq '^[[:space:]]*allow[[:space:]]+\*' "$RULES_FILE"; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "USB-004",
            "severity": "MEDIUM",
            "title": "Overly permissive USB allow rule",
            "description": "Wildcard allow rule may permit unauthorized devices",
            "remediation": "Restrict rules to known devices only"
        }]')
    fi
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    '{
        module: "usb",
        findings: $findings,
        risk_score: ($score | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "USB security scan complete: ${report_id}"
