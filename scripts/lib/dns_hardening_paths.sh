#!/usr/bin/env bash

dns_hardening_select_tmp_root() {
    local test_mode="${1:-0}"
    if [[ "$test_mode" -eq 1 ]]; then
        cd "${TMPDIR:-/tmp}" && pwd -P
    elif [[ -d /run && "$(stat -c '%u' /run 2>/dev/null)" == 0 && -w /run ]]; then
        cd /run && pwd -P
    else
        cd /tmp && pwd -P
    fi
}
