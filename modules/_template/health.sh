#!/bin/bash
# Module Health Check Hook Template

set -euo pipefail

# Check if service is running
# if ! systemctl is-active example.service &>/dev/null; then
#     echo "Service not running"
#     exit 1
# fi

# Check configuration validity
# if [[ ! -f /etc/example.conf ]]; then
#     echo "Configuration missing"
#     exit 1
# fi

# All checks passed
exit 0
