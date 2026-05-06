#!/bin/bash

# Script to get IP addresses of all k3s VMs
# Run this on your HOST machine

echo "=========================================="
echo "K3s Cluster VM IP Discovery"
echo "=========================================="
echo ""

# Function to get IP for a MAC address from DHCP leases
get_ip_for_mac() {
    local mac="$1"
    sudo cat /var/lib/libvirt/dnsmasq/virbr0.status 2>/dev/null | \
        python3 -c "import sys, json; data=json.load(sys.stdin); print(next((item['ip-address'] for item in data if item['mac-address']=='$mac'), ''))"
}

# Function to get hostname for a MAC address from DHCP leases
get_hostname_for_mac() {
    local mac="$1"
    sudo cat /var/lib/libvirt/dnsmasq/virbr0.status 2>/dev/null | \
        python3 -c "import sys, json; data=json.load(sys.stdin); print(next((item['hostname'] for item in data if item['mac-address']=='$mac'), ''))"
}

# Get VM MAC addresses and map to IPs
echo "VM IP Addresses:"
echo "----------------------------------------"

for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    # Get MAC address for this VM
    mac=$(sudo virsh domiflist $vm | awk '/vnet/ {print $5}')

    if [ -n "$mac" ]; then
        ip=$(get_ip_for_mac "$mac")
        current_hostname=$(get_hostname_for_mac "$mac")

        if [ -n "$ip" ]; then
            echo "$vm:"
            echo "  MAC Address: $mac"
            echo "  IP Address:  $ip"
            echo "  Hostname:    $current_hostname"

            # Check if hostname matches VM name
            if [ "$current_hostname" != "$vm" ]; then
                echo "  WARNING: Hostname mismatch! Should be '$vm' but is '$current_hostname'"
                echo "  ACTION NEEDED: ssh andre@$ip and fix hostname"
            fi
        else
            echo "$vm:"
            echo "  MAC Address: $mac"
            echo "  IP Address:  NOT FOUND"
            echo "  WARNING: VM did not get an IP from DHCP"
        fi
        echo ""
    fi
done

echo "=========================================="
echo "Summary:"
echo "----------------------------------------"

total=0
ready=0
for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    mac=$(sudo virsh domiflist $vm | awk '/vnet/ {print $5}')
    ip=$(get_ip_for_mac "$mac")
    hostname=$(get_hostname_for_mac "$mac")
    total=$((total + 1))

    if [ -n "$ip" ] && [ "$hostname" = "$vm" ]; then
        echo "✓ $vm is ready at $ip"
        ready=$((ready + 1))
    elif [ -n "$ip" ] && [ "$hostname" != "$vm" ]; then
        echo "⚠ $vm has IP $ip but wrong hostname: $hostname"
    else
        echo "✗ $vm has no IP address"
    fi
done

echo ""
echo "Status: $ready/$total VMs ready for k3s setup"
echo "=========================================="

if [ $ready -lt 3 ]; then
    echo ""
    echo "Next Steps:"
    echo "1. Fix VMs with wrong hostnames using SSH"
    echo "2. For VMs without IPs, try rebooting them:"
    echo "   sudo virsh reboot <vm-name>"
    echo ""
fi
