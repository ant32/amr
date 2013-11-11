#!/usr/bin/bash
build_home=''
repo_name='mingw-w64-testing'
chroot_dir="$build_home/build/chroot"
src_dir="$build_home/build"
script_dir="$build_home/scripts"
log_dir="$build_home/srv/http/logs"
pkgbuilds_dir="$build_home/build/pkgbuilds"
repo_dir="/srv/http/archlinux/mingw-w64-testing/os/x86_64"
log_file="$log_dir/update.log"


############# MODIFICATIONS TO PACKAGES #############################

before_build() {
  #rubenvb --------
  # mingw-w64-crt should makedepend on mingw-w64-gcc-base
  [ "$npkg" = 'mingw-w64-crt 3.0.0-2' ] && \
    sed -e "s|'mingw-w64-gcc-base' ||" \
        -e "s|makedepends=()|makedepends=('mingw-w64-gcc-base')|" -i PKGBUILD

  # mingw-w64-gcc should makedepend on mingw-w64-gcc-base
  [ "$npkg" = 'mingw-w64-gcc 4.8.2-2' ] && \
    sed "s|makedepends=(|makedepends=('mingw-w64-gcc-base' |" -i PKGBUILD

  #naelstrof ------
  # add staticlibs option and remove !libtool
  [ "$npkg" = 'mingw-w64-alure 1.2-2' ] && sed "s|(!strip !buildflags)|(staticlibs !strip !buildflags)|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-enet 1.3.9-2' ] && sed "s|('!strip' '!buildflags' '!libtool')|('staticlibs' '!strip' '!buildflags')|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-flac 1:1.3.0-2' ] && sed "s|(!libtool !strip !buildflags)|(!staticlibs !strip !buildflags)|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-glew 1.10.0-2' ] && sed "s|(!strip !buildflags)|(staticlibs !strip !buildflags)|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-libogg' ] && sed "s|('!libtool' '!strip' '!buildflags')|('staticlibs' '!strip' '!buildflags')|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-libsndfile 1.0.25-2' ] && sed "s|('!libtool' '!strip')|('staticlibs' '!strip')|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-libvorbis' ] && sed "s|(!libtool !strip !buildflags)|(staticlibs !strip !buildflags)|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-lua 5.2.2-1' ] && sed "s|(!strip !buildflags)|(staticlibs !strip !buildflags)|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-openal 1.15.1-4' ] && sed "s|(!strip !buildflags)|(staticlibs !strip !buildflags)|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-physfs 2.0.3-2' ] && sed "s|('!strip' '!buildflags')|('staticlibs' '!strip' '!buildflags')|" -i PKGBUILD
  [ "$npkg" = 'mingw-w64-soil 0708-1' ] && sed "s|('!strip' '!buildflags')|('staticlibs' '!strip' '!buildflags')|" -i PKGBUILD

  #xantares -------
  # add staticlibs option and remove !libtool
  [ "$npkg" = 'mingw-w64-angleproject 1.0.0.r1561-1' ] && sed "s|('!strip' '!buildflags' '!libtool')|('!strip' '!buildflags' 'staticlibs')|" -i PKGBUILD

  #skudo ----------
  # manual way to install qt4-dummy for now
  #if [ "$pkg" = 'mingw-w64-qt4-static' ]; then
  #  [ "$dept" = 'mingw-w64-qt4' ] && unset dept
  #  if [ "$dept" = 'mingw-w64-qt4-dummy' ]; then
  #    pushd "$src_dir"
  #    curl -O https://dl.dropboxusercontent.com/u/33784287/websharing/mingw-w64-qt4-dummy/PKGBUILD
  #    makepkg -i --noconfirm --asroot
  #    rm -fR pkg src mingw-w64-qt4-dummy-1-1-any.pkg.tar.xz PKGBUILD
  #    unset dept
  #    popd
  #  fi
  #fi

  # some source tarballs don't have the correct permissions
  chmod 777 -R .
}
modify_ver() {
  # manual changes to some packages to make them not auto update
  [ "$npkg" = 'gyp-svn 1775-1' ] && nver='1779-1'
  [ "$npkg" = 'mingw-w64-gettext 0.18.2.1-1' ] && nver='0.18.3.1-2'
  [ "$npkg" = 'mingw-w64-glib2 2.37.1-1' ] && nver='2.38.1-1'
  [ "$npkg" = 'mingw-w64-dbus 1.6.12-1' ] && nver='1.6.16-2'
  [ "$npkg" = 'mingw-w64-termcap 1.3.1-3' ] && nver='1.3.1-4'
}


############# FUNCTIONS #############################################

compile() {
  for pkg in "${buildlist[@]}"; do
    mkdir -p "$src_dir/$pkg"
    echo "building $pkg" | tee -a $log_file
    # download package
    curl https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz | tar xz -C "$src_dir"
    
    pushd "$src_dir/$pkg"
      source_package PKGBUILD
      before_build
      # compile package
      arch-nspawn "$chroot_dir/root" pacman -Sy
      makechrootpkg -c -r "$chroot_dir" -l mingw | tee "$pkg.log"
      # if package was created update temp repository
      if [ -f *.pkg.tar.xz ]; then
        for pkgtar in *.pkg.tar.xz; do
          # sourceforge does not accept the colon that is produced from packages with an epoch.
          npkgtar="${pkgtar/:/_}"
          mv "$pkgtar" "$repo_dir/$npkgtar"
          repo-add "$repo_dir/$repo_name.db.tar.gz" "$repo_dir/$npkgtar"
          # delete old package from cache since the checksum of it is incorrect now.
          rm "/var/cache/pacman/pkg/$npkgtar"
        done
      else
        sed -i '$ d' $log_file # delete last line and replace with failed
        echo "$pkg failed to build" | tee -a $log_file
      fi
      # compress and store away log
      tar -czf "$log_dir/`date "+%Y%m%d-%H%M"`-$pkg.log.tar.gz" "$pkg.log"
    popd
    # delete the package directory
    rm -fR "$src_dir/$pkg"
  done
}


create_updatelist() {
  unset updatelist
  mkdir -p "$pkgbuilds_dir"
  # loop to check for packages that are outdated
  for pkg in ${pkglist[@]}; do
    echo "downloading PKGBUILD for $pkg"
    curl -s "https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/PKGBUILD" > "$pkgbuilds_dir/$pkg"
    source_package "$pkgbuilds_dir/$pkg"
    curver=`pacman -Si $pkg 2>/dev/null | grep Version | tr -d ' ' | sed -e "s/Version://" | head -n 1`
    modify_ver
    if [ "$curver" != $nver ]; then
      echo "updating $pkg from $curver to $nver" | tee -a $log_file
      updatelist+=($pkg)
    fi
  done
}


create_buildlist() {
  unset buildlist
  for pkg in ${updatelist[@]}; do
    echo -n "$pkg "
    buildlist+=($pkg)
    # check all packages and add the package to the list that depends on pkg
    # this is not needed if the package does not exsist yet
    if [[ `pacman -Si $pkg 2>/dev/null` ]]; then
    for dep in ${pkglist[@]}; do
      # if package hasn't been built yet don't add it as a reverse dependency
      if [[ `pacman -Si $dep 2>/dev/null` ]]; then
        source_package "$pkgbuilds_dir/$dep"
        for rdep in "${depends[@]}" "${optdepends[@]}" "${makedepends[@]}"; do
          # remove description from dependency
          i=`expr index "${rdep}" ':><=' - 1`
          if [ "$i" -eq '-1' ]; then i="${#rdep}"; fi
          # if package in reverse dependencies then add to build list
          if [ "${rdep:0:$i}" = "$pkg" ]; then buildlist+=($dep) ;fi
        done
      fi
    done; fi
  done
  # loop and remove duplicates (only buld the last time needed)
  echo -e '\nRemoving duplicates from build list'
  x=0; buldlength=${#buildlist[@]} 
  while (( $x < $buldlength )); do
    testpkg=${buildlist[x]}
    y=0
    while (( $y < $x )); do
      [ "$testpkg" = "${buildlist[y]}" ] && unset buildlist[y]
      let "y+=1"
    done
    let "x+=1"
  done
  echo -e "Update will now rebuild the following packages.\n${buildlist[@]}"
}

source_package() {
  unset depends optdepends makedepends epoch nver
  source $1
  [[ "$epoch" ]] && nver="${epoch}:"
  nver="${nver}${pkgver}-${pkgrel}"
  npkg="$pkgname $nver"
}


clean_dirs() {
  rm -fR "$chroot_dir"
  rm -fR "$pkgbuilds_dir"
}

prepare_chroot() {
  # create new chroot
  clean_dirs
  mkdir -p "$chroot_dir"
  mkarchroot "$chroot_dir/root" base-devel

  echo '
[multilib]
Include = /etc/pacman.d/mirrorlist
[mingw-w64-testing]
SigLevel = Optional TrustAll
Server = http://127.0.0.1/archlinux/$repo/os/$arch
[mingw-w64]
SigLevel = Optional TrustAll
Server = http://127.0.0.1/archlinux/$repo/os/$arch
[ant32]
SigLevel = Optional TrustAll
Server = https://dl.dropboxusercontent.com/u/195642432' >> "$chroot_dir/root/etc/pacman.conf"

  sed 's|#PACKAGER="John Doe <john@doe.com>"|PACKAGER="ant32 <antreimer@gmail.com>"|' -i "$chroot_dir/root/etc/makepkg.conf"

  arch-nspawn "$chroot_dir/root" pacman -Syu
}


# check for lock file and create one if it does not exsist
if [ ! -f "$script_dir/lock" ]; then

  # create lock
  touch "$script_dir/lock"
  echo "STARTING UPDATE `date`" | tee -a $log_file

  pacman -Sy
  prepare_chroot

  # create package list
  unset pkglist
  while read pkg; do if [ "${pkg:0:1}" != "#" ]; then pkglist+=($pkg); fi; done < "$script_dir/buildlist.txt"

  if [ "$1" = 'rebuild' ]; then
    buildlist=( "${pkglist[@]}" )
  else 
    echo "Creating update list ..."
    create_updatelist
    echo "Creating build list (This may take a while) ..."
    create_buildlist
  fi

  echo "We will now start compiling ..."
  compile

  # remove lock
  echo "Building packages completed at `date`" | tee -a $log_file
  clean_dirs
  rm "$script_dir/lock"
fi
