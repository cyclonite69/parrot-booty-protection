#!/bin/bash
# run.sh for ipv6 module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/ipv6"
mkdir -p "$REPORT_DIR"

echo "Disabling IPv6 via sysctl and GRUB..."
sudo tee /etc/sysctl.d/99-pbp-ipv6-disable.conf > /dev/null << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sudo sysctl -p /etc/sysctl.d/99-pbp-ipv6-disable.conf

# Modify GRUB if not already present
if ! grep -q "ipv6.disable=1" /etc/default/grub; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub
    sudo update-grub
fi

{
    echo "--- IPv6 Policy Report: $TIMESTAMP ---"
    echo "Mode: DISABLED"
    echo -e "
[Sysctl Status]"
    sysctl net.ipv6.conf.all.disable_ipv6
    echo -e "
[Kernel Command Line]"
    cat /proc/cmdline
} > "$REPORT_DIR/ipv6_status_$TIMESTAMP.txt"

echo "IPv6 policy applied. Reboot recommended for full kernel effect."
