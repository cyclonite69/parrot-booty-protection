#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'
cfg="/etc/NetworkManager/conf.d/pbp-mac-randomization.conf"

if [[ ! -f "$cfg" ]]; then
  findings=$(echo "$findings" | jq '. += [{
    "id": "MAC-001",
    "severity": "MEDIUM",
    "title": "MAC randomization not configured",
    "description": "NetworkManager MAC randomization config file is missing",
    "remediation": "Enable MAC module to configure randomized MAC addresses"
  }]')
elif ! grep -q "cloned-mac-address=random" "$cfg"; then
  findings=$(echo "$findings" | jq '. += [{
    "id": "MAC-002",
    "severity": "LOW",
    "title": "MAC randomization incomplete",
    "description": "Config exists but randomized MAC mode not detected",
    "remediation": "Set cloned-mac-address=random in NetworkManager config"
  }]')
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
  --argjson findings "$findings" \
  --arg score "$risk_score" \
  '{
    module: "mac",
    findings: $findings,
    risk_score: ($score | tonumber),
    status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
  }')

report_id=$(create_report "scan" "$report_data")
echo "MAC randomization scan complete: ${report_id}"
