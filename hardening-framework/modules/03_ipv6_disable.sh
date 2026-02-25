#!/bin/bash
# 03_ipv6_disable.sh - Disable IPv6 Module
# DESCRIPTION: Completely disables IPv6 functionality via sysctl.
# DEPENDENCIES: sysctl, grep

MODULE_NAME="ipv6_disable"
MODULE_DESC="Total IPv6 Removal (Disable)"
MODULE_VERSION="1.0"
CONFIG_FILE="/etc/sysctl.d/70-disable-ipv6.conf"

install() {
    log_info "Disabling IPv6 via sysctl..."

    cat << EOF > "$CONFIG_FILE"
# Disable IPv6 - Applied by Hardening Framework
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    log_info "Applying sysctl settings..."
    sysctl -p "$CONFIG_FILE" >/dev/null 2>&1 || sysctl --system >/dev/null

    if verify; then
        log_info "IPv6 has been disabled."
        return 0
    else
        log_error "Failed to disable IPv6."
        rollback
        return 1
    fi
}

status() {
    local all_disabled=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
    if [[ "$all_disabled" == "1" ]]; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check if IPv6 addresses are still present (excluding loopback if needed, but we disable lo too)
    if [ -f /proc/net/if_inet6 ] && [ -s /proc/net/if_inet6 ]; then
        # Some interfaces might still have IPv6 until restart or manual down/up
        # But if sysctl is 1, it's technically "disabled" for new operations
        local current_val=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
        if [[ "$current_val" == "1" ]]; then
            return 0
        else
            return 1
        fi
    else
        return 0 # No IPv6 stack found or empty
    fi
}

rollback() {
    log_info "Re-enabling IPv6..."
    if [ -f "$CONFIG_FILE" ]; then
        rm "$CONFIG_FILE"
        log_info "Removed $CONFIG_FILE. Re-enabling IPv6 via sysctl..."
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null
        sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null
        sysctl --system >/dev/null
    else
        log_warn "Configuration file not found, nothing to remove."
    fi
}
