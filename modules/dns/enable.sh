#!/bin/bash
# DNS Guard - Enable Unbound with DoH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../core/policy.sh"

echo "Configuring Unbound DNS with DoH..."

# Request approval
request_approval "dns_enable" "Configure Unbound with DNS-over-HTTPS" || exit 1

# Configure Unbound
cat > /etc/unbound/unbound.conf.d/pbp-doh.conf << 'EOF'
server:
    interface: 127.0.0.1
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 127.0.0.0/8 allow
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    prefetch: yes
    
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
EOF

# Lock resolv.conf
cat > /etc/resolv.conf << 'EOF'
# PBP DNS Guard - Managed by Unbound
nameserver 127.0.0.1
options edns0 trust-ad
EOF

chattr +i /etc/resolv.conf

# Disable NetworkManager DNS management
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/pbp-no-dns.conf << 'EOF'
[main]
dns=none
systemd-resolved=false
EOF

# Restart services
systemctl restart NetworkManager 2>/dev/null || true
systemctl restart unbound
systemctl enable unbound

echo "✅ DNS Guard enabled - Authority: Unbound"
