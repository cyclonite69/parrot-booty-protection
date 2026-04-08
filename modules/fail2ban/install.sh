#!/bin/bash
set -euo pipefail

echo "Installing Fail2Ban..."
apt-get update -qq
apt-get install -y fail2ban
echo "Fail2Ban installed"
