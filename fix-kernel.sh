#!/bin/bash
# KERNEL SYNC: SSD -> eMMC
echo ">>> Синхронизация ядра..."

# Поиск eMMC (ищем раздел p1 на устройстве mmcblk, исключая текущий корень, если это не mmc)
EMMC_PART=$(lsblk -lp -o NAME,TYPE | grep "mmcblk" | grep "part" | grep "p1" | awk '{print $1}' | sort | tail -n 1)

if [ -z "$EMMC_PART" ]; then echo "eMMC не найдена!"; exit 1; fi

sudo mkdir -p /mnt/update_fix
sudo mount $EMMC_PART /mnt/update_fix

echo "Копирование ядра с SSD на eMMC..."
sudo cp -r /boot/dtb* /mnt/update_fix/boot/ 2>/dev/null || sudo cp -r /boot/dtb /mnt/update_fix/boot/
sudo cp /boot/Image /mnt/update_fix/boot/
sudo cp /boot/uInitrd /mnt/update_fix/boot/
sudo cp /boot/vmlinuz* /mnt/update_fix/boot/ 2>/dev/null || true
sudo cp /boot/initrd.img* /mnt/update_fix/boot/ 2>/dev/null || true

sync
sudo umount /mnt/update_fix
echo ">>> Готово! Ядра синхронизированы."
