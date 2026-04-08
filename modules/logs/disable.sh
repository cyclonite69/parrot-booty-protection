#!/bin/bash
set -euo pipefail

echo "Disabling logs module..."
rm -f /etc/logrotate.d/pbp-security
echo "Logs module disabled"
