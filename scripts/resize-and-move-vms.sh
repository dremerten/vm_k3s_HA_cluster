#!/bin/bash

# Script to resize VMs and move disks to /home/kvm_vms_data
# Requirements:
#   - k3s-cluster1: 2 CPU, 4GB RAM, 40GB disk
#   - k3s-cluster2: 2 CPU, 4GB RAM, 10GB disk
#   - k3s-cluster3: 2 CPU, 4GB RAM, 10GB disk
#   - All disks moved to /home/kvm_vms_data

set -e

NEW_DISK_DIR="/home/kvm_vms_data"

echo "=========================================="
echo "VM Resize and Move Script"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

echo "Step 1: Create new disk directory"
echo "----------------------------------------"
mkdir -p "$NEW_DISK_DIR"
chown libvirt-qemu:kvm "$NEW_DISK_DIR" || chown qemu:qemu "$NEW_DISK_DIR" || true
chmod 755 "$NEW_DISK_DIR"
echo "✓ Created $NEW_DISK_DIR"
echo ""

echo "Step 2: Check current VM status"
echo "----------------------------------------"
virsh list --all | grep k3s-cluster
echo ""

echo "Step 3: Shutdown all VMs"
echo "----------------------------------------"
for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    if virsh list --state-running | grep -q "$vm"; then
        echo "Shutting down $vm..."
        virsh shutdown "$vm"
    else
        echo "$vm already stopped"
    fi
done

echo "Waiting 30 seconds for graceful shutdown..."
sleep 30

# Force shutdown if still running
for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    if virsh list --state-running | grep -q "$vm"; then
        echo "Force stopping $vm..."
        virsh destroy "$vm"
    fi
done
echo "✓ All VMs stopped"
echo ""

echo "Step 4: Process each VM"
echo "----------------------------------------"

# Process k3s-cluster1 (40GB disk)
echo "Processing k3s-cluster1 (40GB disk, 2 CPU, 4GB RAM)..."
OLD_DISK_1="/var/lib/libvirt/images/k3s-cluster1.qcow2"
NEW_DISK_1="$NEW_DISK_DIR/k3s-cluster1.qcow2"

if [ -f "$OLD_DISK_1" ]; then
    echo "  Current disk info:"
    qemu-img info "$OLD_DISK_1" | grep -E "virtual size|disk size|file format"

    echo "  Moving disk to $NEW_DISK_DIR..."
    mv "$OLD_DISK_1" "$NEW_DISK_1"

    echo "  Resizing disk to 40GB..."
    qemu-img resize "$NEW_DISK_1" 40G

    echo "  Updating VM configuration..."
    virsh detach-disk k3s-cluster1 vda --config || true
    virsh attach-disk k3s-cluster1 "$NEW_DISK_1" vda --driver qemu --subdriver qcow2 --targetbus virtio --config

    echo "  Updating CPU and RAM..."
    virsh setvcpus k3s-cluster1 2 --config --maximum
    virsh setvcpus k3s-cluster1 2 --config
    virsh setmaxmem k3s-cluster1 4G --config
    virsh setmem k3s-cluster1 4G --config

    echo "✓ k3s-cluster1 complete"
else
    echo "  WARNING: Disk not found at $OLD_DISK_1"
fi
echo ""

# Process k3s-cluster2 (10GB disk)
echo "Processing k3s-cluster2 (10GB disk, 2 CPU, 4GB RAM)..."
OLD_DISK_2="/var/lib/libvirt/images/k3s-cluster2.qcow2"
NEW_DISK_2="$NEW_DISK_DIR/k3s-cluster2.qcow2"

if [ -f "$OLD_DISK_2" ]; then
    echo "  Current disk info:"
    qemu-img info "$OLD_DISK_2" | grep -E "virtual size|disk size|file format"

    echo "  Moving disk to $NEW_DISK_DIR..."
    mv "$OLD_DISK_2" "$NEW_DISK_2"

    echo "  Resizing disk to 10GB..."
    qemu-img resize "$NEW_DISK_2" 10G

    echo "  Updating VM configuration..."
    virsh detach-disk k3s-cluster2 vda --config || true
    virsh attach-disk k3s-cluster2 "$NEW_DISK_2" vda --driver qemu --subdriver qcow2 --targetbus virtio --config

    echo "  Updating CPU and RAM..."
    virsh setvcpus k3s-cluster2 2 --config --maximum
    virsh setvcpus k3s-cluster2 2 --config
    virsh setmaxmem k3s-cluster2 4G --config
    virsh setmem k3s-cluster2 4G --config

    echo "✓ k3s-cluster2 complete"
else
    echo "  WARNING: Disk not found at $OLD_DISK_2"
fi
echo ""

# Process k3s-cluster3 (10GB disk)
echo "Processing k3s-cluster3 (10GB disk, 2 CPU, 4GB RAM)..."
OLD_DISK_3="/var/lib/libvirt/images/k3s-cluster3.qcow2"
NEW_DISK_3="$NEW_DISK_DIR/k3s-cluster3.qcow2"

if [ -f "$OLD_DISK_3" ]; then
    echo "  Current disk info:"
    qemu-img info "$OLD_DISK_3" | grep -E "virtual size|disk size|file format"

    echo "  Moving disk to $NEW_DISK_DIR..."
    mv "$OLD_DISK_3" "$NEW_DISK_3"

    echo "  Resizing disk to 10GB..."
    qemu-img resize "$NEW_DISK_3" 10G

    echo "  Updating VM configuration..."
    virsh detach-disk k3s-cluster3 vda --config || true
    virsh attach-disk k3s-cluster3 "$NEW_DISK_3" vda --driver qemu --subdriver qcow2 --targetbus virtio --config

    echo "  Updating CPU and RAM..."
    virsh setvcpus k3s-cluster3 2 --config --maximum
    virsh setvcpus k3s-cluster3 2 --config
    virsh setmaxmem k3s-cluster3 4G --config
    virsh setmem k3s-cluster3 4G --config

    echo "✓ k3s-cluster3 complete"
else
    echo "  WARNING: Disk not found at $OLD_DISK_3"
fi
echo ""

echo "Step 5: Start all VMs"
echo "----------------------------------------"
for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    echo "Starting $vm..."
    virsh start "$vm"
done
echo "✓ All VMs started"
echo ""

echo "Step 6: Verify new configuration"
echo "----------------------------------------"
sleep 5
for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    echo "=== $vm ==="
    virsh dominfo "$vm" | grep -E "CPU|Max memory|Used memory"
    virsh domblklist "$vm" | grep vda
    echo ""
done

echo "=========================================="
echo "IMPORTANT: Disk resize at QEMU level is complete."
echo "You must ALSO resize the filesystem inside each VM:"
echo ""
echo "1. SSH into each VM"
echo "2. Run: sudo growpart /dev/vda 1"
echo "3. Run: sudo resize2fs /dev/vda1  (or xfs_growfs / if using XFS)"
echo "4. Verify: df -h"
echo "=========================================="
echo ""
echo "✓ Script complete!"
