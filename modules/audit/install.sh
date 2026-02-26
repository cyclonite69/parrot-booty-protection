#!/bin/bash
set -euo pipefail

echo "Installing auditd..."

apt-get update -qq
apt-get install -y auditd audispd-plugins

echo "auditd installed"
