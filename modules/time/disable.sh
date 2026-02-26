#!/bin/bash
set -euo pipefail

echo "Disabling NTS time synchronization..."

systemctl stop chronyd
systemctl disable chronyd

echo "Time module disabled"
