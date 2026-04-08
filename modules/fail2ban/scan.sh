#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

if ! command -v fail2ban-client &>/dev/null; then
  findings=$(echo "$findings" | jq '. += [{
    "id": "F2B-001",
    "severity": "CRITICAL",
    "title": "Fail2Ban missing",
    "description": "fail2ban-client command not found",
    "remediation": "Install fail2ban package"
  }]')
else
  if ! fail2ban-client ping 2>/dev/null | grep -q "Server replied"; then
    findings=$(echo "$findings" | jq '. += [{
      "id": "F2B-002",
      "severity": "HIGH",
      "title": "Fail2Ban daemon not running",
      "description": "Fail2Ban is not actively protecting services",
      "remediation": "Start fail2ban service"
    }]')
  fi

  if ! fail2ban-client status 2>/dev/null | grep -q "sshd"; then
    findings=$(echo "$findings" | jq '. += [{
      "id": "F2B-003",
      "severity": "MEDIUM",
      "title": "SSHD jail not active",
      "description": "No sshd jail detected in Fail2Ban status",
      "remediation": "Enable sshd jail in /etc/fail2ban/jail.local"
    }]')
  fi
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
  --argjson findings "$findings" \
  --arg score "$risk_score" \
  '{
    module: "fail2ban",
    findings: $findings,
    risk_score: ($score | tonumber),
    status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
  }')

report_id=$(create_report "scan" "$report_data")
echo "Fail2Ban scan complete: ${report_id}"
