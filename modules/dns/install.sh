#!/bin/bash
# DNS Guard - Unbound-based DNS with enforcement

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../core/policy.sh"

echo "Installing Unbound DNS resolver..."

# Request approval
request_approval "dns_install" "Install Unbound DNS resolver with DoH" || exit 1

# Install packages
apt-get update -qq
apt-get install -y unbound dns-root-data

# Disable conflicting services
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true

echo "✅ Unbound installed"
