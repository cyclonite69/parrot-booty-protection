#!/bin/bash
set -euo pipefail

if ! systemctl is-active auditd &>/dev/null; then
    echo "auditd not running"
    exit 1
fi

if ! auditctl -l &>/dev/null; then
    echo "auditctl not responding"
    exit 1
fi

exit 0
