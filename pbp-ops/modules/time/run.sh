#!/bin/bash
# run.sh for time module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/time"
mkdir -p "$REPORT_DIR"

echo "Configuring Chrony with NTS servers..."
sudo tee /etc/chrony/chrony.conf > /dev/null << EOF
# Parrot Booty Protection - NTS Configuration
server time.cloudflare.com nts iburst
server ntppool1.time.nl nts iburst
server nts.netnod.se nts iburst

driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF

sudo systemctl restart chrony
sleep 2

{
    echo "--- NTS Time Hardening Report: $TIMESTAMP ---"
    echo -e "
[Tracking Status]"
    chronyc tracking
    echo -e "
[Sources Status]"
    chronyc sources -v
    echo -e "
[Authdata Status]"
    chronyc authdata
} > "$REPORT_DIR/nts_status_$TIMESTAMP.txt"

echo "Time hardening check complete."
