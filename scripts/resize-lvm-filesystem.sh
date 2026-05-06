#!/bin/bash

# Script to resize LVM filesystem after QEMU disk expansion
# Run this INSIDE each VM after the disk has been resized

set -e

echo "=========================================="
echo "LVM Filesystem Resize Script"
echo "=========================================="
echo ""

echo "Current disk layout:"
echo "----------------------------------------"
lsblk
echo ""

echo "Current filesystem usage:"
echo "----------------------------------------"
df -h
echo ""

echo "Step 1: Rescan disk for new size"
echo "----------------------------------------"
sudo echo 1 > /sys/block/vda/device/rescan 2>/dev/null || true
echo "✓ Disk rescanned"
echo ""

echo "Step 2: Check physical volume"
echo "----------------------------------------"
sudo pvdisplay
echo ""

echo "Step 3: Resize physical partition (vda3 for LVM)"
echo "----------------------------------------"
# First, check which partition contains the LVM physical volume
PV_PARTITION=$(sudo pvdisplay | grep "PV Name" | awk '{print $3}')
echo "LVM Physical Volume is on: $PV_PARTITION"

# Get the partition number (e.g., /dev/vda3 -> 3)
PART_NUM=$(echo "$PV_PARTITION" | grep -o '[0-9]*$')
echo "Partition number: $PART_NUM"

echo "Growing partition $PART_NUM..."
sudo growpart /dev/vda $PART_NUM || echo "Partition already at max size or growpart not needed"
echo ""

echo "Step 4: Resize physical volume"
echo "----------------------------------------"
sudo pvresize "$PV_PARTITION"
echo "✓ Physical volume resized"
echo ""

echo "Step 5: Check volume group"
echo "----------------------------------------"
sudo vgdisplay
echo ""

echo "Step 6: Extend logical volume to use all free space"
echo "----------------------------------------"
LV_PATH="/dev/mapper/ubuntu--vg-ubuntu--lv"
echo "Extending $LV_PATH to use 100% of VG..."
sudo lvextend -l +100%FREE "$LV_PATH"
echo "✓ Logical volume extended"
echo ""

echo "Step 7: Resize filesystem"
echo "----------------------------------------"
# Detect filesystem type
FS_TYPE=$(df -T "$LV_PATH" | tail -1 | awk '{print $2}')
echo "Filesystem type: $FS_TYPE"

if [ "$FS_TYPE" = "ext4" ] || [ "$FS_TYPE" = "ext3" ]; then
    echo "Resizing ext4 filesystem..."
    sudo resize2fs "$LV_PATH"
elif [ "$FS_TYPE" = "xfs" ]; then
    echo "Resizing XFS filesystem..."
    sudo xfs_growfs /
else
    echo "Unknown filesystem type: $FS_TYPE"
    echo "Please resize manually"
    exit 1
fi
echo "✓ Filesystem resized"
echo ""

echo "=========================================="
echo "Final Results:"
echo "=========================================="
echo ""

echo "Disk layout:"
lsblk
echo ""

echo "Filesystem usage:"
df -h
echo ""

echo "✓ Resize complete!"
echo "=========================================="
