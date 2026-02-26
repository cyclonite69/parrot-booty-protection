#!/bin/bash
# run.sh for firewall module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/firewall"
mkdir -p "$REPORT_DIR"

echo "Applying hardened nftables ruleset..."
# We'll use the project config but ensure it's copied to the system location
sudo cp /home/dbcooper/parrot-booty-protection/configs/nftables.conf /etc/nftables.conf
sudo nft -f /etc/nftables.conf
sudo systemctl restart nftables

{
    echo "--- Firewall Hardening Report: $TIMESTAMP ---"
    echo -e "
[Active Ruleset Summary]"
    sudo nft list ruleset | grep -E "table|chain|policy"
    echo -e "
[Detailed Ruleset]"
    sudo nft list ruleset
} > "$REPORT_DIR/firewall_status_$TIMESTAMP.txt"

echo "Firewall hardening complete."
