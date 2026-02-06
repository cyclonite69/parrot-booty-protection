#!/bin/bash

# DNS Hardening Monitoring Setup
# Installs periodic monitoring and alerts

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

[[ $EUID -ne 0 ]] && { echo -e "${RED}Must run as root${NC}"; exit 1; }

echo -e "${GREEN}=== DNS Hardening Monitoring Setup ===${NC}\n"

# Check if already installed
if sudo crontab -l 2>/dev/null | grep -q "dns_monitor.sh"; then
    echo -e "${YELLOW}Monitoring already installed${NC}"
    echo ""
    sudo crontab -l | grep dns_
    echo ""
    read -p "Reinstall? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# Get interval
echo "Select monitoring interval:"
echo "1) Every 5 minutes"
echo "2) Every 15 minutes"
echo "3) Every 30 minutes (recommended)"
echo "4) Every hour"
read -p "Choice [3]: " choice
choice=${choice:-3}

case $choice in
    1) INTERVAL="*/5 * * * *" ;;
    2) INTERVAL="*/15 * * * *" ;;
    3) INTERVAL="*/30 * * * *" ;;
    4) INTERVAL="0 * * * *" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

# Copy scripts
echo -e "\n${GREEN}Installing scripts...${NC}"
cp scripts/dns_monitor.sh /usr/local/bin/
cp scripts/dns_alert.sh /usr/local/bin/
chmod +x /usr/local/bin/dns_monitor.sh /usr/local/bin/dns_alert.sh

# Install cron jobs
echo -e "${GREEN}Setting up cron jobs...${NC}"
(crontab -l 2>/dev/null | grep -v "dns_monitor.sh" | grep -v "dns_alert.sh"; echo "$INTERVAL /usr/local/bin/dns_monitor.sh"; echo "$INTERVAL /usr/local/bin/dns_alert.sh") | crontab -

echo -e "\n${GREEN}✓ Monitoring installed!${NC}"
echo ""
echo "Interval: $INTERVAL"
echo "Monitor log: /var/log/dns_hardening_monitor.log"
echo "Alert log: /var/log/dns_hardening_alerts.log"
echo ""
echo "To uninstall: sudo ./scripts/dns_monitoring_uninstall.sh"
