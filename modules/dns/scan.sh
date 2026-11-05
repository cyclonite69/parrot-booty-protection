#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"
source "${PBP_ROOT}/core/lib/dns_time_diagnostics.sh"

findings='[]'

# Fixture injection for tests (static files only).
UNBOUND_CONF_PATH="${PBP_UNBOUND_CONF_FILE:-/etc/unbound/unbound.conf}"
RESOLV_CONF_PATH="${PBP_RESOLV_CONF_FILE:-/etc/resolv.conf}"
LSATTR_FIXTURE="${PBP_LSATTR_FILE:-}"
NM_PRINT_FIXTURE="${PBP_NM_PRINT_CONFIG_FILE:-}"
DIG_VALID_FIXTURE="${PBP_DIG_VALID_FILE:-}"
DIG_BOGUS_FIXTURE="${PBP_DIG_BOGUS_FILE:-}"
SKIP_LIVE_RUNTIME="${PBP_DNS_SKIP_LIVE_RUNTIME:-0}"

is_active_service() {
    local svc="$1"
    if [[ -n "${PBP_FAKE_ACTIVE_SERVICES:-}" ]]; then
        printf '%s\n' "${PBP_FAKE_ACTIVE_SERVICES}" | grep -qx "$svc"
        return $?
    fi
    if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
        return 0
    fi
    pgrep -x "$svc" &>/dev/null
}

add_finding() {
    local id="$1" severity="$2" category="$3" title="$4" description="$5" remediation="$6"
    findings=$(echo "$findings" | jq \
        --arg id "$id" \
        --arg sev "$severity" \
        --arg cat "$category" \
        --arg title "$title" \
        --arg desc "$description" \
        --arg rem "$remediation" \
        '. += [{
            id: $id,
            severity: $sev,
            category: $cat,
            title: $title,
            description: $desc,
            remediation: $rem
        }]')
}

read_unbound_conf_text() {
    if [[ -f "$UNBOUND_CONF_PATH" ]]; then
        unbound_read_config_tree "$UNBOUND_CONF_PATH"
        return $?
    fi
    return 1
}

# --- Configuration checks (static text / effective config strings) ---
# These are NOT proof of runtime DNS behavior.

if is_active_service unbound || [[ -n "${PBP_UNBOUND_CONF_FILE:-}" ]]; then
    conf_text="$(read_unbound_conf_text || true)"

    if [[ -z "${conf_text}" ]]; then
        add_finding "DNS-001" "HIGH" "configuration" \
            "Unbound configuration not readable" \
            "Could not read Unbound configuration for DoT / DNSSEC / forwarding checks" \
            "Ensure unbound.conf is present and readable"
    else
        if ! unbound_root_forward_zone_has_setting "$conf_text" "forward-tls-upstream" "yes"; then
            add_finding "DNS-001" "HIGH" "configuration" \
                "DNS over TLS not configured" \
                "The root forward-zone does not set forward-tls-upstream: yes (configuration check only)" \
                "Set forward-tls-upstream: yes in unbound forward-zone"
        fi

        if ! unbound_has_dnssec_validation "$conf_text"; then
            add_finding "DNS-002" "MEDIUM" "configuration" \
                "DNSSEC not clearly configured" \
                "Active server-section DNSSEC validation settings were not detected" \
                "Enable DNSSEC trust anchor/validation in unbound configuration"
        fi

        if ! unbound_has_fail_closed_forwarding "$conf_text"; then
            add_finding "DNS-007" "HIGH" "configuration" \
                "Fail-closed forwarding not configured" \
                "forward-first: no was not found; recursive fallback may be permitted (configuration check only)" \
                "Set forward-first: no in the root forward-zone"
        fi

        ta_count="$(unbound_trust_anchor_count "$conf_text")"
        if [[ "$ta_count" -gt 1 ]]; then
            add_finding "DNS-008" "HIGH" "configuration" \
                "Duplicate DNSSEC trust-anchor declarations" \
                "Found ${ta_count} auto-trust-anchor-file declarations; Unbound may fail to start" \
                "Declare auto-trust-anchor-file exactly once"
        fi

        rc_enable="$(unbound_remote_control_enable "$conf_text")"
        if [[ "$rc_enable" == "unknown" ]]; then
            add_finding "DNS-009" "MEDIUM" "configuration" \
                "Remote-control policy not explicit" \
                "control-enable was not found in configuration text" \
                "Set an explicit remote-control control-enable policy"
        fi
    fi

    if [[ -f "$RESOLV_CONF_PATH" ]]; then
        if ! grep -qE '^[[:space:]]*nameserver[[:space:]]+127\.0\.0\.1([[:space:]]|$)' "$RESOLV_CONF_PATH" 2>/dev/null; then
            add_finding "DNS-004" "MEDIUM" "configuration" \
                "System resolver not pinned to localhost" \
                "nameserver 127.0.0.1 was not found in resolver configuration (configuration check only; not proof of an active leak)" \
                "Point resolv.conf to 127.0.0.1"
        fi
    else
        add_finding "DNS-004" "MEDIUM" "configuration" \
            "Resolver configuration missing" \
            "Resolver configuration file was not found" \
            "Create a resolv.conf pinned to 127.0.0.1"
    fi

    # NetworkManager effective dns= (configuration/effective-settings check)
    nm_effective_dns=""
    if [[ -n "$NM_PRINT_FIXTURE" && -f "$NM_PRINT_FIXTURE" ]]; then
        nm_effective_dns=$(grep -E '^[[:space:]]*dns=' "$NM_PRINT_FIXTURE" | awk -F= '{print $2}' | tr -d ' ' | head -1 || true)
    elif command -v NetworkManager &>/dev/null && [[ "$SKIP_LIVE_RUNTIME" != "1" ]]; then
        nm_effective_dns=$(NetworkManager --print-config 2>/dev/null | grep -E '^[[:space:]]*dns=' | awk -F= '{print $2}' | tr -d ' ' | head -1 || true)
    fi
    if [[ -n "$nm_effective_dns" && "$nm_effective_dns" != "none" ]]; then
        add_finding "DNS-005" "HIGH" "configuration" \
            "NetworkManager DNS management active" \
            "Effective NetworkManager dns=\"${nm_effective_dns}\" instead of \"none\" (configuration check only)" \
            "Configure dns=none in NetworkManager conf.d"
    fi

    # Immutable bit — configuration hygiene, not sovereignty proof
    lsattr_out=""
    if [[ -n "$LSATTR_FIXTURE" && -f "$LSATTR_FIXTURE" ]]; then
        lsattr_out="$(cat "$LSATTR_FIXTURE")"
    elif command -v lsattr &>/dev/null && [[ "$SKIP_LIVE_RUNTIME" != "1" ]]; then
        lsattr_out="$(lsattr "$RESOLV_CONF_PATH" 2>/dev/null || true)"
    fi
    if [[ -n "$lsattr_out" ]]; then
        if ! resolv_conf_immutable_from_lsattr "$lsattr_out"; then
            add_finding "DNS-006" "MEDIUM" "configuration" \
                "Resolv.conf is not locked as immutable" \
                "Immutable bit (+i) is not set. This is a configuration hygiene check, not proof of DNS sovereignty or leak status." \
                "Lock resolv.conf with: sudo chattr +i /etc/resolv.conf"
        fi
    elif [[ "$SKIP_LIVE_RUNTIME" == "1" && -z "$LSATTR_FIXTURE" ]]; then
        add_finding "DNS-006" "INFO" "unverified" \
            "Resolv.conf immutable state unverified" \
            "No lsattr fixture or live probe available" \
            "Provide lsattr output or run with sufficient permissions"
    fi

    # --- Runtime verification (behavioral; never claimed from config text alone) ---
    if [[ "$SKIP_LIVE_RUNTIME" == "1" ]]; then
        if [[ -n "$DIG_VALID_FIXTURE" && -f "$DIG_VALID_FIXTURE" ]]; then
            if ! grep -Eq 'status:[[:space:]]*NOERROR' "$DIG_VALID_FIXTURE" || ! grep -Eq 'flags:.*\bad\b' "$DIG_VALID_FIXTURE"; then
                add_finding "DNS-010" "HIGH" "runtime" \
                    "DNSSEC-validated resolution failed" \
                    "Fixture dig output for a signed domain lacked NOERROR+AD (runtime fixture)" \
                    "Check Unbound DNSSEC validation and upstream DoT"
            fi
        fi
        if [[ -n "$DIG_BOGUS_FIXTURE" && -f "$DIG_BOGUS_FIXTURE" ]]; then
            if ! grep -Eq 'status:[[:space:]]*SERVFAIL|SERVFAIL' "$DIG_BOGUS_FIXTURE"; then
                add_finding "DNS-011" "HIGH" "runtime" \
                    "Bogus DNSSEC domain was not rejected" \
                    "Fixture dig output for an invalid DNSSEC domain lacked SERVFAIL (runtime fixture)" \
                    "Ensure DNSSEC validation is enforcing"
            fi
        fi
    else
        # Live runtime probes — results labelled as runtime, not config
        if command -v dig &>/dev/null; then
            valid_out="$(dig +dnssec +time=2 +tries=1 cloudflare.com @127.0.0.1 2>/dev/null || true)"
            if ! printf '%s\n' "$valid_out" | grep -Eq 'status:[[:space:]]*NOERROR' \
                || ! printf '%s\n' "$valid_out" | grep -Eq 'flags:.*\bad\b'; then
                add_finding "DNS-010" "HIGH" "runtime" \
                    "DNSSEC-validated resolution failed" \
                    "Live dig to a signed domain did not return NOERROR with AD flag" \
                    "Check Unbound service, DNSSEC trust anchor, and upstream DoT"
            fi

            bogus_out="$(dig +dnssec +time=2 +tries=1 dnssec-failed.org @127.0.0.1 2>/dev/null || true)"
            if ! printf '%s\n' "$bogus_out" | grep -Eq 'SERVFAIL'; then
                add_finding "DNS-011" "HIGH" "runtime" \
                    "Bogus DNSSEC domain was not rejected" \
                    "Live dig to dnssec-failed.org did not return SERVFAIL" \
                    "Ensure DNSSEC validation is enforcing"
            fi
        else
            # Fallback connectivity only — do not claim DNSSEC verified
            if command -v drill &>/dev/null; then
                if ! drill @127.0.0.1 cloudflare.com &>/dev/null; then
                    add_finding "DNS-003" "CRITICAL" "runtime" \
                        "DNS resolution failure" \
                        "Unable to resolve via unbound (runtime check; DNSSEC not verified)" \
                        "Check unbound service and upstream connectivity"
                fi
            elif ! getent ahosts cloudflare.com &>/dev/null; then
                add_finding "DNS-003" "CRITICAL" "runtime" \
                    "DNS resolution failure" \
                    "Unable to resolve domain names (runtime check; DNSSEC not verified)" \
                    "Check unbound service and upstream connectivity"
            fi
        fi
    fi

elif is_active_service systemd-resolved; then
    if [[ ! -f /etc/systemd/resolved.conf ]] || ! grep -q "DNSOverTLS=yes" /etc/systemd/resolved.conf 2>/dev/null; then
        add_finding "DNS-001" "HIGH" "configuration" \
            "DNS over TLS not configured" \
            "systemd-resolved DoT setting was not detected (configuration check only)" \
            "Enable DoT in systemd-resolved configuration"
    fi
    if [[ "$SKIP_LIVE_RUNTIME" != "1" ]]; then
        if ! resolvectl query cloudflare.com &>/dev/null; then
            add_finding "DNS-003" "CRITICAL" "runtime" \
                "DNS resolution failure" \
                "Unable to resolve domain names via systemd-resolved" \
                "Check DNS server connectivity"
        fi
    fi
else
    add_finding "DNS-000" "CRITICAL" "runtime" \
        "No supported DNS resolver active" \
        "Neither unbound nor systemd-resolved appears to be active" \
        "Start and configure a supported local DNS resolver"
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
