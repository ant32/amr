[ "$PWD" = '/etc/profile.d/' ] && deletelater=true

pacman -Syu --ignore filesystem,bash --noconfirm
pacman -S bash --noconfirm
pacman -Su --noconfirm

# some packages require more ram
fallocate -l 512M /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# creating packages as a user without a home folder does not always work
useradd -m amr

mkdir -p /build/scripts
cd /build/scripts

curl -O https://aur.archlinux.org/packages/du/dummy/PKGBUILD
makepkg --asroot
rm -fR PKGBUILD src pkg

curl -O https://raw.github.com/ant32/amr/master/buildlist.txt
curl -O https://raw.github.com/ant32/amr/master/repo_update.sh
curl -O https://raw.github.com/ant32/amr/master/update.sh
chmod +x repo_update.sh
chmod +x update.sh

echo '
[multilib]
Include = /etc/pacman.d/mirrorlist
[mingw-w64]
SigLevel = Optional TrustAll
Server = file:///srv/http/archlinux/$repo/os/$arch
[mingw-w64-testing]
SigLevel = Optional TrustAll
Server = file:///srv/http/archlinux/$repo/os/$arch
[ant32]
SigLevel = Optional TrustAll
Server = https://dl.dropboxusercontent.com/u/195642432' >> /etc/pacman.conf

mkdir -p /srv/http/archlinux/mingw-w64{-testing,}/os/x86_64
cp dummy-1-1-any.pkg.tar.xz /build/scripts
cp dummy-1-1-any.pkg.tar.xz /srv/http/archlinux/mingw-w64/os/x86_64
cp dummy-1-1-any.pkg.tar.xz /srv/http/archlinux/mingw-w64-testing/os/x86_64
./repo_update.sh
pacman -Sy
chown -R amr /build /srv/http/archlinux

pacman -S fusecompress-1 screen --noconfirm
screen ./update.sh

[ $deletelater ] && rm /etc/profile.d/step3.sh
