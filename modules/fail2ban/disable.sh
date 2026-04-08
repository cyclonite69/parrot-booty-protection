#!/bin/bash
set -euo pipefail

echo "Disabling Fail2Ban..."

if command -v systemctl &>/dev/null; then
  systemctl stop fail2ban 2>/dev/null || true
  systemctl disable fail2ban 2>/dev/null || true
fi

echo "Fail2Ban disabled"
