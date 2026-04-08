#!/bin/bash
set -euo pipefail

echo "Configuring security log rotation..."

mkdir -p /var/log/pbp

cat > /etc/logrotate.d/pbp-security << 'EOF'
/var/log/pbp/*.log {
    rotate 14
    daily
    missingok
    notifempty
    compress
    delaycompress
    create 0640 root adm
}
EOF

echo "Logs module enabled"
