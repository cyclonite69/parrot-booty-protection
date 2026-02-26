#!/bin/bash
# install.sh for container module
echo "Ensuring container audit tools are ready..."
sudo apt-get update -q
sudo apt-get install -y podman jq
echo "Ready."
