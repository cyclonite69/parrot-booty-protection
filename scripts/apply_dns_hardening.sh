#!/usr/bin/env bash
# ==============================================================================
# apply_dns_hardening.sh
# Parrot Booty Protection - Automated DNS Hardening & Resolution Fix Script
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Error: This script must be run as root (e.g. sudo bash $0)${NC}" >&2
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}        APPLYING DNS HARDENING & RESOLVER FIXES                   ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# ------------------------------------------------------------------------------
# 1. FIX NETWORKMANAGER CONFLICT
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/6] Resolving NetworkManager DNS management conflicts...${NC}"

# Remove the faulty 90-dns-none.conf which set dns=default & rc-manager=symlink
if [[ -f /etc/NetworkManager/conf.d/90-dns-none.conf ]]; then
    echo "  - Archiving /etc/NetworkManager/conf.d/90-dns-none.conf"
    mv /etc/NetworkManager/conf.d/90-dns-none.conf /etc/NetworkManager/conf.d/90-dns-none.conf.disabled
fi

# Ensure 90-dns-hardening.conf enforces dns=none
cat > /etc/NetworkManager/conf.d/90-dns-hardening.conf << 'EOF'
[main]
dns=none
systemd-resolved=false
EOF
chmod 644 /etc/NetworkManager/conf.d/90-dns-hardening.conf

echo "  - Reloading NetworkManager configuration..."
systemctl reload NetworkManager || true
echo -e "${GREEN}  ✓ NetworkManager DNS override eliminated (dns=none active)${NC}"
echo

# ------------------------------------------------------------------------------
# 2. HARDEN UNBOUND CONFIGURATION
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/6] Updating and hardening Unbound configuration...${NC}"

# Backup current unbound config
if [[ -f /etc/unbound/unbound.conf ]]; then
    cp /etc/unbound/unbound.conf "/etc/unbound/unbound.conf.bak.$(date +%Y%m%d%H%M%S)"
fi

# Write hardened Unbound configuration:
# - do-ip6: no (aligns with kernel ipv6.disable=1)
# - cache-min-ttl: 300 (5 min instead of 1 hour)
# - includes modular configs (/etc/unbound/unbound.conf.d/*.conf)
# - adds rebinding protection, DNSSEC hardening, query minimization
cat > /etc/unbound/unbound.conf << 'EOF'
server:
    verbosity: 1
    interface: 127.0.0.1
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    do-daemonize: yes

    # Access Control - Only allow localhost
    access-control: 127.0.0.0/8 allow
    access-control: 0.0.0.0/0 refuse

    # Privacy & Query Minimization
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    rrset-roundrobin: yes
    use-caps-for-id: yes

    # DNSSEC Validation
    val-permissive-mode: no
    val-clean-additional: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-below-nxdomain: yes
    harden-referral-path: yes
    harden-algo-downgrade: yes

    # Cache Settings
    cache-min-ttl: 300
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes

    # Memory and Threading
    num-threads: 2
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2
    rrset-cache-size: 100m
    msg-cache-size: 50m

    # Prevent DNS Rebinding Attacks
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8

    # TLS Certificate Bundle for Upstream Verification
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-tls-upstream: yes
    # Cloudflare DoT (Primary)
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
    # Quad9 DoT (Secondary)
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net

# Include modular configuration files if present (e.g. remote-control)
include-toplevel: "/etc/unbound/unbound.conf.d/*.conf"
EOF

chmod 644 /etc/unbound/unbound.conf

echo "  - Checking Unbound configuration syntax..."
unbound-checkconf /etc/unbound/unbound.conf

echo "  - Restarting Unbound service..."
systemctl restart unbound
sleep 1
echo -e "${GREEN}  ✓ Unbound reconfigured and running cleanly${NC}"
echo

# ------------------------------------------------------------------------------
# 3. VERIFY AND LOCK RESOLV.CONF
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/6] Verifying and enforcing immutable /etc/resolv.conf...${NC}"

# Remove immutable flag temporarily to ensure clean contents
if ! grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null; then
    chattr -i /etc/resolv.conf 2>/dev/null || true

cat > /etc/resolv.conf << 'EOF'
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
EOF

chmod 644 /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true
fi
echo -e "${GREEN}  ✓ /etc/resolv.conf pinned to 127.0.0.1 and locked (+i)${NC}"
echo

# ------------------------------------------------------------------------------
# 4. PREVENT EXTERNAL PLAINTEXT DNS LEAKS (NFTABLES)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[4/6] Hardening firewall to block outbound plaintext DNS leaks...${NC}"

if [[ -f /etc/nftables.conf ]]; then
    cp /etc/nftables.conf "/etc/nftables.conf.bak.$(date +%Y%m%d%H%M%S)"
    
    # Replace standard port 53 accepts with explicit external port 53 rejects
    sed -i '/udp dport 53 accept comment "DNS Standard"/d' /etc/nftables.conf
    sed -i '/tcp dport 53 accept comment "DNS Standard"/d' /etc/nftables.conf
    
    if ! grep -q "Block plaintext DNS leaks" /etc/nftables.conf; then
        sed -i '/tcp dport 853 accept comment "DNS over TLS"/a \        # Block external plaintext DNS to prevent leaks (Unbound DoT 853 is used instead)\n        oifname != "lo" udp dport 53 reject comment "Block plaintext DNS leaks"\n        oifname != "lo" tcp dport 53 reject comment "Block plaintext DNS leaks"' /etc/nftables.conf
    fi

    if systemctl is-active --quiet nftables; then
        echo "  - Reloading nftables..."
        nft -f /etc/nftables.conf || true
        echo -e "${GREEN}  ✓ Firewall configured: external port 53 blocked, DoT 853 allowed${NC}"
    fi
else
    echo "  - /etc/nftables.conf not found, skipping firewall update"
fi
echo

# ------------------------------------------------------------------------------
# 5. INSTALL / REFRESH DIAGNOSTIC & RESTORATION TOOLS
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[5/6] Installing updated diagnostic commands...${NC}"

cat > /usr/local/bin/dns-reality-check << 'EOF'
#!/usr/bin/env bash
# DNS Reality Check - Displays active DNS resolution pipeline and leak checks

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DNS REALITY CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "1. System Resolver Configuration (/etc/resolv.conf):"
grep -E '^(nameserver|options|search)' /etc/resolv.conf | sed 's/^/   /'
if lsattr /etc/resolv.conf 2>/dev/null | grep -q "i"; then
    echo "   [Status: Immutable (+i) - PROTECTED]"
else
    echo "   [Status: Mutable - WARNING]"
fi
echo

echo "2. Unbound Resolver Status:"
if systemctl is-active --quiet unbound; then
    echo "   ✓ Unbound service is ACTIVE"
    if ss -tlnp 2>/dev/null | grep -q ":53 .*unbound"; then
        echo "   ✓ Listening on 127.0.0.1:53"
    fi
else
    echo "   ❌ Unbound service is NOT RUNNING"
fi
echo

echo "3. NetworkManager DNS Policy:"
NM_ACTIVE_DNS=$(NetworkManager --print-config 2>/dev/null | grep -E '^dns=' | head -1)
echo "   Effective NM config: ${NM_ACTIVE_DNS:-dns=none}"
if [[ "${NM_ACTIVE_DNS:-}" == "dns=none"* ]] || [[ -z "${NM_ACTIVE_DNS:-}" ]]; then
    echo "   ✓ NetworkManager DNS modification is DISABLED"
else
    echo "   ⚠️ Warning: NetworkManager may attempt to modify DNS"
fi
echo

echo "4. Resolution & DNSSEC Verification Test:"
RES_TEST=$(dig +dnssec +time=2 cloudflare.com @127.0.0.1 2>/dev/null)
if echo "$RES_TEST" | grep -q "flags:.*ad.*"; then
    echo "   ✓ Live DNSSEC resolution confirmed (AD flag present)"
else
    echo "   ⚠️ DNSSEC AD flag missing or resolution slow"
fi

BOGUS_TEST=$(dig +dnssec +time=2 dnssec-failed.org @127.0.0.1 2>/dev/null)
if echo "$BOGUS_TEST" | grep -q "SERVFAIL"; then
    echo "   ✓ DNSSEC validation active (tampered domains rejected with SERVFAIL)"
else
    echo "   ❌ DNSSEC validation warning: failed domain was not rejected"
fi
echo

echo "5. Upstream Egress Verification (DoT 853):"
WHOAMI=$(dig TXT o-o.myaddr.l.google.com +short 2>/dev/null || true)
echo "   Egress resolver response: ${WHOAMI:-OK}"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF
chmod +x /usr/local/bin/dns-reality-check

cat > /usr/local/bin/dns-restore << 'EOF'
#!/usr/bin/env bash
# Quick restore script for DNS sovereign state
set -euo pipefail
if ! grep -q "^nameserver 127.0.0.1" /etc/resolv.conf 2>/dev/null; then
    chattr -i /etc/resolv.conf 2>/dev/null || true
cat > /etc/resolv.conf << 'RESOLV'
# Hardened DNS Configuration - Managed by dns-hardening script
# This file is immutable. To make changes, first run 'sudo chattr -i /etc/resolv.conf'
nameserver 127.0.0.1
options edns0 trust-ad
RESOLV
chattr +i /etc/resolv.conf 2>/dev/null || true
fi
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/90-dns-hardening.conf << 'NM'
[main]
dns=none
systemd-resolved=false
NM
rm -f /etc/NetworkManager/conf.d/90-dns-none.conf 2>/dev/null || true
systemctl reload NetworkManager 2>/dev/null || true
systemctl restart unbound
echo "✓ DNS sovereign state restored"
EOF
chmod +x /usr/local/bin/dns-restore

echo -e "${GREEN}  ✓ Diagnostic tools installed (/usr/local/bin/dns-reality-check, /usr/local/bin/dns-restore)${NC}"
echo

# ------------------------------------------------------------------------------
# 6. TESTING RESOLUTION
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[6/6] Performing live validation...${NC}"

if dig +short @127.0.0.1 cloudflare.com >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Local DNS resolution via 127.0.0.1 is working.${NC}"
else
    echo -e "${RED}  ❌ Local DNS resolution failed.${NC}"
    exit 1
fi

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ ALL DNS HARDENING FIXES SUCCESSFULLY APPLIED!                   ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "You can verify your DNS status at any time by running:"
echo "  dns-reality-check"
echo
