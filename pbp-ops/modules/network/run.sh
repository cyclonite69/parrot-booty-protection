#!/bin/bash
# run.sh for network module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/network"
mkdir -p "$REPORT_DIR"

# Ensure xsltproc is available for HTML conversion
if ! command -v xsltproc >/dev/null; then
    sudo apt-get install -y xsltproc
fi

echo "Running Network Exposure Scan..."
sudo nmap -sS -sV -O -Pn -oX "$REPORT_DIR/network_scan_$TIMESTAMP.xml" localhost

echo "Generating HTML report..."
xsltproc "$REPORT_DIR/network_scan_$TIMESTAMP.xml" -o "$REPORT_DIR/network_scan_$TIMESTAMP.html"

echo "Scan complete. HTML report saved."
