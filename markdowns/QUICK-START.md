# Quick Start: Fix VM Network and Get IPs

## Step 1: Access and Fix Each VM

Open 3 terminal windows and run these commands (one per window):

### Terminal 1 - Fix k3s-cluster1:
```bash
sudo virsh console k3s-cluster1
# Press Enter if blank screen
# Login with your credentials
# Then run:
sudo hostnamectl set-hostname k3s-cluster1 && \
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id && \
sudo systemd-machine-id-setup && \
sudo reboot
# Press Ctrl+] to exit console
```

### Terminal 2 - Fix k3s-cluster2:
```bash
sudo virsh console k3s-cluster2
# Press Enter, login, then run:
sudo hostnamectl set-hostname k3s-cluster2 && \
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id && \
sudo systemd-machine-id-setup && \
sudo reboot
# Press Ctrl+] to exit
```

### Terminal 3 - Fix k3s-cluster3:
```bash
sudo virsh console k3s-cluster3
# Press Enter, login, then run:
sudo hostnamectl set-hostname k3s-cluster3 && \
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id && \
sudo systemd-machine-id-setup && \
sudo reboot
# Press Ctrl+] to exit
```

## Step 2: Wait for Reboot

Wait 60 seconds for all VMs to reboot and get new IPs.

## Step 3: Get All IPs

```bash
cd /home/andre/vm_k3s_HA_cluster
./get-vm-ips.sh
```

Or check DHCP leases directly:

```bash
sudo cat /var/lib/libvirt/dnsmasq/virbr0.status | python3 -m json.tool
```

You should now see 3 VMs with:
- Correct hostnames (k3s-cluster1, k3s-cluster2, k3s-cluster3)
- Unique IP addresses (192.168.122.X)

## Step 4: Test Connectivity

```bash
# Get the IPs from step 3, then:
ping -c 2 <cluster1-ip>
ping -c 2 <cluster2-ip>
ping -c 2 <cluster3-ip>
```

## Step 5: Proceed with K3s Setup

Once you have all 3 IPs, update the load balancer configuration and follow:
```bash
cat k3s-cluster-setup.md
```

## Troubleshooting

**Can't see login prompt?**
- Press Enter several times
- Wait a few seconds
- Try `sudo virsh console <vm-name> --force`

**VM not getting IP?**
- Make sure it rebooted: `sudo virsh list`
- Try restarting: `sudo virsh reboot <vm-name>`
- Check inside VM: `sudo virsh console <vm-name>`, then `ip addr show`

**Need to exit console?**
- Press: `Ctrl + ]`
