#!/bin/bash
set -euo pipefail

echo "Applying mount safety sysctls..."

cat > /etc/sysctl.d/99-pbp-mount.conf << 'EOF'
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF

sysctl --system >/dev/null 2>&1 || true

echo "Mount hardening enabled"
