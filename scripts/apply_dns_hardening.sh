#!/usr/bin/env bash
# ==============================================================================
# apply_dns_hardening.sh
# Parrot Booty Protection - Automated DNS Hardening & Resolution Fix Script
#
# Canonical Unbound configuration: configs/unbound.conf (relative to repo root).
# This script does NOT embed an Unbound configuration heredoc.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CANONICAL_UNBOUND_CONF="${REPO_ROOT}/configs/unbound.conf"
# shellcheck source=scripts/lib/dns_hardening_transaction.sh
source "${SCRIPT_DIR}/lib/dns_hardening_transaction.sh"
# shellcheck source=scripts/lib/dns_hardening_paths.sh
source "${SCRIPT_DIR}/lib/dns_hardening_paths.sh"
TEST_ROOT_INPUT=""
TEST_ROOT=""
DRY_RUN=0

host_path() {
    printf '%s%s' "$TEST_ROOT" "$1"
}

TX_DIR=""
STAGE_DIR=""
BACKUP_DIR=""
BACKUP_READY=0
TRANSACTION_ACTIVE=0
NM_SERVICE_TOUCHED=0
UNBOUND_SERVICE_TOUCHED=0
NM_WAS_ACTIVE=0
UNBOUND_WAS_ACTIVE=0

usage() {
    cat <<'USAGE'
Usage: sudo bash scripts/apply_dns_hardening.sh [--dry-run]

  --dry-run   Report planned actions without modifying files, attributes, or services.

Canonical Unbound template: configs/unbound.conf

Internal test mode: --test-root DIR (DIR must be a generated test directory under TMPDIR)
USAGE
}

log_info() { echo -e "${BLUE}$*${NC}"; }
log_ok() { echo -e "${GREEN}$*${NC}"; }
log_warn() { echo -e "${YELLOW}$*${NC}"; }
log_err() { echo -e "${RED}$*${NC}" >&2; }

die() {
    log_err "❌ $*"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        --test-root)
            [[ -z "$TEST_ROOT_INPUT" ]] || die "--test-root may only be specified once"
            shift
            [[ $# -gt 0 ]] || die "--test-root requires a directory"
            TEST_ROOT_INPUT="$1"
            shift
            continue
            ;;
        --test-root=*)
            [[ -z "$TEST_ROOT_INPUT" ]] || die "--test-root may only be specified once"
            TEST_ROOT_INPUT="${1#--test-root=}"
            [[ -n "$TEST_ROOT_INPUT" ]] || die "--test-root requires a directory"
            ;;
        *) die "Unknown argument: $1" ;;
    esac
    shift
done

if [[ -n "$TEST_ROOT_INPUT" ]]; then
    test_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
    TEST_ROOT="$(cd "$TEST_ROOT_INPUT" 2>/dev/null && pwd -P)" \
        || die "Test root must be an existing directory"
    [[ "$TEST_ROOT" == "$test_parent"/pbp-dns-hardening-test.* && ! -L "$TEST_ROOT_INPUT" ]] \
        || die "Test root must be a non-symlink pbp-dns-hardening-test.* directory under TMPDIR"
fi
if [[ -n "$TEST_ROOT" ]]; then
    TMP_ROOT="$(dns_hardening_select_tmp_root 1)" || die "TMPDIR is not an accessible directory"
else
    TMP_ROOT="$(dns_hardening_select_tmp_root 0)" || die "Could not resolve a trusted temporary directory"
fi

test_path_is_trusted() {
    local path="$1" owner_mode mode
    [[ -e "$path" && ! -L "$path" ]] || return 1
    owner_mode="$(/usr/bin/stat -c '%u:%a' -- "$path")" || return 1
    [[ "${owner_mode%%:*}" == "$EUID" ]] || return 1
    mode="${owner_mode#*:}"
    (( (8#$mode & 022) == 0 ))
}

test_tmp_root_is_trusted() {
    local current="$TMP_ROOT" owner_mode owner mode mode_value
    while :; do
        owner_mode="$(/usr/bin/stat -c '%u:%a' -- "$current")" || return 1
        owner="${owner_mode%%:*}"
        mode="${owner_mode#*:}"
        mode_value=$((8#$mode))
        if [[ "$current" == "$TMP_ROOT" ]]; then
            [[ "$owner" == "$EUID" ]] || return 1
            (( (mode_value & 022) == 0 )) || return 1
        else
            [[ "$owner" == "$EUID" || "$owner" == 0 ]] || return 1
            if (( (mode_value & 022) != 0 )); then
                [[ "$owner" == 0 ]] && (( (mode_value & 01000) != 0 )) || return 1
            fi
        fi
        [[ "$current" == "/" ]] && return 0
        current="${current%/*}"
        [[ -n "$current" ]] || current="/"
    done
}

temp_dir_is_valid() {
    local path="$1" pattern="$2"
    local parent="${path%/*}" name="${path##*/}" owner_mode
    parent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 1
    [[ "$parent" == "$TMP_ROOT" && -d "$path" && ! -L "$path" ]] || return 1
    # These are intentional glob patterns for the generated directory names.
    # shellcheck disable=SC2053
    [[ "$name" == $pattern ]] || return 1
    owner_mode="$(stat -c '%u:%a' -- "$path")" || return 1
    [[ "$owner_mode" == "${EUID}:700" ]]
}

test_command_path_safe() {
    local command_name="$1" command_path command_parent current
    if declare -F "$command_name" >/dev/null; then
        die "--test-root requires test-harness executables and refuses shell function overrides: $command_name"
    fi
    command_path="$(builtin type -P "$command_name" 2>/dev/null)" || {
        die "--test-root requires a test-harness $command_name command on PATH"
    }
    [[ "$command_path" == /* && -x "$command_path" && ! -L "$command_path" ]] || {
        die "--test-root requires $command_name to resolve to a regular executable inside the test harness"
    }
    command_parent="$(cd "${command_path%/*}" 2>/dev/null && pwd -P)" || {
        die "Could not resolve test-harness command directory for $command_name"
    }
    [[ "$command_parent" == "$TMP_ROOT" || "$command_parent" == "$TMP_ROOT/"* ]] || {
        die "--test-root requires $command_name to resolve inside the test harness under TMPDIR"
    }
    test_path_is_trusted "$command_path" || {
        die "--test-root requires $command_name to be owned by the current user and not group/other-writable"
    }
    current="$command_parent"
    while [[ "$current" == "$TMP_ROOT" || "$current" == "$TMP_ROOT/"* ]]; do
        test_path_is_trusted "$current" || {
            die "--test-root requires private, current-user-owned command directories: $current"
        }
        [[ "$current" == "$TMP_ROOT" ]] && break
        current="${current%/*}"
    done
}

UNBOUND_TARGET="$(host_path /etc/unbound/unbound.conf)"
NM_CONF_DIR="$(host_path /etc/NetworkManager/conf.d)"
NM_POLICY_PATH="${NM_CONF_DIR}/90-dns-hardening.conf"
NM_LEGACY_PATH="${NM_CONF_DIR}/90-dns-none.conf"
UNBOUND_DROPIN_DIR="$(host_path /etc/unbound/unbound.conf.d)"
RESOLV_TARGET="$(host_path /etc/resolv.conf)"
RESOLV_WRITE_TARGET="$RESOLV_TARGET"
if [[ -L "$RESOLV_TARGET" ]]; then
    [[ -z "$TEST_ROOT" ]] || die "Test-root resolver path must not be a symlink"
    RESOLV_WRITE_TARGET="$(readlink -f -- "$RESOLV_TARGET")" \
        || die "Could not resolve resolver symlink: $RESOLV_TARGET"
fi
REALITY_TARGET="$(host_path /usr/local/bin/dns-reality-check)"
RESTORE_TARGET="$(host_path /usr/local/bin/dns-restore)"
ROOT_KEY_TARGET="$(host_path /var/lib/unbound/root.key)"

test_path_safe() {
    local path="$1"
    local relative="${path#"$TEST_ROOT"/}"
    local current="$TEST_ROOT"
    local component
    local -a components=()
    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" ]] || continue
        current="${current}/${component}"
        [[ ! -L "$current" ]] || {
            printf 'Test-root path contains a symlink: %s\n' "$current" >&2
            return 1
        }
    done
}

if [[ -n "$TEST_ROOT" ]]; then
    test_tmp_root_is_trusted \
        || die "--test-root requires a private current-user-owned TMPDIR under safe ancestors"
    test_path_is_trusted "$TEST_ROOT" \
        || die "--test-root requires a current-user-owned directory not group/other-writable"
    [[ -f "$TEST_ROOT/.pbp-test-root" && ! -L "$TEST_ROOT/.pbp-test-root" ]] \
        || die "Test root is missing its .pbp-test-root marker"
    test_path_is_trusted "$TEST_ROOT/.pbp-test-root" \
        || die "--test-root marker must be current-user-owned and not group/other-writable"
    for required_command in systemctl chattr dig lsattr unbound-checkconf; do
        test_command_path_safe "$required_command"
    done
    for test_path in \
        "$UNBOUND_TARGET" "$NM_POLICY_PATH" "$NM_LEGACY_PATH" "$UNBOUND_DROPIN_DIR" \
        "$RESOLV_TARGET" "$REALITY_TARGET" "$RESTORE_TARGET" "$ROOT_KEY_TARGET" \
        "$(host_path /var/backups)"; do
        test_path_safe "$test_path" || die "Unsafe path under test root"
    done
fi

if [[ $DRY_RUN -eq 0 && $EUID -ne 0 && -z "$TEST_ROOT" ]]; then
    die "This script must be run as root (e.g. sudo bash $0), or use --dry-run"
fi

[[ -f "$CANONICAL_UNBOUND_CONF" ]] || die "Canonical Unbound config missing: $CANONICAL_UNBOUND_CONF"

timestamp() { date +%Y%m%d%H%M%S; }

restore_service_state() {
    local service="$1" was_active="$2" action="$3"
    local restored_status
    if [[ "$was_active" -eq 1 ]]; then
        if [[ "$action" == "reload" ]]; then
            systemctl reload "$service" || return 1
        else
            systemctl restart "$service" || return 1
        fi
        restored_status="$(systemctl is-active "$service" 2>/dev/null || true)"
        [[ "$restored_status" == active ]]
    else
        systemctl stop "$service" >/dev/null 2>&1 || true
        restored_status="$(systemctl is-active "$service" 2>/dev/null || true)"
        [[ "$restored_status" == inactive ]]
    fi
}

rollback_transaction() {
    local failed=0
    local files_restored=0
    log_err "Deployment failed; restoring recorded filesystem state..."
    tx_cleanup_temps || failed=1
    if tx_rollback_files; then
        files_restored=1
    else
        failed=1
    fi

    if [[ "$files_restored" -eq 1 && "$UNBOUND_SERVICE_TOUCHED" -eq 1 ]]; then
        if restore_service_state unbound "$UNBOUND_WAS_ACTIVE" restart; then
            log_info "  Restored Unbound service state"
        else
            log_err "  CRITICAL: failed to restore Unbound service state"
            failed=1
        fi
    fi
    if [[ "$files_restored" -eq 1 && "$NM_SERVICE_TOUCHED" -eq 1 ]]; then
        if restore_service_state NetworkManager "$NM_WAS_ACTIVE" reload; then
            log_info "  Restored NetworkManager service state"
        else
            log_err "  CRITICAL: failed to restore NetworkManager service state"
            failed=1
        fi
    fi
    if [[ "$files_restored" -eq 0 ]]; then
        [[ "$UNBOUND_SERVICE_TOUCHED" -eq 0 ]] \
            || log_err "  CRITICAL: Unbound service restore skipped because file rollback was incomplete"
        [[ "$NM_SERVICE_TOUCHED" -eq 0 ]] \
            || log_err "  CRITICAL: NetworkManager reload skipped because file rollback was incomplete"
    fi

    if [[ "$failed" -eq 0 ]]; then
        log_ok "Rollback verified for every changed path and touched service"
    else
        log_err "CRITICAL: rollback was incomplete; inspect the per-resource errors above"
        log_err "Transaction backup retained at: ${BACKUP_DIR}"
    fi
    return "$failed"
}

cleanup_owned_dir() {
    local path="$1" expected_root="$2" pattern="$3" label="$4"
    local parent name owner_mode
    [[ -n "$path" && ( -e "$path" || -L "$path" ) ]] || return 0
    parent="${path%/*}"
    name="${path##*/}"
    parent="$(cd "$parent" 2>/dev/null && pwd -P)" || {
        log_err "Could not resolve parent directory while cleaning ${label}: ${path}"
        return 1
    }
    # These are intentional glob patterns for the generated directory names.
    # shellcheck disable=SC2053
    if [[ "$name" != $pattern ]]; then
        log_err "Refusing to clean unrecognised ${label} directory: ${path}"
        return 1
    fi
    if [[ "$parent" != "$expected_root" || ! -d "$path" || -L "$path" ]]; then
        log_err "Refusing unsafe ${label} cleanup; directory remains at: ${path}"
        return 1
    fi
    owner_mode="$(stat -c '%u:%a' -- "$path")" || {
        log_err "Could not inspect ${label} directory before cleanup: ${path}"
        return 1
    }
    if [[ "$owner_mode" != "${EUID}:700" ]]; then
        log_err "Refusing ${label} cleanup with unexpected owner or mode (${owner_mode}): ${path}"
        return 1
    fi
    if ! rm -rf -- "$path" || [[ -e "$path" || -L "$path" ]]; then
        log_err "Could not remove ${label} directory; it remains at: ${path}"
        return 1
    fi
}

on_exit() {
    local status=$?
    trap - EXIT
    trap '' HUP INT TERM
    if [[ "$TRANSACTION_ACTIVE" -eq 1 && "$status" -ne 0 ]]; then
        if ! rollback_transaction; then
            status=2
        fi
    fi
    tx_cleanup_temps || status=2
    if ! cleanup_owned_dir "$STAGE_DIR" "$TMP_ROOT" 'pbp-unbound-stage.*' "staging"; then
        status=2
    fi
    if ! cleanup_owned_dir "$TX_DIR" "$TMP_ROOT" 'pbp-dns-hardening.*' "transaction snapshot"; then
        status=2
    fi
    if [[ "$BACKUP_READY" -eq 0 ]]; then
        backup_root="$(cd "$(host_path /var/backups)" 2>/dev/null && pwd -P)" || backup_root=""
        if [[ -n "$backup_root" ]] \
            && ! cleanup_owned_dir "$BACKUP_DIR" "$backup_root" 'pbp-dns-hardening-*' "transaction backup"; then
            status=2
        fi
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}        APPLYING DNS HARDENING & RESOLVER FIXES                   ${NC}"
if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}        MODE: DRY-RUN (no host changes)                           ${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "  Canonical Unbound template: ${CANONICAL_UNBOUND_CONF}"
echo

# ------------------------------------------------------------------------------
# 1. FIX NETWORKMANAGER CONFLICT
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/6] Resolving NetworkManager DNS management conflicts...${NC}"

if [[ $DRY_RUN -eq 1 ]]; then
    log_warn "  [dry-run] Would archive 90-dns-none.conf if present and write dns=none"
else
    command -v systemctl >/dev/null 2>&1 || die "systemctl is required for deployment"
    [[ -d "$(host_path /var/backups)" ]] || die "Backup directory is missing: $(host_path /var/backups)"
    nm_initial_status="$(systemctl is-active NetworkManager 2>/dev/null || true)"
    unbound_initial_status="$(systemctl is-active unbound 2>/dev/null || true)"
    case "$nm_initial_status" in
        active) NM_WAS_ACTIVE=1 ;;
        inactive) NM_WAS_ACTIVE=0 ;;
        *) die "Cannot safely snapshot NetworkManager service state: ${nm_initial_status:-unknown}" ;;
    esac
    case "$unbound_initial_status" in
        active) UNBOUND_WAS_ACTIVE=1 ;;
        inactive) UNBOUND_WAS_ACTIVE=0 ;;
        *) die "Cannot safely snapshot Unbound service state: ${unbound_initial_status:-unknown}" ;;
    esac

    TX_DIR="$(mktemp -d "${TMP_ROOT}/pbp-dns-hardening.XXXXXX")" \
        || die "Could not create transaction snapshot directory"
    TX_DIR="$(cd "$TX_DIR" && pwd -P)" || die "Could not resolve transaction snapshot directory"
    temp_dir_is_valid "$TX_DIR" 'pbp-dns-hardening.*' \
        || die "Transaction snapshot directory has unexpected owner, mode, or location"
    tx_track "$NM_POLICY_PATH" || die "Could not snapshot NetworkManager policy"
    tx_track "$NM_LEGACY_PATH" || die "Could not snapshot legacy NetworkManager policy"
    tx_track "${NM_LEGACY_PATH}.disabled" || die "Could not snapshot NetworkManager archive path"
    tx_track "$UNBOUND_TARGET" || die "Could not snapshot Unbound configuration"
    for dropin in root-auto-trust-anchor-file.conf remote-control.conf; do
        tx_track "${UNBOUND_DROPIN_DIR}/${dropin}" || die "Could not snapshot Unbound drop-in"
        tx_track "${UNBOUND_DROPIN_DIR}/${dropin}.disabled.pbp" || die "Could not snapshot Unbound drop-in archive"
    done
        tx_track "$RESOLV_TARGET" || die "Could not snapshot resolver path"
        if [[ "$RESOLV_WRITE_TARGET" != "$RESOLV_TARGET" ]]; then
            tx_track "$RESOLV_WRITE_TARGET" || die "Could not snapshot resolver target"
        fi
    tx_track "$REALITY_TARGET" || die "Could not snapshot DNS reality-check tool"
    tx_track "$RESTORE_TARGET" || die "Could not snapshot DNS restore tool"
        for managed_dir in "$NM_CONF_DIR" "$UNBOUND_DROPIN_DIR" "$(host_path /usr/local/bin)"; do
            if [[ ! -d "$managed_dir" ]]; then
                tx_track "$managed_dir" || die "Could not snapshot managed directory: $managed_dir"
            fi
        done

        BACKUP_DIR="$(mktemp -d "$(host_path /var/backups)/pbp-dns-hardening-$(timestamp).XXXXXX")" \
        || die "Could not create persistent transaction backup"
    backup_root="$(cd "$(host_path /var/backups)" && pwd -P)"
    backup_parent="${BACKUP_DIR%/*}"
    backup_parent="$(cd "$backup_parent" && pwd -P)"
    backup_owner_mode="$(stat -c '%u:%a' -- "$BACKUP_DIR")"
    [[ "$backup_parent" == "$backup_root" && "$backup_owner_mode" == "${EUID}:700" ]] \
        || die "Transaction backup directory has unexpected owner, mode, or location"
    mkdir "${BACKUP_DIR}/resources" || die "Could not create transaction backup resources"
    : > "${BACKUP_DIR}/manifest.tsv"
    for index in "${!TX_PATHS[@]}"; do
        resource="${TX_PATHS[$index]}"
        exists="${TX_BASE_EXISTS[$resource]}"
        printf '%s\t%s\t%s\t%s\t%s\n' "$index" "$exists" "$resource" \
            "${TX_BASE_FLAGS[$resource]}" "${TX_BASE_FP[$resource]}" >> "${BACKUP_DIR}/manifest.tsv"
        if [[ "$exists" -eq 1 ]]; then
            cp -a -- "${TX_DIR}/snapshot.${index}" "${BACKUP_DIR}/resources/${index}" \
                || die "Could not persist backup for $resource"
        fi
    done
    chmod 600 "${BACKUP_DIR}/manifest.tsv"
    BACKUP_READY=1
    log_info "Transaction backup location: ${BACKUP_DIR}"

    TRANSACTION_ACTIVE=1
    tx_ensure_dir "$NM_CONF_DIR" || die "Could not create NetworkManager configuration directory"
    tx_ensure_dir "$UNBOUND_DROPIN_DIR" || die "Could not create Unbound drop-in directory"
    tx_ensure_dir "$(host_path /usr/local/bin)" || die "Could not create /usr/local/bin"

    if [[ -f "$NM_LEGACY_PATH" ]]; then
        echo "  - Archiving ${NM_LEGACY_PATH}"
        tx_move "$NM_LEGACY_PATH" "${NM_LEGACY_PATH}.disabled" \
            || die "Could not archive legacy NetworkManager DNS policy"
    fi

    tx_atomic_write "$NM_POLICY_PATH" 644 <<'EOF'
[main]
dns=none
systemd-resolved=false
EOF

    echo "  - Reloading NetworkManager configuration..."
    NM_SERVICE_TOUCHED=1
    if ! systemctl reload NetworkManager; then
        die "NetworkManager reload failed"
    fi
fi
log_ok "  ✓ NetworkManager DNS policy step complete (dns=none)"
echo

# ------------------------------------------------------------------------------
# 2. HARDEN UNBOUND CONFIGURATION (from canonical template)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/6] Updating Unbound from canonical template...${NC}"

STAGE_DIR=""

if [[ $DRY_RUN -eq 1 ]]; then
    log_warn "  [dry-run] Would validate the template, install it, and restart Unbound"
    if ! unbound-checkconf "$CANONICAL_UNBOUND_CONF"; then
        die "Canonical Unbound configuration failed unbound-checkconf"
    fi
    log_ok "  [dry-run] Canonical Unbound configuration passed unbound-checkconf"
else
    STAGE_DIR="$(mktemp -d "${TMP_ROOT}/pbp-unbound-stage.XXXXXX")"
    STAGE_DIR="$(cd "$STAGE_DIR" && pwd -P)"
    temp_dir_is_valid "$STAGE_DIR" 'pbp-unbound-stage.*' \
        || die "Unbound staging directory has unexpected owner, mode, or location"
    STAGE_CONF="${STAGE_DIR}/unbound.conf"
    cp "$CANONICAL_UNBOUND_CONF" "$STAGE_CONF"
    TX_TEMP_FILES+=("$STAGE_CONF")

    echo "  - Validating staged configuration..."
    # Stage a trust-anchor path unbound-checkconf can read without requiring live deploy yet
    if [[ -r "$ROOT_KEY_TARGET" ]]; then
        cp "$ROOT_KEY_TARGET" "${STAGE_DIR}/root.key"
        sed -i "s|/var/lib/unbound/root.key|${STAGE_DIR}/root.key|g" "$STAGE_CONF"
    fi
    if ! unbound-checkconf "$STAGE_CONF"; then
        die "Staged Unbound configuration failed unbound-checkconf"
    fi
    # Re-copy canonical (with production trust-anchor path) for install
    cp "$CANONICAL_UNBOUND_CONF" "$STAGE_CONF"

    # Disable package drop-ins that would duplicate trust-anchor or remote-control
    for dropin in root-auto-trust-anchor-file.conf remote-control.conf; do
        src="${UNBOUND_DROPIN_DIR}/${dropin}"
        if [[ -f "$src" ]]; then
            tx_move "$src" "${src}.disabled.pbp" || die "Could not disable conflicting drop-in: ${dropin}"
            echo "  - Disabled conflicting drop-in: ${dropin}"
        fi
    done

    echo "  - Installing canonical configuration atomically..."
    tx_atomic_copy "$STAGE_CONF" "$UNBOUND_TARGET" 644 || die "Failed to atomically install Unbound config"
    rm -rf -- "$STAGE_DIR"
    STAGE_DIR=""

    echo "  - Verifying installed configuration..."
    if ! unbound-checkconf "$UNBOUND_TARGET"; then
        die "Installed Unbound configuration failed validation"
    fi

    echo "  - Restarting Unbound service..."
    UNBOUND_SERVICE_TOUCHED=1
    if ! systemctl restart unbound; then
        die "Unbound restart failed"
    fi
    sleep 1
    if ! systemctl is-active --quiet unbound; then
        die "Unbound is not active after restart"
    fi
fi
log_ok "  ✓ Unbound configured from canonical template"
echo

# ------------------------------------------------------------------------------
# 3. VERIFY AND LOCK RESOLV.CONF
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/6] Verifying and enforcing immutable /etc/resolv.conf...${NC}"

resolv_has_localhost=0
resolv_is_immutable=0
if [[ -f "$RESOLV_TARGET" ]] && grep -qE '^[[:space:]]*nameserver[[:space:]]+127\.0\.0\.1([[:space:]]|$)' "$RESOLV_TARGET" 2>/dev/null; then
    resolv_has_localhost=1
fi
if command -v lsattr >/dev/null 2>&1; then
    _lsattr_out="$(lsattr "$RESOLV_WRITE_TARGET" 2>/dev/null || true)"
    _flags="$(printf '%s\n' "$_lsattr_out" | awk 'NF { print $1; exit }')"
    if [[ -n "$_flags" && "$_flags" == *i* ]]; then
        resolv_is_immutable=1
    fi
fi

if [[ $DRY_RUN -eq 1 ]]; then
    log_warn "  [dry-run] localhost=${resolv_has_localhost} immutable=${resolv_is_immutable}"
else
    if [[ $resolv_has_localhost -eq 0 ]]; then
        tx_assert_expected "$RESOLV_WRITE_TARGET" \
            || die "Resolver changed unexpectedly before replacement"
        if chattr -i "$RESOLV_WRITE_TARGET" 2>/dev/null; then
            tx_mark "$RESOLV_WRITE_TARGET" || die "Could not record resolver attribute change"
        fi
        tx_atomic_write "$RESOLV_WRITE_TARGET" 644 <<'EOF'
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
EOF
        resolv_has_localhost=1
    fi
    if [[ $resolv_is_immutable -eq 0 ]]; then
        tx_assert_expected "$RESOLV_WRITE_TARGET" \
            || die "Resolver changed unexpectedly before locking"
        if ! chattr +i "$RESOLV_WRITE_TARGET"; then
            die "Failed to set immutable bit on ${RESOLV_WRITE_TARGET}"
        fi
        tx_mark "$RESOLV_WRITE_TARGET" || die "Could not record resolver immutable attribute"
        resolv_is_immutable=1
    fi
fi

if [[ $resolv_has_localhost -eq 1 && $resolv_is_immutable -eq 1 ]]; then
    log_ok "  ✓ ${RESOLV_TARGET} pinned to 127.0.0.1 and locked (+i)"
elif [[ $DRY_RUN -eq 1 ]]; then
    log_warn "  [dry-run] Would pin ${RESOLV_TARGET} to localhost and enforce immutable state"
    if [[ $resolv_has_localhost -eq 1 && $resolv_is_immutable -eq 0 ]]; then
        log_warn "  ⚠ /etc/resolv.conf points to 127.0.0.1 but is NOT immutable"
    fi
elif [[ $resolv_has_localhost -eq 1 && $resolv_is_immutable -eq 0 ]]; then
    die "Resolver pin OK but immutable lock was not applied"
else
    die "Resolver is not correctly pinned to 127.0.0.1"
fi
echo

# ------------------------------------------------------------------------------
# 4. FIREWALL — DEFERRED (do not mutate host nftables in this revision)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[4/6] Firewall / DNS egress policy...${NC}"
log_warn "  ⚠ DEFERRED: host nftables redesign is intentionally not applied by this script."
log_warn "  ⚠ Future review must account for NTS TCP/4460, UDP/123, UDP/4123 (Netnod),"
log_warn "    rootless Podman/pasta/aardvark paths, and DoH/DoQ policy."
log_warn "  ⚠ Repository configs/nftables.conf is not deployed by this script."
echo

# ------------------------------------------------------------------------------
# 5. INSTALL / REFRESH DIAGNOSTIC & RESTORATION TOOLS
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[5/6] Installing updated diagnostic commands...${NC}"

if [[ $DRY_RUN -eq 1 ]]; then
    log_warn "  [dry-run] Would install /usr/local/bin/dns-reality-check and dns-restore"
else
    tx_atomic_write "$REALITY_TARGET" 755 <<'EOF'
#!/usr/bin/env bash
# DNS Reality Check - Displays active DNS resolution pipeline and leak checks
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS REALITY CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "1. System Resolver Configuration (/etc/resolv.conf):"
grep -E '^(nameserver|options|search)' /etc/resolv.conf | sed 's/^/   /' || true
flags="$(lsattr /etc/resolv.conf 2>/dev/null | awk 'NF { print $1; exit }')"
if [[ -n "${flags:-}" && "$flags" == *i* ]]; then
    echo "   [Status: Immutable (+i) - PROTECTED]"
else
    echo "   [Status: Mutable - WARNING]"
fi
echo

echo "2. Unbound Resolver Status:"
if systemctl is-active --quiet unbound; then
    echo "   ✓ Unbound service is ACTIVE"
else
    echo "   ❌ Unbound service is NOT RUNNING"
fi
echo

echo "3. NetworkManager DNS Policy:"
NM_ACTIVE_DNS="$(NetworkManager --print-config 2>/dev/null | grep -E '^[[:space:]]*dns=' | head -1 || true)"
echo "   Effective NM config: ${NM_ACTIVE_DNS:-dns=(unset)}"
echo

echo "4. Resolution & DNSSEC Verification Test:"
RES_TEST="$(dig +dnssec +time=2 cloudflare.com @127.0.0.1 2>/dev/null || true)"
if echo "$RES_TEST" | grep -q "flags:.*ad.*"; then
    echo "   ✓ Live DNSSEC resolution confirmed (AD flag present)"
else
    echo "   ⚠ DNSSEC AD flag missing or resolution failed (runtime check)"
fi

BOGUS_TEST="$(dig +dnssec +time=2 dnssec-failed.org @127.0.0.1 2>/dev/null || true)"
if echo "$BOGUS_TEST" | grep -q "SERVFAIL"; then
    echo "   ✓ DNSSEC validation active (tampered domains rejected with SERVFAIL)"
else
    echo "   ❌ DNSSEC validation warning: failed domain was not rejected"
fi
echo
EOF

    tx_atomic_write "$RESTORE_TARGET" 755 <<'EOF'
#!/usr/bin/env bash
# Quick restore script for DNS sovereign state
set -euo pipefail
if [[ $EUID -ne 0 ]]; then
    echo "Must run as root" >&2
    exit 1
fi
need_write=0
if ! grep -qE '^[[:space:]]*nameserver[[:space:]]+127\.0\.0\.1([[:space:]]|$)' /etc/resolv.conf 2>/dev/null; then
    need_write=1
fi
flags="$(lsattr /etc/resolv.conf 2>/dev/null | awk 'NF { print $1; exit }')"
if [[ -z "${flags:-}" || "$flags" != *i* ]]; then
    need_write=1
fi
if [[ $need_write -eq 1 ]]; then
    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat > /etc/resolv.conf << 'RESOLV'
# Hardened DNS Configuration - Managed by dns-hardening script
nameserver 127.0.0.1
options edns0 trust-ad
RESOLV
    chattr +i /etc/resolv.conf
fi
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/90-dns-hardening.conf << 'NM'
[main]
dns=none
systemd-resolved=false
NM
if [[ -f /etc/NetworkManager/conf.d/90-dns-none.conf ]]; then
    mv /etc/NetworkManager/conf.d/90-dns-none.conf /etc/NetworkManager/conf.d/90-dns-none.conf.disabled
fi
systemctl reload NetworkManager
if ! unbound-checkconf /etc/unbound/unbound.conf; then
    echo "Unbound config invalid; refusing restart" >&2
    exit 1
fi
systemctl restart unbound
echo "✓ DNS sovereign state restored"
EOF
fi
log_ok "  ✓ Diagnostic tools step complete"
echo

# ------------------------------------------------------------------------------
# 6. TESTING RESOLUTION
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[6/6] Performing live validation...${NC}"

if [[ $DRY_RUN -eq 1 ]]; then
    log_warn "  [dry-run] Skipping live dig validation"
else
    dns_answer=""
    for attempt in 1 2 3 4 5; do
        dns_answer="$(dig +short +time=3 +tries=1 @127.0.0.1 cloudflare.com 2>/dev/null || true)"
        [[ -n "$dns_answer" ]] && break
    done
    if [[ -z "$dns_answer" ]]; then
        die "Local DNS resolution via 127.0.0.1 failed after ${attempt} attempts"
    fi
    log_ok "  ✓ Local DNS resolution via 127.0.0.1 is working."
    TRANSACTION_ACTIVE=0
fi

echo
log_ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $DRY_RUN -eq 1 ]]; then
    log_ok "✅ DRY-RUN COMPLETE — no host configuration was modified"
else
    log_ok "✅ DNS HARDENING FIXES SUCCESSFULLY APPLIED"
fi
log_ok "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Canonical Unbound template: ${CANONICAL_UNBOUND_CONF}"
if [[ $DRY_RUN -eq 0 ]]; then
    echo "Pre-change transaction backup: ${BACKUP_DIR}"
fi
echo "Verify anytime with: dns-reality-check"
echo
