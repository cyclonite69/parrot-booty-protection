#!/bin/bash

# Parrot Booty Protection - NTP Hardener v1.0
# Purpose: Guard your time treasure by configuring Chrony with NTS (Network Time Security).
# Usage: sudo ./scripts/ntp_harden.sh

set -euo pipefail

# --- Configuration & Setup ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/var/log/ntp_harden_${TIMESTAMP}.log"
BACKUP_DIR="/root/ntp_backups/harden_${TIMESTAMP}"

# --- Logging Functions ---
log() { echo -e "${GREEN}[INFO] $1${NC}" | tee -a "$LOGFILE"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}" | tee -a "$LOGFILE"; }
error() { echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOGFILE"; exit 1; }
step() { echo -e "
${CYAN}--- $1 ---${NC}" | tee -a "$LOGFILE"; }

# --- Helper Functions ---
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root.${NC}"
        exit 1
    fi

    # Check for and install dependencies
    if ! command -v chronyd &> /dev/null; then
        warn "'chrony' is not installed. Attempting to install..."
        apt-get update -q
        DEBIAN_FRONTEND=noninteractive apt-get install -y chrony
        log "✅ Chrony installed."
    fi
    
    # Ensure systemd-timesyncd is disabled to prevent conflict
    if systemctl is-active --quiet systemd-timesyncd; then
        log "Disabling systemd-timesyncd to prevent conflicts..."
        systemctl stop systemd-timesyncd
        systemctl disable systemd-timesyncd
    fi
}

test_nts() {
    log "Testing NTS Synchronization Status..."
    sleep 5
    
    # Check if we have NTS sources
    if chronyc sources | grep -q 'N'; then
        log "✅ Chrony sources show NTS active ('N' flag present)."
        chronyc sources -v | tee -a "$LOGFILE"
    else
        warn "⚠️ No NTS sources found in 'chronyc sources'. This may take a moment."
    fi

    # Check NTS authdata
    if chronyc -N authdata | grep -q 'NTS'; then
        log "✅ NTS Authentication data verified."
        chronyc -N authdata | tee -a "$LOGFILE"
    else
        warn "⚠️ NTS Authentication data not yet available."
    fi

    # Test TLS Connectivity to NTS-KE port
    log "Testing TLS connectivity to time.cloudflare.com:4460..."
    if timeout 5 bash -c 'cat < /dev/null > /dev/tcp/time.cloudflare.com/4460' 2>/dev/null; then
        log "✅ TLS connectivity to NTS Key Exchange (4460) PASSED."
    else
        warn "⚠️ TLS connectivity to port 4460 FAILED. Check nftables rules."
    fi
}

# --- Main Hardening Logic ---
main() {
    require_root
    
    echo -e "${CYAN}🕰️ Starting Parrot Booty Protection: NTP Hardener v1.0${NC}" | tee "$LOGFILE"
    echo -e "${YELLOW}Arrr! Securing your time treasure with NTS...${NC}"
    log "Logfile will be saved to: $LOGFILE"
    log "Backups will be saved to: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    step "1. Backing Up Chrony Configuration"
    if [ -f "/etc/chrony/chrony.conf" ]; then
        cp /etc/chrony/chrony.conf "$BACKUP_DIR/chrony.conf.bak"
        log "✅ /etc/chrony/chrony.conf backed up."
    fi

    step "2. Writing Hardened Chrony Configuration"
    log "Configuring Chrony with NTS servers..."
    
    # Use EOF to write the configuration file safely
    cat > /etc/chrony/chrony.conf << 'EOF'
# Hardened Chrony Configuration - Managed by ntp-hardening script
# Using Network Time Security (NTS) for encrypted time synchronization.

# NTS-enabled servers
server time.cloudflare.com nts iburst
server nts.netnod.se nts iburst
server ptbtime1.ptb.de nts iburst

# Optional Fallback Pool (uncomment if initial sync fails)
# pool pool.ntp.org iburst

# Drift file to store time offset
driftfile /var/lib/chrony/chrony.drift

# Allow the system clock to be stepped in the first three updates if its offset is larger than 1 second.
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC).
rtcsync

# Directory for logging
logdir /var/log/chrony

# Disable remote access
bindcmdaddress 127.0.0.1
bindcmdaddress ::1

# Logging information (optional)
# log measurements statistics tracking
EOF

    log "Setting restrictive permissions on /etc/chrony/chrony.conf..."
    chmod 644 /etc/chrony/chrony.conf

    step "3. Applying and Verifying Configuration"
    log "Restarting Chrony service..."
    systemctl enable chrony >/dev/null 2>&1
    systemctl restart chrony
    
    # Give it a moment to establish connections
    sleep 3
    
    systemctl status chrony --no-pager | grep "Active:" | tee -a "$LOGFILE"
    test_nts

    echo -e "
${GREEN}=== 🦜 TIME TREASURE SECURED ===${NC}"
    echo "Your system clock is now protected by NTS encryption."
    echo "Logfile: $LOGFILE"
    echo "Backup: $BACKUP_DIR"
}

# --- Execute Script ---
main "$@"
