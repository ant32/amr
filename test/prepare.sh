yes | pacman -Sy devtools screen

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
