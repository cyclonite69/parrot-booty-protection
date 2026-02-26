#!/bin/bash
# install_ops.sh - Deploy the Parrot Booty Protection Ops Platform

set -euo pipefail

PBP_ROOT="/opt/parrot-booty-protection"
USER_NAME=$(whoami)

echo "⚓ Deploying the PBP Ops Platform..."

# 1. Create Structure
sudo mkdir -p $PBP_ROOT/{modules,reports,logs,scripts,configs,ui,scheduler,state,lib}
sudo mkdir -p $PBP_ROOT/reports/{rootkit,network,time,dns,firewall,system,container,ipv6}

# 2. Copy Platform Files
echo "Copying rigging..."
sudo cp -r pbp-ops/lib/* $PBP_ROOT/lib/
sudo cp -r pbp-ops/modules/* $PBP_ROOT/modules/
sudo cp -r pbp-ops/ui/* $PBP_ROOT/ui/

# 3. Set Permissions
sudo chown -R $USER_NAME:$USER_NAME $PBP_ROOT
sudo find $PBP_ROOT/modules -type f -name "*.sh" -exec chmod +x {} +

# 4. Install Dependencies
echo "Installing base dependencies..."
sudo apt-get update -q
sudo apt-get install -y python3-pip python3-venv whiptail jq
python3 -m venv $PBP_ROOT/venv
$PBP_ROOT/venv/bin/pip install fastapi uvicorn

# 5. Create Systemd Service for UI
cat << EOF | sudo tee /etc/systemd/system/pbp-ops.service
[Unit]
Description=Parrot Booty Protection Ops Console
After=network.target

[Service]
ExecStart=$PBP_ROOT/venv/bin/uvicorn app:app --host 0.0.0.0 --port 8080
WorkingDirectory=$PBP_ROOT/ui
Restart=always
User=$USER_NAME

[Install]
WantedBy=multi-user.target
EOF

# 6. Create Scheduler
cat << EOF | sudo tee /etc/systemd/system/pbp-scheduler.timer
[Unit]
Description=PBP Daily Security Audit

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now pbp-ops.service
sudo systemctl enable --now pbp-scheduler.timer

echo -e "
🏴‍☠️ PBP Ops Platform Deployed!"
echo "Dashboard available at: http://localhost:8080"
