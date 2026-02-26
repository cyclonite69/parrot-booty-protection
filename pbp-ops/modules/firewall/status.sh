#!/bin/bash
# status.sh for firewall module
if systemctl is-active --quiet nftables && sudo nft list ruleset | grep -q "policy drop"; then
    echo "active"
else
    echo "inactive"
fi
