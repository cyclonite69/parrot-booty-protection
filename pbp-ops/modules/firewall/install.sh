#!/bin/bash
# install.sh for firewall module
echo "Installing nftables..."
sudo apt-get update -q
sudo apt-get install -y nftables
sudo systemctl enable nftables
echo "Installation complete."
