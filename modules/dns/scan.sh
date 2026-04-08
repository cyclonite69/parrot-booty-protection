#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

is_active_service() {
    local svc="$1"
    if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
        return 0
    fi
    pgrep -x "$svc" &>/dev/null
}

dns_resolution_ok() {
    local target="${1:-cloudflare.com}"
    if command -v drill &>/dev/null; then
        drill @127.0.0.1 "$target" &>/dev/null
        return $?
    fi
    if command -v dig &>/dev/null; then
        dig +short @127.0.0.1 "$target" | grep -q .
        return $?
    fi
    getent ahosts "$target" &>/dev/null
}

if is_active_service unbound; then
    # Check encrypted upstream on unbound config.
    if ! grep -Rqs "forward-tls-upstream:[[:space:]]*yes" /etc/unbound /etc/unbound/unbound.conf* 2>/dev/null; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "DNS-001",
            "severity": "HIGH",
            "title": "DNS over TLS not enabled",
            "description": "Unbound does not appear to use TLS for upstream DNS",
            "remediation": "Set forward-tls-upstream: yes in unbound forward-zone"
        }]')
    fi

    # Check DNSSEC on unbound config.
    if ! grep -RqsE "auto-trust-anchor-file|harden-dnssec-stripped:[[:space:]]*yes" /etc/unbound /etc/unbound/unbound.conf* 2>/dev/null; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "DNS-002",
            "severity": "MEDIUM",
            "title": "DNSSEC not clearly enabled",
            "description": "Unbound DNSSEC validation settings were not detected",
            "remediation": "Enable DNSSEC trust anchor/validation in unbound configuration"
        }]')
    fi

    # Basic leak check for local-stub configuration.
    if ! grep -qE "^[[:space:]]*nameserver[[:space:]]+127\\.0\\.0\\.1([[:space:]]|$)" /etc/resolv.conf 2>/dev/null; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "DNS-004",
            "severity": "MEDIUM",
            "title": "Potential DNS leak detected",
            "description": "System resolver is not pinned to local unbound stub (127.0.0.1)",
            "remediation": "Point /etc/resolv.conf to 127.0.0.1"
        }]')
    fi

    # Test DNS resolution in unbound mode.
    if ! dns_resolution_ok "cloudflare.com"; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "DNS-003",
            "severity": "CRITICAL",
            "title": "DNS resolution failure",
            "description": "Unable to resolve domain names via unbound",
            "remediation": "Check unbound service and upstream resolver connectivity"
        }]')
    fi
elif is_active_service systemd-resolved; then
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
    if ! resolvectl status 2>/dev/null | grep -q "DNSSEC.*yes"; then
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
    current_dns="$(resolvectl status 2>/dev/null | grep "Current DNS Server" | awk '{print $NF}' | head -n1)"
    if [[ -n "$current_dns" ]] && ! grep -q "$current_dns" /etc/systemd/resolved.conf 2>/dev/null; then
        findings=$(echo "$findings" | jq --arg dns "$current_dns" '. += [{
            "id": "DNS-004",
            "severity": "MEDIUM",
            "title": "Potential DNS leak detected",
            "description": ("Using unconfigured DNS server: " + $dns),
            "remediation": "Verify DNS configuration"
        }]')
    fi
else
    findings=$(echo "$findings" | jq '. += [{
        "id": "DNS-000",
        "severity": "CRITICAL",
        "title": "No supported DNS resolver active",
        "description": "Neither unbound nor systemd-resolved appears to be active",
        "remediation": "Start and configure a supported local DNS resolver"
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
