#!/bin/bash
# 40_dns_monitoring.sh - DNS Security Monitoring
# DESCRIPTION: Monitors DNS immutability and DoT status, provides alerts.
# DEPENDENCIES: cron, unbound, notify-send (optional)

set -euo pipefail

MODULE_NAME="dns_monitoring"
MODULE_DESC="Background DNS & DoT Monitor"
MODULE_VERSION="1.0"

MONITOR_SCRIPT="/usr/local/bin/dns_monitor.sh"
TLS_MONITOR_SCRIPT="/usr/local/bin/dns_tls_monitor.sh"
ALERT_SCRIPT="/usr/local/bin/dns_alert.sh"
INTERVAL="*/30 * * * *" # Every 30 minutes
MONITOR_LOG="/var/log/dns_hardening_monitor.log"
ALERT_LOG="/var/log/dns_hardening_alerts.log"

view_reports() {
    local choice=$(whiptail --title "📡 DNS Lookout Logs" --menu "Select a log to view from the crow's nest:" 15 60 3 \
        "Monitor" "Immutability Check History" \
        "Alerts" "Security Alert History" \
        "Back" "Return to the Quarterdeck" 3>&1 1>&2 2>&3)
    
    case "$choice" in
        "Monitor")
            [ -f "$MONITOR_LOG" ] && whiptail --textbox "$MONITOR_LOG" 25 80 || whiptail --msgbox "Log not found." 8 40
            ;;
        "Alerts")
            [ -f "$ALERT_LOG" ] && whiptail --textbox "$ALERT_LOG" 25 80 || whiptail --msgbox "Log not found." 8 40
            ;;
    esac
}

install() {
    log_step "Installing DNS Monitoring Suite"
    
    log_info "1. Installing scripts to /usr/local/bin/..."
    cp scripts/dns_monitor.sh "$MONITOR_SCRIPT"
    cp scripts/dns_tls_monitor.sh "$TLS_MONITOR_SCRIPT"
    cp scripts/dns_alert.sh "$ALERT_SCRIPT"
    chmod +x "$MONITOR_SCRIPT" "$TLS_MONITOR_SCRIPT" "$ALERT_SCRIPT"
    
    log_info "2. Setting up Cron jobs..."
    # Clean up existing cron jobs first to avoid duplicates
    (crontab -l 2>/dev/null | grep -v "dns_monitor.sh" | grep -v "dns_tls_monitor.sh" | grep -v "dns_alert.sh" || true) > /tmp/current_crontab
    
    echo "$INTERVAL $MONITOR_SCRIPT" >> /tmp/current_crontab
    echo "$INTERVAL $TLS_MONITOR_SCRIPT" >> /tmp/current_crontab
    
    crontab /tmp/current_crontab
    rm /tmp/current_crontab
    
    log_info "Cron jobs installed."

    if verify; then
        log_info "DNS Monitoring Suite installed successfully."
        return 0
    else
        log_error "DNS Monitoring verification failed."
        return 1
    fi
}

status() {
    if crontab -l 2>/dev/null | grep -q "dns_monitor.sh" && [ -f "$MONITOR_SCRIPT" ]; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying DNS Monitoring installation..."
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        log_error "Monitor script missing."
        return 1
    fi
    if ! crontab -l 2>/dev/null | grep -q "dns_monitor.sh"; then
        log_error "Cron job not found."
        return 1
    fi
    return 0
}

rollback() {
    log_step "Rolling back DNS Monitoring Suite"
    log_info "Removing Cron jobs..."
    (crontab -l 2>/dev/null | grep -v "dns_monitor.sh" | grep -v "dns_tls_monitor.sh" | grep -v "dns_alert.sh" || true) > /tmp/current_crontab
    
    # If file is empty, remove crontab entirely
    if [ ! -s /tmp/current_crontab ]; then
        crontab -r || true
    else
        crontab /tmp/current_crontab
    fi
    rm /tmp/current_crontab
    
    log_info "Removing scripts from /usr/local/bin/..."
    rm -f "$MONITOR_SCRIPT" "$TLS_MONITOR_SCRIPT" "$ALERT_SCRIPT"
    
    log_info "DNS Monitoring Suite rollback complete."
}
