#!/bin/bash
# PBP Core Engine - Module Orchestration

set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
PBP_MODULES_DIR="${PBP_MODULES_DIR:-${PBP_ROOT}/modules}"

source "${PBP_ROOT}/core/lib/logging.sh"
source "${PBP_ROOT}/core/state.sh"
source "${PBP_ROOT}/core/registry.sh"
source "${PBP_ROOT}/core/lib/backup.sh"
source "${PBP_ROOT}/core/health.sh"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges"
        return 1
    fi
}

execute_hook() {
    local module="$1"
    local hook="$2"
    shift 2
    local args=("$@")
    
    local hook_script=$(get_module_hook "$module" "$hook")
    if [[ -z "$hook_script" ]]; then
        log_warn "Hook ${hook} not found for module ${module}"
        return 0
    fi
    
    if [[ ! -x "$hook_script" ]]; then
        chmod +x "$hook_script"
    fi
    
    log_info "Executing: ${module}/${hook}"
    
    if bash "$hook_script" "${args[@]}"; then
        log_info "Hook completed: ${module}/${hook}"
        return 0
    else
        log_error "Hook failed: ${module}/${hook}"
        return 1
    fi
}

module_install() {
    local module="$1"
    
    check_root || return 1
    
    local current_status=$(get_module_status "$module")
    if [[ "$current_status" != "uninstalled" ]]; then
        log_info "Module already installed: ${module}"
        return 0
    fi
    
    log_info "Installing module: ${module}"
    
    # Validate manifest
    local manifest="${PBP_MODULES_DIR}/${module}/manifest.json"
    validate_manifest "$manifest" || return 1
    
    # Check dependencies
    check_dependencies "$module" || return 1
    
    # Check conflicts
    check_conflicts "$module" || return 1
    
    # Execute install hook
    if ! execute_hook "$module" "install"; then
        log_error "Installation failed: ${module}"
        log_action "install" "$module" "failed"
        return 1
    fi
    
    # Update state
    set_module_state "$module" "installed" "{}"
    log_action "install" "$module" "success"
    
    return 0
}

module_enable() {
    local module="$1"
    local config="${2:-{}}"
    
    check_root || return 1
    
    local current_status=$(get_module_status "$module")
    
    if [[ "$current_status" == "enabled" ]]; then
        log_info "Module already enabled: ${module}"
        return 0
    fi
    
    if [[ "$current_status" == "uninstalled" ]]; then
        log_info "Installing module first: ${module}"
        module_install "$module" || return 1
    fi
    
    log_info "Enabling module: ${module}"
    
    # Create backup of affected files
    local manifest=$(get_module_manifest "$module")
    local backup_files=$(echo "$manifest" | jq -r '.backup_files[]? // empty')
    
    if [[ -n "$backup_files" ]]; then
        local backup_id=$(create_backup "$module" $backup_files)
        log_info "Backup created: ${backup_id}"
    fi
    
    # Execute enable hook
    if ! execute_hook "$module" "enable"; then
        log_error "Enable failed: ${module}"
        log_action "enable" "$module" "failed"
        
        # Attempt rollback
        if [[ -n "${backup_id:-}" ]]; then
            log_warn "Attempting rollback..."
            restore_backup "$module" "$backup_id"
        fi
        
        return 1
    fi
    
    # Health check
    if ! check_module_health "$module"; then
        log_error "Health check failed after enable: ${module}"
        
        if [[ -n "${backup_id:-}" ]]; then
            log_warn "Rolling back due to health check failure..."
            restore_backup "$module" "$backup_id"
        fi
        
        log_action "enable" "$module" "failed" "health_check_failed"
        return 1
    fi
    
    # Update state
    set_module_state "$module" "enabled" "$config"
    log_action "enable" "$module" "success"
    
    return 0
}

module_disable() {
    local module="$1"
    
    check_root || return 1
    
    local current_status=$(get_module_status "$module")
    
    if [[ "$current_status" != "enabled" ]]; then
        log_info "Module not enabled: ${module}"
        return 0
    fi
    
    log_info "Disabling module: ${module}"
    
    # Execute disable hook
    if ! execute_hook "$module" "disable"; then
        log_error "Disable failed: ${module}"
        log_action "disable" "$module" "failed"
        return 1
    fi
    
    # Update state
    set_module_state "$module" "installed" "{}"
    log_action "disable" "$module" "success"
    
    return 0
}

module_scan() {
    local module="$1"
    
    local current_status=$(get_module_status "$module")
    
    if [[ "$current_status" != "enabled" ]]; then
        log_error "Module not enabled: ${module}"
        return 1
    fi
    
    log_info "Scanning with module: ${module}"
    
    # Execute scan hook
    if ! execute_hook "$module" "scan"; then
        log_error "Scan failed: ${module}"
        log_action "scan" "$module" "failed"
        return 1
    fi
    
    log_action "scan" "$module" "success"
    return 0
}

module_rollback() {
    local module="$1"
    local backup_id="${2:-}"
    
    check_root || return 1
    
    if [[ -z "$backup_id" ]]; then
        # Get most recent backup
        backup_id=$(list_backups "$module" | head -n1)
    fi
    
    if [[ -z "$backup_id" ]]; then
        log_error "No backups found for module: ${module}"
        return 1
    fi
    
    log_info "Rolling back module: ${module} to backup ${backup_id}"
    
    # Verify backup integrity
    if ! verify_backup "$module" "$backup_id"; then
        log_error "Backup verification failed: ${backup_id}"
        return 1
    fi
    
    # Restore backup
    if ! restore_backup "$module" "$backup_id"; then
        log_error "Restore failed: ${module}"
        return 1
    fi
    
    # Update state to installed (not enabled)
    set_module_state "$module" "installed" "{}"
    
    return 0
}

scan_all() {
    local failed=0
    
    for module in $(list_enabled_modules); do
        if ! module_scan "$module"; then
            ((failed++))
        fi
    done
    
    return $failed
}

status_all() {
    echo "=== PBP System Status ==="
    echo
    
    echo "Enabled Modules:"
    for module in $(list_enabled_modules); do
        echo "  ✓ $module"
    done
    echo
    
    echo "Installed Modules:"
    for module in $(list_installed_modules); do
        local status=$(get_module_status "$module")
        if [[ "$status" == "installed" ]]; then
            echo "  ○ $module"
        fi
    done
    echo
    
    echo "System Health:"
    if check_system_health; then
        echo "  ✓ All checks passed"
    else
        echo "  ✗ Issues detected (see logs)"
    fi
}
