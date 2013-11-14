# this script it used with digital ocean vm

# update
pacman -Syu --ignore filesystem,bash --noconfirm
pacman -S bash --noconfirm
pacman -Su --noconfirm
# install needed packages
yes | pacman -Sy devtools screen darkhttpd

mkdir -p /build /scripts

cd /build
curl -O https://aur.archlinux.org/packages/du/dummy/PKGBUILD
makepkg --asroot
rm -fR PKGBUILD src pkg

cd /scripts

curl -O https://raw.github.com/ant32/amr/master/buildlist.txt
curl -O https://raw.github.com/ant32/amr/master/test/update.sh
curl -O https://raw.github.com/ant32/amr/master/test/repo_update.sh
chmod +x update.sh
chmod +x repo_update.sh

mkdir -p /srv/http/archlinux/mingw-w64{-testing,}/os/x86_64
mkdir -p /srv/http/logs
cp /build/dummy-1-1-any.pkg.tar.xz /scripts
cp /build/dummy-1-1-any.pkg.tar.xz /srv/http/archlinux/mingw-w64/os/x86_64
cp /build/dummy-1-1-any.pkg.tar.xz /srv/http/archlinux/mingw-w64-testing/os/x86_64
./repo_update.sh

# create swap partition
fallocate -l 512M /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# configure pacman.conf
echo '
[multilib]
Include = /etc/pacman.d/mirrorlist
[mingw-w64]
SigLevel = Optional TrustAll
Server = file:///srv/http/archlinux/$repo/os/$arch
[mingw-w64-testing]
SigLevel = Optional TrustAll
Server = file:///srv/http/archlinux/$repo/os/$arch' >> /etc/pacman.conf

# set up http server
#service
echo '[Unit]
Description=Darkhttpd Webserver

[Service]
EnvironmentFile=/etc/conf.d/darkhttpd
ExecStart=/usr/bin/darkhttpd $DARKHTTPD_ROOT --daemon $DARKHTTPD_OPTS
Type=forking

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/darkhttpd.service
#socket
echo '[Unit]
Conflicts=darkhttpd.service

[Socket]
ListenStream=80
Accept=no

[Install]
WantedBy=sockets.target' > /etc/systemd/system/darkhttpd.socket
#conf
echo 'DARKHTTPD_ROOT="/srv/http"
DARKHTTPD_OPTS="--uid nobody --gid nobody --chroot"' > /etc/conf.d/darkhttpd
# enable/start service
systemctl enable darkhttpd
systemctl start darkhttpd
