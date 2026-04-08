#!/bin/bash
set -euo pipefail

if [[ ! -d /var/log/pbp ]]; then
  echo "/var/log/pbp is missing"
  exit 1
fi

if [[ ! -f /etc/logrotate.d/pbp-security ]]; then
  echo "logrotate policy missing: /etc/logrotate.d/pbp-security"
  exit 1
fi

exit 0
