#!/usr/bin/env bash
# Fixture-based regression tests for DNS/NTS hardening consistency.
# Does NOT read live /etc, run chronyc/lsattr/unbound-control, or execute apply script.
set -euo pipefail

PBP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PBP_ROOT
FIXTURES="${PBP_ROOT}/tests/fixtures"
# shellcheck source=core/lib/dns_time_diagnostics.sh
source "${PBP_ROOT}/core/lib/dns_time_diagnostics.sh"

TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pbp-dns-nts-test.XXXXXX")"
TEST_TMPDIR="$(cd "$TEST_TMPDIR" && pwd -P)"

cleanup_test_tmpdir() {
    local requested="${1:-$TEST_TMPDIR}"
    local tmp_parent

    tmp_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
    if [[ "$requested" != "$TEST_TMPDIR" \
        || "$requested" != "$tmp_parent"/pbp-dns-nts-test.* \
        || ! -d "$requested" \
        || -L "$requested" ]]; then
        return 1
    fi
    rm -rf -- "$TEST_TMPDIR"
}

# shellcheck disable=SC2317
on_exit() {
    local status=$?
    trap - EXIT HUP INT TERM
    if ! cleanup_test_tmpdir; then
        echo "Test cleanup refused an invalid temporary directory: $TEST_TMPDIR" >&2
        if [[ $status -eq 0 ]]; then
            status=1
        fi
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Regression guard: cleanup must reject a pre-existing shared path and leave it alone.
SHARED_TMPDIR="${TMPDIR:-/tmp}/pbp-dns-nts-test"
if [[ -d "$SHARED_TMPDIR" && ! -L "$SHARED_TMPDIR" ]]; then
    shared_manifest_before="$(find "$SHARED_TMPDIR" -type f -print0 | sort -z | xargs -0 -r sha256sum)"
    if cleanup_test_tmpdir "$SHARED_TMPDIR"; then
        echo "✗ cleanup accepted a pre-existing shared temporary path" >&2
        exit 1
    fi
    shared_manifest_after="$(find "$SHARED_TMPDIR" -type f -print0 | sort -z | xargs -0 -r sha256sum)"
    if [[ "$shared_manifest_before" != "$shared_manifest_after" ]]; then
        echo "✗ pre-existing shared temporary contents changed" >&2
        exit 1
    fi
fi

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "✓ ${desc}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ ${desc} (expected='${expected}' actual='${actual}')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local desc="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    if "$@"; then
        echo "✓ ${desc}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ ${desc}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_false() {
    local desc="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! "$@"; then
        echo "✓ ${desc}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ ${desc} (expected failure)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== NTS authdata classification ==="
assert_eq "501 Not authorised -> UNVERIFIED" \
    "UNVERIFIED" "$(assess_nts_authdata "$(cat "${FIXTURES}/nts/authdata_501.txt")")"
assert_eq "Authenticated NTS rows -> PASS" \
    "PASS" "$(assess_nts_authdata "$(cat "${FIXTURES}/nts/authdata_pass.txt")")"
assert_eq "Readable non-NTS sources -> FAIL" \
    "FAIL" "$(assess_nts_authdata "$(cat "${FIXTURES}/nts/authdata_fail_no_nts.txt")")"
assert_eq "NTS mode with zero KeyID -> WARNING" \
    "WARNING" "$(assess_nts_authdata "$(cat "${FIXTURES}/nts/authdata_warning_weak.txt")")"
assert_eq "Empty authdata -> UNAVAILABLE" \
    "UNAVAILABLE" "$(assess_nts_authdata "")"
assert_eq "Garbage authdata -> ERROR" \
    "ERROR" "$(assess_nts_authdata "totally unexpected output")"
assert_eq "PASS fixture authenticated source count" \
    "3" "$(count_nts_authenticated_sources "$(cat "${FIXTURES}/nts/authdata_pass.txt")")"
assert_eq "FAIL fixture authenticated source count" \
    "0" "$(count_nts_authenticated_sources "$(cat "${FIXTURES}/nts/authdata_fail_no_nts.txt")")"

echo
echo "=== lsattr immutable-bit parsing ==="
assert_true "immutable set fixture detected" \
    resolv_conf_immutable_from_lsattr "$(cat "${FIXTURES}/lsattr/immutable_set.txt")"
assert_false "immutable unset fixture not detected" \
    resolv_conf_immutable_from_lsattr "$(cat "${FIXTURES}/lsattr/immutable_unset.txt")"

echo
echo "=== Canonical Unbound template policy ==="
CANON="$(cat "${PBP_ROOT}/configs/unbound.conf")"
assert_true "forward-first: no present" unbound_has_fail_closed_forwarding "$CANON"
assert_eq "exactly one trust-anchor declaration" "1" "$(unbound_trust_anchor_count "$CANON")"
assert_eq "remote-control control-enable is yes" "yes" "$(unbound_remote_control_enable "$CANON")"
assert_true "control-interface unix socket present" \
    grep -Eq 'control-interface:[[:space:]]*/run/unbound\.ctl' <<<"$CANON"
assert_false "no include-toplevel glob of conf.d" \
    grep -Eq 'include-toplevel:.*unbound\.conf\.d/\*\.conf' <<<"$CANON"
assert_false "bad fixture has fail-closed forwarding" \
    unbound_has_fail_closed_forwarding "$(cat "${FIXTURES}/dns/unbound_forward_first_yes.conf")"
assert_true "canonical root forward-zone enables DoT" \
    unbound_root_forward_zone_has_setting "$CANON" "forward-tls-upstream" "yes"
assert_false "non-root forward-zone does not satisfy root DoT policy" \
    unbound_root_forward_zone_has_setting \
    "$(cat "${FIXTURES}/dns/unbound_nonroot_forward_policy.conf")" "forward-tls-upstream" "yes"
assert_false "commented DNSSEC directives are not active" \
    unbound_has_dnssec_validation "$(cat "${FIXTURES}/dns/unbound_nonroot_forward_policy.conf")"
assert_false "DNSSEC hardening without a trust anchor is not validation" \
    unbound_has_dnssec_validation "$(cat "${FIXTURES}/dns/unbound_zero_trust_anchor.conf")"
assert_eq "commented trust-anchor directive is not counted" \
    "0" "$(unbound_trust_anchor_count "$(cat "${FIXTURES}/dns/unbound_nonroot_forward_policy.conf")")"
assert_eq "zero trust-anchor declarations return count successfully" \
    "0" "$(unbound_trust_anchor_count "$(cat "${FIXTURES}/dns/unbound_zero_trust_anchor.conf")")"
dup_ta_count="$(unbound_trust_anchor_count "$(cat "${FIXTURES}/dns/unbound_duplicate_ta.conf")")"
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "${dup_ta_count}" -gt 1 ]]; then
    echo "✓ duplicate TA fixture count > 1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "✗ duplicate TA fixture count > 1 (count=${dup_ta_count})"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo
echo "=== Apply script consumes canonical template (no Unbound heredoc) ==="
APPLY="${PBP_ROOT}/scripts/apply_dns_hardening.sh"
assert_true "apply script references configs/unbound.conf" \
    grep -Eq 'configs/unbound\.conf|CANONICAL_UNBOUND_CONF' "$APPLY"
# shellcheck disable=SC2016
assert_true "apply script copies/cp from canonical path" \
    grep -Eq 'cp .*CANONICAL_UNBOUND_CONF|cp "\$CANONICAL_UNBOUND_CONF"' "$APPLY"
assert_false "apply script has no unbound.conf heredoc sink" \
    grep -Eq 'cat > /etc/unbound/unbound\.conf <<' "$APPLY"
# Stronger: no multi-line server: heredoc embedding forward-zone inside apply script
assert_false "apply script does not embed forward-zone heredoc body" \
    grep -Eq '^[[:space:]]*forward-zone:' "$APPLY"
assert_false "apply script does not embed forward-addr heredoc body" \
    grep -Eq 'forward-addr:[[:space:]]*1\.1\.1\.1' "$APPLY"

echo
echo "=== No divergent Unbound heredoc elsewhere in scripts/ ==="
if grep -REq 'forward-addr:[[:space:]]*1\.1\.1\.1@853' "${PBP_ROOT}/scripts" 2>/dev/null; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "✗ leftover Unbound forward-addr embedding in scripts/"
else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "✓ no Unbound forward-addr embedding in scripts/"
fi

echo
echo "=== Time scanner fixture integration (501 -> UNVERIFIED finding) ==="
export PBP_STATE_DIR="${TEST_TMPDIR}/state"
export PBP_LOG_DIR="${TEST_TMPDIR}/log"
export PBP_BACKUP_DIR="${TEST_TMPDIR}/backups"
export PBP_REPORT_DIR="${TEST_TMPDIR}/reports/time-501"
export PBP_MODULES_DIR="${PBP_ROOT}/modules"
mkdir -p "$PBP_STATE_DIR" "$PBP_LOG_DIR" "$PBP_REPORT_DIR"

export PBP_CHRONYC_AUTHDATA_FILE="${FIXTURES}/nts/authdata_501.txt"
export PBP_CHRONYC_TRACKING_FILE="${FIXTURES}/nts/tracking_normal.txt"
latest_json() {
    find "${PBP_REPORT_DIR}/json" -type f -name '*.json' -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr | head -1 | cut -d' ' -f2-
}

bash "${PBP_ROOT}/modules/time/scan.sh" >/dev/null
latest_report="$(latest_json)"
state_501="$(jq -r '.data.nts_state // empty' "$latest_report" 2>/dev/null || true)"
finding_state_501="$(jq -r '.data.findings[]? | select(.id=="TIME-001") | .state' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "time scan nts_state for 501 fixture" "UNVERIFIED" "${state_501:-}"
assert_eq "TIME-001 state field UNVERIFIED" "UNVERIFIED" "${finding_state_501:-}"
sev_501="$(jq -r '.data.findings[]? | select(.id=="TIME-001") | .severity' "$latest_report" 2>/dev/null | head -1 || true)"
assert_true "501 does not produce HIGH severity FAIL" \
    bash -c "[[ '${sev_501}' != 'HIGH' ]]"

PBP_REPORT_DIR="${TEST_TMPDIR}/reports/time-fail"
mkdir -p "$PBP_REPORT_DIR"
export PBP_CHRONYC_AUTHDATA_FILE="${FIXTURES}/nts/authdata_fail_no_nts.txt"
bash "${PBP_ROOT}/modules/time/scan.sh" >/dev/null
latest_report="$(latest_json)"
state_fail="$(jq -r '.data.nts_state // empty' "$latest_report" 2>/dev/null || true)"
finding_state_fail="$(jq -r '.data.findings[]? | select(.id=="TIME-001") | .state' "$latest_report" 2>/dev/null | head -1 || true)"
sev_fail="$(jq -r '.data.findings[]? | select(.id=="TIME-001") | .severity' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "time scan nts_state for non-NTS fixture" "FAIL" "${state_fail:-}"
assert_eq "TIME-001 state field FAIL" "FAIL" "${finding_state_fail:-}"
assert_eq "non-NTS produces HIGH severity" "HIGH" "${sev_fail:-}"

echo
echo "=== DNS scanner config vs runtime separation (fixtures only) ==="
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-healthy"
mkdir -p "$PBP_REPORT_DIR"
unset PBP_CHRONYC_AUTHDATA_FILE PBP_CHRONYC_TRACKING_FILE
export PBP_DNS_SKIP_LIVE_RUNTIME=1
export PBP_FAKE_ACTIVE_SERVICES="unbound"
export PBP_UNBOUND_CONF_FILE="${PBP_ROOT}/configs/unbound.conf"
export PBP_RESOLV_CONF_FILE="${FIXTURES}/dns/resolv_localhost.txt"
export PBP_LSATTR_FILE="${FIXTURES}/lsattr/immutable_set.txt"
export PBP_NM_PRINT_CONFIG_FILE="${FIXTURES}/dns/nm_dns_none.txt"
export PBP_DIG_VALID_FILE="${FIXTURES}/dns/dig_valid_ad.txt"
export PBP_DIG_BOGUS_FILE="${FIXTURES}/dns/dig_bogus_servfail.txt"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
# Healthy fixture set should not raise DNS-007 / DNS-010 / DNS-011
bad_ids="$(jq -r '.data.findings[]?.id // empty' "$latest_report" 2>/dev/null | sort -u | tr '\n' ' ')"
assert_false "healthy fixtures do not flag fail-closed missing" \
    bash -c "echo '${bad_ids}' | grep -q 'DNS-007'"
assert_false "healthy fixtures do not flag DNSSEC runtime failure" \
    bash -c "echo '${bad_ids}' | grep -q 'DNS-010'"

# Missing trust anchors must produce a finding without aborting the scan. The
# unrelated sibling fixture contains a trust anchor but is not included.
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-zero-trust-anchor"
mkdir -p "$PBP_REPORT_DIR"
export PBP_UNBOUND_CONF_FILE="${FIXTURES}/dns/unbound_zero_trust_anchor.conf"
export PBP_RESOLV_CONF_FILE="${FIXTURES}/dns/resolv_localhost.txt"
export PBP_LSATTR_FILE="${FIXTURES}/lsattr/immutable_set.txt"
export PBP_NM_PRINT_CONFIG_FILE="${FIXTURES}/dns/nm_dns_none.txt"
export PBP_DIG_VALID_FILE="${FIXTURES}/dns/dig_valid_ad.txt"
export PBP_DIG_BOGUS_FILE="${FIXTURES}/dns/dig_bogus_servfail.txt"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
zero_anchor_finding="$(jq -r '.data.findings[]? | select(.id=="DNS-002") | .id' "$latest_report" 2>/dev/null | head -1 || true)"
zero_anchor_duplicate="$(jq -r '.data.findings[]? | select(.id=="DNS-008") | .id' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "zero trust-anchor scan completed and reported DNS-002" "DNS-002" "${zero_anchor_finding:-}"
assert_eq "unreferenced sibling config was not read" "" "${zero_anchor_duplicate:-}"

# Settings in a non-root zone or comments must not satisfy the root policy.
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-nonroot-forward-policy"
mkdir -p "$PBP_REPORT_DIR"
export PBP_UNBOUND_CONF_FILE="${FIXTURES}/dns/unbound_nonroot_forward_policy.conf"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
nonroot_findings="$(jq -r '.data.findings[]?.id // empty' "$latest_report" 2>/dev/null | sort -u | tr '\n' ' ')"
assert_true "non-root DoT policy does not suppress DNS-001" \
    bash -c "echo '${nonroot_findings}' | grep -q 'DNS-001'"
assert_true "commented DNSSEC directives do not suppress DNS-002" \
    bash -c "echo '${nonroot_findings}' | grep -q 'DNS-002'"
assert_true "non-root fail-closed policy does not suppress DNS-007" \
    bash -c "echo '${nonroot_findings}' | grep -q 'DNS-007'"

# Follow explicit include directives only; do not concatenate unrelated files
# from the directory containing the main config.
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-includes"
mkdir -p "$PBP_REPORT_DIR"
export PBP_UNBOUND_CONF_FILE="${FIXTURES}/dns/unbound_include_main.conf"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
included_description="$(jq -r '.data.findings[]? | select(.id=="DNS-008") | .description' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "explicit Unbound include was followed without reading sibling configs" \
    "Found 2 auto-trust-anchor-file declarations; Unbound may fail to start" \
    "${included_description:-}"

# Immutable unset should produce DNS-006 configuration finding
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-immutable"
mkdir -p "$PBP_REPORT_DIR"
export PBP_LSATTR_FILE="${FIXTURES}/lsattr/immutable_unset.txt"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
dns006_cat="$(jq -r '.data.findings[]? | select(.id=="DNS-006") | .category' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "DNS-006 category is configuration" "configuration" "${dns006_cat:-}"

# forward-first: yes fixture should produce DNS-007
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-forward-first"
mkdir -p "$PBP_REPORT_DIR"
export PBP_UNBOUND_CONF_FILE="${FIXTURES}/dns/unbound_forward_first_yes.conf"
export PBP_LSATTR_FILE="${FIXTURES}/lsattr/immutable_set.txt"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
dns007="$(jq -r '.data.findings[]? | select(.id=="DNS-007") | .id' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "forward-first yes produces DNS-007" "DNS-007" "${dns007:-}"

# Runtime fixture failure (no AD) should produce DNS-010 with category runtime
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-runtime"
mkdir -p "$PBP_REPORT_DIR"
export PBP_UNBOUND_CONF_FILE="${PBP_ROOT}/configs/unbound.conf"
export PBP_DIG_VALID_FILE="${FIXTURES}/dns/dig_valid_no_ad.txt"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
dns010_cat="$(jq -r '.data.findings[]? | select(.id=="DNS-010") | .category' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "DNS-010 category is runtime" "runtime" "${dns010_cat:-}"

# External resolv should produce DNS-004 configuration (not labelled verified leak)
PBP_REPORT_DIR="${TEST_TMPDIR}/reports/dns-external-resolv"
mkdir -p "$PBP_REPORT_DIR"
export PBP_RESOLV_CONF_FILE="${FIXTURES}/dns/resolv_external.txt"
export PBP_DIG_VALID_FILE="${FIXTURES}/dns/dig_valid_ad.txt"
bash "${PBP_ROOT}/modules/dns/scan.sh" >/dev/null
latest_report="$(latest_json)"
dns004_cat="$(jq -r '.data.findings[]? | select(.id=="DNS-004") | .category' "$latest_report" 2>/dev/null | head -1 || true)"
dns004_title="$(jq -r '.data.findings[]? | select(.id=="DNS-004") | .title' "$latest_report" 2>/dev/null | head -1 || true)"
assert_eq "DNS-004 category is configuration" "configuration" "${dns004_cat:-}"
assert_false "DNS-004 title does not claim verified leak" \
    bash -c "echo '${dns004_title}' | grep -Eiq 'verified leak|confirmed leak'"

echo
echo "=== Summary ==="
echo "Tests run: ${TESTS_RUN}"
echo "Passed:    ${TESTS_PASSED}"
echo "Failed:    ${TESTS_FAILED}"
if [[ "$TESTS_FAILED" -gt 0 ]]; then
    exit 1
fi
exit 0
