#!/bin/bash
set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

echo "Running nmap scan on localhost..."
nmap_output=$(nmap -sV -T4 localhost 2>/dev/null || true)

# Parse open ports
open_ports=$(echo "$nmap_output" | grep "^[0-9]" | grep "open" | awk '{print $1}' | sed 's|/.*||' | tr '\n' ',' | sed 's/,$//')
open_count=$(echo "$open_ports" | tr ',' '\n' | grep -c . || echo "0")

if [[ "$open_count" -gt 5 ]]; then
    findings=$(echo "$findings" | jq --arg cnt "$open_count" --arg ports "$open_ports" '. += [{
        "id": "RECON-001",
        "severity": "MEDIUM",
        "title": "Multiple open ports detected",
        "description": ($cnt + " open ports: " + $ports),
        "remediation": "Review and close unnecessary services"
    }]')
fi

# Check for risky services
if echo "$nmap_output" | grep -qi "telnet\|ftp\|rlogin"; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "RECON-002",
        "severity": "HIGH",
        "title": "Insecure services detected",
        "description": "Unencrypted services (telnet/ftp) are running",
        "remediation": "Disable insecure services, use SSH/SFTP instead"
    }]')
fi

# Check for database ports exposed
if echo "$nmap_output" | grep -E "3306|5432|27017|6379" | grep -q "open"; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "RECON-003",
        "severity": "MEDIUM",
        "title": "Database ports exposed",
        "description": "Database services accessible on network",
        "remediation": "Bind databases to localhost only"
    }]')
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    --arg ports "$open_ports" \
    --arg count "$open_count" \
    '{
        module: "recon",
        findings: $findings,
        risk_score: ($score | tonumber),
        open_ports: $ports,
        port_count: ($count | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Network reconnaissance complete: ${report_id}"
