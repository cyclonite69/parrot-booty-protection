#!/bin/bash
set -euo pipefail

echo "Installing Podman..."

# Remove Docker if present
systemctl stop docker 2>/dev/null || true
apt-get remove -y docker docker.io containerd 2>/dev/null || true

# Install Podman
apt-get update -qq
apt-get install -y podman slirp4netns fuse-overlayfs

echo "Podman installed"
