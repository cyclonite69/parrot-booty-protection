#!/bin/bash
# 06_firewall_harden.sh - Firewall (Nftables Baseline) Module
# DESCRIPTION: Configures a strict, stateful nftables firewall with default deny inbound.
# DEPENDENCIES: nftables, systemd

MODULE_NAME="firewall_harden"
MODULE_DESC="Zero-Trust Firewall (Nftables)"
MODULE_VERSION="1.0"
NFT_CONF="/etc/nftables.conf"
NFT_BAK="/etc/nftables.conf.bak"
NFT_DYNAMIC_DIR="/etc/nftables.d"

install() {
    log_info "Applying Firewall Hardening (Nftables)..."
    
    # 1. Install Nftables
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y nftables

    # 2. Setup Dynamic Directory
    mkdir -p "$NFT_DYNAMIC_DIR"
    # Ensure it's empty if we're doing a fresh baseline, or keep it? 
    # For a fresh install, we want to ensure only active services have rules.
    # We'll leave existing files for now to avoid breaking other modules.

    # 3. Backup
    if [ ! -f "$NFT_BAK" ]; then
        if [ -f "$NFT_CONF" ]; then
            cp "$NFT_CONF" "$NFT_BAK"
        fi
    fi

    # 4. Create Ruleset
    cat << EOF > "$NFT_CONF"
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Allow loopback
        iif "lo" accept

        # Allow established and related connections
        ct state established,related accept

        # Allow ICMP (Ping)
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Allow SSH (Port 22)
        tcp dport 22 accept
        
        # --- Modular Service Rules ---
        # Include rules for enabled services
        include "$NFT_DYNAMIC_DIR/*.nft"
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;

        # NTS Secure Time
        udp dport 123 accept comment "NTS secure time"
        tcp dport 4460 accept comment "NTS key exchange"
        
        # DNS
        tcp dport 853 accept comment "DNS over TLS"
        udp dport 53 accept comment "DNS Standard"
        tcp dport 53 accept comment "DNS Standard"
        
        # HTTP/HTTPS
        tcp dport 80 accept
        tcp dport 443 accept
        
        # SSH Outbound
        tcp dport 22 accept
    }
}
EOF

    # Ensure the include doesn't crash if the directory is empty
    # nftables requires at least one file or a valid wildcard. 
    # We'll create a dummy file to ensure it starts.
    touch "$NFT_DYNAMIC_DIR/baseline.nft"

    # 5. Enable Service
    systemctl enable nftables
    systemctl restart nftables

    if verify; then
        log_info "Firewall rules applied successfully."
        return 0
    else
        log_error "Firewall verification failed. Reverting..."
        rollback
        return 1
    fi
}

status() {
    if nft list ruleset | grep -q "NTS secure time"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    # Check if nftables service is running
    if ! systemctl is-active --quiet nftables; then
        return 1
    fi
    
    # Check if specific rules are present in running config
    if nft list ruleset | grep -q "NTS secure time"; then
        return 0
    fi
    return 1
}

rollback() {
    log_info "Rolling back Firewall..."
    if [ -f "$NFT_BAK" ]; then
        cp "$NFT_BAK" "$NFT_CONF"
        systemctl restart nftables
        log_info "Restored previous firewall config."
    else
        # If no backup, just flush ruleset (allow all) to be safe? Or restore default?
        # Flushing is safest "open" state.
        nft flush ruleset
        log_warn "No backup found. Flushed ruleset (Permissive)."
    fi
}
