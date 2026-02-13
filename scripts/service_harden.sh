#!/bin/bash

# Service Hardening Wizard - v2.0
# Purpose: Interactively disable unnecessary system services to reduce attack surface.
# Usage: sudo ./service_harden.sh [--status|--revert]

set -euo pipefail

# --- Configuration & Setup ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

REVERT_LOG="/var/log/service_harden_revert.log"

# --- Service Definitions ---
# Using a HEREDOC for a clean, multi-line associative array definition in bash 4+
declare -A SERVICES
while read -r line; do
    key="${line%%|*}"
    val="${line#*|}"
    SERVICES["$key"]="$val"
done <<EOF
cups.service|Printing|Manages printers and printing jobs. Unnecessary if you do not print from this machine.
avahi-daemon.service|Network Discovery|Implements zero-configuration networking (mDNS/Bonjour). Useful for finding network printers/devices, but a security risk and unnecessary on a static workstation.
bluetooth.service|Bluetooth|Manages all Bluetooth devices. If you don't use Bluetooth keyboards, mice, or audio, this increases your attack surface via radio waves.
ModemManager.service|Mobile Broadband|Handles mobile broadband cards (3G/4G/5G). If you only use Wi-Fi or Ethernet, this is safe to disable.
geoclue.service|Geolocation|Provides location information to applications. A potential privacy leak if not explicitly needed.
whoopsie.service|Crash Reporting|Ubuntu's crash database submission daemon. Sends crash reports to Canonical.
apport.service|Crash Reporting|Collects data on application crashes. Can be noisy and is primarily for developers to debug system-wide issues.
packagekit.service|Background Updates|A background service that allows GUI software centers to manage packages. Can be disabled if you manage all packages via the command line (apt).
snapd.service|Package Management|Daemon for the Snap package ecosystem. If you do not use or have Snap packages installed, this is unnecessary overhead.
EOF

# --- UI & Logging ---
step() { echo -e "\n${CYAN}--- $1 ---${NC}"; }
log_ok() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }

# --- Core Functions ---
require_root() { [[ $EUID -ne 0 ]] && echo -e "${RED}This script must be run as root.${NC}" && exit 1; }

run_status_check() {
    step "Service Hardening Status Report"
    for service in "${!SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            local is_enabled=$(systemctl is-enabled "$service" 2>/dev/null && echo "enabled" || echo "disabled")
            local is_active=$(systemctl is-active "$service" 2>/dev/null && echo "active" || echo "inactive")
            
            if [[ "$is_enabled" == "enabled" ]]; then
                log_warn "$(printf "%-25s -> %-8s / %s" "$service" "$is_enabled" "$is_active")"
            else
                log_ok "$(printf "%-25s -> %-8s / %s" "$service" "$is_enabled" "$is_active")"
            fi
        fi
    done
}

run_interactive_wizard() {
    step "Starting Interactive Hardening Wizard"
    local revert_needed=false
    for service in "${!SERVICES[@]}"; do
        IFS='|' read -r category desc <<< "${SERVICES[$service]}"
        if systemctl list-unit-files | grep -q "^${service}"; then
            if systemctl is-enabled --quiet "$service"; then
                echo; step "Category: $category"
                log_info "Service:      $service"
                log_info "Description:  $desc"
                
                read -p "$(echo -e "${YELLOW}Disable this service? [Y/n]: ${NC}")" answer
                answer=${answer:-"y"}
                if [[ "$answer" =~ ^[Yy]$ ]]; then
                    log_warn "Disabling and stopping $service..."
                    # Backup action for revert
                    echo "$service" >> "$REVERT_LOG"
                    revert_needed=true
                    systemctl stop "$service"
                    systemctl disable "$service"
                    log_ok "$service disabled."
                else
                    log_info "$service will be left enabled."
                fi
            fi
        fi
    done
    
    if $revert_needed; then
        log_ok "A revert log has been created at $REVERT_LOG"
        log_info "You can undo these specific changes by running: sudo ./service_harden.sh --revert"
    fi
    log_ok "Interactive wizard complete."
}

run_revert() {
    step "Reverting Disabled Services"
    if [ ! -f "$REVERT_LOG" ]; then
        log_warn "Revert log not found at $REVERT_LOG. No changes to make."
        exit 0
    fi
    
    local services_to_revert=$(cat "$REVERT_LOG" | sort -u)
    log_info "The following services will be re-enabled and started:"
    echo "$services_to_revert"
    
    read -p "$(echo -e "${YELLOW}Proceed with revert? [y/N]: ${NC}")" answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log_info "Revert cancelled."
        exit 0
    fi
    
    for service in $services_to_revert; do
        log_warn "Re-enabling and starting $service..."
        systemctl enable "$service"
        systemctl start "$service"
        log_ok "$service restored."
    done
    
    # Clean up the log for this revert action
    sed -i "/$(echo "$services_to_revert" | tr '\n' '\|' | sed 's/.$//')/d" "$REVERT_LOG"
    log_ok "Revert complete. Log has been updated."
}

# --- Main Execution ---
main() {
    require_root
    
    case "${1-}" in
        --status)
            run_status_check
            ;;
        --revert)
            run_revert
            ;;
        *)
            run_interactive_wizard
            ;;
    esac
}

main "$@"
