#!/bin/bash
# PBP State Management

PBP_STATE_DIR="${PBP_STATE_DIR:-/var/lib/pbp/state}"
PBP_STATE_FILE="${PBP_STATE_DIR}/modules.state"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

init_state() {
    mkdir -p "${PBP_STATE_DIR}"/{backups,checksums}
    if [[ ! -f "${PBP_STATE_FILE}" ]]; then
        echo '{}' > "${PBP_STATE_FILE}"
        chmod 600 "${PBP_STATE_FILE}"
    fi
}

get_module_state() {
    local module="$1"
    init_state
    jq -r --arg mod "$module" '.[$mod] // empty' "${PBP_STATE_FILE}"
}

get_module_status() {
    local module="$1"
    get_module_state "$module" | jq -r '.status // "uninstalled"'
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
