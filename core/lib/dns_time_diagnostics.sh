#!/usr/bin/env bash
# Shared DNS/NTS diagnostic helpers (pure parsers — fixture-friendly).
# Sourced by modules/time/scan.sh, modules/dns/scan.sh, bughunt, and tests.
# shellcheck shell=bash

# Parse lsattr flag field for the immutable bit.
# Args: lsattr output line(s). Returns 0 if immutable flag present.
resolv_conf_immutable_from_lsattr() {
    local lsattr_out="${1:-}"
    local flags
    flags="$(printf '%s\n' "$lsattr_out" | awk 'NF { print $1; exit }')"
    [[ -n "$flags" && "$flags" == *i* ]]
}

# Classify chronyc authdata text into an NTS diagnostic state.
# Prints one of: PASS WARNING FAIL UNVERIFIED UNAVAILABLE ERROR
#
# States:
#   PASS       — at least one source with Mode NTS and nonzero KeyID
#   WARNING    — authdata readable, NTS mode present but KeyID/Type/KLen look unestablished
#   FAIL       — authdata readable with source rows but no NTS authentication
#   UNVERIFIED — chronyc refused (501 Not authorised / Not authorized)
#   UNAVAILABLE — empty output / chronyc missing signalled by caller
#   ERROR      — unexpected/malformed output
assess_nts_authdata() {
    local text="${1-}"
    local line mode keyid type klen
    local saw_header=0
    local nts_ok=0
    local nts_weak=0
    local non_nts=0
    local data_rows=0

    if [[ -z "${text//[[:space:]]/}" ]]; then
        printf '%s\n' "UNAVAILABLE"
        return 0
    fi

    if printf '%s\n' "$text" | grep -Eiq '501[[:space:]]+Not[[:space:]]+authori[sz]ed'; then
        printf '%s\n' "UNVERIFIED"
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line//[[:space:]]/}" ]] && continue
        if [[ "$line" == Name/IP* || "$line" == ===* ]]; then
            saw_header=1
            continue
        fi
        # Skip decorative separators
        [[ "$line" =~ ^=+$ ]] && continue

        # Expect: name mode keyid type klen ...
        # shellcheck disable=SC2086
        set -- $line
        if [[ $# -lt 5 ]]; then
            continue
        fi
        mode="$2"
        keyid="$3"
        type="$4"
        klen="$5"
        data_rows=$((data_rows + 1))

        if [[ "$mode" == "NTS" ]]; then
            if [[ "$keyid" =~ ^[1-9][0-9]*$ && "$type" =~ ^[1-9][0-9]*$ && "$klen" =~ ^[1-9][0-9]*$ ]]; then
                nts_ok=$((nts_ok + 1))
            else
                nts_weak=$((nts_weak + 1))
            fi
        else
            non_nts=$((non_nts + 1))
        fi
    done <<<"$text"

    if (( nts_ok > 0 )); then
        printf '%s\n' "PASS"
        return 0
    fi
    if (( nts_weak > 0 )); then
        printf '%s\n' "WARNING"
        return 0
    fi
    if (( data_rows > 0 || saw_header > 0 )); then
        # Readable authdata with sources but no NTS — FAIL
        if (( data_rows > 0 )); then
            printf '%s\n' "FAIL"
            return 0
        fi
        # Header only with no rows — treat as WARNING (configured path unclear)
        printf '%s\n' "WARNING"
        return 0
    fi

    printf '%s\n' "ERROR"
    return 0
}

# Count NTS-authenticated rows (Mode NTS + nonzero KeyID) from authdata text.
count_nts_authenticated_sources() {
    local text="${1-}"
    local line mode keyid
    local count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line//[[:space:]]/}" ]] && continue
        [[ "$line" == Name/IP* || "$line" =~ ^=+$ ]] && continue
        # shellcheck disable=SC2086
        set -- $line
        (( $# < 3 )) && continue
        mode="$2"
        keyid="$3"
        if [[ "$mode" == "NTS" && "$keyid" =~ ^[1-9][0-9]*$ ]]; then
            count=$((count + 1))
        fi
    done <<<"$text"
    printf '%s\n' "$count"
}

# True if an active directive/value pair appears in the root forward-zone.
unbound_root_forward_zone_has_setting() {
    local conf="${1-}" key="$2" expected="$3"
    printf '%s\n' "$conf" | awk -v key="$key" -v expected="$expected" '
        function finish_zone() {
            if (in_forward && zone_name == "." && setting_found) found=1
        }
        {
            line=$0
            sub(/[[:space:]]*#.*/, "", line)
            if (line ~ /^[[:space:]]*$/) next
            if (line ~ /^[[:space:]]*forward-zone:[[:space:]]*$/) {
                finish_zone()
                in_forward=1
                zone_name=""
                setting_found=0
                next
            }
            if (line ~ /^[[:space:]]*[[:alnum:]_-]+:[[:space:]]*$/) {
                finish_zone()
                in_forward=0
                zone_name=""
                setting_found=0
                next
            }
            if (!in_forward) next
            if (line ~ /^[[:space:]]*name:[[:space:]]*/) {
                sub(/^[[:space:]]*name:[[:space:]]*/, "", line)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                if (line == "\".\"" || line == "\047.\047") line="."
                zone_name=line
                next
            }
            if (line ~ ("^[[:space:]]*" key "[[:space:]]*:[[:space:]]*" expected "([[:space:]]|$)")) {
                setting_found=1
            }
        }
        END {
            finish_zone()
            exit(found ? 0 : 1)
        }
    '
}

# True if the root forward-zone fails closed rather than falling back to recursion.
unbound_has_fail_closed_forwarding() {
    unbound_root_forward_zone_has_setting "${1-}" "forward-first" "no"
}

# True if an active trust anchor is configured in the server section.
unbound_has_dnssec_validation() {
    printf '%s\n' "${1-}" | awk '
        {
            line=$0
            sub(/[[:space:]]*#.*/, "", line)
            if (line ~ /^[[:space:]]*server:[[:space:]]*$/) {
                in_server=1
                next
            }
            if (line ~ /^[[:space:]]*[[:alnum:]_-]+:[[:space:]]*$/) {
                in_server=0
                next
            }
            if (in_server && line ~ /^[[:space:]]*(auto-trust-anchor-file|trust-anchor):[[:space:]]*[^[:space:]]+/) found=1
        }
        END { exit(found ? 0 : 1) }
    '
}

# Count auto-trust-anchor-file declarations in unbound config text.
unbound_trust_anchor_count() {
    local conf="${1-}"
    printf '%s\n' "$conf" | awk '
        {
            sub(/[[:space:]]*#.*/, "", $0)
            if ($0 ~ /^[[:space:]]*auto-trust-anchor-file:/) count++
        }
        END { print count+0 }
    '
}

declare -Ag UNBOUND_CONFIG_ACTIVE_PATHS=()

_unbound_read_config_tree() {
    local path="$1"
    local canonical line include_dir include_pattern include_value include_match
    local -a include_matches=() lines=()

    canonical="$(readlink -f -- "$path")" || return 1
    [[ -r "$canonical" ]] || return 1
    [[ -z "${UNBOUND_CONFIG_ACTIVE_PATHS[$canonical]+active}" ]] || return 1
    UNBOUND_CONFIG_ACTIVE_PATHS["$canonical"]=1

    mapfile -t lines < "$canonical"
    include_dir="${canonical%/*}"
    for line in "${lines[@]}"; do
        printf '%s\n' "$line"
        if [[ "$line" =~ ^[[:space:]]*include(-toplevel)?:[[:space:]]*(.*)$ ]]; then
            include_value="${BASH_REMATCH[2]%%#*}"
            include_value="${include_value#"${include_value%%[![:space:]]*}"}"
            include_value="${include_value%"${include_value##*[![:space:]]}"}"
            if [[ "$include_value" == \"*\" ]]; then
                include_value="${include_value:1:${#include_value}-2}"
            elif [[ "$include_value" == \'*\' ]]; then
                include_value="${include_value:1:${#include_value}-2}"
            fi
            if [[ "$include_value" != /* ]]; then
                include_pattern="${include_dir}/${include_value}"
            else
                include_pattern="$include_value"
            fi
            mapfile -t include_matches < <(compgen -G "$include_pattern" || true)
            if (( ${#include_matches[@]} == 0 )); then
                case "$include_value" in
                    *'*'*|*'?'*|*'['*) ;;
                    *)
                        unset 'UNBOUND_CONFIG_ACTIVE_PATHS[$canonical]'
                        return 1
                        ;;
                esac
            fi
            for include_match in "${include_matches[@]}"; do
                _unbound_read_config_tree "$include_match" || {
                    unset 'UNBOUND_CONFIG_ACTIVE_PATHS[$canonical]'
                    return 1
                }
            done
        fi
    done
    unset 'UNBOUND_CONFIG_ACTIVE_PATHS[$canonical]'
}

# Read only files reached through actual include directives. Relative paths are
# resolved beside the including file; glob includes expand in shell glob order.
unbound_read_config_tree() {
    local path="$1"
    local config_text
    UNBOUND_CONFIG_ACTIVE_PATHS=()
    config_text="$(_unbound_read_config_tree "$path")" || return 1
    printf '%s\n' "$config_text"
}

# Extract remote-control control-enable value (yes|no|unknown).
unbound_remote_control_enable() {
    local conf="${1-}"
    local val
    val="$(printf '%s\n' "$conf" | awk '
        /^[[:space:]]*remote-control:[[:space:]]*$/ { in_rc=1; next }
        in_rc && /^[^[:space:]#]/ { in_rc=0 }
        in_rc && /^[[:space:]]*control-enable:[[:space:]]*/ {
            gsub(/^[[:space:]]*control-enable:[[:space:]]*/, "", $0)
            gsub(/[[:space:]].*$/, "", $0)
            print $0
            exit
        }
    ')"
    if [[ -z "$val" ]]; then
        printf '%s\n' "unknown"
    else
        printf '%s\n' "$val"
    fi
}
