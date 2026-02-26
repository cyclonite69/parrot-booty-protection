#!/bin/bash
set -euo pipefail

echo "Disabling DNS over TLS..."

# Restore default configuration
cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
#DNS=
#FallbackDNS=
#DNSOverTLS=no
#DNSSEC=allow-downgrade
EOF

systemctl restart systemd-resolved

echo "DNS module disabled"
