#!/bin/bash
# Script to expand LVM filesystem inside the VM
# Run this script INSIDE each VM that needs disk expansion

set -e

echo "=========================================="
echo "LVM Filesystem Expansion Script"
echo "=========================================="
echo ""

echo "Current disk layout:"
lsblk
echo ""

echo "Current filesystem usage:"
df -h /
echo ""

echo "Step 1: Resize partition 3 to use all available space"
echo "------------------------------------------------------"
sudo growpart /dev/vda 3
echo ""

echo "Step 2: Resize the physical volume"
echo "-----------------------------------"
sudo pvresize /dev/vda3
echo ""

echo "Step 3: Extend the logical volume to use all free space"
echo "--------------------------------------------------------"
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
echo ""

echo "Step 4: Resize the filesystem"
echo "------------------------------"
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
echo ""

echo "Step 5: Verify the changes"
echo "--------------------------"
echo "New disk layout:"
lsblk
echo ""
echo "New filesystem usage:"
df -h /
echo ""

echo "=========================================="
echo "✓ LVM expansion complete!"
echo "=========================================="
