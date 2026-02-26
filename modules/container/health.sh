#!/bin/bash
set -euo pipefail

# Check if podman is available
if ! command -v podman &>/dev/null; then
    echo "Podman not installed"
    exit 1
fi

# Check if security config exists
if [[ ! -f /etc/containers/containers.conf.d/security.conf ]]; then
    echo "Security configuration missing"
    exit 1
fi

exit 0
