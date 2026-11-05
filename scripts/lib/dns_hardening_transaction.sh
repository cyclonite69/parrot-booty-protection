#!/usr/bin/env bash

declare -ag TX_PATHS=()
declare -ag TX_RESTORE_ORDER=()
declare -ag TX_TEMP_FILES=()
declare -Ag TX_INDEX=()
declare -Ag TX_BASE_EXISTS=()
declare -Ag TX_BASE_FP=()
declare -Ag TX_BASE_FLAGS=()
declare -Ag TX_EXPECTED_FP=()
declare -Ag TX_EXPECTED_INODE=()

tx_flags() {
    local path="$1"
    local output=""
    if command -v lsattr >/dev/null 2>&1 && [[ -e "$path" || -L "$path" ]]; then
        output="$(lsattr -d -- "$path" 2>/dev/null || true)"
        printf '%s\n' "$output" | awk 'NF { print $1; exit }'
    fi
}

tx_fingerprint() {
    local path="$1"
    local metadata content flags
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        printf '%s\n' ABSENT
        return 0
    fi
    metadata="$(stat -c '%F|%u|%g|%a|%s|%Y' -- "$path")" || return 1
    if [[ -L "$path" ]]; then
        content="link:$(readlink -- "$path")"
    elif [[ -f "$path" ]]; then
        content="$(sha256sum -- "$path" | awk '{ print $1 }')" || return 1
    else
        content=non-regular
    fi
    flags="$(tx_flags "$path")"
    printf '%s|%s|%s\n' "$metadata" "$content" "$flags"
}

tx_inode() {
    stat -c '%i' -- "$1"
}

tx_assert_expected() {
    local path="$1"
    local actual
    actual="$(tx_fingerprint "$path")" || return 1
    if [[ "$actual" != "${TX_EXPECTED_FP[$path]}" ]]; then
        printf 'Transaction conflict before mutation; refusing to change unexpected path: %s\n' "$path" >&2
        return 1
    fi
}

tx_track() {
    local path="$1"
    local index before_fp after_fp
    [[ -n "${TX_INDEX[$path]+set}" ]] && return 0
    index="${#TX_PATHS[@]}"
    TX_INDEX["$path"]="$index"
    TX_PATHS+=("$path")
    before_fp="$(tx_fingerprint "$path")" || return 1
    if [[ -e "$path" || -L "$path" ]]; then
        TX_BASE_EXISTS["$path"]=1
        TX_BASE_FLAGS["$path"]="$(tx_flags "$path")"
        cp -a -- "$path" "${TX_DIR}/snapshot.${index}" || return 1
    else
        TX_BASE_EXISTS["$path"]=0
        TX_BASE_FLAGS["$path"]=""
    fi
    after_fp="$(tx_fingerprint "$path")" || return 1
    [[ "$before_fp" == "$after_fp" ]] || {
        printf 'Path changed while it was being snapshotted: %s\n' "$path" >&2
        return 1
    }
    TX_BASE_FP["$path"]="$before_fp"
    TX_EXPECTED_FP["$path"]="${TX_BASE_FP[$path]}"
    if [[ -d "$path" && ! -L "$path" ]]; then
        TX_EXPECTED_INODE["$path"]="$(tx_inode "$path")" || return 1
    fi
}

tx_mark() {
    local path="$1"
    local index="${TX_INDEX[$path]:-}"
    local remaining=()
    local item
    [[ -n "$index" ]] || return 1
    TX_EXPECTED_FP["$path"]="$(tx_fingerprint "$path")" || return 1
    if [[ -d "$path" && ! -L "$path" ]]; then
        TX_EXPECTED_INODE["$path"]="$(tx_inode "$path")" || return 1
    fi
    for item in "${TX_RESTORE_ORDER[@]}"; do
        [[ "$item" == "$path" ]] || remaining+=("$item")
    done
    TX_RESTORE_ORDER=("${remaining[@]}" "$path")
}

tx_track_move_destination() {
    local source="$1" destination="$2"
    [[ ! -e "$destination" && ! -L "$destination" ]] || {
        printf 'Refusing to overwrite pre-existing path: %s\n' "$destination" >&2
        return 1
    }
    tx_track "$source" && tx_track "$destination" && tx_assert_expected "$source"
}

tx_ensure_dir() {
    local path="$1"
    local parent="${path%/*}"
    if [[ -d "$path" ]]; then
        return 0
    fi
    [[ -d "$parent" ]] || {
        printf 'Required parent directory is missing: %s\n' "$parent" >&2
        return 1
    }
    tx_track "$path" && tx_assert_expected "$path" || return 1
    mkdir -- "$path" || return 1
    tx_mark "$path"
}

tx_move() {
    local source="$1" destination="$2"
    local source_fp
    tx_track_move_destination "$source" "$destination" || return 1
    tx_assert_expected "$source" || return 1
    source_fp="$(tx_fingerprint "$source")" || return 1
    mv -Tn -- "$source" "$destination" || return 1
    if [[ -e "$source" || -L "$source" ]] \
        || [[ "$(tx_fingerprint "$destination")" != "$source_fp" ]]; then
        printf 'Move did not complete without overwriting an existing destination: %s\n' "$destination" >&2
        return 1
    fi
    tx_mark "$source" && tx_mark "$destination"
}

tx_atomic_write() {
    local destination="$1" mode="$2"
    local temporary
    tx_assert_expected "$destination" || return 1
    temporary="$(mktemp "${destination}.pbp.XXXXXX")" || return 1
    TX_TEMP_FILES+=("$temporary")
    cat > "$temporary" || return 1
    chmod "$mode" "$temporary" || return 1
    tx_assert_expected "$destination" || return 1
    mv -- "$temporary" "$destination" || return 1
    tx_mark "$destination"
}

tx_atomic_copy() {
    local source="$1" destination="$2" mode="$3"
    local temporary
    tx_assert_expected "$destination" || return 1
    temporary="$(mktemp "${destination}.pbp.XXXXXX")" || return 1
    TX_TEMP_FILES+=("$temporary")
    cp -- "$source" "$temporary" || return 1
    chmod "$mode" "$temporary" || return 1
    tx_assert_expected "$destination" || return 1
    mv -- "$temporary" "$destination" || return 1
    tx_mark "$destination"
}

tx_restore_path() {
    local path="$1"
    local index="${TX_INDEX[$path]}"
    local current_fp="${TX_EXPECTED_FP[$path]}"
    local actual_fp
    local flags="${TX_BASE_FLAGS[$path]}"

    if [[ -d "$path" && ! -L "$path" && "${TX_BASE_EXISTS[$path]}" -eq 0 ]]; then
        if [[ "$(tx_inode "$path")" != "${TX_EXPECTED_INODE[$path]}" ]]; then
            printf 'Rollback conflict; refusing to remove replaced directory: %s\n' "$path" >&2
            return 1
        fi
        if rmdir -- "$path"; then
            return 0
        fi
        printf 'Rollback could not remove newly created non-empty directory: %s\n' "$path" >&2
        return 1
    fi

    actual_fp="$(tx_fingerprint "$path")" || {
        printf 'Rollback could not inspect changed path: %s\n' "$path" >&2
        return 1
    }
    if [[ "$actual_fp" != "$current_fp" ]]; then
        printf 'Rollback conflict; refusing to overwrite unexpected changes at: %s\n' "$path" >&2
        return 1
    fi

    if [[ -e "$path" || -L "$path" ]]; then
        if [[ "$(tx_flags "$path")" == *i* ]] && ! chattr -i -- "$path"; then
            printf 'Rollback could not clear immutable attribute: %s\n' "$path" >&2
            return 1
        fi
        rm -f -- "$path" || {
            printf 'Rollback could not remove changed path: %s\n' "$path" >&2
            return 1
        }
    fi

    if [[ "${TX_BASE_EXISTS[$path]}" -eq 1 ]]; then
        cp -a -- "${TX_DIR}/snapshot.${index}" "$path" || {
            printf 'Rollback could not restore original file: %s\n' "$path" >&2
            return 1
        }
        if [[ "$flags" == *i* ]] && ! chattr +i -- "$path"; then
            printf 'Rollback could not restore immutable attribute: %s\n' "$path" >&2
            return 1
        fi
    fi

    actual_fp="$(tx_fingerprint "$path")" || return 1
    if [[ "$actual_fp" != "${TX_BASE_FP[$path]}" ]]; then
        printf 'Rollback verification failed for: %s\n' "$path" >&2
        return 1
    fi
}

tx_rollback_files() {
    local failed=0
    local index
    for ((index=${#TX_RESTORE_ORDER[@]}-1; index>=0; index--)); do
        tx_restore_path "${TX_RESTORE_ORDER[$index]}" || failed=1
    done
    return "$failed"
}

tx_cleanup_temps() {
    local path
    for path in "${TX_TEMP_FILES[@]}"; do
        [[ -n "$path" ]] && rm -f -- "$path"
    done
}
