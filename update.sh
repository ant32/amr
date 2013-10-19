#!/usr/bin/bash

# update variables
normal_user='sudo -u amr'
builddir='/build'
scriptdir='/scripts'
logdir='/srv/http/logs'
pkgbuildsdir="$builddir/pkgbuilds"
test_repository='/srv/http/archlinux/mingw-w64-testing/os/x86_64'
mainlog="$logdir/update.log"


# my yes function that is limited to 10 rounds
lyes() {
  i=0
  while (( i < 10 )); do
    echo y
    let "i+=1"
  done
}


before_build() {
  npkg="$pkgname $pkgver-$pkgrel"

  # compress some packages while building to save disk space
  # This is not really a solution since it causes other strange errors at times
  # we'll check if there is less then 20GB available for now.
  #if [ $(($(stat -f --format="%a*%S" .))) -lt 20000000000 ]; then
  #  [[ "$pkg" = 'mingw-w64-qt4'* ]] && fusecompress "$PWD" && compressed_dir="$PWD"
  #fi

  # the older gettext does not compile with newer mingw
  [ "$npkg" = 'mingw-w64-gettext 0.18.2.1-1' ] && curl -O 'https://raw.github.com/ant32/pkgbuild/master/mingw-w64-gettext/PKGBUILD'

  # mingw-w64-glib2 is outdated and the older version no longer builds
  [ "$npkg" = 'mingw-w64-glib2 2.37.1-1' ] && pushd .. && curl 'https://dl.dropboxusercontent.com/u/33784287/aur/mingw-w64-glib2-2.38.0-1.src.tar.gz' | $normal_user tar xz && popd
  
  # update dbus (plus make it compatible with posix thread mingw)
  [ "$npkg" = 'mingw-w64-dbus 1.6.12-1' ] && curl -O 'https://raw.github.com/ant32/pkgbuild/master/mingw-w64-dbus/PKGBUILD'
}


after_build() {
  # becuase of the dependency circle that mingw crt and gcc make mingw-w64 has to be removed with force
  lyes | pacman -Rscnd mingw-w64
  [ "$pkg" = 'mingw-w64-qt4-static' ] && lyes | pacman -R mingw-w64-qt4-dummy
  # unmount compressed directory so they can be deleted
  #if [ ! -z "$compressed_dir" ]; then
  #  fusermount -u "$compressed_dir"
  #  unset compressed_dir
  #fi
}


modify_depts() {
  npkg="$pkgname $pkgver-$pkgrel"
  unset temp_depts
  for dept in "${depts[@]}"; do

    # manual way to install qt4-dummy for now
    if [ "$pkg" = 'mingw-w64-qt4-static' ]; then
      [ "$dept" = 'mingw-w64-qt4' ] && unset dept
      if [ "$dept" = 'mingw-w64-qt4-dummy' ]; then
        pushd $builddir
        curl -O https://dl.dropboxusercontent.com/u/33784287/websharing/mingw-w64-qt4-dummy/PKGBUILD
        makepkg -i --noconfirm --asroot
        rm -fR pkg src mingw-w64-qt4-dummy-1-1-any.pkg.tar.xz PKGBUILD
        unset dept
        popd
      fi
    fi
    
    # update dbus (plus make it compatible with posix thread mingw)
    # I changed dbus to depend on expat insted of mingw-w64-libxml2
    [ "$npkg" = 'mingw-w64-dbus 1.6.12-1' ] && [ "$dept" = 'mingw-w64-libxml2' ] && dept='mingw-w64-expat'
    
    # mingw-w64-xmms doesn't exsist
    [ "$npkg" = 'mingw-w64-flac 1.3.0-1' ] && [ "$dept" = 'mingw-w64-xmms' ] && unset dept

    temp_depts+=($dept)
  done

  # some packages have missing dependencies
  [ "$pkgname" = 'mingw-w64-angleproject' ] && temp_depts+=('mingw-w64-headers' 'mingw-w64-crt')
  [ "$pkgname" = 'mingw-w64-giflib' ] && temp_depts+=('docbook-xml')
  [ "$pkgname" = 'mingw-w64-uriparser' ] && temp_depts+=('cmake')
  [ "$pkgname" = 'mingw-w64-pthreads' ] && temp_depts+=('mingw-w64-gcc')

  unset depts
  depts=${temp_depts[@]}
}


modify_ver() {
  # manual changes to some packages to make them not auto update
  [ "$pkg" = 'gyp-svn' ] && [ "$nver" = '1742-1' ] && nver='1750-1'
  [ "$pkg" = 'mingw-w64-gettext' ] && [ "$nver" = '0.18.2.1-1' ] && nver='0.18.3.1-1'
  [ "$pkg" = 'mingw-w64-glib2' ] && [ "$nver" = '2.37.1-1' ] && nver='2.38.0-1'
  [ "$pkg" = 'mingw-w64-dbus' ] && [ "$nver" = '1.6.12-1' ] && nver='1.6.16-1'
}


# compile function
compile() {
  for pkg in "${buildlist[@]}"; do
    $normal_user mkdir -p "$builddir/$pkg"
    buildlog="$builddir/$pkg/$pkg-build.log"
    echo "building $pkg" | tee -a $mainlog $buildlog
    # download package
    curl https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz | $normal_user tar xz -C $builddir
    
    pushd "$builddir/$pkg"
      # install dependencies
      install_deps
      before_build
      # compile package
      $normal_user makepkg --noconfirm -L -c
      # since our space is limited we'll remove src and pkg directories
      rm -fR src pkg
      # if package was created update temp repository
      if [ -f $pkg*.pkg.tar.xz ]; then
        $normal_user cp $pkg*.pkg.tar.xz $test_repository
        $normal_user repo-add $test_repository/mingw-w64-testing.db.tar.gz $test_repository/$pkg*.pkg.tar.xz
        lyes | pacman -Scc && pacman -Syy
      else
        sed -i '$ d' $mainlog $buildlog  # delete last line and replace with failed
        echo "$pkg failed to build" | tee -a $mainlog $buildlog
      fi
      # compress and store away log 
      $normal_user tar -czf "$logdir/`date "+%Y%m%d-%H%M"`-$pkg.log.tar.gz" *.log
    popd
    
    after_build
    # uninstall no longer needed packages (this has to be done cause later when installing
    # dependencies and there already is a package that provides something it'll sometimes not
    # install the correct packages)
    lyes | pacman -Rscnd $(pacman -Qtdq)
    rm -fR "$builddir/$pkg"
  done
}


# install dependencies function
install_deps() {
  unset depts depends optdepends makedepends
  # source file to get the variables
  source ./PKGBUILD
  echo "Installing dependencies for ${pkg}" 2>&1 | tee -a "$builddir/$pkg/$pkg-installdeps.log"
  # loop all dependencies
  for dept in "${depends[@]}" "${optdepends[@]}" "${makedepends[@]}"; do
    # remove description from dependency
    i=`expr index "${dept}" ':' - 1`
    [ "$i" -eq '-1' ] && ndept=$dept || ndept=${dept:0:$i}
    # add to new array
    depts+=("${ndept}")
  done
  
  modify_depts
  
  # install all needed packages as dependencies for easy removal later
  echo "We will now install - ${depts[@]}"
  pacman --sync --asdeps --needed --noconfirm ${depts[@]} 2>&1 | tee -a "$builddir/$pkg/$pkg-installdeps.log"
}


create_updatelist() {
  unset updatelist
  $normal_user mkdir -p $pkgbuildsdir
  # loop to check for packages that are outdated
  for pkg in ${pkglist[@]}; do
    echo "downloading PKGBUILD for $pkg"
    $normal_user curl -s "https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/PKGBUILD" > "$pkgbuildsdir/$pkg"
    unset epoch nver
    source "$pkgbuildsdir/$pkg"
    [[ "$epoch" ]] && nver="${epoch}:"
    nver="${nver}${pkgver}-${pkgrel}"
    curver=`pacman -Si $pkg 2>/dev/null | grep Version | tr -d ' ' | sed -e "s/Version://" | head -n 1`

    modify_ver
    
    if [ "$curver" != $nver ]; then
      echo "updating $pkg from $curver to $nver" | tee -a $mainlog
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
        unset depends optdepends makedepends
        source "$pkgbuildsdir/$dep"
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


# check for lock file and create one if it does not exsist
if [ ! -f "$builddir/update.lock" ]; then

  # create lock
  $normal_user touch "$builddir/update.lock"
  echo "STARTING UPDATE `date`" | tee -a $mainlog

  # update package cache
  lyes | pacman -Scc && pacman -Syy

  # create package list
  unset pkglist
  while read pkg; do if [ "${pkg:0:1}" != "#" ]; then pkglist+=($pkg); fi; done < "$scriptdir/buildlist.txt"

  echo "Creating update list ..."
  create_updatelist
  echo "Creating build list (This may take a while) ..."
  create_buildlist
  echo "We will now start compiling ..."
  compile

  # remove lock
  $normal_user rm -fR $pkgbuildsdir
  echo "Building packages completed at `date`" | tee -a $mainlog
  rm "$builddir/update.lock"
fi
