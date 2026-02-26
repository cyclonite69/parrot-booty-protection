#!/bin/bash
# install_pbp.sh - Deploy the PBP Sentinel Platform v2

set -euo pipefail

PBP_ROOT="/opt/pbp"

echo "⚓ Deploying the Sentinel & Monitoring Suite..."

# 1. Create Structure
sudo mkdir -p $PBP_ROOT/{bin,lib,modules,logs,reports,baseline,forensics,state,systemd}

# 2. Copy Files
sudo cp -r /home/dbcooper/parrot-booty-protection/pbp-core/lib/pbp-lib.sh $PBP_ROOT/lib/
sudo cp -r /home/dbcooper/parrot-booty-protection/pbp-core/bin/* $PBP_ROOT/bin/
sudo cp -r /home/dbcooper/parrot-booty-protection/pbp-core/modules/* $PBP_ROOT/modules/
sudo cp -r /home/dbcooper/parrot-booty-protection/pbp-core/systemd/* /etc/systemd/system/

# 3. Set Permissions
sudo chown -R root:root $PBP_ROOT
sudo chmod -R 750 $PBP_ROOT
sudo find $PBP_ROOT/bin -type f -exec sudo chmod +x {} +
sudo find $PBP_ROOT/modules -type f -exec sudo chmod +x {} +

# 4. Create Symlink
sudo ln -sf $PBP_ROOT/bin/pbp.sh /usr/local/bin/pbp

# 5. Create Main Sentinel Service (if not already copied)
if [ ! -f "/etc/systemd/system/pbp-sentinel.service" ]; then
cat << EOF | sudo tee /etc/systemd/system/pbp-sentinel.service
[Unit]
Description=Parrot Booty Protection Sentinel
After=network.target

[Service]
ExecStart=$PBP_ROOT/bin/pbp-sentinel.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
fi

# 6. Enable Automation
sudo systemctl daemon-reload
sudo systemctl enable --now pbp-sentinel.service
sudo systemctl enable --now pbp-integrity.timer
sudo systemctl enable --now pbp-watch.timer

echo -e "\n🏴‍☠️ Continuous Defensive Platform Deployed!"
echo "Run 'pbp learn' to map the ship's initial state."
echo "Use 'pbp status' to inspect the rigging."
