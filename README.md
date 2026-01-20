# rk3318
Ставим систему c EMMC на SSD в X96MAX с SoC RK3318


# 🚀 Armbian RK3318/RK3328: SSD Boot Tools

Набор скриптов для **правильного** переноса системы Armbian с внутренней памяти (eMMC) на USB-накопитель (SSD/Flash) для TV-боксов на чипах Rockchip RK3318/RK3328.

![Platform](https://img.shields.io/badge/platform-RK3318%20%7C%20RK3328-blue)
![OS](https://img.shields.io/badge/OS-Armbian%20Linux-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ⚠️ Проблема
Большинство гайдов в интернете предлагают использовать `dd` для клонирования системы с eMMC на SSD. Это **неправильно**, так как создает конфликт UUID (два диска с одинаковым ID).

**Последствия метода `dd`:**
* Загрузчик путает разделы.
* При обновлении ядра (`apt upgrade`) новые файлы пишутся на SSD, а загрузка идет старым ядром с eMMC.
* **Итог:** Отвал Wi-Fi, USB и сети после обновлений.

## ✅ Решение
Эти скрипты используют метод чистой установки (`rsync`) и переписывания UUID, что гарантирует:
1.  Стабильную загрузку.
2.  Использование всего объема SSD.
3.  Возможность легкого восстановления при рассинхроне ядер.

---

## 🛠 Установка (Переезд на SSD)

### 1. Подготовка
1.  Загрузите Armbian с внутренней памяти (eMMC).
2.  Подключите ваш SSD или флешку.
3.  Скачайте скрипт `install.sh`.

### 2. Запуск
```bash
sudo chmod +x install.sh
sudo ./install.sh
```

**Что делает скрипт:**
* Форматирует SSD в ext4.
* Генерирует **новый уникальный UUID**.
* Копирует систему через `rsync`.
* Правит `/etc/fstab` на новом диске.
* Обновляет `armbianEnv.txt` на eMMC, указывая загрузчику новый UUID.
* Добавляет *USB Quirks* (фикс для адаптеров JMicron/ASMedia), если нужно.

<details>
<summary>📄 Показать код install.sh</summary>

```bash
#!/bin/bash
# SAFE INSTALLER: eMMC -> SSD
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [ "$EUID" -ne 0 ]; then echo -e "${RED}Run as root!${NC}"; exit 1; fi
command -v rsync >/dev/null || apt-get install -y rsync fdisk

clear
echo -e "${YELLOW}>>> SSD TRANSFER WIZARD${NC}"
CURRENT_DISK=$(findmnt / -o SOURCE -n | sed 's/p[0-9]*$//' | sed 's/[0-9]*$//')

# Select Disk
echo "Available disks:"
lsblk -dpno NAME,SIZE,MODEL | grep -v "loop" | grep -v "zram" | grep -v "$CURRENT_DISK" | awk '{print NR". "$0}'
echo ""
read -p "Select disk number: " NUM
TARGET_DISK=$(lsblk -dpno NAME,SIZE,MODEL | grep -v "loop" | grep -v "zram" | grep -v "$CURRENT_DISK" | awk 'NR=='"$NUM"'{print $1}')

if [ -z "$TARGET_DISK" ]; then echo "Invalid selection"; exit 1; fi

echo -e "${RED}WARNING: $TARGET_DISK will be WIPED!${NC}"
read -p "Type YES to confirm: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then exit 0; fi

# Format
echo "Formatting..."
umount ${TARGET_DISK}* 2>/dev/null
wipefs -a $TARGET_DISK
echo 'type=83' | sfdisk $TARGET_DISK
mkfs.ext4 -F -L armbian-root ${TARGET_DISK}1

# Copy
echo "Copying system (rsync)..."
mkdir -p /mnt/ssd_install
mount ${TARGET_DISK}1 /mnt/ssd_install
rsync -axHAWX --numeric-ids --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/ssd_install/
mkdir -p /mnt/ssd_install/{dev,proc,sys,tmp,run,mnt,media}

# Fstab & Boot config
NEW_UUID=$(blkid -s UUID -o value ${TARGET_DISK}1)
OLD_UUID=$(findmnt / -o UUID -n)
sed -i "s/$OLD_UUID/$NEW_UUID/g" /mnt/ssd_install/etc/fstab

# USB Quirks
echo "Enter USB Quirk ID (e.g. 152d:0578) or press Enter to skip:"
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
echo -e "${GREEN}Done! Please reboot.${NC}"
```
</details>

---

## 🛡 Безопасность обновлений (Важно!)

Так как загрузчик находится на eMMC, а система на SSD, обновление ядра через `apt upgrade` может сломать Wi-Fi (обновляется ядро на SSD, а грузится старое с eMMC).

**Рекомендуется заморозить обновление ядра:**

```bash
sudo apt-mark hold linux-image-edge-rockchip64 linux-dtb-edge-rockchip64 linux-u-boot-rk3318-box-edge
```
*(Если используете ветку current, замените `edge` на `current`)*.

---

## 🚑 Восстановление (Fix Kernel)

Если вы обновили ядро и **отвалился Wi-Fi/USB**, используйте скрипт `fix-kernel.sh`. Он синхронизирует ядра, копируя новую версию с SSD на eMMC.

```bash
sudo chmod +x fix-kernel.sh
sudo ./fix-kernel.sh
sudo reboot
```

<details>
<summary>📄 Показать код fix-kernel.sh</summary>

```bash
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
```
</details>

---

## 🔄 Переключение загрузки (Boot Selector)

Если нужно вернуться на eMMC или загрузиться с другого диска, используйте `boot-select.sh`. Он сканирует UUID всех дисков и прописывает нужный в загрузчик.

```bash
sudo chmod +x boot-select.sh
sudo ./boot-select.sh
```

<details>
<summary>📄 Показать код boot-select.sh</summary>

```bash
#!/bin/bash
# BOOT SELECTOR
if [ "$EUID" -ne 0 ]; then echo "Run as root!"; exit 1; fi

echo "Available boot partitions:"
raw_list=$(lsblk -rn -o NAME,SIZE,TYPE,UUID | grep "part" | grep -v -e "^$" | grep "-")
declare -a uuids
i=1
while read -r line; do
    dev=$(echo $line | awk '{print $1}')
    size=$(echo $line | awk '{print $2}')
    uuid=$(echo $line | awk '{print $4}')
    uuids[$i]=$uuid
    echo "[$i] /dev/$dev ($size) UUID: $uuid"
    ((i++))
done <<< "$raw_list"

echo ""
read -p "Select partition number to boot from: " N
CHOSEN_UUID=${uuids[$N]}

if [ -z "$CHOSEN_UUID" ]; then echo "Error."; exit 1; fi

# Mount eMMC & Edit config
EMMC_PART=$(lsblk -lp -o NAME | grep "mmcblk" | grep "p1" | sort | tail -n 1)
mkdir -p /mnt/boot_sel
mount $EMMC_PART /mnt/boot_sel

ENV="/mnt/boot_sel/boot/armbianEnv.txt"
cp $ENV $ENV.bak_sel
if grep -q "rootdev=" $ENV; then
    sed -i "s|^#*rootdev=.*|rootdev=UUID=$CHOSEN_UUID|" $ENV
else
    echo "rootdev=UUID=$CHOSEN_UUID" >> $ENV
fi

umount /mnt/boot_sel
echo "Boot switched to UUID=$CHOSEN_UUID. Reboot now."
```
</details>

---

## Disclaimer
Эти скрипты предоставляются "как есть". Автор не несет ответственности за потерянные данные. Всегда делайте бэкапы перед форматированием дисков.
