#!/bin/bash
# PBP Health Checks

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

check_module_health() {
    local module="$1"
    
    source "$(dirname "${BASH_SOURCE[0]}")/registry.sh"
    local health_hook=$(get_module_hook "$module" "health")
    
    if [[ -z "$health_hook" || ! -x "$health_hook" ]]; then
        log_warn "No health check for module: ${module}"
        return 0
    fi
    
    if bash "$health_hook"; then
        log_info "Health check passed: ${module}"
        return 0
    else
        log_error "Health check failed: ${module}"
        return 1
    fi
}

check_system_health() {
    local failed=0

    is_active_service() {
        local svc="$1"
        if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
            return 0
        fi
        if pgrep -x "$svc" &>/dev/null; then
            return 0
        fi
        return 1
    }
    
    # DNS service can be either unbound or systemd-resolved.
    if is_active_service unbound; then
        :
    elif is_active_service systemd-resolved; then
        :
    else
        log_warn "No DNS resolver service active (expected: unbound or systemd-resolved)"
        ((failed++))
    fi

    # Time sync service: allow either chronyd or systemd-timesyncd.
    if is_active_service chronyd; then
        :
    elif is_active_service systemd-timesyncd; then
        :
    elif is_active_service ntpd; then
        :
    else
        log_warn "No time sync service active (expected: chronyd, ntpd, or systemd-timesyncd)"
        ((failed++))
    fi
    
    # Check network connectivity
    if ! ping -c1 -W2 1.1.1.1 &>/dev/null; then
        log_warn "Network connectivity issue"
        ((failed++))
    fi
    
    # Check disk space
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $usage -gt 90 ]]; then
        log_warn "Disk usage critical: ${usage}%"
        ((failed++))
    fi
    
    return $failed
}

verify_module_files() {
    local module="$1"
    
    source "$(dirname "${BASH_SOURCE[0]}")/registry.sh"
    local manifest=$(get_module_manifest "$module") || return 1
    
    local hooks=$(echo "$manifest" | jq -r '.hooks | to_entries[] | .value')
    for hook in $hooks; do
        local hook_path="${PBP_MODULES_DIR}/${module}/${hook}"
        if [[ ! -f "$hook_path" ]]; then
            log_error "Missing hook file: ${hook_path}"
            return 1
        fi
    done
    
    return 0
}
