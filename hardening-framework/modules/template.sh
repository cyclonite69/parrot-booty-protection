#!/bin/bash
# template.sh - Standard module structure for Hardening Framework
# DESCRIPTION: Basic template for new modules
# DEPENDENCIES: jq, grep, sed

MODULE_NAME="example_module"
MODULE_DESC="Example hardening module"
MODULE_VERSION="1.0"

install() {
    # 1. Check prerequisites
    if ! command -v jq >/dev/null; then
        echo "Error: jq is required"
        return 1
    fi
    
    # 2. Perform hardening
    echo "Applying $MODULE_NAME..."
    
    # Example: Backup config
    if [ -f "/etc/example.conf" ]; then
        cp "/etc/example.conf" "/etc/example.conf.bak"
    fi
    
    # Example: Apply changes
    # echo "security_level=high" >> "/etc/example.conf"
    
    # 3. Verify changes
    if verify; then
        return 0
    else
        echo "Verification failed for $MODULE_NAME"
        rollback
        return 1
    fi
}

status() {
    # Check if hardening is active
    if grep -q "security_level=high" "/etc/example.conf" 2>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Verify the specific configuration applied
    if [ "$(status)" == "active" ]; then
        return 0
    else
        return 1
    fi
}

rollback() {
    echo "Rolling back $MODULE_NAME..."
    
    # Restore backup
    if [ -f "/etc/example.conf.bak" ]; then
        mv "/etc/example.conf.bak" "/etc/example.conf"
        echo "Restored from backup."
    else
        # Or undo specific changes
        # sed -i '/security_level=high/d' "/etc/example.conf"
        echo "No backup found or changes reverted manually."
    fi
    
    # Restart services if needed
    # systemctl restart example
}
