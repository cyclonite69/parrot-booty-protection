#!/bin/bash
# 05_dns_harden.sh - DNS Hardening Stack Module
# DESCRIPTION: Configures Unbound for DNS-over-TLS (DoT) and DNSSEC validation.
# DEPENDENCIES: unbound, dnsutils, NetworkManager

MODULE_NAME="dns_harden"
MODULE_DESC="Encrypted DNS (DoT) & DNSSEC"
MODULE_VERSION="1.0"
UNBOUND_CONF="/etc/unbound/unbound.conf"
RESOLV_CONF="/etc/resolv.conf"
NM_CONF_DIR="/etc/NetworkManager/conf.d"

install() {
    log_info "Installing Unbound for DoT..."
    
    # 1. Install Unbound and Utils
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y unbound unbound-anchor dnsutils

    # 2. Configure Unbound (Backup first)
    if [ ! -f "${UNBOUND_CONF}.bak" ]; then
        cp "${UNBOUND_CONF}" "${UNBOUND_CONF}.bak"
    fi

    cat << EOF > "${UNBOUND_CONF}"
server:
    verbosity: 0
    interface: 127.0.0.1
    interface: ::1
    port: 53
    do-ip4: yes
    do-ip6: yes
    do-udp: yes
    do-tcp: yes
    do-daemonize: yes

    # Access Control - Only allow localhost
    access-control: 127.0.0.0/8 allow
    access-control: 0.0.0.0/0 refuse
    access-control: ::1 allow
    access-control: ::0/0 refuse

    # Privacy
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    rrset-roundrobin: yes

    # DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    val-permissive-mode: no

    # Cache
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes

    # SSL Certs
    tls-cert-bundle: "/etc/ssl/certs/ca-certificates.crt"

forward-zone:
    name: "."
    forward-tls-upstream: yes
    # Cloudflare DoT
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
    # Quad9 DoT
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 149.112.112.112@853#dns.quad9.net
EOF

    # 3. Configure NetworkManager to ignore DNS
    log_info "Disabling NetworkManager DNS management..."
    mkdir -p "${NM_CONF_DIR}"
    echo -e "[main]
dns=none" > "${NM_CONF_DIR}/90-dns-hardening.conf"

    # 4. Configure resolv.conf
    log_info "Setting localhost as primary resolver..."
    chattr -i "${RESOLV_CONF}" 2>/dev/null || true
    echo "nameserver 127.0.0.1" > "${RESOLV_CONF}"
    # Make immutable to prevent overwrites
    chattr +i "${RESOLV_CONF}"

    # 5. Restart Services
    systemctl restart unbound
    systemctl restart NetworkManager

    sleep 5
    
    if verify; then
        log_info "DNS Hardening applied successfully."
        return 0
    else
        log_error "DNS Hardening verification failed."
        rollback
        return 1
    fi
}

status() {
    if lsattr "${RESOLV_CONF}" 2>/dev/null | grep -q -- "----i---------"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check if unbound is running
    if ! systemctl is-active --quiet unbound; then
        return 1
    fi
    
    # Check if resolv.conf points to localhost
    if ! grep -q "127.0.0.1" "${RESOLV_CONF}"; then
        return 1
    fi
    
    # Check if resolution works (Cloudflare)
    if dig +short google.com @127.0.0.1 >/dev/null; then
        return 0
    fi
    return 1
}

rollback() {
    log_info "Rolling back DNS Hardening..."
    
    # Remove Immutable flag
    chattr -i "${RESOLV_CONF}" 2>/dev/null
    
    # Remove NetworkManager override
    rm "${NM_CONF_DIR}/90-dns-hardening.conf" 2>/dev/null
    
    # Restore Unbound Config
    if [ -f "${UNBOUND_CONF}.bak" ]; then
        cp "${UNBOUND_CONF}.bak" "${UNBOUND_CONF}"
        log_info "Restored Unbound config from backup."
    fi
    
    # Restart NM to pick up DHCP DNS again
    systemctl restart NetworkManager
    log_info "NetworkManager restarted. DHCP DNS should resume."
}
