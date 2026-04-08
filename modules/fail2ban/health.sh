#!/bin/bash
set -euo pipefail

if command -v systemctl &>/dev/null; then
  if ! systemctl is-active fail2ban &>/dev/null; then
    echo "fail2ban service not active"
    exit 1
  fi
fi

if ! command -v fail2ban-client &>/dev/null; then
  echo "fail2ban-client not found"
  exit 1
fi

if ! fail2ban-client ping 2>/dev/null | grep -q "Server replied"; then
  echo "fail2ban daemon not responding"
  exit 1
fi

exit 0
