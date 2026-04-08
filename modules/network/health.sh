#!/bin/bash
set -euo pipefail

is_active_service() {
    local svc="$1"
    if command -v systemctl &>/dev/null && systemctl is-active "$svc" &>/dev/null; then
        return 0
    fi
    if pgrep -x "$svc" &>/dev/null; then
        return 0
    fi
    return 1
}

if ! command -v nft &>/dev/null; then
    echo "nft command not found"
    exit 1
fi

ruleset="$(nft list ruleset 2>/dev/null || true)"

# Check if any nftables rules are loaded at all.
if [[ -z "${ruleset//[[:space:]]/}" ]]; then
    echo "No firewall rules loaded"
    exit 1
fi

# Require inbound filtering presence, regardless of which service manages it.
if ! grep -qE "hook[[:space:]]+input|chain[[:space:]]+input" <<< "$ruleset"; then
    echo "No input filtering chain detected in nftables ruleset"
    exit 1
fi

# Keep visibility when rules are externally managed.
if ! is_active_service nftables; then
    echo "nftables service not active (ruleset appears externally managed)"
fi

# Test network connectivity
if ! ping -c1 -W2 1.1.1.1 &>/dev/null; then
    echo "Network connectivity lost"
    exit 1
fi

exit 0
