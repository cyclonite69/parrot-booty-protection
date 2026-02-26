#!/bin/bash
set -euo pipefail

echo "Installing rootkit scanners..."

apt-get update -qq
apt-get install -y rkhunter chkrootkit

echo "Rootkit scanners installed"
