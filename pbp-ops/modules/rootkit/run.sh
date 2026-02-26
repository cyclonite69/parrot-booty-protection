#!/bin/bash
# run.sh for rootkit module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/rootkit"
mkdir -p "$REPORT_DIR"

echo "Updating signatures..."
sudo rkhunter --update --quiet

echo "Running RKHunter scan..."
sudo rkhunter --check --sk --rwo > "$REPORT_DIR/rkhunter_$TIMESTAMP.log"

echo "Running Chkrootkit scan..."
sudo chkrootkit -q > "$REPORT_DIR/chkrootkit_$TIMESTAMP.log"

echo "Scans complete. Reports saved."
