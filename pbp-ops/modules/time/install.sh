#!/bin/bash
# install.sh for time module
echo "Installing Chrony..."
sudo apt-get update -q
sudo apt-get install -y chrony
sudo systemctl disable --now systemd-timesyncd 2>/dev/null || true
echo "Installation complete."
