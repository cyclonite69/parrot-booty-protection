#!/bin/bash
set -euo pipefail

echo "Installing DNS over TLS support..."

# Ensure systemd-resolved is available
apt-get update -qq
apt-get install -y systemd-resolved

echo "DNS components installed"
