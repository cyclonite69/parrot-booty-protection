#!/bin/bash
# Install PBP Control Restoration System

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏴‍☠️ PBP Control Restoration - Operator Sovereignty"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

PBP_ROOT="/opt/pbp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "📦 Installing control system components..."

# Create directories
mkdir -p /etc/pbp
mkdir -p /var/lib/pbp/integrity
mkdir -p /var/log/pbp/reports/alerts

# Install policy
echo "📋 Installing operator policy..."
cp "$PROJECT_ROOT/config/policy.yaml" /etc/pbp/policy.yaml
chmod 600 /etc/pbp/policy.yaml

# Copy core components
echo "🔧 Installing core components..."
cp "$PROJECT_ROOT/core/policy.sh" "$PBP_ROOT/core/"
cp "$PROJECT_ROOT/core/integrity.sh" "$PBP_ROOT/core/"
cp "$PROJECT_ROOT/core/alerts.sh" "$PBP_ROOT/core/"

# Copy UI
echo "🖥️  Installing control plane UI..."
mkdir -p "$PBP_ROOT/ui"
cp "$PROJECT_ROOT/ui/index.html" "$PBP_ROOT/ui/"

# Copy control script
cp "$PROJECT_ROOT/bin/pbp-control" "$PBP_ROOT/bin/"
chmod +x "$PBP_ROOT/bin/pbp-control"

# Install systemd service
echo "⚙️  Installing integrity watcher service..."
cp "$PROJECT_ROOT/systemd/pbp-integrity.service" /etc/systemd/system/
systemctl daemon-reload

# Initialize integrity baselines
echo "🔐 Creating integrity baselines..."
"$PBP_ROOT/core/integrity.sh" init

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Control system installed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "NEXT STEPS:"
echo
echo "1. Review policy:"
echo "   cat /etc/pbp/policy.yaml"
echo
echo "2. Enable integrity monitoring:"
echo "   systemctl enable --now pbp-integrity.service"
echo
echo "3. Start control plane:"
echo "   pbp control start"
echo "   Access: http://localhost:7777"
echo
echo "4. Reinstall DNS with Unbound:"
echo "   pbp disable dns"
echo "   pbp enable dns"
echo
echo "5. Check integrity:"
echo "   pbp integrity"
echo
echo "6. View alerts:"
echo "   pbp alerts"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛡️  Operator sovereignty restored"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
