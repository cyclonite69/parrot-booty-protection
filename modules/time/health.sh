#!/bin/bash
set -euo pipefail

# Check chronyd service
if ! systemctl is-active chronyd &>/dev/null; then
    echo "chronyd service not running"
    exit 1
fi

# Check if chrony is synchronized
if ! chronyc tracking &>/dev/null; then
    echo "chrony not responding"
    exit 1
fi

exit 0
