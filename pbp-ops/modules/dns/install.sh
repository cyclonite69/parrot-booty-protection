#!/bin/bash
# install.sh for DNS module
echo "Installing Unbound and DNS utilities..."
sudo apt-get update -q
sudo apt-get install -y unbound unbound-anchor dnsutils
sudo unbound-anchor -a /var/lib/unbound/root.key || true
echo "Installation complete."
