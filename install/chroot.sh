# creating packages as a user without a home folder does not always work
useradd -m amr

mkdir -p /scripts /build
cd /scripts

pushd /build
curl -O https://aur.archlinux.org/packages/du/dummy/PKGBUILD
makepkg --asroot
rm -fR PKGBUILD src pkg
popd

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
mkdir -p /srv/http/logs
cp /build/dummy-1-1-any.pkg.tar.xz /scripts
cp /build/dummy-1-1-any.pkg.tar.xz /srv/http/archlinux/mingw-w64/os/x86_64
cp /build/dummy-1-1-any.pkg.tar.xz /srv/http/archlinux/mingw-w64-testing/os/x86_64
./repo_update.sh
pacman -Sy
chown -R amr /build /srv/http/archlinux
chown -R amr /build /srv/http/logs
