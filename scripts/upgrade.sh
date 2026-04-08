#!/bin/bash
# PBP Runtime Upgrade Script

set -euo pipefail

INSTALL_DIR="/opt/pbp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Upgrading PBP runtime in ${INSTALL_DIR}..."

mkdir -p "${INSTALL_DIR}"/{bin,core,modules,config}

cp -r "${PROJECT_ROOT}/bin"/* "${INSTALL_DIR}/bin/"
cp -r "${PROJECT_ROOT}/core"/* "${INSTALL_DIR}/core/"
cp -r "${PROJECT_ROOT}/modules"/* "${INSTALL_DIR}/modules/"
cp -r "${PROJECT_ROOT}/config"/* "${INSTALL_DIR}/config/"

chmod +x "${INSTALL_DIR}/bin"/*
chmod +x "${INSTALL_DIR}/core"/*.sh
chmod +x "${INSTALL_DIR}/core/lib"/*.sh
find "${INSTALL_DIR}/modules" -name "*.sh" -exec chmod +x {} \;

ln -sf "${INSTALL_DIR}/bin/pbp" /usr/local/bin/pbp
ln -sf "${INSTALL_DIR}/bin/pbp-dashboard" /usr/local/bin/pbp-dashboard

if [[ -d "${PROJECT_ROOT}/systemd" ]]; then
    cp "${PROJECT_ROOT}/systemd"/*.service /etc/systemd/system/ 2>/dev/null || true
    cp "${PROJECT_ROOT}/systemd"/*.timer /etc/systemd/system/ 2>/dev/null || true
    systemctl daemon-reload
fi

echo "✓ Upgrade complete"
echo
echo "Next steps:"
echo "  sudo pbp list"
echo "  /opt/pbp/bin/pbp-menu"
