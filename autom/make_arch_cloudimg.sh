#!/bin/bash
# This script aims to create an Arch Linux OpenStack ready Qcow2 image for KVM.

# yaourt -Sy --noconfirm --needed git qemu parted \
#                                 multipath-tools arch-install-scripts

set -e
#set -x

running_as_root() {
  test "$(/usr/bin/id -u)" -eq 0
}

K_MOD=`lsmod |grep loop`
if [ -z "$K_MOD" ]; then sudo modprobe loop; fi;

DATE=`date -Iseconds |sed -r 's/[^a-za-z0-9]//g; s/0000/0/g'`
FILE_NAME=arch-$DATE-x86_64
AMI_NAME=${FILE_NAME}.raw
QCOW2_NAME=${FILE_NAME}.qcow2
R_PASSW='password'

MOUNT_DIR=`mktemp -d -t build-img.XXXXXX`
CHROOT="sudo arch-chroot ${MOUNT_DIR}"
PARTED=/usr/bin/parted

rm -f ${AMI_NAME}

clean () {
  cat <<__EOF__
# Unmount and cleanup
# -------------------
__EOF__

  # ${CHROOT} rm /etc/machine-id /var/lib/dbus/machine-id || true
  ${CHROOT} umount /proc || true
  sudo umount ${MOUNT_DIR}
  # Run FSCK so that resize can work
  sudo tune2fs -j /dev/mapper/${LOOP} || true
  sudo fsck.ext4 -f /dev/mapper/${LOOP} || true
  sudo kpartx -d ${AMI_NAME}
  sudo rmdir ${MOUNT_DIR}
}


cat <<__EOF__
# Create initial volume and install base system
# ---------------------------------------------
__EOF__
/usr/bin/qemu-img create ${AMI_NAME} 1G || clean

${PARTED} -s ${AMI_NAME} mktable msdos
${PARTED} -s -a optimal ${AMI_NAME} mkpart primary ext4 1M 100%
${PARTED} -s ${AMI_NAME} set 1 boot on

LOOP=`sudo kpartx -av ${AMI_NAME} |grep loop |sed -e "s/.*\(loop[^ ]*\).*/\1/"`

sudo mkfs.ext4 -O ^64bit /dev/mapper/${LOOP} || clean
# -O ^64bit option as syslinux does not support it

BLOCK_ID=`sudo blkid /dev/mapper/${LOOP} |cut -d ' ' -f2 |tr -d \"`
sudo mount -o loop /dev/mapper/${LOOP} ${MOUNT_DIR} || clean
sudo pacstrap -c ${MOUNT_DIR} base || clean


cat <<__EOF__
# Miscellaneous configurations
# ----------------------------
__EOF__

${CHROOT} pacman --noconfirm -S openssh cronie syslinux || clean
${CHROOT} pacman --noconfirm -S cloud-init || clean

sudo arch-chroot ${MOUNT_DIR} sh -c "echo root:${R_PASSW} | chpasswd"
sudo sed -i "s/PermitRootLogin yes/PermitRootLogin without-password/" \
  ${MOUNT_DIR}/etc/ssh/sshd_config

echo '# Setup fstab'

echo "# /etc/fstab: static file system information.
proc	/proc	proc	nodev,noexec,nosuid	0	0
${BLOCK_ID}	/	ext4	errors=remount-ro	0	1
" | sudo tee -a ${MOUNT_DIR}/etc/fstab

echo '# Set cloud-arch as hostname'
echo "cloud-arch" |sudo tee ${MOUNT_DIR}/etc/hostname

echo '# Set timezone to UTC'
${CHROOT} rm /etc/localtime
${CHROOT} ln -s /usr/share/zoneinfo/UTC /etc/localtime

echo '# Enable sshd, dhcpcd, cronie'
${CHROOT} systemctl enable dhcpcd@eth0.service
${CHROOT} systemctl enable cronie.service
${CHROOT} systemctl enable sshd.service
# ${CHROOT} systemctl enable cloud-init.service
sudo mkdir -p ${MOUNT_DIR}/root/.ssh

echo '# Setting-up initramfs'
# Growfs used to autoresize image root disk to flavor root disk

sudo sed -i \
  '/^HOOKS=/c\HOOKS=\"base\ udev\ block\ modconf\ filesystems\ keyboard\ fsck\"' \
  ${MOUNT_DIR}/etc/mkinitcpio.conf

sudo sed -i \
  '/^MODULES=/c\MODULES=\"virtio\ virtio_blk\ virtio_pci\ virtio_net\"' \
  ${MOUNT_DIR}/etc/mkinitcpio.conf

${CHROOT} mkinitcpio -p linux

cat <<__EOF__
# Setting-up syslinux
# -------------------
__EOF__

${CHROOT} mkdir -p /boot/syslinux
${CHROOT} cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
KERNEL=`${CHROOT} find boot -name 'vmlinuz-linux'`
RAMDISK=`${CHROOT} find boot -name 'initramfs-linux.img'`
echo "PROMPT 1
TIMEOUT 50
DEFAULT arch
LABEL arch
    LINUX /${KERNEL}
    APPEND root=${BLOCK_ID} rw net.ifnames=0
    INITRD /${RAMDISK}" \
  |sudo tee ${MOUNT_DIR}/boot/syslinux/syslinux.cfg
${CHROOT} extlinux --install /boot/syslinux/
sudo dd bs=440 count=1 conv=notrunc \
        if=${MOUNT_DIR}/usr/lib/syslinux/bios/mbr.bin \
        of=${AMI_NAME}

clean


cat <<__EOF__
# Converting image to qcow2
# -------------------------
__EOF__

sudo qemu-img convert -c -f raw ${AMI_NAME} -O qcow2 ${QCOW2_NAME}
sudo rm ${AMI_NAME}

echo "# The created Arch guest system image is:"
echo `pwd`/$QCOW2_NAME
