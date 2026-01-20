#!/bin/bash
# KERNEL SYNC: SSD -> eMMC
echo ">>> Kernel Synchronization..."

# Find eMMC (looking for p1 on mmcblk, excluding current root if it's not mmc)
EMMC_PART=$(lsblk -lp -o NAME,TYPE | grep "mmcblk" | grep "part" | grep "p1" | awk '{print $1}' | sort | tail -n 1)

if [ -z "$EMMC_PART" ]; then echo "eMMC not found!"; exit 1; fi

sudo mkdir -p /mnt/update_fix
sudo mount $EMMC_PART /mnt/update_fix

echo "Copying kernel from SSD to eMMC..."
sudo cp -r /boot/dtb* /mnt/update_fix/boot/ 2>/dev/null || sudo cp -r /boot/dtb /mnt/update_fix/boot/
sudo cp /boot/Image /mnt/update_fix/boot/
sudo cp /boot/uInitrd /mnt/update_fix/boot/
sudo cp /boot/vmlinuz* /mnt/update_fix/boot/ 2>/dev/null || true
sudo cp /boot/initrd.img* /mnt/update_fix/boot/ 2>/dev/null || true

sync
sudo umount /mnt/update_fix
echo ">>> Done! Kernels are synced."
