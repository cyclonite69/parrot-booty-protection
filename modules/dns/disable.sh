#!/bin/bash
# DNS Guard - Disable and restore

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../core/policy.sh"

echo "Disabling DNS Guard..."

# Request approval
request_approval "dns_disable" "Disable Unbound DNS enforcement" || exit 1

# Unlock resolv.conf
chattr -i /etc/resolv.conf 2>/dev/null || true

# Stop Unbound
systemctl stop unbound
systemctl disable unbound

# Remove NetworkManager override
rm -f /etc/NetworkManager/conf.d/pbp-no-dns.conf
systemctl restart NetworkManager 2>/dev/null || true

echo "✅ DNS Guard disabled"
