#!/bin/bash
# PBP Policy Engine - Enforces operator sovereignty

set -euo pipefail

POLICY_FILE="/etc/pbp/policy.yaml"
FALLBACK_POLICY="/opt/pbp/config/policy.yaml"

# Load policy
load_policy() {
    if [[ -f "$POLICY_FILE" ]]; then
        echo "$POLICY_FILE"
    elif [[ -f "$FALLBACK_POLICY" ]]; then
        echo "$FALLBACK_POLICY"
    else
        echo "ERROR: No policy file found" >&2
        exit 1
    fi
}

# Get policy value
get_policy() {
    local key="$1"
    local policy=$(load_policy)
    grep "^${key}:" "$policy" | cut -d: -f2- | xargs
}

# Check if action requires approval
requires_approval() {
    local action="$1"
    local require=$(get_policy "require_operator_confirmation")
    [[ "$require" == "true" ]]
}

# Request operator approval
request_approval() {
    local action="$1"
    local details="$2"
    
    if ! requires_approval "$action"; then
        return 0
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  OPERATOR APPROVAL REQUIRED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Action: $action"
    echo "Details: $details"
    echo ""
    read -p "Approve this change? [y/N]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Action denied by operator"
        return 1
    fi
    
    echo "✅ Action approved by operator"
    return 0
}

# Validate DNS authority
validate_dns_authority() {
    local authority=$(get_policy "dns_authority")
    echo "$authority"
}

# Check if auto changes allowed
allow_auto_changes() {
    local allow=$(get_policy "allow_auto_changes")
    [[ "$allow" == "true" ]]
}

# Export functions
export -f load_policy get_policy requires_approval request_approval validate_dns_authority allow_auto_changes
