#!/bin/bash
set -euo pipefail

echo "Installing chrony for NTS time synchronization..."

# Stop conflicting services
systemctl stop systemd-timesyncd 2>/dev/null || true
systemctl disable systemd-timesyncd 2>/dev/null || true

# Install chrony
apt-get update -qq
apt-get install -y chrony

echo "Chrony installed successfully"
