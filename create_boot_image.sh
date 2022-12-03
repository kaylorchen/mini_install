#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
device=$1
if [ ! -n "${device}" ] ; then
    echo "error, DEV is empty"
    exit
fi


ls ${device}
if [ $? -ne 0 ] ;then
    echo ${device} does not exist.
    exit
fi

total_sectors=$(sudo fdisk -l ${device} | grep sectors | grep /dev | awk -F ',' '{print $3}' | awk '{print $1}')
start_sector=2048
end_sector=$(expr $total_sectors \- 34)
echo "total_sectors=${total_sectors}, start_sector=${start_sector}, \
end_sector=${end_sector}"

echo "${device} will be formatted"
read -p "Do you want to continue? [N/y] " confirm
if [[ ${confirm} == "y" ]]; then
    echo "-----------------"
    echo "Partitioning image"
    sudo parted -s ${device} mklabel gpt
    sudo parted -a none -s ${device} unit s mkpart  EFI fat32 ${start_sector} 585727
    sudo parted -a none -s ${device} unit s mkpart  rootfs ext4 585728 ${end_sector}

    echo "Setting partition flag"
    sudo parted ${device} set 1 boot on
    sudo parted ${device} set 1 esp on

    echo "Formatting"
    sleep 3
    sudo mkfs.fat -F 32 ${device}1
    sudo mkfs.ext4 ${device}2

    echo "Mounting..."
    sudo mkdir -p rootfs
    sudo mount ${device}2 rootfs

    echo "Extract rootfs..."
    sudo mkdir -p tmp
    sudo tar -xf ubuntu*amd64.tar.gz -C tmp
    sudo cp /etc/resolv.conf tmp/etc/
    echo 'apt update
    apt install parted fdisk grub-efi-amd64 -y
    echo -e "kaylor\nkaylor\n"|passwd root
    sync
    exit
    '|sudo bash ch-mount.sh -m tmp
    rsync -az tmp/ rootfs
    sudo rm -rf tmp

    echo "Installing grub"
    sudo mkdir -p rootfs/boot/efi
    sudo mount -o rw ${device}1 rootfs/boot/efi
    sudo grub-install --target=x86_64-efi --efi-directory=rootfs/boot/efi --removable --boot-directory=rootfs/boot --bootloader-id=grub ${device}

    echo "Copying kernel to boot"
    # sudo cp /boot/vmlinuz .
    sudo cp /boot/vmlinuz-* rootfs/boot/

    echo "Modify grub"
    sudo cp rootfs/etc/default/grub rootfs/etc/default/grub.bak
    sudo echo GRUB_DISABLE_OS_PROBER=true >> rootfs/etc/default/grub 

    # echo "Chroot ......"
    # sudo mount -o bind /dev rootfs/dev
    # sudo mount -o bind /proc rootfs/proc
    # sudo mount -o bind /sys rootfs/sys

    # # echo 'df
    # # apt update
    # # apt install parted fdisk grub-efi-amd64 -y
    # # update-grub
    # # echo -e "kaylor\nkaylor\n"|passwd root
    # # sync
    # # exit
    # # '|sudo chroot rootfs

    # #  grub-install --target=x86_64-efi  /dev/sda
    # sudo chroot rootfs


    # sudo umount rootfs/dev
    # sudo umount rootfs/sys
    # sudo umount rootfs/proc
    # sudo sync

    sudo bash ch-mount.sh -m rootfs

    echo "Umounting device"
    sync
    sleep 3
    sudo umount rootfs/boot/efi
    sudo umount rootfs

    # echo "Associating loopback device to image"
    # sudo losetup /dev/loop100 --partscan --show ${device}
    # sudo mount /dev/loop100p2 rootfs
    # sudo mount -o rw /dev/loop100p1 rootfs/boot/efi

    
    # sync
    # sleep 3
    # sudo umount rootfs/boot/efi
    # sudo umount rootfs
    # sudo losetup -d /dev/loop100
   
    sudo parted -s ${device} p
    sudo fdisk -l ${device}

else
    echo "exit"
    exit
fi

echo "****************"

