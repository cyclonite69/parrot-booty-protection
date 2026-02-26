#!/bin/bash
# 05_dns_harden.sh - DNS Hardening Stack Module
# DESCRIPTION: Configures Unbound for DNS-over-TLS (DoT) and DNSSEC validation.
# DEPENDENCIES: unbound, dnsutils, NetworkManager

set -euo pipefail # Fail fast on errors

MODULE_NAME="dns_harden"
MODULE_DESC="Encrypted DNS (DoT) & DNSSEC"
MODULE_VERSION="1.0"
UNBOUND_CONF="/etc/unbound/unbound.conf"
UNBOUND_CONF_BAK="/etc/unbound/unbound.conf.bak"
RESOLV_CONF="/etc/resolv.conf"
RESOLV_CONF_BAK="/etc/resolv.conf.bak"
NM_CONF_DIR="/etc/NetworkManager/conf.d"
NM_OVERRIDE_FILE="${NM_CONF_DIR}/90-dns-hardening.conf"

view_reports() {
    log_info "Fetching Unbound service status..."
    systemctl status unbound --no-pager > /tmp/unbound_report.txt
    whiptail --title "Unbound Status Report" --textbox /tmp/unbound_report.txt 25 80
    rm /tmp/unbound_report.txt
}

install() {
    log_step "Installing DNS Hardening"
    
    log_info "1. Installing Unbound and DNS utilities..."
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y unbound unbound-anchor dnsutils
    log_info "Unbound and DNS utilities installed."

    log_info "2. Configuring Unbound (backing up current config to $UNBOUND_CONF_BAK)..."
    if [ ! -f "$UNBOUND_CONF_BAK" ]; then
        cp "${UNBOUND_CONF}" "${UNBOUND_CONF_BAK}"
        log_info "Original Unbound config backed up."
    else
        log_warn "Unbound backup already exists. Skipping new backup."
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
    log_info "Unbound configuration written to $UNBOUND_CONF."
    
    log_info "Running unbound-anchor for DNSSEC trust anchor..."
    unbound-anchor -a /var/lib/unbound/root.key || log_warn "unbound-anchor failed. DNSSEC might not work."

    log_info "3. Configuring NetworkManager to ignore DNS..."
    mkdir -p "${NM_CONF_DIR}"
    echo -e "[main]\ndns=none" | tee "${NM_OVERRIDE_FILE}"
    log_info "NetworkManager override written to $NM_OVERRIDE_FILE."

    log_info "4. Configuring /etc/resolv.conf to use local Unbound resolver..."
    # Backup resolv.conf first
    if [ -f "$RESOLV_CONF" ] && [ ! -f "$RESOLV_CONF_BAK" ]; then
        cp "$RESOLV_CONF" "$RESOLV_CONF_BAK"
        log_info "Original $RESOLV_CONF backed up."
    fi

    # Ensure resolv.conf is mutable before writing
    chattr -i "${RESOLV_CONF}" 2>/dev/null || true
    echo "nameserver 127.0.0.1" | tee "${RESOLV_CONF}"
    # Make immutable to prevent overwrites by other services
    chattr +i "${RESOLV_CONF}"
    log_info "$RESOLV_CONF set to 127.0.0.1 and made immutable."

    log_info "5. Restarting Unbound and NetworkManager services..."
    systemctl restart unbound
    systemctl restart NetworkManager
    log_info "Unbound and NetworkManager services restarted."

    sleep 5 # Give services time to start

    if verify; then
        log_info "DNS Hardening applied successfully."
        return 0
    else
        log_error "DNS Hardening verification failed."
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
    log_info "Verifying DNS hardening..."
    # Check if unbound is running
    if ! systemctl is-active --quiet unbound; then
        log_warn "Unbound service is not active. Waiting 5 seconds..."
        sleep 5
        if ! systemctl is-active --quiet unbound; then
            log_error "Unbound service failed to start."
            return 1
        fi
    fi
    log_info "Unbound service is active."
    
    # Check if resolv.conf points to localhost and is immutable
    if ! grep -q "nameserver 127.0.0.1" "${RESOLV_CONF}"; then
        log_error "$RESOLV_CONF does not contain 'nameserver 127.0.0.1'."
        return 1
    fi
    log_info "$RESOLV_CONF points to localhost."

    if ! lsattr "${RESOLV_CONF}" | grep -q -- "----i---------"; then
        log_error "$RESOLV_CONF is not immutable."
        return 1
    fi
    log_info "$RESOLV_CONF is immutable."

    # Check if NetworkManager override is in place (any file in conf.d with dns=none)
    if ! grep -r "dns=none" "${NM_CONF_DIR}" --include="*.conf" >/dev/null; then
        log_error "No NetworkManager override found for dns=none in ${NM_CONF_DIR}."
        return 1
    fi
    log_info "NetworkManager override for dns=none is active."

    # Test DNS resolution with retries
    local success=1
    for i in {1..3}; do
        if dig +short google.com @127.0.0.1 >/dev/null; then
            success=0
            break
        fi
        log_warn "DNS resolution attempt $i failed. Retrying..."
        sleep 2
    done

    if [ $success -ne 0 ]; then
        log_error "DNS resolution via Unbound (127.0.0.1) failed for google.com."
        return 1
    fi
    log_info "DNS resolution via Unbound (127.0.0.1) successful for google.com."

    log_info "DNS hardening verified successfully."
    return 0
}

rollback() {
    log_step "Rolling back DNS Hardening"
    log_info "Rolling back DNS Hardening..."
    
    # Make resolv.conf mutable again
    chattr -i "${RESOLV_CONF}" 2>/dev/null || true
    log_info "$RESOLV_CONF made mutable."

    # Restore original resolv.conf or point to defaults
    if [ -f "$RESOLV_CONF_BAK" ]; then
        cp "$RESOLV_CONF_BAK" "$RESOLV_CONF"
        log_info "Original $RESOLV_CONF restored from backup."
    else
        log_warn "No resolv.conf backup found. Pointing to default DNS servers (Cloudflare/Google)."
        echo "nameserver 1.1.1.1" > "${RESOLV_CONF}"
        echo "nameserver 8.8.8.8" >> "${RESOLV_CONF}"
    fi
    
    # Remove NetworkManager override
    rm "${NM_OVERRIDE_FILE}" 2>/dev/null || true
    log_info "Removed NetworkManager override file $NM_OVERRIDE_FILE."
    
    # Restart NetworkManager to pick up DHCP DNS again
    log_info "Restarting NetworkManager to re-enable DHCP DNS..."
    systemctl restart NetworkManager
    log_info "NetworkManager restarted."

    # Stop and disable Unbound
    log_info "Stopping and disabling Unbound service..."
    systemctl stop unbound 2>/dev/null || true
    systemctl disable unbound 2>/dev/null || true
    log_info "Unbound service stopped and disabled."
    
    # Restore original unbound.conf
    if [ -f "$UNBOUND_CONF_BAK" ]; then
        cp "$UNBOUND_CONF_BAK" "$UNBOUND_CONF"
        log_info "Original Unbound config restored from backup."
    fi

    log_info "DNS Hardening rollback complete. System should now use DHCP DNS."
}
