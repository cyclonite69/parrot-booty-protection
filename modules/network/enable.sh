#!/bin/bash
set -euo pipefail

echo "Configuring nftables firewall..."

cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established/related
        ct state established,related accept
        
        # Allow loopback
        iif lo accept
        
        # Drop invalid
        ct state invalid drop
        
        # Allow ICMP
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        
        # Allow SSH
        tcp dport 22 accept
        
        # Log dropped packets
        limit rate 5/minute log prefix "nft-drop: "
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
        
        # Allow established/related
        ct state established,related accept
        
        # Allow loopback
        oif lo accept
    }
}
EOF

# Enable and start nftables
systemctl enable nftables
systemctl restart nftables

echo "Firewall enabled"
