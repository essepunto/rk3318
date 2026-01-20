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
