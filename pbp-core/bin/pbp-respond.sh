#!/bin/bash
# pbp-respond.sh - Defensive Response Menu for PBP

source "/opt/pbp/lib/pbp-lib.sh"

show_menu() {
    local action=$(whiptail --title "🏴‍☠️ Defensive Response Center" --menu "A threat has been sighted! Choose your counter-measure:" 20 70 6 
        "1_KillProc" "Kill a Suspicious Process" 
        "2_StopListen" "Stop a New Network Listener" 
        "3_FreezeCont" "Freeze a Container (Podman)" 
        "4_Isolate" "Isolate Host Networking (DANGER)" 
        "5_AlertOnly" "Dismiss - Alert Only" 
        "Back" "Return to the Quarterdeck" 3>&1 1>&2 2>&3)

    case "$action" in
        "1_KillProc")
            local pid=$(whiptail --inputbox "Enter PID to scuttle:" 8 40 3>&1 1>&2 2>&3)
            if [ -n "$pid" ]; then
                if whiptail --yesno "Are you sure you want to kill PID $pid?" 8 40; then
                    kill -9 "$pid" && pbp_alert "NOTICE" "RESPONSE" "Scuttled PID $pid."
                fi
            fi
            ;;
        "2_StopListen")
            local port=$(whiptail --inputbox "Enter Port to close:" 8 40 3>&1 1>&2 2>&3)
            if [ -n "$port" ]; then
                local pid=$(ss -tulpn | grep ":$port " | awk '{print $7}' | cut -d'=' -f2 | cut -d',' -f1)
                if [ -n "$pid" ]; then
                    if whiptail --yesno "Found PID $pid listening on $port. Kill it?" 8 40; then
                        kill -9 "$pid" && pbp_alert "NOTICE" "RESPONSE" "Closed port $port by killing PID $pid."
                    fi
                else
                    whiptail --msgbox "Could not find PID for port $port." 8 40
                fi
            fi
            ;;
        "3_FreezeCont")
            local cid=$(whiptail --inputbox "Enter Container ID/Name to freeze:" 8 40 3>&1 1>&2 2>&3)
            if [ -n "$cid" ]; then
                podman pause "$cid" && pbp_alert "NOTICE" "RESPONSE" "Container $cid frozen in time."
            fi
            ;;
        "4_Isolate")
            if whiptail --yesno "DANGER: This will drop ALL networking except loopback. Proceed?" 10 50; then
                # Implement safe isolation (allow lo, drop others)
                nft add table inet isolate
                nft add chain inet isolate input { type filter hook input priority 0 \; policy drop \; }
                nft add chain inet isolate output { type filter hook output priority 0 \; policy drop \; }
                nft add rule inet isolate input iif lo accept
                nft add rule inet isolate output oif lo accept
                pbp_alert "CRITICAL" "RESPONSE" "HOST ISOLATED. All network traffic blocked except loopback."
            fi
            ;;
    esac
}

show_menu
