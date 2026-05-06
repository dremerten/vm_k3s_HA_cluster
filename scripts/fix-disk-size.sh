#!/bin/bash

# Fix disk size inside VM - run with sudo
set -e

echo "Current disk layout:"
lsblk
echo ""

echo "Step 1: Grow partition 3 to use available space"
sudo growpart /dev/vda 3
echo ""

echo "Step 2: Resize physical volume"
sudo pvresize /dev/vda3
echo ""

echo "Step 3: Extend logical volume"
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
echo ""

echo "Step 4: Resize filesystem"
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
echo ""

echo "Done! New disk usage:"
df -h /
lsblk
