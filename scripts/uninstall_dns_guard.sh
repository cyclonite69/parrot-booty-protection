#!/bin/bash
# Uninstall DNS Sovereignty Guard

set -e

if [[ $EUID -ne 0 ]]; then
   echo "❌ Must run as root"
   exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Uninstalling DNS Sovereignty Guard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Stop and disable service
echo "Stopping service..."
systemctl stop dns-sovereignty-guard.service 2>/dev/null || true
systemctl disable dns-sovereignty-guard.service 2>/dev/null || true

# Remove systemd service
echo "Removing systemd service..."
rm -f /etc/systemd/system/dns-sovereignty-guard.service
systemctl daemon-reload

# Remove binary
echo "Removing guard daemon..."
rm -f /opt/pbp/bin/dns-sovereignty-guard

# Ask about data
echo
read -p "Remove logs and state data? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf /var/lib/pbp/dns-guard
    rm -f /var/log/pbp/dns-guard.log
    rm -f /var/log/pbp/dns-alerts.log
    echo "✅ Data removed"
else
    echo "ℹ️  Data preserved in /var/lib/pbp/dns-guard and /var/log/pbp/"
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DNS Sovereignty Guard uninstalled"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
