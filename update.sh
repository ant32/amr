#!/usr/bin/bash
# Entry script to use with a cron job to automaticaly compile packages when updated.

# update variables
normal_user="sudo -u amr"
builddir="/build"
test_repository="/srv/http/archlinux/mingw-w64-testing/os/x86_64"
mainlog="/build/update.log"
tmpf=`mktemp`


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
    # download package
    $normal_user curl -O https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz
    $normal_user tar xzvf $pkg.tar.gz
    pushd $pkg
      # install dependencies
      install_deps
      # compile package
      lyes | $normal_user makepkg -L -c
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
    # becuase of the dependency circle that mingw crt and gcc make it has to be removed with force
    lyes | pacman -Rscnd mingw-w64
    lyes | pacman -Rscnd $(pacman -Qtdq)
  done
}


# install dependencies function
install_deps() {
  unset depts
  # run file so that we get the variables
  source ./PKGBUILD
  echo "Installing deps for ${pkg}" | tee -a "$builddir/$build/installdeps.log"
  # loop all dependencies
  for dept in "${depends[@]}" "${optdepends[@]}" "${makedepends[@]}"; do
    # remove description from dependency
    i=`expr index "${dept}" : - 1`
    # if not found use complete dependency
    if [ "$i" -eq '-1' ]; then
      ndept=$dept
    else
      ndept=${dept:0:$i}
    fi
    # fix some oth the mingw depndencies
    if [ "${ndept}" = "mingw-w64-crt" ]; then ndept="mingw-w64-crt-svn"; fi
    if [ "${ndept}" = "mingw-w64-headers" ]; then ndept="mingw-w64-headers-svn"; fi
    if [[ "${pkgname}" = *"qt5"* ]]; then
      if [ "${ndept}" = "mingw-w64-gcc" ]; then ndept="mingw-w64-gcc-qt5"; fi
    fi
    # add to new array
    depts+=("${ndept}")
  done
  
  # manual stuff
  if [ "${pkgname}" = "mingw-w64-angleproject" ]; then depts+=('mingw-w64-headers-secure' 'mingw-w64-crt-secure'); fi
  
  # install all needed packages as dependencies for easy removal later
  pacman --sync --asdeps --needed --noconfirm ${depts[@]} | tee -a "$builddir/$build/installdeps.log"
}


create_updatelist() {
  unset updatelist
  # loop to check for packages that are outdated
  for pkg in ${pkglist[@]}; do
    curl "https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/PKGBUILD" > tmpf && source tmpf
    curver=`pacman -Si $pkg | grep Version | tr -d ' ' | sed -e "s/Version://"`

    # manual changes to some packages to make them not auto update
    if [ "$pkg" = "mingw-w64-headers-svn" ]; then
      if [ "$pkgver-$pkgrel" = "5792-1" ]; then pkgver="5882"; fi
    fi

    # skip packages
    if [ "$pkg" = "mingw-w64-qt5-qtbase-static" ]; then curver="$pkgver-$pkgrel"; fi
    if [ "$pkg" = "mingw-w64-qt5-qttools" ]; then curver="$pkgver-$pkgrel"; fi
    if [ "$pkg" = "mingw-w64-qt5-qtquick1" ]; then curver="$pkgver-$pkgrel"; fi
    
    if [ "$curver" != "$pkgver-$pkgrel" ]; then
      echo "updating $pkg from $curver to $pkgver-$pkgrel" | tee -a $mainlog
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
        curl "https://aur.archlinux.org/packages/${dep:0:2}/$dep/PKGBUILD" > tmpf && source tmpf
        for rdep in "${depends[@]}" "${optdepends[@]}" "${makedepends[@]}"; do
          # remove description from dependency
          i=`expr index "${rdep}" : - 1`
          if [ "$i" -eq '-1' ]; then i="${#rdep}"; fi
          # if package in reverse dependencies then add to build list
          if [ "${rdep:0:$i}" = "$pkg" ]; then buildlist+=($dep) ;fi
        done
      fi
    done
    build="${pkg}_`date "+%Y%m%d-%H%M"`"
    buildlog="$builddir/$build/build.log"
    $normal_user mkdir -p "$builddir/$build"
    pushd "$builddir/$build"
      echo "package build job: ${buildlist[@]}" | tee -a $mainlog $buildlog
      compile "${buildlist[@]}"
      # create compile log
      if [ -f */*.log ]; then
        $normal_user tar -czf "$builddir/${build}.log.tar.gz" *.log */*.log
      else
        $normal_user tar -czf "$builddir/${build}.log.tar.gz" *.log
      fi
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
  while read pkg; do pkglist+=($pkg); done < "$builddir/scripts/buildlist.txt"

  create_updatelist
  create_compilejobs

  # remove lock
  echo "Building packages completed at `date`" | tee -a $mainlog
  rm "$builddir/update.lock"
fi
