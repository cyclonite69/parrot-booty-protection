#!/bin/bash
set -euo pipefail

hardlinks="$(sysctl -n fs.protected_hardlinks 2>/dev/null || echo 0)"
symlinks="$(sysctl -n fs.protected_symlinks 2>/dev/null || echo 0)"

if [[ "$hardlinks" -lt 1 || "$symlinks" -lt 1 ]]; then
  echo "mount safety sysctls not fully enabled"
  exit 1
fi

exit 0
