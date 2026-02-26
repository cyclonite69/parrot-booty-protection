#!/bin/bash
# 02_ssh_harden.sh - SSH Hardening Module
# DESCRIPTION: Secures the SSH daemon configuration.
# DEPENDENCIES: sshd, sed

set -euo pipefail # Fail fast on errors

MODULE_NAME="ssh_harden"
MODULE_DESC="SSH Hardening"
MODULE_VERSION="1.0"
CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak"

install() {
    log_step "Installing SSH Hardening"
    log_info "Backing up SSH configuration to $BACKUP_FILE..."
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_FILE"
        log_info "Original SSH config backed up."
    else
        log_warn "SSH backup already exists. Skipping new backup."
    fi

    log_info "Applying SSH hardening rules to $CONFIG_FILE..."
    
    # Use sed to modify the configuration file in place
    # Function to update or add a config line
    update_or_add_config() {
        local key="$1"
        local value="$2"
        if grep -q "^[[:space:]]*$key" "$CONFIG_FILE"; then
            sed -i "s/^[[:space:]]*$key.*/$key $value/" "$CONFIG_FILE"
            log_info "Updated '$key' to '$value'."
        else
            echo "$key $value" >> "$CONFIG_FILE"
            log_info "Added '$key' with value '$value'."
        fi
    }

    update_or_add_config "PermitRootLogin" "no"
    update_or_add_config "PasswordAuthentication" "no"
    update_or_add_config "PermitEmptyPasswords" "no"
    update_or_add_config "X11Forwarding" "no"
    update_or_add_config "MaxAuthTries" "3"
    update_or_add_config "LoginGraceTime" "60"

    # Ensure Protocol 2 only
    if ! grep -q "^[[:space:]]*Protocol 2" "$CONFIG_FILE"; then
         sed -i '/^#[[:space:]]*Protocol/a Protocol 2' "$CONFIG_FILE" # Add after commented out Protocol
         if ! grep -q "^[[:space:]]*Protocol 2" "$CONFIG_FILE"; then # If still not there, add to end
             echo "Protocol 2" >> "$CONFIG_FILE"
         fi
         log_info "Ensured 'Protocol 2' is set."
    fi
    
    # Disable weak ciphers/MACs (Example configuration - adjust for compatibility)
    # KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
    # Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    # MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

    log_info "Testing SSH configuration syntax..."
    if sshd -t -f "$CONFIG_FILE"; then
        log_info "SSH configuration syntax is valid. Restarting SSH service..."
        if systemctl list-unit-files | grep -q "^ssh.service"; then
            systemctl restart ssh
        else
            systemctl restart sshd
        fi
        log_info "SSH service restarted."
    else
        log_error "SSH configuration test failed! Reverting changes..."
        rollback
        return 1
    fi

    if verify; then
        log_info "SSH Hardening applied successfully."
        return 0
    else
        log_error "SSH Hardening failed verification."
        return 1
    fi
}

status() {
    if grep -q "PermitRootLogin no" "$CONFIG_FILE" 2>/dev/null && \
       grep -q "PasswordAuthentication no" "$CONFIG_FILE" 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    log_info "Verifying SSH hardening..."
    # Check current runtime configuration
    # Note: sshd -T validates config syntax and outputs effective configuration
    # We use sudo -n (non-interactive) just in case, though the script should run as root
    if sshd -T 2>/dev/null | grep -q "permitrootlogin no"; then
        log_info "PermitRootLogin is 'no' (verified via sshd -T)."
        return 0
    elif grep -q "^[[:space:]]*PermitRootLogin[[:space:]]*no" "$CONFIG_FILE"; then
        log_info "PermitRootLogin is 'no' (verified via config file)."
        return 0
    else
        log_error "PermitRootLogin is NOT 'no'."
        return 1
    fi
}

rollback() {
    log_step "Rolling back SSH Hardening"
    log_info "Rolling back SSH configuration..."
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        log_info "Restored original SSH config from backup. Restarting SSH..."
        if systemctl list-unit-files | grep -q "^ssh.service"; then
            systemctl restart ssh
        else
            systemctl restart sshd
        fi
        log_info "SSH service restarted."
    else
        log_warn "Backup file not found ($BACKUP_FILE). Manual intervention may be required."
        log_info "Attempting to revert common changes..."
        sed -i '/PermitRootLogin no/d' "$CONFIG_FILE"
        sed -i '/PasswordAuthentication no/d' "$CONFIG_FILE"
        sed -i '/PermitEmptyPasswords no/d' "$CONFIG_FILE"
        sed -i '/X11Forwarding no/d' "$CONFIG_FILE"
        sed -i '/MaxAuthTries 3/d' "$CONFIG_FILE"
        sed -i '/LoginGraceTime 60/d' "$CONFIG_FILE"
        sed -i '/Protocol 2/d' "$CONFIG_FILE" # Remove if added
        systemctl restart sshd || true # Attempt restart, ignore if it fails
    fi
    log_info "SSH rollback complete."
}
