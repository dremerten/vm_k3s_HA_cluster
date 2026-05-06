# VM Network Setup and IP Discovery

## Current Status

All 3 VMs are running and connected to the same network (virbr0/default):
- k3s-cluster1: MAC `52:54:00:50:68:18` - No IP yet
- k3s-cluster2: MAC `52:54:00:63:bd:e9` - No IP yet
- k3s-cluster3: MAC `52:54:00:88:be:a9` - IP `192.168.122.99` (but hostname still shows "cve-tester")

## Problem

The VMs were likely cloned from a template and have:
1. Duplicate machine-ids (prevents DHCP from assigning unique IPs)
2. Old hostname references to "cve-tester"
3. Stale network configuration

## Solution: Fix Each VM

### Option 1: Quick Fix (Recommended)

**Run on your HOST machine:**

```bash
# Access each VM console and fix configuration
cd /home/andre/vm_k3s_HA_cluster

# Fix k3s-cluster1
echo "Fixing k3s-cluster1..."
sudo virsh console k3s-cluster1
# Once logged in (press Enter if you see blank screen):
# Username: your-username
# Password: your-password
# Then run:
sudo hostnamectl set-hostname k3s-cluster1
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo reboot

# Exit console: Press Ctrl+]
# Wait 30 seconds for VM to reboot
```

Repeat for k3s-cluster2 and k3s-cluster3:

```bash
# Fix k3s-cluster2
sudo virsh console k3s-cluster2
# Run inside VM:
sudo hostnamectl set-hostname k3s-cluster2
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo reboot

# Exit console: Ctrl+]
```

```bash
# Fix k3s-cluster3
sudo virsh console k3s-cluster3
# Run inside VM:
sudo hostnamectl set-hostname k3s-cluster3
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo reboot

# Exit console: Ctrl+]
```

### Option 2: Using the Fix Script

If you can SSH into the VMs (currently only k3s-cluster3 at 192.168.122.99):

```bash
# Copy fix script to VM
scp /home/andre/vm_k3s_HA_cluster/fix-vm-network.sh user@192.168.122.99:/tmp/

# SSH into VM
ssh user@192.168.122.99

# Run fix script
chmod +x /tmp/fix-vm-network.sh
/tmp/fix-vm-network.sh k3s-cluster3

# Reboot
sudo reboot
```

### After Rebooting All VMs

Wait 1-2 minutes, then check IPs:

**Run on your HOST machine:**

```bash
# Check DHCP leases
sudo cat /var/lib/libvirt/dnsmasq/virbr0.status | python3 -m json.tool

# Or use the helper script
/home/andre/vm_k3s_HA_cluster/get-vm-ips.sh
```

You should see all 3 VMs with unique IPs like:
- k3s-cluster1: 192.168.122.X
- k3s-cluster2: 192.168.122.Y
- k3s-cluster3: 192.168.122.Z

### Verify Network Connectivity

**Run on your HOST machine:**

```bash
# Test connectivity from host to each VM
ping -c 3 192.168.122.X  # cluster1
ping -c 3 192.168.122.Y  # cluster2
ping -c 3 192.168.122.Z  # cluster3
```

**Run inside one of the VMs:**

```bash
# SSH into any VM
ssh user@192.168.122.X

# Test connectivity to other VMs
ping -c 3 192.168.122.Y  # cluster2
ping -c 3 192.168.122.Z  # cluster3

# Test connectivity to host
ping -c 3 192.168.122.1  # virbr0 gateway (your host)
```

## Troubleshooting

### VM doesn't get an IP after reboot

```bash
# Access console
sudo virsh console k3s-cluster<N>

# Check network interface status
ip link show

# Check if dhclient is running
ps aux | grep dhclient

# Manually request DHCP
sudo dhclient -v
```

### Can't access VM console

```bash
# Make sure VM is running
sudo virsh list --all

# If not running, start it
sudo virsh start k3s-cluster<N>

# Force console reset
sudo virsh console k3s-cluster<N> --force
```

### VM console shows blank screen

- Press **Enter** a few times
- The login prompt should appear
- If still blank, exit (Ctrl+]) and try again

## Network Details

**Network**: virbr0 (default libvirt network)
**Subnet**: 192.168.122.0/24
**Gateway**: 192.168.122.1 (your host)
**DHCP Range**: 192.168.122.2 - 192.168.122.254

This network allows:
- ✓ VM to VM communication
- ✓ VM to Host communication
- ✓ Host to VM communication
- ✓ VMs can access internet through host NAT

## Next Steps

Once all VMs have unique IPs and can communicate:
1. Update your load balancer configuration with the actual IPs
2. Proceed with k3s cluster setup from `k3s-cluster-setup.md`
