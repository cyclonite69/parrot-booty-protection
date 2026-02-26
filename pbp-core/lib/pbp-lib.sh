#!/bin/bash
# pbp-lib.sh - Core Library for Parrot Booty Protection

PBP_ROOT="/opt/pbp"
LOG_DIR="$PBP_ROOT/logs"
REPORT_DIR="$PBP_ROOT/reports"
STATE_FILE="$PBP_ROOT/state/engine.json"
BASELINE_FILE="$PBP_ROOT/baseline/system_profile.json"
SIGNAL_DIR="$PBP_ROOT/state/signals"

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

# --- State & Signal Engine ---
pbp_emit_signal() {
    local key="$1"
    local value="$2"
    mkdir -p "$SIGNAL_DIR"
    echo "$value" > "$SIGNAL_DIR/$key"
}

get_pbp_signal() {
    local key="$1"
    [ -f "$SIGNAL_DIR/$key" ] && cat "$SIGNAL_DIR/$key" || echo "0"
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
        printf '{"state": "%s", "last_change": "%s", "reason": "%s"}\n' "$new_state" "$(date)" "$reason" > "$STATE_FILE"
    fi
}

calculate_exposure() {
    local score=100
    
    # 1. Firewall Status (-20)
    if ! systemctl is-active --quiet nftables; then ((score-=20)); fi
    
    # 2. Unknown Ports (-10 per port, max 30)
    local unknown_ports=$(get_pbp_signal "unknown_ports_count")
    ((score -= (unknown_ports * 10)))
    
    # 3. Integrity Violations (-40)
    if [ "$(get_pbp_signal "integrity_violation")" == "1" ]; then ((score-=40)); fi
    
    # 4. Persistence Risks (-15)
    if [ "$(get_pbp_signal "persistence_risk")" == "1" ]; then ((score-=15)); fi

    # 5. Outdated Packages (-10)
    # Placeholder for a future module
    if [ "$(get_pbp_signal "outdated_packages")" == "1" ]; then ((score-=10)); fi

    [ $score -lt 0 ] && score=0
    echo "$score"
}

recalculate_ship_state() {
    local score=$(calculate_exposure)
    local new_state="NORMAL"
    local reason="Ship is operating within baseline parameters."

    if [ $score -lt 50 ]; then
        new_state="COMPROMISED"
        reason="Critical exposure score ($score). Multiple security violations detected."
    elif [ $score -lt 80 ]; then
        new_state="SUSPICIOUS"
        reason="Warning level exposure score ($score). Potential hostile activity."
    elif [ "$(systemctl is-enabled pbp-sentinel)" == "enabled" ]; then
        new_state="HARDENED"
        reason="Defenses are active and sentinel is on watch."
    fi

    set_pbp_state "$new_state" "$reason"
}
