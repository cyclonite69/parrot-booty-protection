#!/bin/bash
# pbp-lib.sh - Core Library for Parrot Booty Protection

PBP_ROOT="/opt/pbp"
LOG_DIR="$PBP_ROOT/logs"
REPORT_DIR="$PBP_ROOT/reports"
STATE_FILE="$PBP_ROOT/state/engine.json"
BASELINE_FILE="$PBP_ROOT/baseline/system_profile.json"

# --- Pirate Themed UI Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# --- Alert & Logging Engine ---
pbp_log() {
    local module="$1"
    local action="$2"
    local result="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp | $module | $action | $result" >> "$LOG_DIR/pbp.log"
}

pbp_alert() {
    local level="$1"
    local module="$2"
    local message="$3"
    
    pbp_log "$module" "ALERT_$level" "$message"
    
    case "$level" in
        "CRITICAL"|"HIGH") echo -e "${RED}[$level] $module: $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}[$level] $module: $message${NC}" ;;
        *) echo -e "${CYAN}[$level] $module: $message${NC}" ;;
    esac
}

get_pbp_state() {
    [ ! -f "$STATE_FILE" ] && echo "NORMAL" && return
    cat "$STATE_FILE" | grep -Po '"state": "\K[^"]*' || echo "NORMAL"
}

set_pbp_state() {
    local new_state="$1"
    local reason="$2"
    local current_state=$(get_pbp_state)
    
    if [ "$new_state" != "$current_state" ]; then
        pbp_alert "NOTICE" "SENTINEL" "Ship state changed from $current_state to $new_state. Reason: $reason"
        echo "{"state": "$new_state", "last_change": "$(date)", "reason": "$reason"}" > "$STATE_FILE"
    fi
}
