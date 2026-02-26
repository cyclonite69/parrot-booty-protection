#!/bin/bash
# PBP Validation Library

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

validate_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS"
        return 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "parrot" && "$ID_LIKE" != *"debian"* ]]; then
        log_warn "Not running on Parrot OS or Debian-based system"
        log_warn "Detected: ${PRETTY_NAME}"
        return 1
    fi
    
    log_info "OS validated: ${PRETTY_NAME}"
    return 0
}

validate_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required"
        return 1
    fi
    return 0
}

validate_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        return 1
    fi
    return 0
}

validate_disk_space() {
    local required_mb="${1:-100}"
    local available=$(df /var | awk 'NR==2 {print $4}')
    local available_mb=$((available / 1024))
    
    if [[ $available_mb -lt $required_mb ]]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi
    
    return 0
}

validate_network() {
    if ! ping -c1 -W2 1.1.1.1 &>/dev/null; then
        log_warn "Network connectivity check failed"
        return 1
    fi
    return 0
}

pre_flight_check() {
    local failed=0
    
    echo "=== Pre-flight Checks ==="
    
    if validate_os; then
        echo "✓ OS compatibility"
    else
        echo "✗ OS compatibility"
        ((failed++))
    fi
    
    if validate_root; then
        echo "✓ Root privileges"
    else
        echo "✗ Root privileges"
        ((failed++))
    fi
    
    local required_cmds=("jq" "systemctl" "sha256sum")
    for cmd in "${required_cmds[@]}"; do
        if validate_command "$cmd"; then
            echo "✓ Command: $cmd"
        else
            echo "✗ Command: $cmd"
            ((failed++))
        fi
    done
    
    if validate_disk_space 500; then
        echo "✓ Disk space"
    else
        echo "✗ Disk space"
        ((failed++))
    fi
    
    if validate_network; then
        echo "✓ Network connectivity"
    else
        echo "⚠ Network connectivity (non-critical)"
    fi
    
    echo
    
    if [[ $failed -gt 0 ]]; then
        log_error "Pre-flight checks failed: ${failed} issues"
        return 1
    fi
    
    log_info "All pre-flight checks passed"
    return 0
}
