#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"
source "${PBP_ROOT}/core/lib/dns_time_diagnostics.sh"

findings='[]'
nts_state="UNAVAILABLE"
nts_sources=0

# Optional fixture injection for tests (never used in production scans).
# PBP_CHRONYC_AUTHDATA_FILE / PBP_CHRONYC_TRACKING_FILE point at static captures.
read_authdata() {
    if [[ -n "${PBP_CHRONYC_AUTHDATA_FILE:-}" && -f "${PBP_CHRONYC_AUTHDATA_FILE}" ]]; then
        cat "${PBP_CHRONYC_AUTHDATA_FILE}"
        return 0
    fi
    if ! command -v chronyc &>/dev/null; then
        return 127
    fi
    chronyc -n authdata 2>&1 || true
}

read_tracking() {
    if [[ -n "${PBP_CHRONYC_TRACKING_FILE:-}" && -f "${PBP_CHRONYC_TRACKING_FILE}" ]]; then
        cat "${PBP_CHRONYC_TRACKING_FILE}"
        return 0
    fi
    chronyc tracking 2>/dev/null || true
}

if ! command -v chronyc &>/dev/null && [[ -z "${PBP_CHRONYC_AUTHDATA_FILE:-}" ]]; then
    nts_state="UNAVAILABLE"
    findings=$(echo "$findings" | jq '. += [{
        "id": "TIME-001",
        "severity": "MEDIUM",
        "category": "availability",
        "title": "chronyc unavailable",
        "description": "chronyc is not installed; NTS authentication cannot be assessed",
        "state": "UNAVAILABLE",
        "remediation": "Install chrony and configure NTS sources"
    }]')
else
    authdata_out="$(read_authdata)"
    auth_rc=0
    if [[ -z "${PBP_CHRONYC_AUTHDATA_FILE:-}" ]] && ! command -v chronyc &>/dev/null; then
        auth_rc=127
    fi

    if [[ $auth_rc -eq 127 && -z "${authdata_out//[[:space:]]/}" ]]; then
        nts_state="UNAVAILABLE"
    else
        nts_state="$(assess_nts_authdata "$authdata_out")"
        nts_sources="$(count_nts_authenticated_sources "$authdata_out")"
    fi

    case "$nts_state" in
        PASS)
            ;;
        UNVERIFIED)
            findings=$(echo "$findings" | jq '. += [{
                "id": "TIME-001",
                "severity": "INFO",
                "category": "unverified",
                "title": "NTS authentication unverified",
                "description": "chronyc authdata returned 501 Not authorised; privileged access is required to confirm NTS. This is not evidence that NTS is disabled.",
                "state": "UNVERIFIED",
                "remediation": "Re-run with: sudo chronyc -N authdata"
            }]')
            ;;
        WARNING)
            findings=$(echo "$findings" | jq '. += [{
                "id": "TIME-001",
                "severity": "MEDIUM",
                "category": "runtime",
                "title": "NTS configured but not fully established",
                "description": "Authdata is readable and indicates NTS mode, but authentication material looks incomplete",
                "state": "WARNING",
                "remediation": "Verify NTS-KE connectivity (TCP 4460) and source health"
            }]')
            ;;
        FAIL)
            findings=$(echo "$findings" | jq '. += [{
                "id": "TIME-001",
                "severity": "HIGH",
                "category": "runtime",
                "title": "NTS authentication not active",
                "description": "Readable chronyc authdata shows time sources without NTS authentication",
                "state": "FAIL",
                "remediation": "Configure NTS servers in chrony.conf and verify key establishment"
            }]')
            ;;
        UNAVAILABLE)
            findings=$(echo "$findings" | jq '. += [{
                "id": "TIME-001",
                "severity": "MEDIUM",
                "category": "availability",
                "title": "NTS authentication data unavailable",
                "description": "No chronyc authdata output was available to assess NTS",
                "state": "UNAVAILABLE",
                "remediation": "Ensure chronyd is running and chronyc can query it"
            }]')
            ;;
        ERROR|*)
            findings=$(echo "$findings" | jq --arg st "$nts_state" '. += [{
                "id": "TIME-001",
                "severity": "MEDIUM",
                "category": "error",
                "title": "NTS authentication assessment error",
                "description": ("Unexpected chronyc authdata output; state=" + $st),
                "state": "ERROR",
                "remediation": "Inspect chronyc -N authdata output manually"
            }]')
            nts_state="ERROR"
            ;;
    esac
fi

tracking_out="$(read_tracking)"
if [[ -n "${tracking_out}" ]]; then
    if ! printf '%s\n' "$tracking_out" | grep -q "Leap status.*Normal"; then
        findings=$(echo "$findings" | jq '. += [{
            "id": "TIME-002",
            "severity": "MEDIUM",
            "category": "runtime",
            "title": "Time synchronization issue",
            "description": "Chrony tracking shows abnormal leap status",
            "remediation": "Check network connectivity to time servers"
        }]')
    fi

    offset=$(printf '%s\n' "$tracking_out" | awk '/System time/ {print $4}' | sed 's/seconds//')
    if [[ -n "${offset:-}" ]] && (( $(echo "${offset:-0} > 1.0" | bc -l 2>/dev/null || echo 0) )); then
        findings=$(echo "$findings" | jq --arg off "$offset" '. += [{
            "id": "TIME-003",
            "severity": "MEDIUM",
            "category": "runtime",
            "title": "Clock offset exceeds threshold",
            "description": ("Clock offset: " + $off + " seconds"),
            "remediation": "Allow more time for synchronization or check time sources"
        }]')
    fi
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    --arg nts "$nts_sources" \
    --arg state "$nts_state" \
    '{
        module: "time",
        findings: $findings,
        risk_score: ($score | tonumber),
        nts_sources: ($nts | tonumber),
        nts_state: $state,
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Time security scan complete: ${report_id} (nts_state=${nts_state})"
