#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

# Check if auditd is running
if ! systemctl is-active auditd &>/dev/null; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "AUDIT-001",
        "severity": "HIGH",
        "title": "Audit daemon not running",
        "description": "System auditing is disabled",
        "remediation": "Start auditd service"
    }]')
fi

# Check for audit rules
rule_count=$(auditctl -l 2>/dev/null | grep -v "No rules" | wc -l || echo "0")
if [[ "$rule_count" -lt 5 ]]; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "AUDIT-002",
        "severity": "MEDIUM",
        "title": "Insufficient audit rules",
        "description": "Few or no audit rules configured",
        "remediation": "Configure audit rules for critical files"
    }]')
fi

# Check audit log size
if [[ -f /var/log/audit/audit.log ]]; then
    log_size=$(du -m /var/log/audit/audit.log | awk '{print $1}')
    if [[ "$log_size" -gt 100 ]]; then
        findings=$(echo "$findings" | jq --arg size "$log_size" '. += [{
            "id": "AUDIT-003",
            "severity": "LOW",
            "title": "Large audit log",
            "description": ("Audit log is " + $size + "MB"),
            "remediation": "Review log rotation settings"
        }]')
    fi
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    --arg rules "$rule_count" \
    '{
        module: "audit",
        findings: $findings,
        risk_score: ($score | tonumber),
        active_rules: ($rules | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Audit scan complete: ${report_id}"
