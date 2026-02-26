#!/bin/bash
set -euo pipefail

echo "Installing nftables firewall..."

# Remove conflicting firewalls
systemctl stop ufw 2>/dev/null || true
systemctl disable ufw 2>/dev/null || true
apt-get remove -y ufw iptables-persistent 2>/dev/null || true

# Install nftables
apt-get update -qq
apt-get install -y nftables

echo "nftables installed"
