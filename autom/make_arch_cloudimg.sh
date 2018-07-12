#!/bin/bash

# This script create an Arch Linux OpenStack ready Qcow2 image for KVM.
# 
# Dependencies: git qemu parted multipath-tools arch-install-scripts

debug="no"
open_interactive_shell="yes"

pkgs="testing userland network system cloud"
disk_size=4
password="password"

testing="iperf3 tcpdump nmap strace hdparm sysstat fio 
         netperf hping perf bmon"
userland="sudo vim git zsh ipython2 unzip wget curl rsync screen"
cloud="python-openstackclient numactl"
network="bridge-utils iproute2 iputils net-tools openvswitch ethtool"
system="lsof openbsd-netcat openresolv openssl haproxy nginx htop"


if [ $debug = 'yes' ]; then
  set -e
  set -x
fi

running_as_root() {
  test "$(/usr/bin/id -u)" -eq 0
}

if [ -z `lsmod |grep loop` ]; then sudo modprobe loop; fi;

DATE=`date -Iseconds |sed -r 's/[^a-za-z0-9]//g; s/0000/0/g'`
FILE_NAME=arch-cloudimg-$DATE-x86_64
AMI_NAME=$FILE_NAME.raw
QCOW2_NAME=$FILE_NAME.qcow2

MOUNT_DIR=`mktemp -d -t build-img.XXXXXX`
CHROOT="sudo arch-chroot $MOUNT_DIR"

rm -f $AMI_NAME ||true

clean () {
  cat <<__EOF__
# Unmount and cleanup
# -------------------
__EOF__
  # $CHROOT rm /etc/machine-id /var/lib/dbus/machine-id || true
  $CHROOT umount /proc || true
  sudo umount $MOUNT_DIR
  # Run FSCK so that resize can work
  sudo tune2fs -j /dev/mapper/$LOOP || true
  sudo fsck.ext4 -f /dev/mapper/$LOOP || true
  sudo kpartx -d $AMI_NAME
  sudo rmdir $MOUNT_DIR
}


cat <<__EOF__
# Create initial volume and install base system
# ---------------------------------------------
__EOF__
/usr/bin/qemu-img create $AMI_NAME ${disk_size}G || clean

PARTED=/usr/bin/parted
$PARTED -s $AMI_NAME mktable msdos
$PARTED -s -a optimal $AMI_NAME mkpart primary ext4 1M 100%
$PARTED -s $AMI_NAME set 1 boot on

LOOP=`sudo kpartx -av $AMI_NAME |grep loop |sed -e "s/.*\(loop[^ ]*\).*/\1/"`

sudo mkfs.ext4 -O ^64bit /dev/mapper/$LOOP || clean
# -O ^64bit option as syslinux does not support it

BLOCK_ID=`sudo blkid /dev/mapper/$LOOP |cut -d ' ' -f2 |tr -d \"`
sudo mount -o loop /dev/mapper/$LOOP $MOUNT_DIR || clean
sudo pacstrap -c $MOUNT_DIR base || clean


cat <<__EOF__
# Miscellaneous configurations
# ----------------------------
__EOF__
PACMAN="$CHROOT pacman --noconfirm -S"

for x in $pkgs; do i+=$(eval echo "\ \$$x"); done

echo "The following packages will be installed: \n $i"

$PACMAN openssh cronie syslinux || clean
$PACMAN $i || clean

$CHROOT sh -c "useradd cloud"
$CHROOT sh -c "mkdir ~cloud && chown -R cloud.cloud ~cloud"
$CHROOT sh -c 'echo "cloud ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers'
$CHROOT sh -c "echo cloud:$password | chpasswd"
$CHROOT sh -c "echo root:$password | chpasswd"

echo '# Setup fstab'

echo "# /etc/fstab: static file system information.
proc	/proc	proc	nodev,noexec,nosuid	0	0
$BLOCK_ID	/	ext4	errors=remount-ro	0	1
" | sudo tee -a $MOUNT_DIR/etc/fstab

echo '# Set cloud-arch as hostname'
echo "cloud-arch" |sudo tee $MOUNT_DIR/etc/hostname

echo '# Set timezone to UTC'
$CHROOT rm /etc/localtime
$CHROOT ln -s /usr/share/zoneinfo/UTC /etc/localtime

echo '# Enable sshd, dhcpcd, cronie'
$CHROOT systemctl enable dhcpcd@eth0.service
$CHROOT systemctl enable cronie.service
$CHROOT systemctl enable sshd.service
# $CHROOT systemctl enable cloud-init-local.service
# $CHROOT systemctl enable cloud-init.service
# $CHROOT systemctl enable cloud-init-config.service
# $CHROOT systemctl enable cloud-init-final.service
sudo mkdir -p $MOUNT_DIR/root/.ssh

echo '# Setting-up initramfs'
# Growfs used to autoresize image root disk to flavor root disk

sudo sed -i \
  '/^HOOKS=/c\HOOKS=\"base\ udev\ block\ modconf\ filesystems\ keyboard\ fsck\"' \
  $MOUNT_DIR/etc/mkinitcpio.conf
sudo sed -i \
  '/^MODULES=/c\MODULES=\"virtio\ virtio_blk\ virtio_pci\ virtio_net\"' \
  $MOUNT_DIR/etc/mkinitcpio.conf

$CHROOT mkinitcpio -p linux

cat <<__EOF__
# Setting-up syslinux
# -------------------
__EOF__

$CHROOT mkdir -p /boot/syslinux
$CHROOT cp /usr/lib/syslinux/bios/*.c32 /boot/syslinux/
kernel=`$CHROOT find boot -name 'vmlinuz-linux'`
ramdisk=`$CHROOT find boot -name 'initramfs-linux.img'`
echo "PROMPT 1
TIMEOUT 50
DEFAULT arch
LABEL arch
    LINUX /$kernel
    APPEND root=$BLOCK_ID rw net.ifnames=0
    INITRD /$ramdisk" \
  |sudo tee $MOUNT_DIR/boot/syslinux/syslinux.cfg
$CHROOT extlinux --install /boot/syslinux/
sudo dd bs=440 count=1 conv=notrunc \
        if=$MOUNT_DIR/usr/lib/syslinux/bios/mbr.bin \
        of=$AMI_NAME

if [ $open_interactive_shell = 'yes' ]; then
  echo "Launching interactive shell, [ctrl]+D to exit and continue"
  $CHROOT || True
fi

# Umount and clean directories and loop device
clean

cat <<__EOF__
# Converting image to qcow2
# -------------------------
__EOF__

sudo qemu-img convert -c -f raw $AMI_NAME -O qcow2 ${QCOW2_NAME}
# sudo rm $AMI_NAME

echo "# The created Arch guest system image is:"
echo `pwd`/$QCOW2_NAME
