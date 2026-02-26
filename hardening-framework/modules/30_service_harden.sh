#!/bin/bash
# 30_service_harden.sh - Attack Surface Reduction (Services)
# DESCRIPTION: Disables unnecessary system services and scuttles their firewall ports.
# DEPENDENCIES: systemd, nftables, whiptail

set -euo pipefail

MODULE_NAME="service_harden"
MODULE_DESC="Disable Services & Scuttle Ports"
MODULE_VERSION="1.2"
REVERT_LOG="/var/log/service_harden_revert.log"
NFT_DYNAMIC_DIR="/etc/nftables.d"
STATE_DIR="$(dirname "$0")/../state"
CONFIG_FILE="$STATE_DIR/services_to_harden.list"

# Service to Port mapping (Service|Description|Ports)
SERVICE_MAP=(
    "cups.service|Printing (IPP)|tcp 631, udp 631"
    "avahi-daemon.service|mDNS/Discovery|udp 5353"
    "bluetooth.service|Bluetooth|none"
    "ModemManager.service|Mobile Broadband|none"
    "geoclue.service|Geolocation|none"
    "whoopsie.service|Crash Reporting|none"
    "apport.service|Crash Reporting|none"
    "packagekit.service|Background Updates|none"
    "snapd.service|Package Management|none"
)

# Load selected services or use default (all)
get_selected_services() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        # Default: All services in map
        for entry in "${SERVICE_MAP[@]}"; do
            echo "${entry%%|*}"
        done
    fi
}

configure_module() {
    local options=()
    local selected=$(get_selected_services)
    
    for entry in "${SERVICE_MAP[@]}"; do
        IFS='|' read -r service desc ports <<< "$entry"
        local state="OFF"
        if echo "$selected" | grep -q "^$service$"; then
            state="ON"
        fi
        options+=("$service" "$desc" "$state")
    done

    local choice=$(whiptail --title "Service Selection Locker" \
        --checklist "Select the services you wish to disable (harden):" 20 75 10 \
        "${options[@]}" 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ]; then
        # Save selection (clean up quotes from whiptail)
        echo "$choice" | tr -d '"' | tr ' ' '\n' > "$CONFIG_FILE"
        whiptail --msgbox "Service list updated. Run 'Enable' or 'Reinstall' to apply changes." 8 50
    fi
}

update_firewall_port() {
    local service="$1"
    local ports="$2"
    local action="$3" # "open" or "close"
    local rule_file="$NFT_DYNAMIC_DIR/${service}.nft"

    if [ "$ports" == "none" ]; then return 0; fi
    if [ ! -d "$NFT_DYNAMIC_DIR" ]; then return 0; fi

    if [ "$action" == "open" ]; then
        log_info "Opening firewall ports for $service: $ports"
        echo "# Firewall rule for $service" > "$rule_file"
        IFS=',' read -ra ADDR <<< "$ports"
        for port_spec in "${ADDR[@]}"; do
            port_spec=$(echo "$port_spec" | xargs)
            echo "$port_spec accept" >> "$rule_file"
        done
    else
        if [ -f "$rule_file" ]; then
            log_info "Scuttling firewall ports for $service (Closing $ports)"
            rm -f "$rule_file"
        fi
    fi

    if systemctl is-active --quiet nftables; then
        nft -f /etc/nftables.conf || log_warn "Failed to reload nftables rules"
    fi
}

install() {
    log_step "Installing Service Hardening"
    touch "$REVERT_LOG"
    
    local selected_to_harden=$(get_selected_services)

    for entry in "${SERVICE_MAP[@]}"; do
        IFS='|' read -r service desc ports <<< "$entry"
        
        # ONLY harden if it's in the selected list
        if echo "$selected_to_harden" | grep -q "^$service$"; then
            if systemctl list-unit-files | grep -q "^${service}"; then
                if systemctl is-enabled --quiet "$service"; then
                    log_info "Disabling and stopping $service..."
                    echo "$service" >> "$REVERT_LOG"
                    systemctl stop "$service" || log_warn "Failed to stop $service"
                    systemctl disable "$service" || log_warn "Failed to disable $service"
                    update_firewall_port "$service" "$ports" "close"
                else
                    log_info "$service is already disabled."
                    update_firewall_port "$service" "$ports" "close"
                fi
            fi
        else
            log_info "Skipping $service (not selected for hardening)."
            # If it's NOT selected for hardening, we should ensure it's NOT disabled 
            # OR just leave it alone? Usually 'install' should enforce the 'hardened' state.
            # If user unselected it, they probably want it ENABLED.
        fi
    done

    if verify; then
        log_info "Service Hardening applied successfully."
        return 0
    else
        log_error "Service Hardening verification failed."
        return 1
    fi
}

status() {
    local selected_to_harden=$(get_selected_services)
    local fully_hardened=true
    
    for service in $selected_to_harden; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            if systemctl is-enabled --quiet "$service"; then
                fully_hardened=false
                break
            fi
        fi
    done

    if [ "$fully_hardened" = true ]; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying Service Hardening & Port Scuttling..."
    local selected_to_harden=$(get_selected_services)
    
    for service in $selected_to_harden; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            if systemctl is-enabled --quiet "$service"; then
                log_error "$service is still enabled!"
                return 1
            fi
        fi
    done
    return 0
}

view_reports() {
    log_info "Fetching Active Service Port Rules..."
    echo "=== Service Firewall Exceptions (/etc/nftables.d/) ===" > /tmp/port_report.txt
    ls -l "$NFT_DYNAMIC_DIR" >> /tmp/port_report.txt
    echo -e "\n--- Rule Contents ---" >> /tmp/port_report.txt
    for f in "$NFT_DYNAMIC_DIR"/*.nft; do
        if [ -f "$f" ]; then
            echo "[$(basename "$f")]" >> /tmp/port_report.txt
            cat "$f" >> /tmp/port_report.txt
            echo "" >> /tmp/port_report.txt
        fi
    done
    whiptail --title "The Port Locker" --textbox /tmp/port_report.txt 25 80
    rm /tmp/port_report.txt 2>/dev/null || true
}

rollback() {
    log_step "Rolling back Service Hardening"
    if [ ! -f "$REVERT_LOG" ] || [ ! -s "$REVERT_LOG" ]; then
        log_warn "No revert log found at $REVERT_LOG. Cannot perform automatic rollback."
        return 0
    fi

    local services_to_revert=$(cat "$REVERT_LOG" | sort -u)
    for service in $services_to_revert; do
        log_info "Re-enabling and starting $service..."
        systemctl unmask "$service" 2>/dev/null || true
        systemctl enable "$service" || log_warn "Failed to enable $service"
        systemctl start "$service" || log_warn "Failed to start $service"
        
        # Re-open the ports
        for entry in "${SERVICE_MAP[@]}"; do
            if [[ "$entry" == "$service"* ]]; then
                IFS='|' read -r s d ports <<< "$entry"
                update_firewall_port "$service" "$ports" "open"
            fi
        done
    done

    truncate -s 0 "$REVERT_LOG"
    log_info "Service Hardening rollback complete. Ports restored."
}
