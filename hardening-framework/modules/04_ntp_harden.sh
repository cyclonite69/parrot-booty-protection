#!/bin/bash
# 04_ntp_harden.sh - Encrypted Time (NTS) Module
# DESCRIPTION: Configures Chrony with NTS (Network Time Security) and authentication.
# DEPENDENCIES: chrony, nftables

MODULE_NAME="ntp_harden"
MODULE_DESC="Encrypted Time Synchronization (NTS)"
MODULE_VERSION="1.0"
CHRONY_CONF="/etc/chrony/chrony.conf"
CHRONY_BAK="/etc/chrony/chrony.conf.bak"

install() {
    log_info "Installing Chrony and enabling NTS..."
    
    # 1. Install Chrony
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y chrony

    # 2. Backup
    if [ ! -f "$CHRONY_BAK" ]; then
        cp "$CHRONY_CONF" "$CHRONY_BAK"
    fi

    # 3. Apply Hardened Configuration
    cat << EOF > "$CHRONY_CONF"
# Hardened Chrony Configuration - Managed by hardening-framework
# Use Network Time Security (NTS)

# Cloudflare NTS
server time.cloudflare.com nts iburst

# Netnod NTS
server nts.netnod.se nts iburst
server ptbtime1.ptb.de nts iburst

# Security: Disable unauthenticated command access
bindcmdaddress 127.0.0.1
bindcmdaddress ::1

# Driftfile
driftfile /var/lib/chrony/chrony.drift

# Allow step in first 3 updates
makestep 1.0 3

# Enable kernel RTC sync
rtcsync

# Log directory
logdir /var/log/chrony

# Leap second handling
leapsectz right/UTC
EOF

    # 4. Restart Service
    systemctl restart chrony
    sleep 5 # Wait for sync attempt

    if verify; then
        log_info "NTS Hardening applied successfully."
        return 0
    else
        log_error "NTS Verification failed. Check network or firewall."
        rollback
        return 1
    fi
}

status() {
    if grep -q "nts.netnod.se" "$CHRONY_CONF" 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check if chronyc reports NTS sources
    if chronyc sources | grep -q "NTS"; then
        return 0
    # Or check if 'N' flag (NTS) is present in sources output
    elif chronyc sources | grep -q "^M.*N"; then
        return 0
    else
        # Try checking authdata
        if chronyc authdata | grep -q "NTS"; then
            return 0
        fi
    fi
    return 1
}

rollback() {
    log_info "Rolling back NTP Hardening..."
    if [ -f "$CHRONY_BAK" ]; then
        cp "$CHRONY_BAK" "$CHRONY_CONF"
        systemctl restart chrony
        log_info "Original configuration restored."
    else
        log_warn "Backup not found. Reinstalling default package config..."
        apt-get install --reinstall -y chrony
    fi
}
