#!/bin/bash
# 70_mount_harden.sh - Partition Mounting Hardening
# DESCRIPTION: Reinforces the hull by setting noexec, nosuid, and nodev on temporary partitions.
# DEPENDENCIES: mount, fstab

set -euo pipefail

MODULE_NAME="mount_harden"
MODULE_DESC="Reinforcing the Hull (Mount Flags)"
MODULE_VERSION="1.0"
FSTAB="/etc/fstab"
FSTAB_BAK="/etc/fstab.bak"

install() {
    log_step "Reinforcing the Hull: Partition Hardening"
    
    # 1. Backup fstab
    if [ ! -f "$FSTAB_BAK" ]; then
        cp "$FSTAB" "$FSTAB_BAK"
        log_info "Original fstab backed up to $FSTAB_BAK."
    fi

    # 2. Apply flags to /tmp, /var/tmp, and /dev/shm
    # We check if they are already in fstab or if we need to add/modify them.
    
    update_fstab_option() {
        local mount_point="$1"
        local new_options="$2"
        
        if grep -q "[[:space:]]$mount_point[[:space:]]" "$FSTAB"; then
            log_info "Updating existing entry for $mount_point..."
            # This is a bit complex with sed, so we'll use a safer approach:
            # We assume standard fstab format.
            sed -i "s|^\([^[:space:]]\+[[:space:]]\+$mount_point[[:space:]]\+[^[:space:]]\+[[:space:]]\+\)\([^[:space:]]\+\)|\1\2,$new_options|" "$FSTAB"
            # Remove duplicate options if they existed
            sed -i "s/defaults,defaults/defaults/g" "$FSTAB"
        else
            log_info "Adding new entry for $mount_point..."
            if [ "$mount_point" == "/tmp" ]; then
                echo "tmpfs /tmp tmpfs defaults,$new_options 0 0" >> "$FSTAB"
            elif [ "$mount_point" == "/dev/shm" ]; then
                echo "tmpfs /dev/shm tmpfs defaults,$new_options 0 0" >> "$FSTAB"
            fi
        fi
    }

    # Apply hardening flags
    # noexec: Prevent execution of binaries
    # nosuid: Ignore set-user-identifier or set-group-identifier bits
    # nodev:  Do not interpret character or block special devices
    update_fstab_option "/tmp" "noexec,nosuid,nodev"
    update_fstab_option "/dev/shm" "noexec,nosuid,nodev"

    # 3. Special handling for /var/tmp (bind mount to /tmp is common)
    if ! grep -q "[[:space:]]/var/tmp[[:space:]]" "$FSTAB"; then
        log_info "Bind mounting /var/tmp to /tmp..."
        echo "/tmp /var/tmp none bin,bind,noexec,nosuid,nodev 0 0" >> "$FSTAB"
    fi

    # 4. Remount everything
    log_info "Remounting partitions to apply new flags..."
    mount -o remount /tmp || true
    mount -o remount /dev/shm || true
    mount -o remount /var/tmp || true

    if verify; then
        log_info "Hull reinforced successfully."
        return 0
    else
        log_error "Hull reinforcement failed verification."
        return 1
    fi
}

status() {
    # Check if /tmp has noexec
    if mount | grep "[[:space:]]/tmp[[:space:]]" | grep -q "noexec"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Inspecting the hull planks (Verifying mount flags)..."
    local failed=0
    
    for mp in "/tmp" "/dev/shm" "/var/tmp"; do
        if ! mount | grep "[[:space:]]$mp[[:space:]]" | grep -q "noexec"; then
            log_warn "$mp is missing 'noexec' flag."
            failed=1
        fi
    done

    if [ $failed -eq 0 ]; then
        log_info "All partitions are securely mounted."
        return 0
    else
        return 1
    fi
}

rollback() {
    log_step "Weakening the Hull: Rolling back mount flags"
    if [ -f "$FSTAB_BAK" ]; then
        cp "$FSTAB_BAK" "$FSTAB"
        log_info "Original fstab restored. Remounting to default..."
        mount -o remount /tmp || true
        mount -o remount /dev/shm || true
        mount -o remount /var/tmp || true
    else
        log_warn "No fstab backup found. Manual intervention required."
    fi
}
