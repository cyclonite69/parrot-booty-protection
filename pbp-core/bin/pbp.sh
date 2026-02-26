#!/bin/bash
# pbp - The Command Center CLI for Parrot Booty Protection

source "/opt/pbp/lib/pbp-lib.sh"

show_help() {
    echo -e "${CYAN}🦜 Parrot Booty Protection (PBP) Command Center${NC}"
    echo "Usage: pbp [command]"
    echo ""
    echo "Commands:"
    echo "  status    Show ship's security state and exposure score"
    echo "  watch     Launch the Tactical Dashboard (War Room)"
    echo "  scan      Run all monitoring modules immediately"
    echo "  learn     Establish the baseline system profile"
    echo "  harden    Enter the Hardening Framework Dashboard"
    echo "  forensic  'Secure The Ship' - Collect evidence snapshot"
    echo "  report    View the latest security reports"
    echo "  selfcheck Verify the PBP Sentinel's health"
}

case "${1-}" in
    "status")
        STATE=$(get_pbp_state)
        SCORE=$(calculate_exposure)
        echo -e "Ship State: ${PURPLE}$STATE${NC}"
        echo -e "Exposure Score: ${YELLOW}$SCORE / 100${NC}"
        ;;
    "watch")
        /opt/pbp/bin/pbp-dashboard.sh
        ;;
    "harden")
        sudo /home/dbcooper/parrot-booty-protection/hardening-framework/hardenctl
        ;;
    "report")
        # Interactive Report Explorer
        local options=()
        for f in /opt/pbp/reports/*.txt; do
            [ -f "$f" ] && options+=("$(basename "$f")" "Security Audit")
        done
        
        choice=$(whiptail --title "The Captain's Great Ledger" --menu "Select a report to view:" 20 70 10 "${options[@]}" 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then
            whiptail --textbox "/opt/pbp/reports/$choice" 25 90
        fi
        ;;
    "learn")
        /opt/pbp/bin/pbp-learn.sh
        ;;
    "scan")
        echo -e "${CYAN}Manning the lookout... Running all modules.${NC}"
        for m in /opt/pbp/modules/*.sh; do [ -x "$m" ] && "$m"; done
        echo -e "${GREEN}Scan complete.${NC}"
        ;;
    "forensic")
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        FILE="/opt/pbp/forensics/pbp_snapshot_$TIMESTAMP.tar.gz"
        echo -e "${RED}🏴‍☠️ SECURING THE SHIP... Collecting evidence.${NC}"
        tar -czf "$FILE" /etc/resolv.conf /etc/ssh/sshd_config /opt/pbp/logs /opt/pbp/reports 2>/dev/null
        echo -e "${GREEN}Evidence locked in the brig: $FILE${NC}"
        ;;
    "selfcheck")
        echo "--- PBP Self Check ---"
        systemctl is-active pbp-sentinel && echo "Sentinel: RUNNING" || echo "Sentinel: DOWN"
        [ -w "/opt/pbp/reports" ] && echo "Reports: WRITABLE"
        ;;
    *)
        show_help
        ;;
esac
