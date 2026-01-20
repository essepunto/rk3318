#!/bin/bash
# SAFE INSTALLER: eMMC -> SSD
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ "$EUID" -ne 0 ]; then echo -e "${RED}Запустите скрипт через sudo!${NC}"; exit 1; fi
command -v rsync >/dev/null || apt-get install -y rsync fdisk

clear
echo -e "${YELLOW}>>> МАСТЕР ПЕРЕНОСА НА SSD/USB${NC}"
CURRENT_DISK=$(findmnt / -o SOURCE -n | sed 's/p[0-9]*$//' | sed 's/[0-9]*$//')

# Выбор диска
echo "Доступные диски:"
lsblk -dpno NAME,SIZE,MODEL | grep -v "loop" | grep -v "zram" | grep -v "$CURRENT_DISK" | awk '{print NR". "$0}'
echo ""
read -p "Выберите номер диска для установки: " NUM
TARGET_DISK=$(lsblk -dpno NAME,SIZE,MODEL | grep -v "loop" | grep -v "zram" | grep -v "$CURRENT_DISK" | awk 'NR=='"$NUM"'{print $1}')

if [ -z "$TARGET_DISK" ]; then echo "Ошибка выбора (неверный номер)"; exit 1; fi

echo -e "${RED}ВНИМАНИЕ: Диск $TARGET_DISK будет полностью ОЧИЩЕН!${NC}"
read -p "Напишите YES для подтверждения: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then exit 0; fi

# Форматирование
echo "Форматирование..."
umount ${TARGET_DISK}* 2>/dev/null
wipefs -a $TARGET_DISK
echo 'type=83' | sfdisk $TARGET_DISK
mkfs.ext4 -F -L armbian-root ${TARGET_DISK}1

# Копирование
echo "Копирование системы (rsync)..."
mkdir -p /mnt/ssd_install
mount ${TARGET_DISK}1 /mnt/ssd_install
rsync -axHAWX --numeric-ids --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/ssd_install/
mkdir -p /mnt/ssd_install/{dev,proc,sys,tmp,run,mnt,media}

# Fstab и настройки загрузки
NEW_UUID=$(blkid -s UUID -o value ${TARGET_DISK}1)
OLD_UUID=$(findmnt / -o UUID -n)
sed -i "s/$OLD_UUID/$NEW_UUID/g" /mnt/ssd_install/etc/fstab

# USB Quirks (Особенности USB контроллеров)
echo "Введите ID для USB Quirks (напр. 152d:0578) или нажмите Enter для пропуска:"
read -p "> " USB_ID
QUIRKS=""
if [ ! -z "$USB_ID" ]; then QUIRKS="usbstorage.quirks=${USB_ID}:u"; fi

ENV_FILE="/boot/armbianEnv.txt"
cp $ENV_FILE $ENV_FILE.bak_install
if grep -q "rootdev=" $ENV_FILE; then
    sed -i "s|^#*rootdev=.*|rootdev=UUID=$NEW_UUID|" $ENV_FILE
else
    echo "rootdev=UUID=$NEW_UUID" >> $ENV_FILE
fi
if [ ! -z "$QUIRKS" ]; then 
    if grep -q "usbstorage.quirks" $ENV_FILE; then
        sed -i "s|^usbstorage.quirks=.*|$QUIRKS|" $ENV_FILE
    else
        echo "$QUIRKS" >> $ENV_FILE
    fi
fi

umount /mnt/ssd_install
echo -e "${GREEN}Готово! Выполните перезагрузку (sudo reboot).${NC}"
