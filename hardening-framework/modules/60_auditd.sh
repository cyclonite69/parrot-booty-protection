#!/bin/bash
# 60_auditd.sh - System Auditing (The Master-at-Arms)
# DESCRIPTION: Monitors critical files and actions with a detailed ledger.
# DEPENDENCIES: auditd

set -euo pipefail

MODULE_NAME="auditd"
MODULE_DESC="The Master-at-Arms (System Auditing)"
MODULE_VERSION="1.0"
AUDIT_RULES="/etc/audit/rules.d/hardening.rules"
AUDIT_RULES_BAK="/etc/audit/rules.d/hardening.rules.bak"

install() {
    log_step "The Master-at-Arms: System Auditing"
    
    # 1. Install Auditd
    log_info "Installing Auditd..."
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y auditd audispd-plugins
    log_info "Auditd installed."

    # 2. Backup
    if [ ! -f "$AUDIT_RULES_BAK" ]; then
        if [ -f "$AUDIT_RULES" ]; then
            cp "$AUDIT_RULES" "$AUDIT_RULES_BAK"
            log_info "Original Auditd rules backed up."
        fi
    fi

    # 3. Create auditing rules (focus on critical files)
    log_info "Creating auditing rules for critical files..."
    cat << EOF > "$AUDIT_RULES"
# Remove any existing rules
-D

# Buffer Size
-b 8192

# Monitor changes to user/group info
-w /etc/group -p wa -k audit_group
-w /etc/passwd -p wa -k audit_passwd
-w /etc/shadow -p wa -k audit_shadow
-w /etc/sudoers -p wa -k audit_sudoers

# Monitor network configuration changes
-w /etc/network/ -p wa -k audit_network
-w /etc/resolv.conf -p wa -k audit_resolv
-w /etc/unbound/ -p wa -k audit_unbound

# Monitor system calls (reboot, shutdown)
-a always,exit -S reboot -S shutdown -k audit_reboot

# Lock the ruleset (requires reboot to change)
# -e 2
EOF
    log_info "Auditd rules written to $AUDIT_RULES."

    # 4. Enable and start Auditd
    log_info "Enabling and starting Auditd service..."
    systemctl enable --now auditd
    # Note: auditd doesn't like systemctl restart, use service instead or its own tool
    service auditd restart || systemctl restart auditd
    log_info "Auditd enabled and started."

    if verify; then
        log_info "The Master-at-Arms is now on watch."
        return 0
    else
        log_error "Auditd verification failed."
        rollback
        return 1
    fi
}

status() {
    if systemctl is-active --quiet auditd 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying the Master-at-Arms is awake..."
    if ! systemctl is-active --quiet auditd; then
        log_error "Auditd service is not active."
        return 1
    fi
    if ! auditctl -l | grep -q "audit_resolv"; then
        log_error "Auditd rules are not correctly loaded."
        return 1
    fi
    log_info "Auditd verified successfully."
    return 0
}

view_reports() {
    log_info "Consulting the Master-at-Arms' Ledger (Audit Logs)..."
    ausearch -m CONFIG,USER_MGMT,DAEMON_CONFIG -ts today > /tmp/audit_report.txt || echo "No audit logs found for today." > /tmp/audit_report.txt
    whiptail --title "The Master-at-Arms' Ledger (Audit Logs)" --textbox /tmp/audit_report.txt 25 80
    rm /tmp/audit_report.txt
}

rollback() {
    log_step "The Master-at-Arms: Abandoning the watch"
    log_info "Stopping and disabling Auditd..."
    systemctl disable --now auditd 2>/dev/null || true
    
    if [ -f "$AUDIT_RULES_BAK" ]; then
        cp "$AUDIT_RULES_BAK" "$AUDIT_RULES"
        log_info "Restored original Auditd rules."
    else
        rm -f "$AUDIT_RULES"
    fi
    
    log_info "Auditd rollback complete."
}
