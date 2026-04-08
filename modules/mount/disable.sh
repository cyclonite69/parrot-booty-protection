#!/bin/bash
set -euo pipefail

echo "Disabling mount hardening..."

rm -f /etc/sysctl.d/99-pbp-mount.conf
sysctl --system >/dev/null 2>&1 || true

echo "Mount hardening disabled"
