#!/bin/bash
# 90_log_explorer.sh - Central Log & Report Viewer
# DESCRIPTION: A unified interface to browse all hardening logs and security reports.
# DEPENDENCIES: whiptail

set -euo pipefail

MODULE_NAME="log_explorer"
MODULE_DESC="Central Log & Report Explorer"
MODULE_VERSION="1.0"

# This module is always "active" because it's a utility
status() { echo "active"; }
verify() { return 0; }
install() { log_info "Utility module. No installation needed."; return 0; }
rollback() { log_info "Utility module. No rollback needed."; return 0; }

view_reports() {
    while true; do
        local choice=$(whiptail --title "📜 The Captain's Great Ledger" --menu "Select a category of logs to inspect:" 20 70 10 \
            "1_Framework" "Main Ship's Log (hardenctl.log)" \
            "2_DNS_Monitor" "DNS Immutability Records" \
            "3_DNS_Alerts" "Enemy Sighted! (Security Alerts)" \
            "4_Malware" "Rootkit & Malware Sightings" \
            "5_Syslog" "The Crew's Watch (Auth Logs)" \
            "Back" "Return to the Quarterdeck" 3>&1 1>&2 2>&3)
        
        case "$choice" in
            "1_Framework")
                [ -f "/var/log/hardenctl.log" ] && whiptail --textbox "/var/log/hardenctl.log" 25 90 || whiptail --msgbox "Log not found in the locker." 8 40
                ;;
            "2_DNS_Monitor")
                [ -f "/var/log/dns_hardening_monitor.log" ] && whiptail --textbox "/var/log/dns_hardening_monitor.log" 25 90 || whiptail --msgbox "Log not found in the locker." 8 40
                ;;
            "3_DNS_Alerts")
                [ -f "/var/log/dns_hardening_alerts.log" ] && whiptail --textbox "/var/log/dns_hardening_alerts.log" 25 90 || whiptail --msgbox "Log not found in the locker." 8 40
                ;;
            "4_Malware")
                local m_choice=$(whiptail --title "Malware Reports" --menu "Choose report:" 15 60 4 \
                    "RKHunter" "rkhunter.log" \
                    "Chkrootkit" "chkrootkit.log" \
                    "Lynis" "lynis.log" \
                    "Back" "Go back" 3>&1 1>&2 2>&3)
                case "$m_choice" in
                    "RKHunter") [ -f "/var/log/security-suite/rkhunter.log" ] && whiptail --textbox "/var/log/security-suite/rkhunter.log" 25 90 || whiptail --msgbox "Not found." 8 30 ;;
                    "Chkrootkit") [ -f "/var/log/security-suite/chkrootkit.log" ] && whiptail --textbox "/var/log/security-suite/chkrootkit.log" 25 90 || whiptail --msgbox "Not found." 8 30 ;;
                    "Lynis") [ -f "/var/log/security-suite/lynis.log" ] && whiptail --textbox "/var/log/security-suite/lynis.log" 25 90 || whiptail --msgbox "Not found." 8 30 ;;
                esac
                ;;
            "5_Syslog")
                if [ -f "/var/log/auth.log" ]; then
                    whiptail --textbox "/var/log/auth.log" 25 90
                elif [ -f "/var/log/secure" ]; then
                    whiptail --textbox "/var/log/secure" 25 90
                else
                    whiptail --msgbox "Auth log not found in the locker." 8 40
                fi
                ;;
            *) break ;;
        esac
    done
}
