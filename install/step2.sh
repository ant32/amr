# script
net_Interface='ens0'
net_IP='dhcp'
net_Address='10.1.0.31/24'
net_Gateway='10.1.0.1'
net_DNS='10.1.0.1'


syslinux-install_update -i -a -m

# edit /boot/syslinux/syslinux.cfg
sed -i 's/sda3/sda1/g' /boot/syslinux/syslinux.cfg
sed -i 's/UI menu.c32/#UI menu.c32/g' /boot/syslinux/syslinux.cfg

#  set up network
systemctl enable sshd.service
if [ "$net_IP" = 'dhcp' ]; then
  echo "Interface=$net_Interface
Connection=ethernet
IP=$net_IP
" > /etc/netctl/$net_Interface
else
  echo "Interface=$net_Interface
Connection=ethernet
IP=$net_IP
Address=('$net_Address')
Gateway='$net_Gateway'
DNS=('$net_DNS')
" > /etc/netctl/$net_Interface
fi
netctl enable $net_Interface

curl https://raw.github.com/ant32/amr/master/install/step3.sh > /etc/profile.d/step3.sh
