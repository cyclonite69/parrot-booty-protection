#!/bin/bash

# DNS Emergency Restoration Script - v2.1
# Purpose: Fully reverts the changes made by dns_harden.sh and restores system defaults.
# Usage: sudo ./dns_restore.sh [--flush-nftables]

set -euo pipefail

# --- Configuration & Setup ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/var/log/dns_restore_${TIMESTAMP}.log"
FLUSH_NFTABLES=false

# --- Logging Functions ---
log() { echo -e "${GREEN}[INFO] $1${NC}" | tee -a "$LOGFILE"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}" | tee -a "$LOGFILE"; }
error() { echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOGFILE"; exit 1; }
step() { echo -e "\n${CYAN}--- $1 ---${NC}" | tee -a "$LOGFILE"; }

# --- Helper Functions ---
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root.${NC}"
        exit 1
    fi
}

parse_args() {
    if [[ "$1" == "--flush-nftables" ]]; then
        FLUSH_NFTABLES=true
        log "Flag --flush-nftables detected. Firewall rules will be flushed."
    fi
}

test_dns() {
    log "Testing DNS resolution with 'nmcli query google.com'..."
    if timeout 5 nmcli query google.com >/dev/null 2>&1; then
        log "✅ DNS test PASSED."
    else
        warn "⚠️ DNS test FAILED. There might be an upstream network issue."
    fi
}

# --- Main Restoration Logic ---
main() {
    require_root
    parse_args "${1:-}"
    
    echo -e "${CYAN}Starting DNS Emergency Restoration v2.1${NC}" | tee "$LOGFILE"
    log "Logfile will be saved to: $LOGFILE"

    step "1. Disabling and Stopping Hardening Services"
    log "Stopping and disabling Unbound..."
    systemctl stop unbound 2>/dev/null || true
    systemctl disable unbound 2>/dev/null || true
    log "Unbound has been stopped and disabled."

    step "2. Removing NetworkManager Override"
    local nm_override_file="/etc/NetworkManager/conf.d/dns-hardening.conf"
    if [ -f "$nm_override_file" ]; then
        log "Removing NetworkManager DNS override file..."
        rm -f "$nm_override_file"
        log "Removed $nm_override_file."
    else
        log "NetworkManager override file not found (already restored)."
    fi

    step "3. Restoring /etc/resolv.conf"
    log "Removing immutable flag from /etc/resolv.conf..."
    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf

    # Find the latest backup to restore from
    local latest_backup=$(ls -td /root/dns_backups/harden_* 2>/dev/null | head -1)
    local backup_info_file="${latest_backup}/resolv.conf.bak.info"

    if [ -f "$backup_info_file" ]; then
        log "Found smart backup info in '$latest_backup'"
        local info=$(cat "$backup_info_file")
        if [[ "$info" == "symlink:"* ]]; then
            local target=${info#symlink:}
            log "Restoring symlink: /etc/resolv.conf -> $target"
            ln -sf "$target" /etc/resolv.conf
            log "✅ Symlink restored."
        elif [ "$info" == "file" ]; then
            log "Restoring backed-up file to /etc/resolv.conf..."
            cp "${latest_backup}/resolv.conf.bak" /etc/resolv.conf
            log "✅ File restored."
        else
            log "Original state was 'missing'. No file to restore."
        fi
    else
        warn "No smart backup info found. Falling back to default system restore."
        local symlink_target="/run/systemd/resolve/stub-resolv.conf"
        if [ ! -f "$symlink_target" ]; then
            warn "Default symlink target '$symlink_target' not found."
            symlink_target="/run/systemd/resolve/resolv.conf"
            log "Attempting fallback target: $symlink_target"
        fi

        if [ -f "$symlink_target" ]; then
            ln -sf "$symlink_target" /etc/resolv.conf
            log "✅ Linked /etc/resolv.conf -> $symlink_target"
        else
            warn "Could not determine system default. Creating generic public DNS as last resort."
            cat > /etc/resolv.conf << 'EOF'
# Fallback DNS - System default could not be determined
nameserver 1.1.1.1
nameserver 9.9.9.9
EOF
        fi
    fi

    step "4. Restarting Core Network Services"
    log "Unmasking and enabling systemd-resolved..."
    systemctl unmask systemd-resolved 2>/dev/null || true
    systemctl enable systemd-resolved 2>/dev/null || true
    log "Restarting systemd-resolved..."
    systemctl restart systemd-resolved

    log "Restarting NetworkManager to apply changes..."
    systemctl restart NetworkManager
    log "Waiting for NetworkManager to settle..."
    sleep 3

    if $FLUSH_NFTABLES; then
        step "5. Flushing Firewall Rules"
        log "Flushing all nftables rules as requested..."
        nft flush ruleset
        log "✅ nftables ruleset flushed."
        warn "Firewall is now open. Consider reloading a baseline configuration."
    fi

    step "6. Final Verification"
    log "Current /etc/resolv.conf:"
    (ls -l /etc/resolv.conf && cat /etc/resolv.conf) | tee -a "$LOGFILE"
    test_dns
    
    echo -e "\n${GREEN}=== DNS RESTORATION COMPLETE ===${NC}"
    echo "The system has been reverted to its default network configuration."
    echo "Unbound is disabled, and NetworkManager is now managing DNS."
    echo "Logfile: $LOGFILE"
}

# --- Execute Script ---
main "$@"
