#!/bin/bash
set -euo pipefail

echo "Configuring Fail2Ban..."

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
EOF

if command -v systemctl &>/dev/null; then
  systemctl enable fail2ban
  systemctl restart fail2ban
fi

echo "Fail2Ban enabled"
