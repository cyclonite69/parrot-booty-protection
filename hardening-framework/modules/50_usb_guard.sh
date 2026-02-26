#!/bin/bash
# 50_usb_guard.sh - Boarding Party Defense (USB Guard)
# DESCRIPTION: Whitelist-based protection against malicious USB devices.
# DEPENDENCIES: usbguard

set -euo pipefail

MODULE_NAME="usb_guard"
MODULE_DESC="The Boarding Party Defense (USB Guard)"
MODULE_VERSION="1.0"
USBGUARD_CONF="/etc/usbguard/usbguard-daemon.conf"
USBGUARD_BAK="/etc/usbguard/usbguard-daemon.conf.bak"
RULES_FILE="/etc/usbguard/rules.conf"
RULES_BAK="/etc/usbguard/rules.conf.bak"
MODULE_TASK_LABEL="Generate New Ruleset (Whitelist Currently Connected)"

install() {
    log_step "The Boarding Party Defense: USB Guard"
    
    # 1. Install USBGuard
    log_info "Installing USBGuard..."
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y usbguard
    log_info "USBGuard installed."

    # 2. Backup
    if [ ! -f "$USBGUARD_BAK" ]; then
        if [ -f "$USBGUARD_CONF" ]; then
            cp "$USBGUARD_CONF" "$USBGUARD_BAK"
            log_info "Original USBGuard config backed up."
        fi
    fi

    # 3. Create initial ruleset based on currently connected devices
    log_info "Generating initial ruleset based on currently connected devices..."
    # If rules exist, back them up
    if [ -f "$RULES_FILE" ] && [ ! -f "$RULES_BAK" ]; then
        cp "$RULES_FILE" "$RULES_BAK"
    fi
    
    # Generate rules based on CURRENT devices to avoid locking the user out of their keyboard/mouse
    usbguard generate-policy > "$RULES_FILE"
    chmod 600 "$RULES_FILE"
    log_info "Initial ruleset generated at $RULES_FILE."

    # 4. Enable and start USBGuard
    log_info "Enabling and starting USBGuard service..."
    systemctl enable --now usbguard
    log_info "USBGuard enabled and started."

    if verify; then
        log_info "The Boarding Party Defense is active."
        return 0
    else
        log_error "USBGuard verification failed. Reverting to avoid lockout..."
        rollback
        return 1
    fi
}

status() {
    if systemctl is-active --quiet usbguard 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying the Boarding Party Defense..."
    if ! systemctl is-active --quiet usbguard; then
        log_error "USBGuard service is not active."
        return 1
    fi
    if [ ! -f "$RULES_FILE" ]; then
        log_error "USBGuard rules file missing."
        return 1
    fi
    log_info "USBGuard verified successfully."
    return 0
}

run_task() {
    log_info "Updating the Boarding Party's Guest List (New Whitelist)..."
    # Back up the old ones first
    cp "$RULES_FILE" "${RULES_FILE}.$(date +%Y%m%d_%H%M%S).bak"
    usbguard generate-policy > "$RULES_FILE"
    chmod 600 "$RULES_FILE"
    systemctl restart usbguard
    log_info "New ruleset generated and applied."
}

view_reports() {
    log_info "Fetching the Guest List (Current USB Rules)..."
    usbguard list-devices > /tmp/usb_report.txt
    whiptail --title "The Boarding List (USB Devices)" --textbox /tmp/usb_report.txt 25 80
    rm /tmp/usb_report.txt
}

rollback() {
    log_step "The Boarding Party Defense: Abandoning defenses"
    log_info "Stopping and disabling USBGuard..."
    systemctl disable --now usbguard 2>/dev/null || true
    
    # Restore backups if they exist
    if [ -f "$RULES_BAK" ]; then
        cp "$RULES_BAK" "$RULES_FILE"
        log_info "Restored original USBGuard rules."
    else
        rm -f "$RULES_FILE"
    fi

    if [ -f "$USBGUARD_BAK" ]; then
        cp "$USBGUARD_BAK" "$USBGUARD_CONF"
        log_info "Restored original USBGuard configuration."
    fi

    log_info "USBGuard rollback complete."
}
