#!/bin/bash
# BOOT SELECTOR (ВЫБОР ЗАГРУЗОЧНОГО ДИСКА)
if [ "$EUID" -ne 0 ]; then echo "Нужен sudo!"; exit 1; fi

echo "Доступные разделы для загрузки:"
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
read -p "Выберите номер раздела для загрузки: " N
CHOSEN_UUID=${uuids[$N]}

if [ -z "$CHOSEN_UUID" ]; then echo "Ошибка."; exit 1; fi

# Монтирование eMMC и правка конфига
EMMC_PART=$(lsblk -lp -o NAME | grep "mmcblk" | grep "p1" | sort | tail -n 1)
mkdir -p /mnt/boot_sel
mount $EMMC_PART /mnt/boot_sel

ENV="/mnt/boot_sel/boot/armbianEnv.txt"
cp $ENV $ENV
