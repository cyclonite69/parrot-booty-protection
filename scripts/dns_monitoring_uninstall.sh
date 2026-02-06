#!/bin/bash

# DNS Hardening Monitoring Uninstall

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}Must run as root${NC}"; exit 1; }

echo -e "${GREEN}=== Uninstalling DNS Monitoring ===${NC}\n"

# Remove cron jobs
if sudo crontab -l 2>/dev/null | grep -q "dns_monitor.sh\|dns_alert.sh"; then
    sudo crontab -l | grep -v "dns_monitor.sh" | grep -v "dns_alert.sh" | sudo crontab -
    echo -e "${GREEN}✓ Removed cron jobs${NC}"
else
    echo "No cron jobs found"
fi

# Remove scripts
if [ -f /usr/local/bin/dns_monitor.sh ]; then
    rm /usr/local/bin/dns_monitor.sh
    echo -e "${GREEN}✓ Removed dns_monitor.sh${NC}"
fi

if [ -f /usr/local/bin/dns_alert.sh ]; then
    rm /usr/local/bin/dns_alert.sh
    echo -e "${GREEN}✓ Removed dns_alert.sh${NC}"
fi

# Ask about logs
echo ""
read -p "Remove log files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f /var/log/dns_hardening_monitor.log
    rm -f /var/log/dns_hardening_alerts.log
    rm -f /var/run/dns_hardening.state
    echo -e "${GREEN}✓ Removed log files${NC}"
fi

echo -e "\n${GREEN}Monitoring uninstalled${NC}"
