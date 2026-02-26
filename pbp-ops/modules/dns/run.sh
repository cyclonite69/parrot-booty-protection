#!/bin/bash
# run.sh for DNS module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/dns"
mkdir -p "$REPORT_DIR"

echo "Applying Unbound configuration..."
sudo cp /home/dbcooper/parrot-booty-protection/configs/unbound.conf /etc/unbound/unbound.conf
sudo systemctl restart unbound

echo "Verifying DNS resolution and DoT..."
dig @127.0.0.1 google.com +short > /dev/null
RESOLUTION_OK=$?

echo "Verifying DNSSEC..."
dig @127.0.0.1 google.com +dnssec | grep -q "ad;"
DNSSEC_OK=$?

{
    echo "--- DNS Hardening Report: $TIMESTAMP ---"
    [ $RESOLUTION_OK -eq 0 ] && echo "[PASS] Local DNS Resolution" || echo "[FAIL] Local DNS Resolution"
    [ $DNSSEC_OK -eq 0 ] && echo "[PASS] DNSSEC Validation" || echo "[FAIL] DNSSEC Validation"
    echo -e "
Unbound Status:"
    systemctl status unbound --no-pager
} > "$REPORT_DIR/dns_status_$TIMESTAMP.txt"

echo "DNS hardening check complete."
