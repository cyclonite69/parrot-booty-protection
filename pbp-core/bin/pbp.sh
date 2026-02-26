#!/bin/bash
# pbp - The Command Center CLI for Parrot Booty Protection

source "/opt/pbp/lib/pbp-lib.sh"

show_help() {
    echo -e "${CYAN}🦜 Parrot Booty Protection (PBP) Command Center${NC}"
    echo "Usage: pbp [command]"
    echo ""
    echo "Commands:"
    echo "  status    Show ship's security state and exposure score"
    echo "  watch     Launch the Tactical Dashboard (Terminal War Room)"
    echo "  ops       Show instructions for the Web Ops Console"
    echo "  scan      Run all monitoring modules immediately"
    echo "  learn     Establish the baseline system profile"
    echo "  harden    Enter the Hardening Framework Dashboard"
    echo "  respond   Launch the Defensive Response Center"
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
    "ops")
        echo -e "${CYAN}🏴‍☠️ Web Ops Console is active!${NC}"
        echo "Point your browser to: http://localhost:8080"
        echo "Manage modules, run scans, and view the ledger from the Quarterdeck."
        ;;
    "harden")
        sudo /home/dbcooper/parrot-booty-protection/hardening-framework/hardenctl
        ;;
    "respond")
        /opt/pbp/bin/pbp-respond.sh
        ;;
    "report")
        # Unified Report Explorer (Terminal version)
        local options=()
        # Search in both old and new report locations
        for d in /opt/pbp/reports /opt/parrot-booty-protection/reports/*; do
            if [ -d "$d" ]; then
                for f in "$d"/*; do
                    [ -f "$f" ] && options+=("$(basename "$f")" "Security Audit")
                done
            fi
        done
        
        if [ ${#options[@]} -eq 0 ]; then
            whiptail --msgbox "No reports found in the ledger." 8 40
            exit 0
        fi

        choice=$(whiptail --title "The Captain's Great Ledger" --menu "Select a report to view:" 20 70 10 "${options[@]}" 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then
            # Find the file again to show it
            local full_path=$(find /opt/pbp/reports /opt/parrot-booty-protection/reports -name "$choice" | head -1)
            whiptail --textbox "$full_path" 25 90
        fi
        ;;
    "learn")
        /opt/pbp/bin/pbp-learn.sh
        ;;
    "scan")
        echo -e "${CYAN}Manning the lookout... Running all modules.${NC}"
        for m in /opt/pbp/modules/*.sh /opt/parrot-booty-protection/modules/*/run.sh; do 
            if [ -x "$m" ]; then
                echo "Executing $(basename $(dirname "$m"))..."
                "$m"
            fi
        done
        echo -e "${GREEN}Scan complete.${NC}"
        ;;
    "forensic")
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        FILE="/opt/pbp/forensics/pbp_snapshot_$TIMESTAMP.tar.gz"
        echo -e "${RED}🏴‍☠️ SECURING THE SHIP... Collecting evidence.${NC}"
        tar -czf "$FILE" /etc/resolv.conf /etc/ssh/sshd_config /opt/pbp/logs /opt/pbp/reports /opt/parrot-booty-protection/reports 2>/dev/null
        echo -e "${GREEN}Evidence locked in the brig: $FILE${NC}"
        ;;
    "selfcheck")
        echo "--- PBP Self Check ---"
        systemctl is-active pbp-sentinel && echo "Sentinel: RUNNING" || echo "Sentinel: DOWN"
        systemctl is-active pbp-ops && echo "Web Ops: RUNNING" || echo "Web Ops: DOWN"
        [ -w "/opt/pbp/reports" ] && echo "Reports: WRITABLE"
        systemctl is-active --quiet nftables && echo "Firewall: ACTIVE" || echo "Firewall: DOWN"
        ;;
    *)
        show_help
        ;;
esac
