#!/bin/bash
# Absolute truth: What is ACTUALLY running

echo "=== SYSTEMD SERVICES (ENABLED) ==="
systemctl list-unit-files --state=enabled --no-pager | grep pbp

echo ""
echo "=== SYSTEMD SERVICES (ACTIVE) ==="
systemctl list-units --state=active --no-pager | grep pbp

echo ""
echo "=== CRON JOBS ==="
crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$'
sudo crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$'

echo ""
echo "=== RUNNING PROCESSES ==="
ps aux | grep -E 'pbp|dns-sovereignty|hardenctl' | grep -v grep

echo ""
echo "=== LISTENING PORTS ==="
sudo ss -tlnp | grep -E '7777|7778|8080'

echo ""
echo "=== INSTALLED BINARIES ==="
ls -la /usr/local/bin/ | grep -E 'pbp|dns-sovereignty'
ls -la /opt/pbp/bin/ 2>/dev/null | grep -v '^total'

echo ""
echo "=== TRUTH: Nothing runs unless you started it ==="
