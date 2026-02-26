#!/bin/bash
set -euo pipefail

echo "Configuring NTS time synchronization..."

# Deploy NTS-enabled chrony configuration
cat > /etc/chrony/chrony.conf << 'EOF'
# NTS-authenticated time servers
server time.cloudflare.com iburst nts
server nts.ntp.se iburst nts
server ntppool1.time.nl iburst nts

# Fallback NTP servers (no NTS)
pool 2.debian.pool.ntp.org iburst

# Record drift
driftfile /var/lib/chrony/chrony.drift

# Allow large clock adjustments
makestep 1.0 3

# Enable kernel synchronization
rtcsync

# Log measurements
logdir /var/log/chrony
log measurements statistics tracking

# Security
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
cmdallow 127.0.0.1
cmdallow ::1
EOF

# Restart chrony
systemctl restart chronyd
systemctl enable chronyd

echo "NTS time synchronization enabled"
