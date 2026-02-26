#!/bin/bash
set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

# Check NTS authentication status
nts_status=$(chronyc -n authdata 2>/dev/null | grep -c "NTS" || echo "0")
if [[ "$nts_status" -eq 0 ]]; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "TIME-001",
        "severity": "HIGH",
        "title": "NTS authentication not active",
        "description": "No NTS-authenticated time sources detected",
        "remediation": "Verify NTS server connectivity and certificates"
    }]')
fi

# Check time synchronization status
if ! chronyc tracking | grep -q "Leap status.*Normal"; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "TIME-002",
        "severity": "MEDIUM",
        "title": "Time synchronization issue",
        "description": "Chrony tracking shows abnormal leap status",
        "remediation": "Check network connectivity to time servers"
    }]')
fi

# Check clock offset
offset=$(chronyc tracking | awk '/System time/ {print $4}' | sed 's/seconds//')
if (( $(echo "$offset > 1.0" | bc -l 2>/dev/null || echo 0) )); then
    findings=$(echo "$findings" | jq --arg off "$offset" '. += [{
        "id": "TIME-003",
        "severity": "MEDIUM",
        "title": "Clock offset exceeds threshold",
        "description": ("Clock offset: " + $off + " seconds"),
        "remediation": "Allow more time for synchronization or check time sources"
    }]')
fi

# Calculate risk
risk_score=$(calculate_risk_score "$findings")

# Generate report
report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    --arg nts "$nts_status" \
    '{
        module: "time",
        findings: $findings,
        risk_score: ($score | tonumber),
        nts_sources: ($nts | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Time security scan complete: ${report_id}"
