#!/bin/bash
# run.sh for system module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/system"
mkdir -p "$REPORT_DIR"

echo "1. Applying Kernel Sysctl Hardening..."
sudo tee /etc/sysctl.d/99-pbp-hardening.conf > /dev/null << EOF
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Logging of martians
net.ipv4.conf.all.log_martians = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-pbp-hardening.conf

echo "2. Scuttling Risky Services..."
for srv in avahi-daemon cups bluetooth; do
    sudo systemctl disable --now $srv 2>/dev/null || true
done

echo "3. Securing SSH Rigging..."
if [ -f /etc/ssh/sshd_config ]; then
    sudo sed -i 's/^[# ]*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null || true
fi

{
    echo "--- System Hardening Compliance Report: $TIMESTAMP ---"
    echo -e "
[Kernel Hardening]"
    sysctl net.ipv4.tcp_syncookies
    sysctl net.ipv4.conf.all.rp_filter
    echo -e "
[Service Status]"
    for srv in avahi-daemon cups bluetooth; do
        echo -n "$srv: "
        systemctl is-active $srv || echo "inactive (SECURED)"
    done
    echo -e "
[SSH Posture]"
    grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config
} > "$REPORT_DIR/compliance_$TIMESTAMP.txt"

echo "System hardening pack complete."
