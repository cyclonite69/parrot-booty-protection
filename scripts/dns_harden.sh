#!/bin/bash

# DNS Hardening Script - v2.0
# Purpose: Harden DNS by setting a static, immutable resolv.conf and configuring NetworkManager.
# Usage: sudo ./dns_harden.sh

set -euo pipefail

# --- Configuration & Setup ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/var/log/dns_harden_${TIMESTAMP}.log"
BACKUP_DIR="/root/dns_backups/harden_${TIMESTAMP}"

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

    # Check for and install dependencies
    if ! command -v unbound &> /dev/null; then
        warn "'unbound' is not installed. Attempting to install dependencies..."
        apt-get update -q
        DEBIAN_FRONTEND=noninteractive apt-get install -y unbound unbound-anchor dnsutils
        log "✅ Dependencies installed."
    fi

    # Ensure DNSSEC root key exists
    if [ ! -f "/var/lib/unbound/root.key" ]; then
        warn "DNSSEC root key missing. Generating..."
        # unbound-anchor returns 1 if it updated the key, which is expected here
        unbound-anchor -a /var/lib/unbound/root.key || true
        chown unbound:unbound /var/lib/unbound/root.key
        log "✅ DNSSEC root key generated."
    fi
}

test_dns() {
    log "Testing DNS resolution with 'dig @127.0.0.1 google.com'..."
    if timeout 5 dig @127.0.0.1 google.com >/dev/null 2>&1; then
        log "✅ DNS test PASSED. Local resolver is working."
    else
        warn "⚠️ DNS test FAILED. Unbound may not be running or configured correctly."
    fi
}

# --- Main Hardening Logic ---
main() {
    require_root
    
    echo -e "${CYAN}Starting DNS Hardening Script v2.0${NC}" | tee "$LOGFILE"
    log "Logfile will be saved to: $LOGFILE"
    log "Backups will be saved to: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    step "1. Backing Up Network Configurations"
    # Backup NetworkManager config
    cp /etc/NetworkManager/NetworkManager.conf "$BACKUP_DIR/NetworkManager.conf.bak" 2>/dev/null || true

    # Intelligent backup of resolv.conf
    if [ -L "/etc/resolv.conf" ]; then
        local target=$(readlink -f /etc/resolv.conf)
        log "/etc/resolv.conf is a symlink to '$target'."
        echo "symlink:$target" > "$BACKUP_DIR/resolv.conf.bak.info"
    elif [ -f "/etc/resolv.conf" ]; then
        log "/etc/resolv.conf is a regular file."
        cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak"
        echo "file" > "$BACKUP_DIR/resolv.conf.bak.info"
    else
        log "/etc/resolv.conf not found, nothing to back up."
        echo "missing" > "$BACKUP_DIR/resolv.conf.bak.info"
    fi
    log "✅ Backup metadata saved to $BACKUP_DIR/resolv.conf.bak.info"

    step "2. Configuring NetworkManager to Ignore DNS"
    local nm_override_file="/etc/NetworkManager/conf.d/dns-hardening.conf"
    log "Creating NetworkManager override at $nm_override_file"
    mkdir -p "$(dirname "$nm_override_file")"
    cat > "$nm_override_file" << 'EOF'
[main]
dns=none
rc-manager=unmanaged
EOF
    log "Restarting NetworkManager to apply settings..."
    systemctl restart NetworkManager

    step "3. Creating Hardened resolv.conf"
    log "Removing immutable flag (if it exists)..."
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    log "Creating new static /etc/resolv.conf..."
    rm -f /etc/resolv.conf
    cat > /etc/resolv.conf << 'EOF'
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
EOF
    
    log "Setting immutable flag on /etc/resolv.conf to prevent modifications..."
    chattr +i /etc/resolv.conf
    log "Verifying immutable flag:"
    lsattr /etc/resolv.conf | tee -a "$LOGFILE"

    step "4. Final Verification"
    log "Ensuring Unbound is enabled and running..."
    systemctl enable unbound >/dev/null 2>&1
    systemctl restart unbound
    
    # Give unbound a moment to start
    sleep 2
    
    systemctl status unbound --no-pager | grep "Active:" | tee -a "$LOGFILE"
    test_dns

    # Optional: Fix Docker DNS
    if command -v docker &> /dev/null; then
        step "5. Docker Integration"
        log "Docker detected. Containers often fail to resolve DNS with local resolvers."
        read -p "Apply Docker DNS fix (highly recommended)? [Y/n]: " fix_docker
        fix_docker=${fix_docker:-y}
        if [[ "$fix_docker" =~ ^[Yy]$ ]]; then
            ./scripts/docker_dns_fix.sh --apply
        else
            warn "Skipping Docker fix. Containers may lose DNS resolution."
        fi
    fi

    echo -e "\n${GREEN}=== DNS HARDENING COMPLETE ===${NC}"
    echo "System DNS is now hardened and locked."
    echo "Logfile: $LOGFILE"
    echo "Backup: $BACKUP_DIR"
    echo -e "To temporarily undo: ${YELLOW}sudo chattr -i /etc/resolv.conf${NC}"
    echo -e "To fully restore: ${YELLOW}sudo ./scripts/dns_restore.sh${NC}"
}

# --- Execute Script ---
main "$@"
