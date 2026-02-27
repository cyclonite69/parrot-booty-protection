#!/bin/bash
# Integrity Watcher - Monitor protected files

set -euo pipefail

WATCH_DIR="/var/lib/pbp/integrity"
ALERT_LOG="/var/log/pbp/integrity-alerts.log"
POLICY_FILE="/opt/pbp/config/policy.yaml"

mkdir -p "$WATCH_DIR"
mkdir -p "$(dirname "$ALERT_LOG")"

# Get protected files from policy
get_protected_files() {
    grep -A 10 "^protected_files:" "$POLICY_FILE" | grep "^  -" | sed 's/^  - //'
}

# Create baseline checksums
create_baseline() {
    local file="$1"
    local hash_file="$WATCH_DIR/$(echo "$file" | tr '/' '_').sha256"
    
    if [[ -f "$file" ]]; then
        sha256sum "$file" > "$hash_file"
    fi
}

# Check file integrity
check_integrity() {
    local file="$1"
    local hash_file="$WATCH_DIR/$(echo "$file" | tr '/' '_').sha256"
    
    if [[ ! -f "$hash_file" ]]; then
        return 0  # No baseline yet
    fi
    
    if [[ ! -f "$file" ]]; then
        echo "DELETED"
        return 1
    fi
    
    if ! sha256sum -c "$hash_file" &>/dev/null; then
        echo "MODIFIED"
        return 1
    fi
    
    echo "OK"
    return 0
}

# Generate alert
generate_alert() {
    local file="$1"
    local status="$2"
    local timestamp=$(date -Iseconds)
    
    cat >> "$ALERT_LOG" << EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[PBP INTEGRITY ALERT]
Timestamp: $timestamp
File: $file
Status: $status
Action: Configuration will be restored
Operator approval required for changes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

    # Terminal alert if interactive
    if [[ -t 1 ]]; then
        echo "⚠️  INTEGRITY ALERT: $file - $status"
    fi
}

# Restore from backup
restore_file() {
    local file="$1"
    local backup="/var/lib/pbp/state/backups/$(basename "$file").backup"
    
    if [[ -f "$backup" ]]; then
        cp "$backup" "$file"
        echo "✅ Restored: $file"
    fi
}

# Main watch loop
watch_integrity() {
    echo "Starting integrity watcher..."
    
    while true; do
        for file in $(get_protected_files); do
            status=$(check_integrity "$file")
            
            if [[ "$status" != "OK" ]]; then
                generate_alert "$file" "$status"
                restore_file "$file"
                create_baseline "$file"
            fi
        done
        
        sleep 60
    done
}

# Initialize baselines
init_baselines() {
    echo "Creating integrity baselines..."
    for file in $(get_protected_files); do
        create_baseline "$file"
    done
    echo "✅ Baselines created"
}

# Command handling
case "${1:-}" in
    init)
        init_baselines
        ;;
    watch)
        watch_integrity
        ;;
    check)
        for file in $(get_protected_files); do
            status=$(check_integrity "$file")
            echo "$file: $status"
        done
        ;;
    *)
        echo "Usage: $0 {init|watch|check}"
        exit 1
        ;;
esac
