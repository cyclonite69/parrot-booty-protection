#!/bin/bash
set -euo pipefail

echo "Installing MAC randomization dependencies..."
apt-get update -qq
apt-get install -y macchanger
echo "MAC randomization dependencies installed"
