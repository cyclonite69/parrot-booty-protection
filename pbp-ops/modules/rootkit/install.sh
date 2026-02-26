#!/bin/bash
# install.sh for rootkit module
echo "Installing Rootkit Sentry tools..."
sudo apt-get update -q
sudo apt-get install -y rkhunter chkrootkit
sudo rkhunter --propupd --quiet
echo "Installation complete."
