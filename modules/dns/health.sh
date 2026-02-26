#!/bin/bash
set -euo pipefail

# Check systemd-resolved service
if ! systemctl is-active systemd-resolved &>/dev/null; then
    echo "systemd-resolved not running"
    exit 1
fi

# Test DNS resolution
if ! resolvectl query google.com &>/dev/null; then
    echo "DNS resolution failed"
    exit 1
fi

exit 0
