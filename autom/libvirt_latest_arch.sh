IMG_NAME=`ls -at arch-*-x86_64.qcow2 |head -n1`
sudo virsh destroy arch_epheo
sudo virsh undefine arch_epheo
sudo mv ${IMG_NAME} /var/lib/libvirt/images/arch-latest-x86_64.qcow2
sudo virsh define ~epheo/vm/arch.xml
sudo virsh start arch_epheo
