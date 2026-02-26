#!/bin/bash
# PBP Backup and Restore

PBP_BACKUP_DIR="${PBP_BACKUP_DIR:-/var/lib/pbp/state/backups}"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

create_backup() {
    local module="$1"
    local files=("${@:2}")
    
    local backup_id=$(date +%Y%m%d_%H%M%S)
    local backup_path="${PBP_BACKUP_DIR}/${module}_${backup_id}"
    
    mkdir -p "$backup_path"
    
    local manifest="${backup_path}/manifest.json"
    echo '{"files": []}' > "$manifest"
    
    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            local rel_path="${file#/}"
            local backup_file="${backup_path}/${rel_path}"
            
            mkdir -p "$(dirname "$backup_file")"
            cp -a "$file" "$backup_file"
            
            local checksum=$(sha256sum "$file" | awk '{print $1}')
            jq --arg f "$file" --arg c "$checksum" \
                '.files += [{path: $f, checksum: $c}]' "$manifest" > "${manifest}.tmp"
            mv "${manifest}.tmp" "$manifest"
            
            log_info "Backed up: ${file} -> ${backup_file}"
        fi
    done
    
    echo "$backup_id"
}

list_backups() {
    local module="$1"
    
    if [[ ! -d "$PBP_BACKUP_DIR" ]]; then
        return 0
    fi
    
    find "$PBP_BACKUP_DIR" -maxdepth 1 -type d -name "${module}_*" | \
        xargs -n1 basename | \
        sed "s/${module}_//" | \
        sort -r
}

restore_backup() {
    local module="$1"
    local backup_id="$2"
    
    local backup_path="${PBP_BACKUP_DIR}/${module}_${backup_id}"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: ${backup_path}"
        return 1
    fi
    
    local manifest="${backup_path}/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        log_error "Backup manifest missing: ${manifest}"
        return 1
    fi
    
    local files=$(jq -r '.files[].path' "$manifest")
    for file in $files; do
        local rel_path="${file#/}"
        local backup_file="${backup_path}/${rel_path}"
        
        if [[ -f "$backup_file" ]]; then
            mkdir -p "$(dirname "$file")"
            cp -a "$backup_file" "$file"
            log_info "Restored: ${backup_file} -> ${file}"
        fi
    done
    
    log_action "restore" "$module" "success" "backup_id=${backup_id}"
    return 0
}

verify_backup() {
    local module="$1"
    local backup_id="$2"
    
    local backup_path="${PBP_BACKUP_DIR}/${module}_${backup_id}"
    local manifest="${backup_path}/manifest.json"
    
    if [[ ! -f "$manifest" ]]; then
        return 1
    fi
    
    local files=$(jq -r '.files[] | @json' "$manifest")
    while IFS= read -r entry; do
        local path=$(echo "$entry" | jq -r '.path')
        local expected_sum=$(echo "$entry" | jq -r '.checksum')
        
        local rel_path="${path#/}"
        local backup_file="${backup_path}/${rel_path}"
        
        if [[ ! -f "$backup_file" ]]; then
            log_error "Backup file missing: ${backup_file}"
            return 1
        fi
        
        local actual_sum=$(sha256sum "$backup_file" | awk '{print $1}')
        if [[ "$actual_sum" != "$expected_sum" ]]; then
            log_error "Checksum mismatch: ${backup_file}"
            return 1
        fi
    done <<< "$files"
    
    return 0
}
