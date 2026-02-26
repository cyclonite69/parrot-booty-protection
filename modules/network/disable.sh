#!/bin/bash
set -euo pipefail

echo "Disabling nftables firewall..."

# Flush all rules
nft flush ruleset

# Stop and disable service
systemctl stop nftables
systemctl disable nftables

echo "Firewall disabled"
