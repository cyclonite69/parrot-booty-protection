#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

mount_opts="$(findmnt -no OPTIONS /tmp 2>/dev/null || true)"
for opt in noexec nodev nosuid; do
  if ! grep -qw "$opt" <<< "$mount_opts"; then
    findings=$(echo "$findings" | jq --arg opt "$opt" '. += [{
      "id": "MNT-001",
      "severity": "MEDIUM",
      "title": "Weak /tmp mount options",
      "description": ("Missing /tmp option: " + $opt),
      "remediation": "Add noexec,nodev,nosuid on /tmp where operationally possible"
    }]')
  fi
done

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
  --argjson findings "$findings" \
  --arg score "$risk_score" \
  '{
    module: "mount",
    findings: $findings,
    risk_score: ($score | tonumber),
    status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
  }')

report_id=$(create_report "scan" "$report_data")
echo "Mount scan complete: ${report_id}"
