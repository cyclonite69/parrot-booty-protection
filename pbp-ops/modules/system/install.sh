#!/bin/bash
# install.sh for system module
echo "Ensuring system hardening tools are ready..."
sudo apt-get update -q
sudo apt-get install -y procps sed grep
echo "Ready."
