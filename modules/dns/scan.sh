#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

# Check if DoT is enabled
if ! grep -q "DNSOverTLS=yes" /etc/systemd/resolved.conf 2>/dev/null; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "DNS-001",
        "severity": "HIGH",
        "title": "DNS over TLS not enabled",
        "description": "DNS queries are not encrypted",
        "remediation": "Enable DoT in systemd-resolved configuration"
    }]')
fi

# Check DNSSEC
if ! resolvectl status | grep -q "DNSSEC.*yes"; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "DNS-002",
        "severity": "MEDIUM",
        "title": "DNSSEC not fully enabled",
        "description": "DNS responses may not be validated",
        "remediation": "Enable DNSSEC validation"
    }]')
fi

# Test DNS resolution
if ! resolvectl query cloudflare.com &>/dev/null; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "DNS-003",
        "severity": "CRITICAL",
        "title": "DNS resolution failure",
        "description": "Unable to resolve domain names",
        "remediation": "Check DNS server connectivity"
    }]')
fi

# Check for DNS leaks (non-configured servers in use)
current_dns=$(resolvectl status | grep "Current DNS Server" | awk '{print $NF}')
if [[ -n "$current_dns" ]] && ! grep -q "$current_dns" /etc/systemd/resolved.conf; then
    findings=$(echo "$findings" | jq --arg dns "$current_dns" '. += [{
        "id": "DNS-004",
        "severity": "MEDIUM",
        "title": "Potential DNS leak detected",
        "description": ("Using unconfigured DNS server: " + $dns),
        "remediation": "Verify DNS configuration"
    }]')
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    '{
        module: "dns",
        findings: $findings,
        risk_score: ($score | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "DNS security scan complete: ${report_id}"
