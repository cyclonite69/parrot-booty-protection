#!/bin/bash
# status.sh for ipv6 module
if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" == "1" ]; then
    echo "active"
else
    echo "inactive"
fi
