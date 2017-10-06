#!/bin/bash
# This script aims to create an Arch Linux OpenStack ready Qcow2 image for KVM.

# yaourt -Sy --noconfirm --needed git qemu parted mbr \
#                                 multipath-tools arch-install-scripts

set -e
set -x

sudo modprobe loop

FILE_NAME=arch-$(date '+%Y%m%d')-x86_64
AMI_NAME=${FILE_NAME}.raw
QCOW2_NAME=${FILE_NAME}.qcow2
rm -f ${AMI_NAME}


# Create initial volume and install base system
# =============================================

PARTED=/usr/bin/parted
/usr/bin/qemu-img create ${AMI_NAME} 1G

${PARTED} -s ${AMI_NAME} mktable msdos
${PARTED} -s -a optimal ${AMI_NAME} mkpart primary ext4 1M 100%
${PARTED} -s ${AMI_NAME} set 1 boot on
install-mbr ${AMI_NAME}

LOOP=`sudo kpartx -av ${AMI_NAME} |grep loop |sed -e "s/.*\(loop[^ ]*\).*/\1/"`

sudo mkfs.ext4 /dev/mapper/${LOOP}

BLOCK_ID=`sudo blkid /dev/mapper/${LOOP} |cut -d ' ' -f2`
MOUNT_DIR=`mktemp -d -t build-img.XXXXXX`
sudo mount -o loop /dev/mapper/${LOOP} ${MOUNT_DIR}
sudo pacstrap -c ${MOUNT_DIR} base


# Misc conf
# =========

sudo arch-chroot ${MOUNT_DIR} sh -c "echo root:password | chpasswd"
#sed -i "s/PermitRootLogin yes/PermitRootLogin without-password/" \
#  ${MOUNT_DIR}/etc/ssh/sshd_config

# Setup fstab
echo "# /etc/fstab: static file system information.
proc	/proc	proc	nodev,noexec,nosuid	0	0
UUID=${BLOCK_ID}	/	ext4	errors=remount-ro	0	1
" | sudo tee -a ${MOUNT_DIR}/etc/fstab

# Set a basic hostname
echo "cloud-arch" |sudo tee ${MOUNT_DIR}/etc/hostname

# Timezone
sudo arch-chroot ${MOUNT_DIR} rm /etc/localtime
sudo arch-chroot ${MOUNT_DIR} ln -s /usr/share/zoneinfo/UTC /etc/localtime

# Services
sudo arch-chroot ${MOUNT_DIR} pacman --noconfirm -S openssh cronie syslinux
sudo arch-chroot ${MOUNT_DIR} systemctl enable dhcpcd@eth0.service
sudo arch-chroot ${MOUNT_DIR} systemctl enable cronie.service
sudo arch-chroot ${MOUNT_DIR} systemctl enable sshd.service
sudo mkdir -p ${MOUNT_DIR}/root/.ssh

# Setting-up initramfs
sudo arch-chroot ${MOUNT_DIR} mkinitcpio -p linux
# sudo sed -i -r -e '/^HOOKS=/ { s/fsck/fsck growfs/ }' \
#   ${MOUNT_DIR}/etc/mkinitcpio.conf


# Setting-up syslinux
# ===================

sudo mkdir -p ${MOUNT_DIR}/boot/syslinux
sudo cp ${MOUNT_DIR}/usr/lib/syslinux/bios/*.c32 ${MOUNT_DIR}/boot/syslinux/
ls ${MOUNT_DIR}/boot/syslinux/
KERNEL=`sudo chroot ${MOUNT_DIR} find boot -name 'vmlinuz-linux'`
RAMDISK=`sudo chroot ${MOUNT_DIR} find boot -name 'initramfs-linux.img'`
echo "default linux
timeout 1
label linux
kernel ${KERNEL}
append initrd=${RAMDISK} root=UUID=${BLOCK_ID} ro quiet" \
  |sudo tee ${MOUNT_DIR}/boot/syslinux/syslinux.cfg
sudo arch-chroot ${MOUNT_DIR} extlinux -i /boot/syslinux
sudo arch-chroot ${MOUNT_DIR} dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=/dev/mapper/${LOOP}

# Unmount and cleanup everything
# ==============================

sudo chroot ${MOUNT_DIR} umount /proc || true
sudo umount ${MOUNT_DIR}
# Run FSCK so that resize can work
sudo tune2fs -j /dev/mapper/${LOOP} || true
sudo fsck.ext4 -f /dev/mapper/${LOOP} || true
sudo kpartx -d ${AMI_NAME}
sudo rmdir ${MOUNT_DIR}


# Convert Final Image
# ===================

sudo qemu-img convert -c -f raw ${AMI_NAME} -O qcow2 ${QCOW2_NAME}
sudo rm ${AMI_NAME}
