#!/bin/bash
set -euo pipefail

echo "Installing nmap..."

apt-get update -qq
apt-get install -y nmap

echo "nmap installed"
