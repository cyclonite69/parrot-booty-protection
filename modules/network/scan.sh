#!/bin/bash
set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

# Check if nftables is active
if ! systemctl is-active nftables &>/dev/null; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "NET-001",
        "severity": "CRITICAL",
        "title": "Firewall not active",
        "description": "nftables service is not running",
        "remediation": "Start nftables service"
    }]')
fi

# Check for default drop policy
if ! nft list ruleset | grep -q "policy drop"; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "NET-002",
        "severity": "HIGH",
        "title": "No default drop policy",
        "description": "Firewall may allow unexpected traffic",
        "remediation": "Set default drop policy on input chain"
    }]')
fi

# Check for open ports
open_ports=$(ss -tuln | grep LISTEN | wc -l)
if [[ "$open_ports" -gt 10 ]]; then
    findings=$(echo "$findings" | jq --arg ports "$open_ports" '. += [{
        "id": "NET-003",
        "severity": "MEDIUM",
        "title": "Many listening ports detected",
        "description": ("Found " + $ports + " listening ports"),
        "remediation": "Review and close unnecessary services"
    }]')
fi

# Check for IPv6 if disabled
if ! ip -6 addr show | grep -q "inet6" 2>/dev/null; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "NET-004",
        "severity": "LOW",
        "title": "IPv6 disabled",
        "description": "IPv6 is not available on this system",
        "remediation": "None required if intentional"
    }]')
fi

risk_score=$(calculate_risk_score "$findings")

# Get listening ports for report
listening_ports=$(ss -tuln | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -n | uniq | tr '\n' ',' | sed 's/,$//')

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    --arg ports "$listening_ports" \
    '{
        module: "network",
        findings: $findings,
        risk_score: ($score | tonumber),
        listening_ports: $ports,
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Network security scan complete: ${report_id}"
