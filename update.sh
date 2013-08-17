#!/usr/bin/bash
# Entry script to use with a cron job to automaticaly compile packages when updated.

# update variables
normal_user="sudo -u amr"
builddir="/build"
pkgbuildsdir="$builddir/pkgbuilds"
test_repository="/srv/http/archlinux/mingw-w64-testing/os/x86_64"
mainlog="/build/update.log"

# my yes function that is limited to 10 rounds
lyes() {
  i=0
  while (( i < 10 )); do
    echo y
    let "i+=1"
  done
}


# compile function
compile() {
  for pkg in "$@"; do
    echo "building $pkg" | tee -a $mainlog $buildlog
    # manual way to install qt4-dummy for now
    if [ "$pkg" = 'mingw-w64-qt4-static' ]; then
      curl -O https://dl.dropboxusercontent.com/u/33784287/websharing/mingw-w64-qt4-dummy/PKGBUILD
      makepkg -i --noconfirm --asroot
      rm -fR pkg src mingw-w64-qt4-dummy-1-1-any.pkg.tar.xz PKGBUILD
    fi
    # download package
    $normal_user curl -O https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz
    $normal_user tar xzvf $pkg.tar.gz
    pushd $pkg
      # install dependencies
      install_deps
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
        sed -i '$ d' $mainlog $buildlog
        echo "$pkg failed to build" | tee -a $mainlog $buildlog
      fi
    popd
    # uninstall no longer needed packages (this has to be done cause later when installing
    # dependencies and there already is a package that provides something it'll sometimes not
    # install the correct packages)
    # becuase of the dependency circle that mingw crt and gcc make mingw-w64 has to be removed with force
    lyes | pacman -Rscnd mingw-w64
    lyes | pacman -Rscnd $(pacman -Qtdq)
  done
}


# install dependencies function
install_deps() {
  unset depts depends optdepends makedepends
  # source file to get the variables
  source ./PKGBUILD
  echo "Installing dependencies for ${pkg}" 2>&1 | tee -a "$builddir/$build/$pkg/$pkg-installdeps.log"
  # loop all dependencies
  for dept in "${depends[@]}" "${optdepends[@]}" "${makedepends[@]}"; do
    # remove description from dependency
    i=`expr index "${dept}" ':' - 1`
    [ "$i" -eq '-1' ] && ndept=$dept || ndept=${dept:0:$i}

    # secure crt should be build with secure headers
    [ "${pkgname}" = 'mingw-w64-crt-secure' ] && [ "${ndept}" = "mingw-w64-headers" ] && ndept='mingw-w64-headers-secure'
    # there is currenty a problem with the latest stable mingw-w64 crt and headers
    [ "${ndept}" = 'mingw-w64-crt' ] && ndept='mingw-w64-crt-svn'
    [ "${ndept}" = 'mingw-w64-headers' ] && ndept='mingw-w64-headers-svn'
    # qt5 package require a patched gcc to build
    [[ "${pkgname}" = *"qt5"* ]] && [ "${ndept}" = 'mingw-w64-gcc' ] && ndept='mingw-w64-gcc-qt5'
    # mingw-w64-xmms and mingw-w64-qt4-dummy don't exsist
    [ "${ndept}" = 'mingw-w64-xmms' ] && unset ndept
    [ "${ndept}" = 'mingw-w64-qt4-dummy' ] && unset ndept
    [ "${pkgname}" = 'mingw-w64-qt4-static' ] && [ "${ndept}" = 'mingw-w64-qt4' ] && unset ndept

    # add to new array
    depts+=("${ndept}")
  done
  
  # some packages have missing dependencies
  [ "$pkgname" = 'mingw-w64-angleproject' ] && depts+=('mingw-w64-headers-secure' 'mingw-w64-crt-secure')
  [ "$pkgname" = 'mingw-w64-giflib' ] && depts+=('docbook-xml')
  [ "$pkgname" = 'mingw-w64-sdl_ttf' ] && depts+=('freetype2')
  [ "$pkgname" = 'mingw-w64-sdl2_ttf' ] && depts+=('freetype2')
  [ "$pkgname" = 'mingw-w64-openjpeg' ] && depts+=('lib32-glibc' 'libtiff')
  [ "$pkgname" = 'mingw-w64-librsvg' ] && depts+=('gdk-pixbuf2')
  [ "$pkgname" = 'mingw-w64-glfw' ] && depts+=('cmake')
  [ "$pkgname" = 'mingw-w64-gtk3' ] && depts+=('python2')
  [ "$pkgname" = 'mingw-w64-libbluray' ] && depts+=('libxml2')
  [ "$pkgname" = 'mingw-w64-schroedinger' ] && depts+=('orc')
  [ "$pkgname" = 'mingw-w64-ffmpeg' ] && depts+=('mingw-w64-pkg-config' )
  [ "$pkgname" = 'mingw-w64-uriparser' ] && depts+=('cmake')
  [ "$pkgname" = 'mingw-w64-qwt' ] && depts+=('mingw-w64-qt4')
  [ "$pkgname" = 'mingw-w64-pthreads' ] && depts+=('mingw-w64-gcc')
  
  # install all needed packages as dependencies for easy removal later
  pacman --sync --asdeps --needed --noconfirm ${depts[@]} 2>&1 | tee -a "$builddir/$build/$pkg/$pkg-installdeps.log"
}
build/

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
    curver=`pacman -Si $pkg | grep Version | tr -d ' ' | sed -e "s/Version://" | head -n 1`

    # manual changes to some packages to make them not auto update
    [ "$pkg" = 'mingw-w64-headers-svn' ] && [ "$nver" = '5792-1' ] && nver='5882-1'
    [ "$pkg" = 'gyp-svn' ] && [ "$nver" = '1678-1' ] && nver='1694-1'
    
    if [ "$curver" != $nver ]; then
      echo "updating $pkg from $curver to $nver" | tee -a $mainlog
      updatelist+=($pkg)
    fi
  done
}


create_compilejobs() {
  # for each outdated package create a compile job
  for pkg in ${updatelist[@]}; do
    buildlist=($pkg)
    # check all packages and add the package to the list tath depends on pkg
    for dep in ${pkglist[@]}; do
      # if package hasn't been built yet don't add it as a reverse dependency
      if [[ `pacman -Si $dep` ]]; then
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
    done
    build="${pkg}_`date "+%Y%m%d-%H%M"`"
    buildlog="$builddir/$build/$pkg/$pkg-build.log"
    $normal_user mkdir -p "$builddir/$build"
    pushd "$builddir/$build"
      [ "${#buildlist[@]}" -gt 1 ] && echo "package build job: ${buildlist[@]}" | tee -a $mainlog $buildlog
      compile "${buildlist[@]}"
      # create compile log
      $normal_user tar -czf "$builddir/${build}.log.tar.gz" */*.log
    popd
    $normal_user rm -fR "$builddir/$build"
  done
}


# check for lock file and create one if it does not exsist
if [ ! -f update.lock ]; then

  # create lock
  $normal_user touch "$builddir/update.lock"
  echo "STARTING UPDATE `date`" | tee -a $mainlog

  # update package cache
  lyes | pacman -Scc && pacman -Syy

  # create package list
  unset pkglist
  while read pkg; do if [ "${pkg:0:1}" != "#" ]; then pkglist+=($pkg); fi; done < "$builddir/scripts/buildlist.txt"

  create_updatelist
  create_compilejobs

  # remove lock
  $normal_user rm -fR $pkgbuildsdir
  echo "Building packages completed at `date`" | tee -a $mainlog
  rm "$builddir/update.lock"
fi
