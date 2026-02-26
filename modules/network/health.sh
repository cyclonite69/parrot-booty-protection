#!/bin/bash
set -euo pipefail

# Check nftables service
if ! systemctl is-active nftables &>/dev/null; then
    echo "nftables not running"
    exit 1
fi

# Check if rules are loaded
if ! nft list ruleset | grep -q "chain input"; then
    echo "No firewall rules loaded"
    exit 1
fi

# Test network connectivity
if ! ping -c1 -W2 1.1.1.1 &>/dev/null; then
    echo "Network connectivity lost"
    exit 1
fi

exit 0
