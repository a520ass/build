#!/bin/sh

echo "Start script create MBR and filesystem"

# Check the current system running disk
root_devname="$(df / | tail -n1 | awk '{print $1}' | awk -F '/' '{print substr($3, 1, length($3)-2)}')"
if lsblk -l | grep -E "^${root_devname}boot0" >/dev/null; then
    echo "you are running in emmc mode, please boot system with usb or tf card!"
    exit 1
fi

# Find emmc disk, first find emmc containing boot0 partition
install_emmc="$(lsblk -l -o NAME | grep -oE '(mmcblk[0-9]?boot0)' | sed "s/boot0//g")"
# Find emmc disk, find emmc that does not contain the boot0 partition
if [ -z "${install_emmc}" ]; then 
 install_emmc="$(lsblk -l -o NAME | grep -oE '(mmcblk[0-9]?)' | grep -vE ^${root_devname} | uniq)"
fi
# Check if emmc exists
if [ -z "${install_emmc}" ]; then 
 echo "No emmc can be found to install the armbian system!"
 exit 1
fi
# Location of emmc
DEV_EMMC="/dev/${install_emmc}"
echo "DEV_EMMC: [ ${DEV_EMMC} ]"

echo "Start backup u-boot default"

dd if="${DEV_EMMC}" of=/root/u-boot-default-aml.img bs=1M count=4

echo "Start create MBR and partittion"

parted -s "${DEV_EMMC}" mklabel msdos
parted -s "${DEV_EMMC}" mkpart primary fat32 700M 1212M
parted -s "${DEV_EMMC}" mkpart primary ext4 1213M 100%

echo "Start restore u-boot"

dd if=/root/u-boot-default-aml.img of="${DEV_EMMC}" conv=fsync bs=1 count=442
dd if=/root/u-boot-default-aml.img of="${DEV_EMMC}" conv=fsync bs=512 skip=1 seek=1

sync

echo "Done"

echo "Start copy system for eMMC."

mkdir -p /ddbr
chmod 777 /ddbr

PART_BOOT="${DEV_EMMC}p1"
PART_ROOT="${DEV_EMMC}p2"
DIR_INSTALL="/ddbr/install"

if [ -d $DIR_INSTALL ] ; then
    rm -rf $DIR_INSTALL
fi
mkdir -p $DIR_INSTALL

if grep -q $PART_BOOT /proc/mounts ; then
    echo "Unmounting BOOT partiton."
    umount -f $PART_BOOT
fi
echo -n "Formatting BOOT partition..."
mkfs.vfat -n "BOOT_EMMC" $PART_BOOT
echo "done."

mount -o rw $PART_BOOT $DIR_INSTALL

echo -n "Copying BOOT..."
cp -r /boot/* $DIR_INSTALL && sync
echo "done."

rm $DIR_INSTALL/s9*
rm $DIR_INSTALL/aml*

if [ -f /boot/u-boot.ext ] ; then
    mv -f $DIR_INSTALL/u-boot.ext $DIR_INSTALL/u-boot.emmc
    sync
fi

if grep -q $PART_ROOT /proc/mounts ; then
    echo "Unmounting ROOT partiton."
    umount -f $PART_ROOT
fi

echo "Formatting ROOT partition..."
mke2fs -F -q -t ext4 -L ROOT_EMMC -m 0 $PART_ROOT
e2fsck -n $PART_ROOT
echo "done."

UUID=`blkid -s UUID $PART_ROOT | awk -F "\"" '{print $2}'`
echo "ROOT_EMMC UUID:${UUID}"
echo -n "Edit armbianEnv config..."
sed -i 's/rootdev=UUID=.*$/rootdev=UUID='"$UUID"'/g' "$DIR_INSTALL/armbianEnv.txt"
sed -i '/usbstoragequirks/d' "$DIR_INSTALL/armbianEnv.txt"
echo "done."

umount $DIR_INSTALL


echo "Copying ROOTFS."

mount -o rw $PART_ROOT $DIR_INSTALL

cd /
echo "Copy BIN"
tar -cf - bin | (cd $DIR_INSTALL; tar -xpf -)
#echo "Copy BOOT"
#mkdir -p $DIR_INSTALL/boot
#tar -cf - boot | (cd $DIR_INSTALL; tar -xpf -)
echo "Create DEV"
mkdir -p $DIR_INSTALL/dev
#tar -cf - dev | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy ETC"
tar -cf - etc | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy HOME"
tar -cf - home | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy LIB"
tar -cf - lib | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy LIB64"
tar -cf - lib64 | (cd $DIR_INSTALL; tar -xpf -)
echo "Create MEDIA"
mkdir -p $DIR_INSTALL/media
#tar -cf - media | (cd $DIR_INSTALL; tar -xpf -)
echo "Create MNT"
mkdir -p $DIR_INSTALL/mnt
#tar -cf - mnt | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy OPT"
tar -cf - opt | (cd $DIR_INSTALL; tar -xpf -)
echo "Create PROC"
mkdir -p $DIR_INSTALL/proc
echo "Copy ROOT"
tar -cf - root | (cd $DIR_INSTALL; tar -xpf -)
echo "Create RUN"
mkdir -p $DIR_INSTALL/run
echo "Copy SBIN"
tar -cf - sbin | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy SELINUX"
tar -cf - selinux | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy SRV"
tar -cf - srv | (cd $DIR_INSTALL; tar -xpf -)
echo "Create SYS"
mkdir -p $DIR_INSTALL/sys
echo "Create TMP"
mkdir -p $DIR_INSTALL/tmp
echo "Copy USR"
tar -cf - usr | (cd $DIR_INSTALL; tar -xpf -)
echo "Copy VAR"
tar -cf - var | (cd $DIR_INSTALL; tar -xpf -)
sync

echo "Copy fstab"

rm $DIR_INSTALL/etc/fstab
cp -a /root/fstab $DIR_INSTALL/etc/fstab

rm $DIR_INSTALL/root/install*.sh
rm $DIR_INSTALL/root/fstab
rm $DIR_INSTALL/usr/bin/ddbr


cd /
sync

umount $DIR_INSTALL

echo "*******************************************"
echo "Complete copy OS to eMMC "
echo "*******************************************"
