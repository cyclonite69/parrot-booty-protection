#!/usr/bin/env bash
set -euo pipefail

PBP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY_SCRIPT="${PBP_ROOT}/scripts/apply_dns_hardening.sh"
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pbp-dns-hardening-safety.XXXXXX")"
TEST_TMPDIR="$(cd "$TEST_TMPDIR" && pwd -P)"
TEST_ROOT=""

cleanup_test_tmpdir() {
    local requested="${1:-$TEST_TMPDIR}"
    local tmp_parent
    tmp_parent="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
    [[ "$requested" == "$TEST_TMPDIR" \
        && "$requested" == "$tmp_parent"/pbp-dns-hardening-safety.* \
        && -d "$requested" && ! -L "$requested" ]] || return 1
    rm -rf -- "$TEST_TMPDIR"
}

on_exit() {
    local status=$?
    trap - EXIT
    if ! cleanup_test_tmpdir "$TEST_TMPDIR"; then
        echo "Refusing unsafe test cleanup: $TEST_TMPDIR" >&2
        [[ "$status" -ne 0 ]] || status=1
    fi
    exit "$status"
}
trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

TEST_ROOT="$(mktemp -d "${TEST_TMPDIR}/pbp-dns-hardening-test.XXXXXX")"
printf 'parrot-booty-protection safety test\n' > "$TEST_ROOT/.pbp-test-root"
chmod 600 "$TEST_ROOT/.pbp-test-root"
STATE_DIR="${TEST_TMPDIR}/state"
BIN_DIR="${TEST_TMPDIR}/bin"
ORIGINALS="${TEST_TMPDIR}/originals"
mkdir -p "$STATE_DIR" "$BIN_DIR" "$ORIGINALS"
chmod 700 "$STATE_DIR" "$BIN_DIR" "$ORIGINALS"

make_sandbox() {
    mkdir -p \
        "$TEST_ROOT/etc/NetworkManager/conf.d" \
        "$TEST_ROOT/etc/unbound/unbound.conf.d" \
        "$TEST_ROOT/etc/unbound" \
        "$TEST_ROOT/usr/local/bin" \
        "$TEST_ROOT/var/lib/unbound" \
        "$TEST_ROOT/var/backups"
    printf 'legacy nm policy\n' > "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf"
    printf 'old unbound config\n' > "$TEST_ROOT/etc/unbound/unbound.conf"
    printf 'old trust-anchor drop-in\n' > "$TEST_ROOT/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf"
    printf 'old remote-control drop-in\n' > "$TEST_ROOT/etc/unbound/unbound.conf.d/remote-control.conf"
    printf 'nameserver 192.0.2.53\n' > "$TEST_ROOT/etc/resolv.conf"
    printf 'old reality-check\n' > "$TEST_ROOT/usr/local/bin/dns-reality-check"
    printf 'old restore-tool\n' > "$TEST_ROOT/usr/local/bin/dns-restore"
    printf 'test root key\n' > "$TEST_ROOT/var/lib/unbound/root.key"
    chmod 640 "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf"
    chmod 600 "$TEST_ROOT/etc/unbound/unbound.conf"
    chmod 640 "$TEST_ROOT/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf"
    chmod 600 "$TEST_ROOT/etc/unbound/unbound.conf.d/remote-control.conf"
    chmod 644 "$TEST_ROOT/etc/resolv.conf"
    chmod 640 "$TEST_ROOT/usr/local/bin/dns-reality-check"
    chmod 600 "$TEST_ROOT/usr/local/bin/dns-restore"

    : > "$STATE_DIR/NetworkManager"
    : > "$STATE_DIR/unbound"
    printf 'active\n' > "$STATE_DIR/NetworkManager"
    printf 'active\n' > "$STATE_DIR/unbound"
    : > "$STATE_DIR/attributes"

    cp -a "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf" "$ORIGINALS/nm-legacy"
    cp -a "$TEST_ROOT/etc/unbound/unbound.conf" "$ORIGINALS/unbound.conf"
    cp -a "$TEST_ROOT/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf" "$ORIGINALS/root-anchor"
    cp -a "$TEST_ROOT/etc/unbound/unbound.conf.d/remote-control.conf" "$ORIGINALS/remote-control"
    cp -a "$TEST_ROOT/etc/resolv.conf" "$ORIGINALS/resolv.conf"
    cp -a "$TEST_ROOT/usr/local/bin/dns-reality-check" "$ORIGINALS/dns-reality-check"
    cp -a "$TEST_ROOT/usr/local/bin/dns-restore" "$ORIGINALS/dns-restore"
}

reset_sandbox() {
    [[ -d "$TEST_ROOT" && ! -L "$TEST_ROOT" \
        && -f "$TEST_ROOT/.pbp-test-root" && ! -L "$TEST_ROOT/.pbp-test-root" ]] || {
        echo "Refusing to reset sandbox without its marker: $TEST_ROOT" >&2
        return 1
    }
    local canonical_root canonical_tmp
    canonical_root="$(cd "$TEST_ROOT" && pwd -P)" || return 1
    canonical_tmp="$(cd "$TEST_TMPDIR" && pwd -P)" || return 1
    [[ "$canonical_root" == "$canonical_tmp"/pbp-dns-hardening-test.* ]] || {
        echo "Refusing to reset unexpected sandbox path: $canonical_root" >&2
        return 1
    }
    rm -rf -- "${TEST_ROOT:?}/etc" "${TEST_ROOT:?}/usr" "${TEST_ROOT:?}/var"
    make_sandbox
}

cat > "$BIN_DIR/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command="$1"
shift
printf '%s %s\n' "$command" "$*" >> "$PBP_TEST_STATE_DIR/systemctl.log"
if [[ "$command" == restart && "${1:-}" == unbound \
    && "${PBP_TEST_FAILPOINT:-}" == signal-term ]]; then
    printf '%s\n' "$PPID" > "$PBP_TEST_STATE_DIR/apply-script.pid"
    : > "$PBP_TEST_STATE_DIR/systemctl-blocked"
    while [[ ! -e "$PBP_TEST_STATE_DIR/systemctl-release" ]]; do sleep 0.05; done
fi
if [[ "$command" == restart && "${1:-}" == unbound \
    && "${PBP_TEST_FAILPOINT:-}" == second-signal ]]; then
    restart_count=0
    [[ ! -f "$PBP_TEST_STATE_DIR/signal-restart-count" ]] \
        || restart_count="$(cat "$PBP_TEST_STATE_DIR/signal-restart-count")"
    restart_count=$((restart_count + 1))
    printf '%s\n' "$restart_count" > "$PBP_TEST_STATE_DIR/signal-restart-count"
    if [[ "$restart_count" -eq 2 ]]; then
        printf '%s\n' "$PPID" > "$PBP_TEST_STATE_DIR/apply-script.pid"
        : > "$PBP_TEST_STATE_DIR/rollback-blocked"
        while [[ ! -e "$PBP_TEST_STATE_DIR/rollback-release" ]]; do sleep 0.05; done
    fi
fi
fail_once() {
    [[ "${PBP_TEST_FAILPOINT:-}" == "$1" && ! -e "$PBP_TEST_STATE_DIR/failure-used" ]] || return 1
    : > "$PBP_TEST_STATE_DIR/failure-used"
    return 0
}
case "$command" in
    is-active)
        quiet=0
        if [[ "${1:-}" == --quiet ]]; then quiet=1; shift; fi
        state="$(cat "$PBP_TEST_STATE_DIR/$1")"
        [[ "$quiet" -eq 1 ]] || printf '%s\n' "$state"
        [[ "$state" == active ]]
        ;;
    reload)
        if [[ "$1" == NetworkManager ]] && fail_once nm-reload; then exit 1; fi
        ;;
    restart)
        if [[ "$1" == unbound ]] && fail_once unbound-restart; then exit 1; fi
        if [[ "$1" == unbound && "${PBP_TEST_FAILPOINT:-}" == unbound-rollback-restart ]]; then
            count=0
            [[ ! -f "$PBP_TEST_STATE_DIR/restart-count" ]] || count="$(cat "$PBP_TEST_STATE_DIR/restart-count")"
            count=$((count + 1))
            printf '%s\n' "$count" > "$PBP_TEST_STATE_DIR/restart-count"
            (( count <= 2 )) && exit 1
        fi
        if [[ "$1" == unbound ]]; then
            printf 'active\n' > "$PBP_TEST_STATE_DIR/unbound"
        fi
        ;;
    stop)
        printf 'inactive\n' > "$PBP_TEST_STATE_DIR/$1"
        ;;
    *)
        echo "unexpected systemctl command: $command $*" >&2
        exit 90
        ;;
esac
EOF

cat > "$BIN_DIR/unbound-checkconf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PBP_TEST_DRY_RUN:-0}" == 1 ]]; then
    printf 'dry-run-unbound-checkconf: %s\n' "$1"
    exit 0
fi
if [[ "${PBP_TEST_FAILPOINT:-}" == staged-checkconf \
    && "$1" == */pbp-unbound-stage.*/unbound.conf \
    && ! -e "$PBP_TEST_STATE_DIR/failure-used" ]]; then
    : > "$PBP_TEST_STATE_DIR/failure-used"
    exit 1
fi
if [[ "${PBP_TEST_FAILPOINT:-}" == installed-checkconf \
    && "$1" == "$PBP_TEST_ROOT/etc/unbound/unbound.conf" \
    && ! -e "$PBP_TEST_STATE_DIR/failure-used" ]]; then
    : > "$PBP_TEST_STATE_DIR/failure-used"
    exit 1
fi
exit 0
EOF

cat > "$BIN_DIR/dig" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PBP_TEST_FAILPOINT:-}" == dig-validation \
    || "${PBP_TEST_FAILPOINT:-}" == dig-always-fail \
    || "${PBP_TEST_FAILPOINT:-}" == second-signal ]]; then
    attempt=0
    [[ ! -f "$PBP_TEST_STATE_DIR/dig-attempts" ]] \
        || attempt="$(cat "$PBP_TEST_STATE_DIR/dig-attempts")"
    printf '%s\n' "$((attempt + 1))" > "$PBP_TEST_STATE_DIR/dig-attempts"
    exit 1
fi
if [[ "${PBP_TEST_FAILPOINT:-}" == dig-retry-two ]]; then
    attempt=0
    [[ ! -f "$PBP_TEST_STATE_DIR/dig-attempts" ]] \
        || attempt="$(cat "$PBP_TEST_STATE_DIR/dig-attempts")"
    attempt=$((attempt + 1))
    printf '%s\n' "$attempt" > "$PBP_TEST_STATE_DIR/dig-attempts"
    if [[ "$attempt" -le 2 ]]; then
        exit 1
    fi
fi
if [[ "${PBP_TEST_FAILPOINT:-}" == dig-servfail ]]; then
    exit 0
fi
if [[ "${PBP_TEST_FAILPOINT:-}" == concurrent-change ]]; then
    if [[ ! -e "$PBP_TEST_STATE_DIR/failure-used" ]]; then
        : > "$PBP_TEST_STATE_DIR/failure-used"
        printf 'unrelated concurrent edit\n' > \
            "$PBP_TEST_ROOT/etc/NetworkManager/conf.d/90-dns-hardening.conf"
    fi
    exit 1
fi
printf '%s\n' "$*" >> "$PBP_TEST_STATE_DIR/dig.log"
printf '%s\n' '192.0.2.1'
exit 0
EOF

cat > "$BIN_DIR/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PBP_TEST_FAILPOINT:-}" == move-destination \
    && "${1:-}" == -Tn \
    && "${4:-}" == "$PBP_TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf.disabled" \
    && ! -e "$PBP_TEST_STATE_DIR/move-race-created" ]]; then
    printf 'concurrent destination\n' > "$4"
    : > "$PBP_TEST_STATE_DIR/move-race-created"
fi
exec /bin/mv "$@"
EOF

cat > "$BIN_DIR/lsattr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
query_path=''
for argument in "$@"; do query_path="$argument"; done
flags='----------------------e-------'
if [[ -f "$PBP_TEST_STATE_DIR/attributes.path" \
    && "$query_path" == "$(cat "$PBP_TEST_STATE_DIR/attributes.path")" \
    && "$(cat "$PBP_TEST_STATE_DIR/attributes")" == i ]]; then
    flags='i----------------------e-------'
fi
printf '%s  %s\n' "$flags" "$query_path"
EOF

cat > "$BIN_DIR/chattr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == +i && "${PBP_TEST_FAILPOINT:-}" == chattr-immutable \
    && ! -e "$PBP_TEST_STATE_DIR/failure-used" ]]; then
    : > "$PBP_TEST_STATE_DIR/failure-used"
    exit 1
fi
path=''
for argument in "$@"; do path="$argument"; done
case "$1" in
    +i)
        printf 'i\n' > "$PBP_TEST_STATE_DIR/attributes"
        printf '%s\n' "$path" > "$PBP_TEST_STATE_DIR/attributes.path"
        ;;
    -i)
        : > "$PBP_TEST_STATE_DIR/attributes"
        : > "$PBP_TEST_STATE_DIR/attributes.path"
        ;;
    *) echo "unexpected chattr option: $1" >&2; exit 90 ;;
esac
EOF
chmod 755 "$BIN_DIR/"*

assert_restored() {
    local failed=0
    local expected_nm="${1:-active}"
    local expected_unbound="${2:-active}"
    local path original
    local -a pairs=(
        "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf|$ORIGINALS/nm-legacy"
        "$TEST_ROOT/etc/unbound/unbound.conf|$ORIGINALS/unbound.conf"
        "$TEST_ROOT/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf|$ORIGINALS/root-anchor"
        "$TEST_ROOT/etc/unbound/unbound.conf.d/remote-control.conf|$ORIGINALS/remote-control"
        "$TEST_ROOT/etc/resolv.conf|$ORIGINALS/resolv.conf"
        "$TEST_ROOT/usr/local/bin/dns-reality-check|$ORIGINALS/dns-reality-check"
        "$TEST_ROOT/usr/local/bin/dns-restore|$ORIGINALS/dns-restore"
    )
    for pair in "${pairs[@]}"; do
        path="${pair%%|*}"
        original="${pair#*|}"
        if [[ ! -f "$path" ]] || ! cmp -s "$original" "$path" \
            || [[ "$(stat -c '%a:%u:%g:%s:%Y' "$original")" != "$(stat -c '%a:%u:%g:%s:%Y' "$path")" ]]; then
            echo "not restored: $path" >&2
            failed=1
        fi
    done
    for path in \
        "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-hardening.conf" \
        "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf.disabled" \
        "$TEST_ROOT/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf.disabled.pbp" \
        "$TEST_ROOT/etc/unbound/unbound.conf.d/remote-control.conf.disabled.pbp"; do
        if [[ -e "$path" || -L "$path" ]]; then
            echo "unexpected path after rollback: $path" >&2
            failed=1
        fi
    done
    [[ "$(cat "$STATE_DIR/NetworkManager")" == "$expected_nm" ]] || failed=1
    [[ "$(cat "$STATE_DIR/unbound")" == "$expected_unbound" ]] || failed=1
    [[ ! -s "$STATE_DIR/attributes" ]] || failed=1
    return "$failed"
}

run_failure_case() {
    local failpoint="$1"
    local deploy_tmpdir="${2:-$TEST_TMPDIR}"
    local output="${TEST_TMPDIR}/output-${failpoint}.log"
    reset_sandbox
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count" "$STATE_DIR/dig-attempts"
    PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT="$failpoint" \
    TMPDIR="$deploy_tmpdir" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1 && {
            echo "expected injected deployment failure: $failpoint" >&2
            return 1
        }
    if [[ "$failpoint" == concurrent-change ]]; then
        grep -q 'Rollback conflict; refusing to overwrite unexpected changes' "$output" || {
            cat "$output" >&2
            return 1
        }
        grep -q 'CRITICAL: rollback was incomplete' "$output" || {
            cat "$output" >&2
            return 1
        }
        grep -q 'unrelated concurrent edit' \
            "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-hardening.conf"
    else
        grep -q 'Rollback verified for every changed path and touched service' "$output" || {
            cat "$output" >&2
            return 1
        }
        assert_restored || {
            cat "$output" >&2
            return 1
        }
        if [[ "$failpoint" == dig-servfail ]]; then
            grep -q 'Local DNS resolution via 127.0.0.1 failed after 5 attempts' "$output"
        fi
    fi
    echo "PASS failure injection: $failpoint"
}

run_rollback_failure_case() {
    local output="${TEST_TMPDIR}/output-rollback-service-failure.log"
    reset_sandbox
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count"
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=unbound-rollback-restart \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        echo "expected rollback service failure injection" >&2
        return 1
    fi
    grep -q 'CRITICAL: failed to restore Unbound service state' "$output"
    grep -q 'CRITICAL: rollback was incomplete' "$output"
    grep -q 'Transaction backup retained at:' "$output"
    if grep -q 'Rollback verified for every changed path and touched service' "$output"; then
        echo "rollback incorrectly reported complete after a service restore failure" >&2
        return 1
    fi
    assert_restored
    echo "PASS rollback failure is reported as incomplete"
}

run_inactive_service_case() {
    local output="${TEST_TMPDIR}/output-inactive-service.log"
    reset_sandbox
    printf 'inactive\n' > "$STATE_DIR/unbound"
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count"
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=dig-validation \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        echo "expected injected validation failure with initially inactive Unbound" >&2
        return 1
    fi
    grep -q 'Rollback verified for every changed path and touched service' "$output"
    assert_restored active inactive
    printf 'active\n' > "$STATE_DIR/unbound"
    echo "PASS rollback restores an initially inactive service"
}

run_success_case() {
    local deploy_tmpdir="${1:-$TEST_TMPDIR}"
    local failpoint="${2:-none}"
    local output="${TEST_TMPDIR}/output-success.log"
    local backup_dir
    reset_sandbox
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count" "$STATE_DIR/dig-attempts"
    rm -f "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-hardening.conf"
    PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT="$failpoint" \
        TMPDIR="$deploy_tmpdir" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1 || {
            cat "$output" >&2
            return 1
        }
    cmp -s "${PBP_ROOT}/configs/unbound.conf" "$TEST_ROOT/etc/unbound/unbound.conf"
    grep -q '^dns=none$' "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-hardening.conf"
    [[ -f "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf.disabled" ]]
    [[ -f "$TEST_ROOT/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf.disabled.pbp" ]]
    [[ -f "$TEST_ROOT/etc/unbound/unbound.conf.d/remote-control.conf.disabled.pbp" ]]
    grep -q 'nameserver 127.0.0.1' "$TEST_ROOT/etc/resolv.conf"
    [[ "$(cat "$STATE_DIR/attributes")" == i ]]
    [[ "$(stat -c '%a' "$TEST_ROOT/usr/local/bin/dns-reality-check")" == 755 ]]
    [[ "$(stat -c '%a' "$TEST_ROOT/usr/local/bin/dns-restore")" == 755 ]]
    [[ "$(cat "$STATE_DIR/NetworkManager")" == active ]]
    [[ "$(cat "$STATE_DIR/unbound")" == active ]]
    backup_dir="$(sed -n 's/^Pre-change transaction backup: //p' "$output")"
    [[ -f "$backup_dir/manifest.tsv" && -f "$backup_dir/resources/1" ]]
    if [[ "$failpoint" == dig-retry-two ]]; then
        [[ "$(cat "$STATE_DIR/dig-attempts")" == 3 ]]
    fi
    echo "PASS sandbox deployment and timestamped pre-change backup"
}

run_repeated_success_case() {
    local output="${TEST_TMPDIR}/output-repeated-success.log"
    local backup_dir
    run_success_case
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=none \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        :
    else
        cat "$output" >&2
        return 1
    fi
    backup_dir="$(sed -n 's/^Pre-change transaction backup: //p' "$output")"
    [[ -f "$backup_dir/manifest.tsv" ]]
    cmp -s "${PBP_ROOT}/configs/unbound.conf" "$TEST_ROOT/etc/unbound/unbound.conf"
    echo "PASS repeated sandbox deployment with the legacy policy already archived"
}

assert_no_deployment_tempdirs() {
    local path
    for path in "$TEST_TMPDIR"/pbp-dns-hardening.* "$TEST_TMPDIR"/pbp-unbound-stage.*; do
        if [[ -e "$path" || -L "$path" ]]; then
            echo "unexpected deployment temporary directory remains: $path" >&2
            return 1
        fi
    done
}

run_signal_rollback_case() {
    local signal_name="$1" expected_status="$2"
    local output="${TEST_TMPDIR}/output-signal-${signal_name}.log"
    local script_pid status attempt controller_pid
    reset_sandbox
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count" \
        "$STATE_DIR/systemctl-blocked" "$STATE_DIR/systemctl-release" \
        "$STATE_DIR/apply-script.pid"
    (
        for ((attempt=0; attempt<200; attempt++)); do
            [[ -e "$STATE_DIR/systemctl-blocked" ]] && break
            sleep 0.05
        done
        [[ -e "$STATE_DIR/systemctl-blocked" ]] || exit 91
        script_pid="$(cat "$STATE_DIR/apply-script.pid")"
        kill "-$signal_name" "$script_pid"
        : > "$STATE_DIR/systemctl-release"
    ) &
    controller_pid=$!
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=signal-term \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        status=0
    else
        status=$?
    fi
    if ! wait "$controller_pid"; then
        cat "$output" >&2
        echo "signal controller failed before delivering SIG${signal_name}" >&2
        return 1
    fi
    if [[ ! -e "$STATE_DIR/systemctl-blocked" ]]; then
        echo "systemctl stub did not reach its blocking point" >&2
        return 1
    fi
    [[ "$status" -eq "$expected_status" || "$status" -eq 2 ]] || {
        cat "$output" >&2
        echo "unexpected SIG${signal_name} exit status: $status" >&2
        return 1
    }
    assert_restored || {
        cat "$output" >&2
        return 1
    }
    echo "PASS SIG${signal_name} triggered rollback and restored files and service state (status $status)"
}

run_second_signal_case() {
    local output="${TEST_TMPDIR}/output-second-signal.log"
    local status attempt controller_pid
    reset_sandbox
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count" \
        "$STATE_DIR/signal-restart-count" "$STATE_DIR/rollback-blocked" \
        "$STATE_DIR/rollback-release" "$STATE_DIR/apply-script.pid"
    (
        for ((attempt=0; attempt<300; attempt++)); do
            [[ -e "$STATE_DIR/rollback-blocked" ]] && break
            sleep 0.05
        done
        [[ -e "$STATE_DIR/rollback-blocked" ]] || exit 91
        kill -INT "$(cat "$STATE_DIR/apply-script.pid")"
        : > "$STATE_DIR/rollback-release"
    ) &
    controller_pid=$!
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=second-signal \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        status=0
    else
        status=$?
    fi
    if ! wait "$controller_pid"; then
        cat "$output" >&2
        echo "second-signal controller failed" >&2
        return 1
    fi
    [[ "$status" -eq 1 || "$status" -eq 2 ]] || {
        cat "$output" >&2
        echo "unexpected exit status after second signal during rollback: $status" >&2
        return 1
    }
    grep -q 'Rollback verified for every changed path and touched service' "$output"
    assert_restored
    echo "PASS second SIGINT during rollback did not interrupt restoration"
}

run_destination_race_case() {
    local output="${TEST_TMPDIR}/output-move-destination-race.log"
    reset_sandbox
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/move-race-created"
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=move-destination \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        echo "expected destination-race failure" >&2
        return 1
    fi
    grep -q 'Move did not complete without overwriting an existing destination' "$output" || {
        cat "$output" >&2
        return 1
    }
    [[ "$(cat "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf")" == "legacy nm policy" ]]
    [[ "$(cat "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-none.conf.disabled")" == "concurrent destination" ]]
    echo "PASS tx_move preserved a destination created concurrently"
}

run_missing_managed_directories_case() {
    local output="${TEST_TMPDIR}/output-missing-managed-dirs.log"
    reset_sandbox
    cp -a "$TEST_ROOT/etc/unbound/unbound.conf" "$ORIGINALS/missing-case-unbound.conf"
    cp -a "$TEST_ROOT/etc/resolv.conf" "$ORIGINALS/missing-case-resolv.conf"
    mv "$TEST_ROOT/etc/NetworkManager/conf.d" "$ORIGINALS/saved-nm-conf.d"
    mv "$TEST_ROOT/etc/unbound/unbound.conf.d" "$ORIGINALS/saved-unbound-dropins"
    mv "$TEST_ROOT/usr/local/bin" "$ORIGINALS/saved-local-bin"
    rm -f "$STATE_DIR/failure-used" "$STATE_DIR/restart-count"
    if PBP_TEST_ROOT="$TEST_ROOT" \
        PBP_TEST_STATE_DIR="$STATE_DIR" \
        PBP_TEST_FAILPOINT=dig-validation \
        TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
        bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" > "$output" 2>&1; then
        echo "expected injected validation failure with missing managed directories" >&2
        return 1
    fi
    grep -q 'Rollback verified for every changed path and touched service' "$output" || {
        cat "$output" >&2
        return 1
    }
    [[ ! -e "$TEST_ROOT/etc/NetworkManager/conf.d" \
        && ! -e "$TEST_ROOT/etc/unbound/unbound.conf.d" \
        && ! -e "$TEST_ROOT/usr/local/bin" ]]
    cmp -s "$ORIGINALS/missing-case-unbound.conf" "$TEST_ROOT/etc/unbound/unbound.conf"
    cmp -s "$ORIGINALS/missing-case-resolv.conf" "$TEST_ROOT/etc/resolv.conf"
    [[ "$(cat "$STATE_DIR/NetworkManager")" == active \
        && "$(cat "$STATE_DIR/unbound")" == active ]]
    assert_no_deployment_tempdirs
    echo "PASS reverse rollback removes files before newly created managed directories"
}

make_sandbox

echo "=== Strict dry-run command interception ==="
GUARD_BIN="${TEST_TMPDIR}/guard-bin"
mkdir -p "$GUARD_BIN"
chmod 700 "$GUARD_BIN"
cat > "$GUARD_BIN/guard" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${0##*/}" >> "$PBP_TEST_MUTATION_LOG"
exit 97
EOF
chmod 755 "$GUARD_BIN/guard"
for command in mktemp unbound-anchor systemctl chattr cp mv chmod chown mkdir rmdir rm \
    ln sed truncate dig install touch tee dd chgrp mknod mkfifo; do
    cp "$GUARD_BIN/guard" "$GUARD_BIN/$command"
done
cat > "$GUARD_BIN/unbound-checkconf" <<'EOF'
#!/usr/bin/env bash
printf 'dry-run-unbound-checkconf: %s\n' "$1"
EOF
chmod 755 "$GUARD_BIN/unbound-checkconf"
cat > "$GUARD_BIN/lsattr" <<'EOF'
#!/usr/bin/env bash
last_argument=''
for argument in "$@"; do last_argument="$argument"; done
printf '%s  %s\n' '----------------------e-------' "$last_argument"
EOF
chmod 755 "$GUARD_BIN/lsattr"
MUTATION_LOG="${TEST_TMPDIR}/mutation.log"
: > "$MUTATION_LOG"
chmod 600 "$MUTATION_LOG"
# PATH guards cannot intercept shell builtins or redirections; the full filesystem
# snapshot below is the backstop for those mutation paths.
before_listing="$(find "$TEST_ROOT" -printf '%p %y %m %u:%g %s %T@\n' | sort)"
dry_run_status=0
if env \
    PBP_TEST_MUTATION_LOG="$MUTATION_LOG" \
    PBP_TEST_DRY_RUN=1 \
    TMPDIR="$TEST_TMPDIR" PATH="$GUARD_BIN:$PATH" \
    bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" --dry-run > "${TEST_TMPDIR}/dry-run.log" 2>&1; then
    dry_run_status=0
else
    dry_run_status=$?
fi
if [[ -s "$MUTATION_LOG" ]]; then
    echo "FAIL dry-run invoked mutating command(s): $(cat "$MUTATION_LOG")" >&2
    exit 1
fi
if [[ "$dry_run_status" -ne 0 ]]; then
    cat "${TEST_TMPDIR}/dry-run.log" >&2
    echo "FAIL dry-run exited with status $dry_run_status" >&2
    exit 1
fi
after_listing="$(find "$TEST_ROOT" -printf '%p %y %m %u:%g %s %T@\n' | sort)"
[[ "$before_listing" == "$after_listing" ]]
grep -q "dry-run-unbound-checkconf: ${PBP_ROOT}/configs/unbound.conf" "${TEST_TMPDIR}/dry-run.log"
echo "PASS dry-run performed no intercepted writes or sandbox changes"

echo
echo "=== Production dry-run ignores hostile TMPDIR ==="
HOSTILE_TMPDIR="${TEST_TMPDIR}/hostile-tmp"
mkdir -m 700 "$HOSTILE_TMPDIR"
printf 'preserve\n' > "$HOSTILE_TMPDIR/sentinel"
hostile_before="$(find "$HOSTILE_TMPDIR" -printf '%p %y %m %u:%g %s %T@\n' | sort)"
TMPDIR="$HOSTILE_TMPDIR" bash "$APPLY_SCRIPT" --dry-run \
    > "${TEST_TMPDIR}/hostile-tmp-dry-run.log" 2>&1 || {
    cat "${TEST_TMPDIR}/hostile-tmp-dry-run.log" >&2
    exit 1
}
hostile_after="$(find "$HOSTILE_TMPDIR" -printf '%p %y %m %u:%g %s %T@\n' | sort)"
[[ "$hostile_before" == "$hostile_after" ]]
source "${PBP_ROOT}/scripts/lib/dns_hardening_paths.sh"
if [[ -d /run && "$(stat -c '%u' /run)" == 0 && -w /run ]]; then
    expected_trusted_root=/run
else
    expected_trusted_root=/tmp
fi
selected_tmp_root="$(TMPDIR="$HOSTILE_TMPDIR" dns_hardening_select_tmp_root 0)"
selected_test_root="$(TMPDIR="$HOSTILE_TMPDIR" dns_hardening_select_tmp_root 1)"
if [[ "$selected_tmp_root" != "$expected_trusted_root" ]]; then
    echo "FAIL production temporary root trusted hostile TMPDIR: $selected_tmp_root" >&2
    exit 1
fi
if [[ "$selected_test_root" != "$HOSTILE_TMPDIR" ]]; then
    echo "FAIL test mode did not honor TMPDIR: $selected_test_root" >&2
    exit 1
fi
echo "PASS production TMP_ROOT selection uses trusted /run or /tmp, independent of hostile TMPDIR"

echo
echo "=== Test-root command path restriction ==="
system_path_command_log="${TEST_TMPDIR}/system-path-command.log"
# Exported functions intercept accidental command execution by the child script.
# shellcheck disable=SC2317
systemctl() { printf 'systemctl\n' >> "$PBP_TEST_SYSTEM_COMMAND_LOG"; return 90; }
# shellcheck disable=SC2317
chattr() { printf 'chattr\n' >> "$PBP_TEST_SYSTEM_COMMAND_LOG"; return 90; }
# shellcheck disable=SC2317
dig() { printf 'dig\n' >> "$PBP_TEST_SYSTEM_COMMAND_LOG"; return 90; }
# shellcheck disable=SC2317
lsattr() { printf 'lsattr\n' >> "$PBP_TEST_SYSTEM_COMMAND_LOG"; return 90; }
# shellcheck disable=SC2317
unbound-checkconf() { printf 'unbound-checkconf\n' >> "$PBP_TEST_SYSTEM_COMMAND_LOG"; return 90; }
export -f systemctl chattr dig lsattr unbound-checkconf
if env -i HOME="$HOME" TMPDIR="$TEST_TMPDIR" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    /bin/bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" \
    > "${TEST_TMPDIR}/system-path-refusal.log" 2>&1; then
    echo "FAIL --test-root accepted system command paths" >&2
    exit 1
fi
grep -q 'resolve inside the test harness' "${TEST_TMPDIR}/system-path-refusal.log"
[[ ! -s "$system_path_command_log" ]]
if PBP_TEST_SYSTEM_COMMAND_LOG="$system_path_command_log" \
    TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
    /bin/bash "$APPLY_SCRIPT" --test-root "$TEST_ROOT" \
    > "${TEST_TMPDIR}/function-override-refusal.log" 2>&1; then
    echo "FAIL --test-root accepted exported command function overrides" >&2
    exit 1
fi
grep -q 'refuses shell function overrides' "${TEST_TMPDIR}/function-override-refusal.log"
[[ ! -s "$system_path_command_log" ]]
unset -f systemctl chattr dig lsattr unbound-checkconf
echo "PASS --test-root refused system paths and exported function overrides without invoking commands"

unsafe_tmpdir_parent="${TEST_TMPDIR}/unsafe-tmpdir-parent"
unsafe_tmpdir="${unsafe_tmpdir_parent}/private"
mkdir -m 777 "$unsafe_tmpdir_parent"
mkdir -m 700 "$unsafe_tmpdir"
unsafe_test_root="$(mktemp -d "${unsafe_tmpdir}/pbp-dns-hardening-test.XXXXXX")"
printf 'parrot-booty-protection safety test\n' > "$unsafe_test_root/.pbp-test-root"
chmod 600 "$unsafe_test_root/.pbp-test-root"
cp -a "$BIN_DIR" "$unsafe_tmpdir/bin"
if PBP_TEST_DRY_RUN=1 TMPDIR="$unsafe_tmpdir" PATH="$unsafe_tmpdir/bin:$PATH" \
    /bin/bash "$APPLY_SCRIPT" --test-root "$unsafe_test_root" \
    > "${TEST_TMPDIR}/untrusted-tmpdir-refusal.log" 2>&1; then
    echo "FAIL --test-root accepted a group/other-writable TMPDIR" >&2
    exit 1
fi
grep -q 'private current-user-owned TMPDIR under safe ancestors' \
    "${TEST_TMPDIR}/untrusted-tmpdir-refusal.log"
[[ ! -s "$system_path_command_log" ]]
echo "PASS --test-root refused a writable TMPDIR before invoking commands"

echo
echo "=== Transaction rollback failure injection ==="
for failpoint in nm-reload installed-checkconf unbound-restart chattr-immutable dig-validation dig-servfail; do
    run_failure_case "$failpoint"
done
run_rollback_failure_case
run_inactive_service_case
run_success_case "$TEST_TMPDIR" dig-retry-two
echo "PASS DNS validation retried twice before succeeding"
run_failure_case dig-always-fail
[[ "$(cat "$STATE_DIR/dig-attempts")" == 5 ]]
echo "PASS DNS validation gave up after five failed attempts"

echo
echo "=== Signal-triggered transactional rollback ==="
run_signal_rollback_case TERM 143
assert_no_deployment_tempdirs
run_signal_rollback_case HUP 129
assert_no_deployment_tempdirs
run_signal_rollback_case INT 130
assert_no_deployment_tempdirs
run_second_signal_case
assert_no_deployment_tempdirs

echo
echo "=== Canonical temporary-root cleanup ==="
TMPDIR_LINK="${TEST_TMPDIR}/tmp-link"
ln -s "$TEST_TMPDIR" "$TMPDIR_LINK"
run_failure_case staged-checkconf "${TMPDIR_LINK}/"
assert_no_deployment_tempdirs
echo "PASS failed deployment removed snapshot and stage dirs with symlinked trailing-slash TMPDIR"
run_success_case "${TMPDIR_LINK}/"
assert_no_deployment_tempdirs
echo "PASS successful deployment removed snapshot and stage dirs with symlinked trailing-slash TMPDIR"

echo
echo "=== Concurrent-change protection ==="
run_failure_case concurrent-change
rm -f "$TEST_ROOT/etc/NetworkManager/conf.d/90-dns-hardening.conf"
run_destination_race_case

echo
echo "=== Test-root symlink escape protection ==="
SYMLINK_ROOT="$(mktemp -d "${TEST_TMPDIR}/pbp-dns-hardening-test.XXXXXX")"
printf 'parrot-booty-protection safety test\n' > "$SYMLINK_ROOT/.pbp-test-root"
chmod 600 "$SYMLINK_ROOT/.pbp-test-root"
OUTSIDE_DIR="${TEST_TMPDIR}/outside"
mkdir -p "$OUTSIDE_DIR"
printf 'preserve me\n' > "$OUTSIDE_DIR/sentinel"
mkdir -p "$SYMLINK_ROOT/etc"
ln -s "$OUTSIDE_DIR" "$SYMLINK_ROOT/etc/NetworkManager"
sentinel_before="$(sha256sum "$OUTSIDE_DIR/sentinel")"
if PBP_TEST_ROOT="$SYMLINK_ROOT" PBP_TEST_STATE_DIR="$STATE_DIR" \
    TMPDIR="$TEST_TMPDIR" PATH="$BIN_DIR:$PATH" \
    bash "$APPLY_SCRIPT" --test-root "$SYMLINK_ROOT" --dry-run \
    > "${TEST_TMPDIR}/symlink-root.log" 2>&1; then
    echo "FAIL test-root symlink was accepted" >&2
    exit 1
fi
grep -q 'Test-root path contains a symlink' "${TEST_TMPDIR}/symlink-root.log"
[[ "$sentinel_before" == "$(sha256sum "$OUTSIDE_DIR/sentinel")" ]]
echo "PASS test-root symlink path was refused without touching the target"

echo
echo "=== Reverse rollback ordering with absent managed directories ==="
run_missing_managed_directories_case

echo
echo "=== Repeated deployment success path ==="
run_repeated_success_case
