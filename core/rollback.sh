#!/bin/bash
# PBP Rollback System

set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"

source "${PBP_ROOT}/core/lib/logging.sh"
source "${PBP_ROOT}/core/lib/backup.sh"
source "${PBP_ROOT}/core/state.sh"

rollback_module() {
    local module="$1"
    local backup_id="${2:-}"
    
    if [[ $EUID -ne 0 ]]; then
        log_error "Rollback requires root privileges"
        return 1
    fi
    
    if [[ -z "$backup_id" ]]; then
        backup_id=$(list_backups "$module" | head -n1)
        if [[ -z "$backup_id" ]]; then
            log_error "No backups available for: ${module}"
            return 1
        fi
        log_info "Using most recent backup: ${backup_id}"
    fi
    
    log_info "Rolling back ${module} to ${backup_id}"
    
    if ! verify_backup "$module" "$backup_id"; then
        log_error "Backup integrity check failed"
        return 1
    fi
    
    if ! restore_backup "$module" "$backup_id"; then
        log_error "Restore operation failed"
        return 1
    fi
    
    set_module_state "$module" "installed" "{}"
    log_action "rollback" "$module" "success" "backup_id=${backup_id}"
    
    echo "Rollback complete. Module disabled. Re-enable with: pbp enable ${module}"
    return 0
}

list_module_backups() {
    local module="$1"
    
    echo "Available backups for ${module}:"
    for backup_id in $(list_backups "$module"); do
        echo "  ${backup_id}"
    done
}
