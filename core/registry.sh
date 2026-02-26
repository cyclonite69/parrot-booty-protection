#!/bin/bash
# PBP Module Registry

PBP_MODULES_DIR="${PBP_MODULES_DIR:-/opt/pbp/modules}"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

validate_manifest() {
    local manifest="$1"
    
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest not found: $manifest"
        return 1
    fi
    
    local required_fields=("name" "version" "description" "hooks")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$manifest" &>/dev/null; then
            log_error "Missing required field: $field in $manifest"
            return 1
        fi
    done
    
    return 0
}

get_module_manifest() {
    local module="$1"
    local manifest="${PBP_MODULES_DIR}/${module}/manifest.json"
    
    if [[ ! -f "$manifest" ]]; then
        log_error "Module not found: $module"
        return 1
    fi
    
    cat "$manifest"
}

get_module_hook() {
    local module="$1"
    local hook="$2"
    
    local manifest=$(get_module_manifest "$module") || return 1
    local hook_script=$(echo "$manifest" | jq -r --arg h "$hook" '.hooks[$h] // empty')
    
    if [[ -z "$hook_script" ]]; then
        log_warn "Hook not defined: ${hook} for module ${module}"
        return 1
    fi
    
    echo "${PBP_MODULES_DIR}/${module}/${hook_script}"
}

list_available_modules() {
    if [[ ! -d "$PBP_MODULES_DIR" ]]; then
        return 0
    fi
    
    for module_dir in "${PBP_MODULES_DIR}"/*; do
        if [[ -d "$module_dir" && -f "${module_dir}/manifest.json" ]]; then
            basename "$module_dir"
        fi
    done
}

check_dependencies() {
    local module="$1"
    local manifest=$(get_module_manifest "$module") || return 1
    
    local deps=$(echo "$manifest" | jq -r '.dependencies[]? // empty')
    for dep in $deps; do
        local dep_status=$(source "$(dirname "${BASH_SOURCE[0]}")/state.sh" && get_module_status "$dep")
        if [[ "$dep_status" != "enabled" && "$dep_status" != "installed" ]]; then
            log_error "Missing dependency: ${dep} for module ${module}"
            return 1
        fi
    done
    
    return 0
}

check_conflicts() {
    local module="$1"
    local manifest=$(get_module_manifest "$module") || return 1
    
    local conflicts=$(echo "$manifest" | jq -r '.conflicts[]? // empty')
    for conflict in $conflicts; do
        if command -v "$conflict" &>/dev/null || systemctl is-active "$conflict" &>/dev/null 2>&1; then
            log_error "Conflict detected: ${conflict} is present (required by ${module})"
            return 1
        fi
    done
    
    return 0
}

requires_root() {
    local module="$1"
    local manifest=$(get_module_manifest "$module") || return 1
    echo "$manifest" | jq -r '.requires_root // false'
}
