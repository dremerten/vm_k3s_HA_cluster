#!/bin/bash
# Script to delete old VMs and clone k3s-cluster1 to create cluster2 and cluster3

set -e

echo "=========================================="
echo "VM Clone Script"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

echo "Step 1: Shutdown and delete old k3s-cluster2 and k3s-cluster3"
echo "--------------------------------------------------------------"
for vm in k3s-cluster2 k3s-cluster3; do
    if virsh list --state-running | grep -q "$vm"; then
        echo "Shutting down $vm..."
        virsh shutdown "$vm"
    fi
done

echo "Waiting 15 seconds for graceful shutdown..."
sleep 15

# Force shutdown if still running
for vm in k3s-cluster2 k3s-cluster3; do
    if virsh list --state-running | grep -q "$vm"; then
        echo "Force stopping $vm..."
        virsh destroy "$vm"
    fi
done

# Undefine the VMs
for vm in k3s-cluster2 k3s-cluster3; do
    echo "Undefining $vm..."
    virsh undefine "$vm" --nvram || virsh undefine "$vm" || true
done

# Remove old disk files
echo "Removing old disk files..."
rm -f /home/kvm_vms_data/k3s-c2/k3s-cluster2.qcow2
rm -f /home/kvm_vms_data/k3s-c3/k3s-cluster3.qcow2

echo "✓ Old VMs deleted"
echo ""

echo "Step 2: Shutdown k3s-cluster1 for cloning"
echo "------------------------------------------"
if virsh list --state-running | grep -q "k3s-cluster1"; then
    echo "Shutting down k3s-cluster1..."
    virsh shutdown k3s-cluster1
    echo "Waiting 20 seconds for graceful shutdown..."
    sleep 20

    # Force shutdown if still running
    if virsh list --state-running | grep -q "k3s-cluster1"; then
        echo "Force stopping k3s-cluster1..."
        virsh destroy k3s-cluster1
    fi
fi
echo "✓ k3s-cluster1 is shut down"
echo ""

echo "Step 3: Clone k3s-cluster1 to k3s-cluster2 (12GB disk)"
echo "-------------------------------------------------------"
virt-clone \
  --original k3s-cluster1 \
  --name k3s-cluster2 \
  --file /home/kvm_vms_data/k3s-c2/k3s-cluster2.qcow2

echo "Resizing k3s-cluster2 disk to 12GB..."
qemu-img resize /home/kvm_vms_data/k3s-c2/k3s-cluster2.qcow2 12G --shrink

echo "✓ k3s-cluster2 created"
echo ""

echo "Step 4: Clone k3s-cluster1 to k3s-cluster3 (12GB disk)"
echo "-------------------------------------------------------"
virt-clone \
  --original k3s-cluster1 \
  --name k3s-cluster3 \
  --file /home/kvm_vms_data/k3s-c3/k3s-cluster3.qcow2

echo "Resizing k3s-cluster3 disk to 12GB..."
qemu-img resize /home/kvm_vms_data/k3s-c3/k3s-cluster3.qcow2 12G --shrink

echo "✓ k3s-cluster3 created"
echo ""

echo "Step 5: Start all VMs"
echo "---------------------"
for vm in k3s-cluster1 k3s-cluster2 k3s-cluster3; do
    echo "Starting $vm..."
    virsh start "$vm"
done
echo "✓ All VMs started"
echo ""

echo "Step 6: Display VM information"
echo "-------------------------------"
sleep 5
virsh list --all
echo ""

echo "=========================================="
echo "IMPORTANT: Post-clone configuration needed!"
echo "=========================================="
echo ""
echo "For k3s-cluster2 and k3s-cluster3, you must:"
echo ""
echo "1. SSH into each VM"
echo "2. Change hostname:"
echo "   sudo hostnamectl set-hostname k3s-cluster2  # or k3s-cluster3"
echo ""
echo "3. Update /etc/hosts"
echo ""
echo "4. Change static IP (if configured):"
echo "   Edit /etc/netplan/*.yaml"
echo ""
echo "5. Shrink LVM to fit in 12GB disk:"
echo "   sudo lvreduce -L 9G /dev/ubuntu-vg/ubuntu-lv"
echo "   sudo resize2fs /dev/ubuntu-vg/ubuntu-lv"
echo "   sudo pvresize --setphysicalvolumesize 10.5G /dev/vda3"
echo ""
echo "6. Reboot each VM"
echo ""
echo "=========================================="
echo "✓ Clone script complete!"
