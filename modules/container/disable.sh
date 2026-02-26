#!/bin/bash
set -euo pipefail

echo "Disabling container hardening..."

# Remove security overrides
rm -f /etc/containers/containers.conf.d/security.conf

echo "Container module disabled"
