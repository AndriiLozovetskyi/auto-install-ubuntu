#!/usr/bin/env bash

config_file="config.ini"

function read_ini {
    local section="$1"
    local key="$2"

    # Зчитуємо значення
    value=$(grep -E "^\[$section\]" -A 1000 "$config_file" | grep -E "^\s*$key\s*=" | cut -d '=' -f 2- | sed 's/^[ \t]*//;s/[ \t]*$//')

    echo "$value"
}


IMAGE=$(read_ini "conf" "IMAGE")
DIR=$(read_ini "conf" "DIR")

HOSTNAME=$(read_ini "conf" "HOSTNAME")
USERNAME=$(read_ini "conf" "USERNAME")
PASSWORD=$(echo -n $(read_ini "conf" "PASSWORD") | openssl passwd -6 -stdin)


echo 'UNZIP ISO...'

sudo apt update -y; sudo apt install -y \
  p7zip xorriso whois

rm -rf $DIR
mkdir $DIR

7z -y x $IMAGE -o$DIR

mv  $DIR/'[BOOT]' ./BOOT

GRUB_CONFIG=$(cat << 'EOF'
menuentry 'Autoinstall Ubuntu Server' {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/server/  ---
    initrd  /casper/initrd
}
EOF
)

echo "$GRUB_CONFIG" | sed '1s/^/ /' "$DIR/boot/grub/grub.cfg" | tee -a "$DIR/boot/grub/grub.cfg"

echo 'ZIP ISO...'


mkdir $DIR/server

cp -r ubuntu-settings/* $DIR/

# If not exist files
touch $DIR/server/meta-data
touch $DIR/server/user-data

cd $DIR
xorriso -as mkisofs -r \
  -V 'Ubuntu LTS AUTO (EFIBIOS)' \
  -o ../ubuntu-autoinstall.iso \
  --grub2-mbr ../BOOT/1-Boot-NoEmul.img \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c '/boot.catalog' \
  -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:::' \
  -no-emul-boot \
  .