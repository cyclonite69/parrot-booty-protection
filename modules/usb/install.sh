#!/bin/bash
set -euo pipefail

echo "Installing USBGuard..."

apt-get update -qq
apt-get install -y usbguard

mkdir -p /etc/usbguard

echo "USBGuard installed"
