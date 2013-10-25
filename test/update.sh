#!/usr/bin/bash
settingsfile='/scripts/settings.conf'

############# MODIFICATIONS TO PACKAGES #############################

before_build() {
  # the older gettext does not compile with newer mingw
  [ "$npkg" = 'mingw-w64-gettext 0.18.2.1-1' ] && curl -O 'https://raw.github.com/ant32/pkgbuild/master/mingw-w64-gettext/PKGBUILD'

  # mingw-w64-glib2 is outdated and the older version no longer builds
  [ "$npkg" = 'mingw-w64-glib2 2.37.1-1' ] && pushd .. && curl 'https://dl.dropboxusercontent.com/u/33784287/aur/mingw-w64-glib2-2.38.0-1.src.tar.gz' | tar xz && popd
  
  # update dbus (plus make it compatible with posix thread mingw)
  [ "$npkg" = 'mingw-w64-dbus 1.6.12-1' ] && curl -O 'https://raw.github.com/ant32/pkgbuild/master/mingw-w64-dbus/PKGBUILD'
  
  # mingw-w64-pthreads does not replace or provide mingw-w64-winpthreads
  [ "$npkg" = 'mingw-w64-pthreads 2.9.1-2' ] &&
    sed -e "s/replaces=('mingw-w64-winpthreads')//" \
        -e "s/provides=('mingw-w64-headers-bootstrap' 'mingw-w64-winpthreads')/provides=('mingw-w64-headers-bootstrap')/" -i PKGBUILD
  
  # mingw-w64-crt should makedepend on mingw-w64-gcc-base
  sed -e "s|'mingw-w64-gcc-base' ||" \
      -e "s|makedepends=()|makedepends=('mingw-w64-gcc-base')|" -i PKGBUILD
  
  # mingw-w64-gcc should makedepend on mingw-w64-gcc-base
  sed "s|makedepends=(|makedepends=('mingw-w64-gcc-base' |" -i PKGBUILD
}
modify_ver() {
  # manual changes to some packages to make them not auto update
  [ "$npkg" = 'gyp-svn 1742-1' ] && nver='1750-1'
  [ "$npkg" = 'mingw-w64-gettext 0.18.2.1-1' ] && nver='0.18.3.1-1'
  [ "$npkg" = 'mingw-w64-glib2 2.37.1-1' ] && nver='2.38.0-1'
  [ "$npkg" = 'mingw-w64-dbus 1.6.12-1' ] && nver='1.6.16-1'
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
      makechrootpkg -c -r "$chroot_dir" -l
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
      tar -czf "$log_dir/`date "+%Y%m%d-%H%M"`-$pkg.log.tar.gz" *.log
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
#[mingw-w64]
#SigLevel = Optional TrustAll
#Server = file:///srv/http/archlinux/$repo/os/$arch
[mingw-w64-testing]
SigLevel = Optional TrustAll
Server = http://localhost
[ant32]
SigLevel = Optional TrustAll
Server = https://dl.dropboxusercontent.com/u/195642432' >> "$chroot_dir/root/etc/pacman.conf"

  darkhttpd "$repo_dir" &
  http_pid=$!
}


# check for lock file and create one if it does not exsist
if [ ! -f "$script_dir/update.lock" ]; then

  # create lock
  touch "$script_dir/update.lock"
  echo "STARTING UPDATE `date`" | tee -a $log_file
  
  source "$settingsfile"
  prepare_chroot

  # create package list
  unset pkglist
  while read pkg; do if [ "${pkg:0:1}" != "#" ]; then pkglist+=($pkg); fi; done < "$script_dir/buildlist.txt"

  echo "Creating update list ..."
  create_updatelist
  echo "Creating build list (This may take a while) ..."
  create_buildlist
  echo "We will now start compiling ..."
  compile

  # remove lock
  echo "Building packages completed at `date`" | tee -a $log_file
  clean_dirs
  kill $http_pid
  rm "$script_dir/update.lock"
fi
