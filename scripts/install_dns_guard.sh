#!/bin/bash
# Install DNS Sovereignty Guard

set -e

if [[ $EUID -ne 0 ]]; then
   echo "❌ Must run as root"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installing DNS Sovereignty Guard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Create directories
echo "Creating directories..."
mkdir -p /var/lib/pbp/dns-guard
mkdir -p /var/log/pbp
mkdir -p /opt/pbp/bin

# Install guard
echo "Installing guard daemon..."
cp "$PROJECT_ROOT/bin/dns-sovereignty-guard" /opt/pbp/bin/
chmod +x /opt/pbp/bin/dns-sovereignty-guard

# Install systemd service
echo "Installing systemd service..."
cp "$PROJECT_ROOT/systemd/dns-sovereignty-guard.service" /etc/systemd/system/
systemctl daemon-reload

# Initialize baseline
echo "Initializing DNS baseline..."
/opt/pbp/bin/dns-sovereignty-guard init

# Enable and start service
echo "Enabling service..."
systemctl enable dns-sovereignty-guard.service
systemctl start dns-sovereignty-guard.service

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DNS Sovereignty Guard installed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Status:"
systemctl status dns-sovereignty-guard.service --no-pager -l
echo
echo "Commands:"
echo "  systemctl status dns-sovereignty-guard    # View status"
echo "  journalctl -u dns-sovereignty-guard -f    # View live logs"
echo "  tail -f /var/log/pbp/dns-alerts.log       # View alerts"
echo "  /opt/pbp/bin/dns-sovereignty-guard check  # Manual check"
echo
echo "Configure email alerts (optional):"
echo "  echo 'EMAIL_TO=admin@example.com' > /var/lib/pbp/dns-guard/email.conf"
echo
