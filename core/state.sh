#!/bin/bash
# PBP State Management

PBP_STATE_DIR="${PBP_STATE_DIR:-/var/lib/pbp/state}"
PBP_STATE_FILE="${PBP_STATE_DIR}/modules.state"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

init_state() {
    # Only create state if we have write permissions
    if [[ -w "${PBP_STATE_DIR}" ]] || [[ ! -e "${PBP_STATE_DIR}" && -w "$(dirname "${PBP_STATE_DIR}")" ]]; then
        mkdir -p "${PBP_STATE_DIR}"/{backups,checksums}
        if [[ ! -f "${PBP_STATE_FILE}" ]]; then
            echo '{}' > "${PBP_STATE_FILE}"
            chmod 600 "${PBP_STATE_FILE}"
        fi
    fi
}

get_module_state() {
    local module="$1"
    # Only init if state file doesn't exist
    [[ ! -f "${PBP_STATE_FILE}" ]] && init_state
    # Return empty if state file still doesn't exist (no permissions)
    [[ ! -f "${PBP_STATE_FILE}" ]] && echo '{}' && return
    jq -r --arg mod "$module" '.[$mod] // empty' "${PBP_STATE_FILE}"
}

get_module_status() {
    local module="$1"
    local state=$(get_module_state "$module")
    [[ -z "$state" ]] && echo "uninstalled" && return
    echo "$state" | jq -r '.status // "uninstalled"'
}

set_module_state() {
    local module="$1"
    local status="$2"
    local config="${3:-\{\}}"
    
    init_state
    
    # Validate config is valid JSON
    if ! echo "$config" | jq empty 2>/dev/null; then
        config='{}'
    fi
    
    local backup_id=$(date +%Y%m%d_%H%M%S)
    local state=$(jq -n \
        --arg mod "$module" \
        --arg stat "$status" \
        --arg ver "1.0.0" \
        --arg ts "$(date -Iseconds)" \
        --arg bid "$backup_id" \
        --argjson cfg "$config" \
        '{status: $stat, version: $ver, timestamp: $ts, backup_id: $bid, config: $cfg}')
    
    jq --arg mod "$module" --argjson state "$state" \
        '.[$mod] = $state' "${PBP_STATE_FILE}" > "${PBP_STATE_FILE}.tmp"
    
    mv "${PBP_STATE_FILE}.tmp" "${PBP_STATE_FILE}"
    chmod 600 "${PBP_STATE_FILE}"
    
    log_info "State updated: ${module} -> ${status}"
}

list_enabled_modules() {
    init_state
    jq -r 'to_entries[] | select(.value.status == "enabled") | .key' "${PBP_STATE_FILE}"
}

list_installed_modules() {
    init_state
    jq -r 'to_entries[] | select(.value.status != "uninstalled") | .key' "${PBP_STATE_FILE}"
}

get_all_states() {
    init_state
    cat "${PBP_STATE_FILE}"
}
