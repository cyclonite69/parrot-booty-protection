#!/bin/bash
# Install PBP Reporting Dependencies

set -euo pipefail

echo "Installing PBP reporting dependencies..."

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Update package list
apt-get update -qq

# Install dependencies
echo "Installing pandoc..."
apt-get install -y pandoc

echo "Installing wkhtmltopdf..."
apt-get install -y wkhtmltopdf

echo "Installing jq..."
apt-get install -y jq

echo "Installing Python3 and Jinja2..."
apt-get install -y python3 python3-pip
pip3 install --quiet jinja2

# Verify installations
echo
echo "Verifying installations..."

for cmd in pandoc wkhtmltopdf jq python3; do
    if command -v "$cmd" &>/dev/null; then
        echo "✓ $cmd installed"
    else
        echo "✗ $cmd installation failed"
        exit 1
    fi
done

# Verify Jinja2
if python3 -c "import jinja2" 2>/dev/null; then
    echo "✓ jinja2 installed"
else
    echo "✗ jinja2 installation failed"
    exit 1
fi

echo
echo "✓ All dependencies installed successfully"
