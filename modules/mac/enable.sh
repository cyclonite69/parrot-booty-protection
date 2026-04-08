#!/bin/bash
set -euo pipefail

echo "Configuring MAC randomization..."

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/pbp-mac-randomization.conf << 'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

if command -v systemctl &>/dev/null; then
  systemctl restart NetworkManager 2>/dev/null || true
fi

echo "MAC randomization enabled"
