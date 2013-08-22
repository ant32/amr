echo -e "n\n\n\n\n\nw" | fdisk /dev/sda
mkfs.btrfs /dev/sda1
mount /dev/sda1 /mnt
pacstrap -i /mnt base base-devel syslinux openssh nginx
genfstab -p /mnt >> /mnt/etc/fstab
echo amr > /mnt/etc/hostname
arch-chroot /mnt
