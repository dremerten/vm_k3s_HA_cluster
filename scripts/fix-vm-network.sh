#!/bin/bash

# Fix VM Network Configuration Script
# Run this script INSIDE each VM after accessing via: sudo virsh console <vm-name>
#
# Usage:
#   For k3s-cluster1: ./fix-vm-network.sh k3s-cluster1
#   For k3s-cluster2: ./fix-vm-network.sh k3s-cluster2
#   For k3s-cluster3: ./fix-vm-network.sh k3s-cluster3

if [ $# -ne 1 ]; then
    echo "Usage: $0 <hostname>"
    echo "Example: $0 k3s-cluster1"
    exit 1
fi

HOSTNAME=$1

echo "=========================================="
echo "Fixing VM Network for: $HOSTNAME"
echo "=========================================="

# 1. Set hostname
echo "Setting hostname to $HOSTNAME..."
sudo hostnamectl set-hostname $HOSTNAME

# 2. Update /etc/hosts
echo "Updating /etc/hosts..."
sudo sed -i "s/cve-tester/$HOSTNAME/g" /etc/hosts
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/g" /etc/hosts

# 3. Regenerate machine-id (critical for cloned VMs)
echo "Regenerating machine-id..."
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo ln -sf /etc/machine-id /var/lib/dbus/machine-id

# 4. Clean up old DHCP leases
echo "Cleaning old DHCP leases..."
sudo rm -f /var/lib/dhcp/dhclient.leases
sudo rm -f /var/lib/dhclient/*

# 5. Restart networking
echo "Restarting network..."
sudo systemctl restart systemd-networkd 2>/dev/null || true
sudo systemctl restart networking 2>/dev/null || true
sudo systemctl restart NetworkManager 2>/dev/null || true

# 6. Force DHCP renewal
echo "Renewing DHCP lease..."
sudo dhclient -r 2>/dev/null || true
sudo dhclient 2>/dev/null || true

echo ""
echo "=========================================="
echo "Configuration complete!"
echo "=========================================="
echo "Current IP address:"
ip addr show | grep "inet " | grep -v "127.0.0.1"
echo ""
echo "Current hostname:"
hostname
echo ""
echo "Please reboot for all changes to take effect:"
echo "  sudo reboot"
echo "=========================================="
