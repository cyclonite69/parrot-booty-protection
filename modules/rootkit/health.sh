#!/bin/bash
set -euo pipefail

if ! command -v rkhunter &>/dev/null; then
    echo "rkhunter not installed"
    exit 1
fi

if ! command -v chkrootkit &>/dev/null; then
    echo "chkrootkit not installed"
    exit 1
fi

exit 0
