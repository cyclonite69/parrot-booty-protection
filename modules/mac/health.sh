#!/bin/bash
set -euo pipefail

cfg="/etc/NetworkManager/conf.d/pbp-mac-randomization.conf"

if [[ ! -f "$cfg" ]]; then
  echo "MAC randomization config missing"
  exit 1
fi

if ! grep -q "cloned-mac-address=random" "$cfg"; then
  echo "MAC randomization setting missing"
  exit 1
fi

exit 0
