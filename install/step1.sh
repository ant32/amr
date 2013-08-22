echo -e 'n\n\n\n\n\nw' | fdisk /dev/sda
mkfs.ext4 /dev/sda1
mount /dev/sda1 /mnt
echo -e '\n\n' | pacstrap -i /mnt base base-devel syslinux openssh nginx
genfstab -p /mnt >> /mnt/etc/fstab
echo amr > /mnt/etc/hostname
curl https://raw.github.com/ant32/amr/master/install/step2.sh > /mnt/root/step2.sh
arch-chroot /mnt 'bash /root/step2.sh'
umount /mnt
reboot
