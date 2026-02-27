#!/bin/bash
# EMERGENCY STOP - Disable all automation before cleanup

set -x

echo "=== STOPPING ACTIVE SERVICES ==="
sudo systemctl stop pbp-ops.service
sudo systemctl stop pbp-sentinel.service
sudo systemctl disable pbp-ops.service
sudo systemctl disable pbp-sentinel.service

echo ""
echo "=== DISABLING TIMERS ==="
sudo systemctl stop pbp-integrity.timer
sudo systemctl stop pbp-watch.timer
sudo systemctl disable pbp-integrity.timer
sudo systemctl disable pbp-watch.timer

echo ""
echo "=== REMOVING CRON JOBS ==="
crontab -l 2>/dev/null | grep -v dns_monitor | grep -v dns_tls_monitor | crontab -
sudo crontab -l 2>/dev/null | grep -v dns_monitor | grep -v dns_tls_monitor | sudo crontab -

echo ""
echo "=== VERIFICATION ==="
systemctl list-units --state=active | grep pbp
ps aux | grep -E 'pbp|dns-sovereignty' | grep -v grep

echo ""
echo "✅ All automation stopped"
