#!/bin/bash
# 02_ssh_harden.sh - SSH Hardening Module
# DESCRIPTION: Secures the SSH daemon configuration.
# DEPENDENCIES: sshd, sed

MODULE_NAME="ssh_harden"
MODULE_DESC="SSH Hardening"
MODULE_VERSION="1.0"
CONFIG_FILE="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak"

install() {
    log_info "Backing up SSH configuration..."
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_FILE"
    fi

    log_info "Applying SSH hardening..."
    
    # Use sed to modify the configuration file in place
    # Disable root login
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$CONFIG_FILE" || echo "PermitRootLogin no" >> "$CONFIG_FILE"
    
    # Disable password authentication (use keys)
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$CONFIG_FILE" || echo "PasswordAuthentication no" >> "$CONFIG_FILE"
    
    # Disable empty passwords
    sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$CONFIG_FILE" || echo "PermitEmptyPasswords no" >> "$CONFIG_FILE"
    
    # Disable X11 forwarding
    sed -i 's/^X11Forwarding.*/X11Forwarding no/' "$CONFIG_FILE" || echo "X11Forwarding no" >> "$CONFIG_FILE"
    
    # Use Protocol 2 only (usually default, but ensure it)
    if ! grep -q "^Protocol 2" "$CONFIG_FILE"; then
         echo "Protocol 2" >> "$CONFIG_FILE"
    fi
    
    # Restrict allowed users (Example: only current user)
    # AllowUsers $USER (This is risky if the user doesn't exist or is root, so we skip it for safety in this template)
    
    # Set MaxAuthTries
    sed -i 's/^MaxAuthTries.*/MaxAuthTries 3/' "$CONFIG_FILE" || echo "MaxAuthTries 3" >> "$CONFIG_FILE"
    
    # Set LoginGraceTime
    sed -i 's/^LoginGraceTime.*/LoginGraceTime 60/' "$CONFIG_FILE" || echo "LoginGraceTime 60" >> "$CONFIG_FILE"
    
    # Disable weak ciphers/MACs (Example configuration - adjust for compatibility)
    # KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
    # Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
    # MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com

    # Validate configuration before restart
    if sshd -t; then
        log_info "Configuration valid. Restarting SSH service..."
        systemctl restart sshd
    else
        log_error "SSH configuration test failed! Reverting..."
        rollback
        return 1
    fi

    if verify; then
        log_info "SSH Hardening applied successfully."
        return 0
    else
        log_error "SSH Hardening verification failed."
        rollback
        return 1
    fi
}

status() {
    if grep -q "PermitRootLogin no" "$CONFIG_FILE" && grep -q "PasswordAuthentication no" "$CONFIG_FILE"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check current runtime configuration
    # Note: sshd -T validates config syntax and outputs effective configuration
    if sshd -T | grep -q "permitrootlogin no"; then
        return 0
    else
        return 1
    fi
}

rollback() {
    log_info "Rolling back SSH Hardening..."
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        log_info "Restored from backup. Restarting SSH..."
        systemctl restart sshd
    else
        log_warn "Backup file not found. Manual intervention required."
    fi
}
