#!/bin/bash
set -euo pipefail

echo "Configuring DNS over TLS..."

# Configure systemd-resolved for DoT
cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=
DNSOverTLS=yes
DNSSEC=yes
DNSStubListener=yes
Cache=yes
EOF

# Ensure resolv.conf points to systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Restart systemd-resolved
systemctl restart systemd-resolved
systemctl enable systemd-resolved

echo "DNS over TLS enabled"
