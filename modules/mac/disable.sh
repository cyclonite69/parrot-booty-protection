#!/bin/bash
set -euo pipefail

echo "Disabling MAC randomization..."

rm -f /etc/NetworkManager/conf.d/pbp-mac-randomization.conf

if command -v systemctl &>/dev/null; then
  systemctl restart NetworkManager 2>/dev/null || true
fi

echo "MAC randomization disabled"
