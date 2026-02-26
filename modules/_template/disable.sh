#!/bin/bash
# Module Disable Hook Template

set -euo pipefail

echo "Disabling example module..."

# Stop services
# systemctl stop example.service
# systemctl disable example.service

# Revert security settings
# sysctl -w net.example.setting=0

echo "Module disabled"
exit 0
