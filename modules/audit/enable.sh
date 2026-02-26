#!/bin/bash
set -euo pipefail

echo "Configuring auditd rules..."

mkdir -p /etc/audit/rules.d

cat > /etc/audit/rules.d/pbp.rules << 'EOF'
# Delete all existing rules
-D

# Buffer size
-b 8192

# Failure mode (1=printk, 2=panic)
-f 1

# Watch critical files
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Watch system binaries
-w /usr/bin/sudo -p x -k privileged
-w /usr/bin/su -p x -k privileged

# Make configuration immutable
-e 2
EOF

systemctl enable auditd
systemctl restart auditd

echo "Audit rules configured"
