#!/bin/bash
set -euo pipefail

if ! command -v nmap &>/dev/null; then
    echo "nmap not installed"
    exit 1
fi

exit 0
