#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

if [[ ! -d /var/log/pbp ]]; then
  findings=$(echo "$findings" | jq '. += [{
    "id": "LOG-001",
    "severity": "MEDIUM",
    "title": "PBP log directory missing",
    "description": "/var/log/pbp does not exist",
    "remediation": "Create /var/log/pbp and ensure services can write to it"
  }]')
else
  oversized="$(find /var/log/pbp -type f -name '*.log' -size +100M 2>/dev/null | wc -l)"
  if [[ "$oversized" -gt 0 ]]; then
    findings=$(echo "$findings" | jq --arg cnt "$oversized" '. += [{
      "id": "LOG-002",
      "severity": "LOW",
      "title": "Large security log files detected",
      "description": ("Found " + $cnt + " log files larger than 100MB"),
      "remediation": "Review logrotate settings and archive old logs"
    }]')
  fi
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
  --argjson findings "$findings" \
  --arg score "$risk_score" \
  '{
    module: "logs",
    findings: $findings,
    risk_score: ($score | tonumber),
    status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
  }')

report_id=$(create_report "scan" "$report_data")
echo "Logs scan complete: ${report_id}"
