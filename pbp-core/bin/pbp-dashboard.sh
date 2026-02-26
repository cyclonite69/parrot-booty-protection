#!/bin/bash
# pbp-dashboard.sh - Tactical Display for Parrot Booty Protection

source "/opt/pbp/lib/pbp-lib.sh"

# Function to draw a separator
draw_line() {
    echo -e "${BLUE}--------------------------------------------------------------------------------${NC}"
}

while true; do
    clear
    STATE=$(get_pbp_state)
    SCORE=$(calculate_exposure)
    
    # Header
    echo -e "${CYAN}🏴‍☠️  PARROT BOOTY PROTECTION : TACTICAL DASHBOARD  🏴‍☠️${NC}"
    draw_line
    
    # Main Posture
    case "$STATE" in
        "NORMAL") POSTURE_COL="${GREEN}" ;;
        "HARDENED") POSTURE_COL="${CYAN}" ;;
        "SUSPICIOUS") POSTURE_COL="${YELLOW}" ;;
        "UNDER_INVESTIGATION") POSTURE_COL="${PURPLE}" ;;
        "COMPROMISED") POSTURE_COL="${RED}" ;;
    esac
    
    echo -ne "  SHIP STATUS: ${POSTURE_COL}[%-20s]${NC}" "$STATE"
    echo -e "    EXPOSURE SCORE: ${YELLOW}[ $SCORE / 100 ]${NC}"
    
    # Sentinel Status
    SENTINEL_ACT=$(systemctl is-active pbp-sentinel)
    [ "$SENTINEL_ACT" == "active" ] && S_COL="${GREEN}" || S_COL="${RED}"
    echo -e "  SENTINEL: ${S_COL}$SENTINEL_ACT${NC} | MONITORING HEALTH: ${GREEN}SOUND${NC}"
    
    draw_line
    
    # Last Integrity Scan
    LAST_FIM=$(grep "CHECK_PASS" "$LOG_DIR/pbp.log" | tail -1 | awk '{print $1, $2}')
    [ -z "$LAST_FIM" ] && LAST_FIM="Never"
    echo -e "  LAST HULL INTEGRITY CHECK: ${CYAN}$LAST_FIM${NC}"
    
    # Recent Alerts (Last 5)
    echo -e "
${RED}🚩 RECENT SECURITY ALERTS (The Lookout's Journal):${NC}"
    if [ -f "$LOG_DIR/pbp.log" ]; then
        grep "ALERT_" "$LOG_DIR/pbp.log" | tail -5 | sort -r | while read -r line; do
            # Format: timestamp | module | action | result
            TS=$(echo "$line" | cut -d'|' -f1)
            MOD=$(echo "$line" | cut -d'|' -f2)
            MSG=$(echo "$line" | cut -d'|' -f4)
            echo -e "  ${YELLOW}$TS${NC} | ${RED}$MOD${NC} | $MSG"
        done
    else
        echo "  No alerts recorded in the ledger."
    fi
    
    # Active Sockets / Listeners
    echo -e "
${PURPLE}📡 ACTIVE NETWORK LISTENERS (Newly Detected Ports):${NC}"
    ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -u | xargs echo "  Ports:"
    
    draw_line
    echo -e "  [pbp forensic] - Secure Ship | [pbp scan] - Manual Scan | [Ctrl+C] - Exit War Room"
    
    sleep 5
done
