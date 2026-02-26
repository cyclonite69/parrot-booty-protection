#!/bin/bash
set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

echo "Running rkhunter scan (this may take several minutes)..."
rkhunter_output=$(rkhunter --check --skip-keypress --report-warnings-only 2>/dev/null || true)

if echo "$rkhunter_output" | grep -q "Warning"; then
    warning_count=$(echo "$rkhunter_output" | grep -c "Warning" || echo "0")
    findings=$(echo "$findings" | jq --arg cnt "$warning_count" '. += [{
        "id": "RK-001",
        "severity": "HIGH",
        "title": "rkhunter warnings detected",
        "description": ($cnt + " warnings found during rootkit scan"),
        "remediation": "Review rkhunter log at /var/log/rkhunter.log"
    }]')
fi

echo "Running chkrootkit scan..."
chkrootkit_output=$(chkrootkit 2>/dev/null || true)

if echo "$chkrootkit_output" | grep -qi "INFECTED"; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "RK-002",
        "severity": "CRITICAL",
        "title": "Potential rootkit detected",
        "description": "chkrootkit found suspicious files or processes",
        "remediation": "Investigate immediately, consider system reinstall"
    }]')
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    '{
        module: "rootkit",
        findings: $findings,
        risk_score: ($score | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Rootkit scan complete: ${report_id}"
