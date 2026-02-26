#!/bin/bash
# PBP Installation Script

set -euo pipefail

INSTALL_DIR="/opt/pbp"
STATE_DIR="/var/lib/pbp"
LOG_DIR="/var/log/pbp"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Parrot Booty Protection - Installation Script           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Pre-flight checks
echo "Running pre-flight checks..."
source "$(dirname "$0")/../core/lib/validation.sh"
if ! pre_flight_check; then
    echo
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo
echo "Installing PBP to ${INSTALL_DIR}..."

# Create directories
mkdir -p "${INSTALL_DIR}"/{bin,core,modules,config}
mkdir -p "${STATE_DIR}"/{state,backups}
mkdir -p "${LOG_DIR}"/{reports/{json,html,checksums},modules}

# Copy files
echo "Copying files..."
cp -r "$(dirname "$0")/../bin"/* "${INSTALL_DIR}/bin/"
cp -r "$(dirname "$0")/../core"/* "${INSTALL_DIR}/core/"
cp -r "$(dirname "$0")/../modules"/* "${INSTALL_DIR}/modules/"
cp -r "$(dirname "$0")/../config"/* "${INSTALL_DIR}/config/"

# Set permissions
chmod +x "${INSTALL_DIR}/bin"/*
chmod +x "${INSTALL_DIR}/core"/*.sh
chmod +x "${INSTALL_DIR}/core/lib"/*.sh
find "${INSTALL_DIR}/modules" -name "*.sh" -exec chmod +x {} \;

# Make directories and binaries readable by all users
chmod 755 "${INSTALL_DIR}"
chmod 755 "${INSTALL_DIR}/bin"
chmod 755 "${INSTALL_DIR}/bin"/*
chmod 755 "${INSTALL_DIR}/core"
chmod 755 "${INSTALL_DIR}/core/lib"
chmod 755 "${INSTALL_DIR}/modules"

chmod 750 "${STATE_DIR}"
chmod 750 "${LOG_DIR}"

# Create symlink
ln -sf "${INSTALL_DIR}/bin/pbp" /usr/local/bin/pbp
ln -sf "${INSTALL_DIR}/bin/pbp-dashboard" /usr/local/bin/pbp-dashboard

# Install systemd timers
if [[ -d "$(dirname "$0")/../systemd" ]]; then
    echo "Installing systemd timers..."
    cp "$(dirname "$0")/../systemd"/*.service /etc/systemd/system/
    cp "$(dirname "$0")/../systemd"/*.timer /etc/systemd/system/
    systemctl daemon-reload
fi

# Initialize state
"${INSTALL_DIR}/core/state.sh" init_state 2>/dev/null || true

echo
echo "✓ Installation complete!"
echo
echo "Quick start:"
echo "  pbp list                 # List available modules"
echo "  pbp enable time          # Enable time security"
echo "  pbp scan                 # Run security scan"
echo "  pbp dashboard            # Launch TUI dashboard"
echo
echo "Enable automated scans:"
echo "  systemctl enable --now pbp-scan-daily.timer"
echo "  systemctl enable --now pbp-audit-weekly.timer"
echo
