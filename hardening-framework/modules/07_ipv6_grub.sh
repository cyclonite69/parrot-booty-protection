#!/bin/bash
# 07_ipv6_grub.sh - IPv6 Policy Module (GRUB Method)
# DESCRIPTION: Disables IPv6 at the kernel level via GRUB configuration.
# DEPENDENCIES: grub-mkconfig, update-grub

MODULE_NAME="ipv6_grub"
MODULE_DESC="Total IPv6 Removal (GRUB Kernel Flag)"
MODULE_VERSION="1.0"
GRUB_FILE="/etc/default/grub"
GRUB_BAK="/etc/default/grub.bak"

install() {
    log_info "Disabling IPv6 via GRUB kernel parameter..."
    
    # 1. Backup GRUB config
    if [ ! -f "$GRUB_BAK" ]; then
        cp "$GRUB_FILE" "$GRUB_BAK"
    fi

    # 2. Modify GRUB_CMDLINE_LINUX_DEFAULT
    # Check if ipv6.disable=1 already exists
    if grep -q "ipv6.disable=1" "$GRUB_FILE"; then
        log_info "GRUB config already contains ipv6.disable=1"
    else
        # Append to the existing line.
        # This is a bit fragile with sed, but we try to be safe.
        # We look for the line, remove the closing quote, add our flag, and add the quote back.
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/' "$GRUB_FILE"
        log_info "Added ipv6.disable=1 to GRUB default command line."
    fi

    # 3. Update GRUB
    log_info "Updating GRUB bootloader..."
    update-grub

    if verify; then
        log_info "IPv6 Disabled in GRUB config. REBOOT REQUIRED."
        whiptail --msgbox "IPv6 has been disabled in GRUB.

A REBOOT IS REQUIRED for this to take effect." 10 50
        return 0
    else
        log_error "Failed to verify GRUB modification."
        rollback
        return 1
    fi
}

status() {
    if grep -q "ipv6.disable=1" "$GRUB_FILE"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check if the config file has the setting
    if grep -q "ipv6.disable=1" "$GRUB_FILE"; then
        return 0
    fi
    return 1
}

rollback() {
    log_info "Reverting IPv6 GRUB changes..."
    if [ -f "$GRUB_BAK" ]; then
        cp "$GRUB_BAK" "$GRUB_FILE"
        update-grub
        log_info "Restored original GRUB config. Reboot required to re-enable IPv6."
        whiptail --msgbox "IPv6 re-enabled in GRUB.

A REBOOT IS REQUIRED." 10 50
    else
        # Manual fallback
        sed -i 's/ ipv6.disable=1//' "$GRUB_FILE"
        update-grub
        log_warn "Backup not found. Manually removed flag."
    fi
}
