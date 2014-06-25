#!/usr/bin/bash
build_home='/build/amr'
repo_name='mingw-w64-testing'
chroot_dir="$build_home/build/chroot"
src_dir="$build_home/build"
script_dir="$build_home"
log_dir="$build_home/Dropbox/logs"
pkgbuilds_dir="$build_home/build/pkgbuilds"
test_dir="$build_home/Dropbox/repo-testing"
log_file="$build_home/Dropbox/update.log"


############# MODIFICATIONS TO PACKAGES #############################

before_build() {
  #skudo ----------
  # manual way to install qt4-dummy for now
  if [ "$pkg" = 'mingw-w64-qt4-static' ]; then
    pushd "$src_dir"
    curl -O https://dl.dropboxusercontent.com/u/33784287/websharing/mingw-w64-qt4-dummy/PKGBUILD
    makepkg --noconfirm --asroot 2>&1 | tee -a "$pkg.log"
    rm -R pkg src PKGBUILD
    yes | makechrootpkg -r "$chroot_dir" -I mingw-w64-qt4-dummy-1-1-any.pkg.tar.xz -l root -- --noprogressbar 2>&1 | tee -a "$pkg.log"
    rm mingw-w64-qt4-dummy-1-1-any.pkg.tar.xz
    popd
  fi
  [ "$last_pkg" = 'mingw-w64-qt4-static' ] && \
    arch-nspawn "$chroot_dir/root" pacman -Rscnd --quiet --noconfirm mingw-w64-qt4-dummy 2>&1 | tee -a "$pkg.log"
  
  # used if needing to do something after last build but before next build_home
  last_pkg="$pkg"

  # some source tarballs don't have the correct permissions
  chmod 777 -R .
}
modify_ver() {
  # manual changes to some packages to make them not auto update
  [ "$npkg" = 'gyp-svn 1775-1' ] && nver='1847-1'
  [ "$npkg" = 'mingw-w64-cal3d-svn 560-1' ] && nver='562-1'
  [ "$npkg" = 'mingw-w64-headers-svn 6298-1' ] && nver='6638-1'
  [ "$npkg" = 'mingw-w64-crt-svn 6362-1' ] && nver='6638-1'
  [ "$npkg" = 'mingw-w64-winpthreads-svn 6362-1' ] && nver='6638-1'
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
      makechrootpkg -c -r "$chroot_dir" -l mingw -- --noprogressbar 2>&1 | tee "$pkg.log"
      # if package was created update temp repository
      if [ -f *.pkg.tar.xz ]; then
        for pkgtar in *.pkg.tar.xz; do
          npkgtar=$(/build/amr/fixname.py $pkgtar)
          echo "Renaming $pkgtar to $npkgtar"
          # move to test dir and add to test repo
          mv "$pkgtar" "$test_dir/$npkgtar"
          repo-add "$test_dir/$repo_name.db.tar.gz" "$test_dir/$npkgtar"
        done
      else
        sed -i '$ d' $log_file # delete last line and replace with failed
        echo "$pkg failed to build" | tee -a $log_file
      fi
      # compress and store away log
      tar -czf "$log_dir/$pkg.log.tar.gz" "$pkg.log"
    popd
    # delete the package directory
    rm -fR "$src_dir/$pkg"
  done
}


create_updatelist() {
  unset updatelist
  mkdir -p "$pkgbuilds_dir"
  ./downloalpkgs.py
  # loop to check for packages that are outdated
  echo "Find packages that need to be updated"
  for pkg in ${pkglist[@]}; do
    #echo "downloading PKGBUILD for $pkg"
    #curl -s "https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/PKGBUILD" > "$pkgbuilds_dir/$pkg"
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
Server = http://127.0.0.1/
[mingw-w64]
SigLevel = Optional TrustAll
Server = http://downloads.sourceforge.net/project/mingw-w64-archlinux/$arch
' >> "$chroot_dir/root/etc/pacman.conf"

  sed 's|#PACKAGER="John Doe <john@doe.com>"|PACKAGER="ant32 <antreimer@gmail.com>"|' -i "$chroot_dir/root/etc/makepkg.conf"

  arch-nspawn "$chroot_dir/root" pacman -Syu
}


# check for lock file and create one if it does not exsist
if [ ! -f "$script_dir/lock" ]; then

  # create lock
  touch "$script_dir/lock"
  echo "STARTING UPDATE `date`" | tee -a $log_file
  
  # start darkhttpd
  darkhttpd "$test_dir" &
  dpid=$!
  
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
    #create_buildlist
    buildlist=( "${updatelist[@]}" )
  fi

  echo "We will now start compiling ..."
  compile

  # stop darkhttpd
  kill -s 9 $dpid
  
  # remove lock
  echo "Building packages completed at `date`" | tee -a $log_file
  clean_dirs
  rm "$script_dir/lock"
fi
