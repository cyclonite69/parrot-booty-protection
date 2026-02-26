#!/bin/bash
set -euo pipefail

echo "Disabling audit rules..."

rm -f /etc/audit/rules.d/pbp.rules
systemctl restart auditd

echo "Audit module disabled"
