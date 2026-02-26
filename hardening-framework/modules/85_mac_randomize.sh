#!/bin/bash
# 85_mac_randomize.sh - Network Interface Privacy (MAC Randomization)
# DESCRIPTION: Mask the identity of your ship with random MAC addresses.
# DEPENDENCIES: NetworkManager

set -euo pipefail

MODULE_NAME="mac_randomize"
MODULE_DESC="The Ghost Ship (Identity Masking)"
MODULE_VERSION="1.0"
NM_CONF_DIR="/etc/NetworkManager/conf.d"
NM_MAC_FILE="${NM_CONF_DIR}/99-mac-randomization.conf"

install() {
    log_step "The Ghost Ship: Identity Masking"
    
    # 1. Create NetworkManager config for MAC randomization
    # Using 'stable' instead of 'random' ensures we get the same MAC for the SAME network,
    # which prevents issues with captive portals or MAC filtering, 
    # but still randomizes across DIFFERENT networks.
    
    cat << EOF > "$NM_MAC_FILE"
[device]
wifi.scan-rand-mac-address=yes

[connection]
# wifi.cloned-mac-address=random
# ethernet.cloned-mac-address=random

# Using 'stable' is generally more reliable for daily use
wifi.cloned-mac-address=stable
ethernet.cloned-mac-address=stable
EOF
    log_info "NetworkManager configuration written to $NM_MAC_FILE."

    # 2. Reload NetworkManager
    log_info "Reloading NetworkManager to mask our identity..."
    systemctl restart NetworkManager
    log_info "NetworkManager restarted."

    if verify; then
        log_info "The Ghost Ship is now masked."
        return 0
    else
        log_error "Failed to mask identity."
        return 1
    fi
}

status() {
    if [ -f "$NM_MAC_FILE" ] && grep -q "wifi.cloned-mac-address=stable" "$NM_MAC_FILE"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying the Ghost Ship's masking..."
    if [ ! -f "$NM_MAC_FILE" ]; then
        log_error "Identity masking config missing."
        return 1
    fi
    if ! grep -q "wifi.cloned-mac-address=stable" "$NM_MAC_FILE"; then
        log_error "Identity masking config is not correctly set."
        return 1
    fi
    return 0
}

rollback() {
    log_step "The Ghost Ship: Unmasking identity"
    if [ -f "$NM_MAC_FILE" ]; then
        rm -f "$NM_MAC_FILE"
        log_info "Identity masking config removed. Restarting NetworkManager..."
        systemctl restart NetworkManager
    else
        log_warn "Identity masking config not found."
    fi
    log_info "Identity masking rollback complete."
}
