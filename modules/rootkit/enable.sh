#!/bin/bash
set -euo pipefail

echo "Initializing rootkit scanners..."

# Update rkhunter database
rkhunter --update || true
rkhunter --propupd || true

echo "Rootkit scanning enabled"
