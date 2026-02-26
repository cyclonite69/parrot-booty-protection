#!/bin/bash
# 80_fail2ban.sh - Intrusion Prevention (Fail2Ban)
# DESCRIPTION: Throws scoundrels in the Iron Brig (bans IPs with failed logins).
# DEPENDENCIES: fail2ban, nftables

set -euo pipefail

MODULE_NAME="fail2ban"
MODULE_DESC="The Iron Brig (Intrusion Prevention)"
MODULE_VERSION="1.0"
FAIL2BAN_CONF="/etc/fail2ban/jail.local"
FAIL2BAN_BAK="/etc/fail2ban/jail.local.bak"

install() {
    log_step "The Iron Brig: Intrusion Prevention"
    
    # 1. Install Fail2Ban
    log_info "Installing Fail2Ban..."
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
    log_info "Fail2Ban installed."

    # 2. Backup existing jail.local
    if [ ! -f "$FAIL2BAN_BAK" ]; then
        if [ -f "$FAIL2BAN_CONF" ]; then
            cp "$FAIL2BAN_CONF" "$FAIL2BAN_BAK"
            log_info "Original Fail2Ban config backed up."
        fi
    fi

    # 3. Create jail.local for nftables and common services
    log_info "Creating jail.local with nftables backend..."
    cat << EOF > "$FAIL2BAN_CONF"
[DEFAULT]
# Ban for 1 hour
bantime = 3600
# Look back over 10 minutes
findtime = 600
# Allow 5 failed attempts
maxretry = 5

# Use nftables as the backend
banaction = nftables-multiport
chain = input

[sshd]
enabled = true
# If SSH is on a non-standard port, update here
port = ssh
EOF
    log_info "Fail2Ban configuration written to $FAIL2BAN_CONF."

    # 4. Enable and start Fail2Ban
    log_info "Enabling and starting Fail2Ban service..."
    systemctl enable --now fail2ban
    log_info "Fail2Ban enabled and started."

    if verify; then
        log_info "The Iron Brig is active."
        return 0
    else
        log_error "Fail2Ban verification failed."
        rollback
        return 1
    fi
}

status() {
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying the Iron Brig's bars..."
    if ! systemctl is-active --quiet fail2ban; then
        log_error "Fail2Ban service is not active."
        return 1
    fi
    if ! fail2ban-client status sshd >/dev/null 2>&1; then
        log_error "Fail2Ban sshd jail is not correctly configured."
        return 1
    fi
    log_info "Fail2Ban verified successfully."
    return 0
}

view_reports() {
    log_info "Inspecting the Iron Brig (Banned IPs)..."
    echo "=== Current Prisoners (Banned IPs) ===" > /tmp/f2b_report.txt
    fail2ban-client status sshd >> /tmp/f2b_report.txt
    whiptail --title "The Iron Brig (Banned IPs)" --textbox /tmp/f2b_report.txt 25 80
    rm /tmp/f2b_report.txt
}

rollback() {
    log_step "The Iron Brig: Releasing the scoundrels"
    log_info "Stopping and disabling Fail2Ban..."
    systemctl disable --now fail2ban 2>/dev/null || true
    
    if [ -f "$FAIL2BAN_BAK" ]; then
        cp "$FAIL2BAN_BAK" "$FAIL2BAN_CONF"
        log_info "Restored original Fail2Ban configuration."
    else
        rm -f "$FAIL2BAN_CONF"
    fi
    
    log_info "Fail2Ban rollback complete."
}
