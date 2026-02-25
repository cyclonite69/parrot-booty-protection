#!/bin/bash
# 01_sysctl_harden.sh - Kernel Sysctl Hardening
# DESCRIPTION: Secures the kernel by applying various sysctl settings.
# DEPENDENCIES: grep, sysctl

MODULE_NAME="sysctl_harden"
MODULE_DESC="Kernel Sysctl Hardening"
MODULE_VERSION="1.0"
CONFIG_FILE="/etc/sysctl.d/99-hardening.conf"

install() {
    log_info "Applying Sysctl Hardening..."

    cat << EOF > "$CONFIG_FILE"
# Kernel Hardening - Applied by Hardening Framework
# Prevent IP Spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP Broadcast Echo Requests (prevent smurf attacks)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable ICMP Redirects (prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Disable IP Source Routing (prevent spoofing)
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians (logging spoofed packets)
net.ipv4.conf.all.log_martians = 1

# Enable TCP SYN Cookies (protect against SYN floods)
net.ipv4.tcp_syncookies = 1

# Disable IPv6 Router Solicitations
net.ipv6.conf.all.router_solicitations = 0
net.ipv6.conf.default.router_solicitations = 0

# Disable IPv6 Router Preferences
net.ipv6.conf.all.accept_ra_rtr_pref = 0
net.ipv6.conf.default.accept_ra_rtr_pref = 0

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Hide kernel pointers
kernel.kptr_restrict = 2
EOF

    log_info "Loading sysctl settings..."
    sysctl --system >/dev/null

    if verify; then
        log_info "Sysctl Hardening applied successfully."
        return 0
    else
        log_error "Sysctl Hardening failed verification."
        rollback
        return 1
    fi
}

status() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check a few key settings
    local rp_filter=$(sysctl net.ipv4.conf.all.rp_filter | awk '{print $3}')
    local icmp_echo=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts | awk '{print $3}')

    if [[ "$rp_filter" == "1" && "$icmp_echo" == "1" ]]; then
        return 0
    else
        return 1
    fi
}

rollback() {
    log_info "Rolling back Sysctl Hardening..."
    if [ -f "$CONFIG_FILE" ]; then
        rm "$CONFIG_FILE"
        log_info "Removed $CONFIG_FILE. Reloading default sysctl..."
        sysctl --system >/dev/null # This might not revert active runtime values fully without reboot, but removes persistent config
    else
        log_warn "Configuration file not found, nothing to remove."
    fi
}
