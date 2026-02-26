#!/bin/bash
# PBP Module Demo (non-root safe)

PBP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PBP_ROOT
export PBP_MODULES_DIR="${PBP_ROOT}/modules"
export PBP_STATE_DIR="/tmp/pbp-demo/state"
export PBP_LOG_DIR="/tmp/pbp-demo/log"
export PBP_BACKUP_DIR="/tmp/pbp-demo/backups"
export PBP_REPORT_DIR="/tmp/pbp-demo/reports"

# Setup demo environment
mkdir -p "$PBP_STATE_DIR" "$PBP_LOG_DIR" "$PBP_BACKUP_DIR" "$PBP_REPORT_DIR"

echo "PBP Security Platform Demo"
echo "=========================="
echo

./bin/pbp list

echo
echo "Module details:"
echo

for module in time dns network container audit rootkit recon; do
    desc=$(jq -r '.description' "modules/${module}/manifest.json" 2>/dev/null)
    deps=$(jq -r '.dependencies | join(", ")' "modules/${module}/manifest.json" 2>/dev/null)
    echo "📦 ${module}"
    echo "   ${desc}"
    [[ -n "$deps" && "$deps" != "" ]] && echo "   Dependencies: ${deps}"
    echo
done
