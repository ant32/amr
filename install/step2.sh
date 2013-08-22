# script
syslinux-install_update -i -a -m

# edit /boot/syslinux/syslinux.cfg
sed -i 's/sda3/sda1/g' /boot/syslinux/syslinux.cfg
sed -i 's/UI menu.c32/#UI menu.c32/g' /boot/syslinux/syslinux.cfg

systemctl enable sshd.service
echo "
Interface=ens0
Connection=ethernet
IP=static
Address=('10.1.0.31/24')
Gateway='10.1.0.1'
DNS=('10.1.0.1')
" > /etc/netctl/ethernet-static
netctl enable ethernet-static
