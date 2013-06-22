#!/usr/bin/bash
# Entry script to use with a cron job to automaticaly compile packages when updated.

# TODO: Create a text file wich states which packages where successfully compiled
# and combine that with the log files into a compressed archive.


# update variables
normal_user="sudo -u amr"
checkdir="/build/checkdir"
builddir="/build"
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
    echo "building $pkg" | tee -a $mainlog
    # download package
    $normal_user curl -O https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz
    $normal_user tar xzvf $pkg.tar.gz
    pushd $pkg
      # install dependencies
      install_deps
      # compile package
      lyes | $normal_user makepkg -L -c
      # since our space is limited we'll remove src and pkg directories
      rm -fR src; rm -fR pkg
      # if package was created update temp repository
      if [ -f $pkg*.pkg.tar.xz ]; then
        $normal_user cp $pkg*.pkg.tar.xz $test_repository
        $normal_user repo-add $test_repository/temp.db.tar.gz $test_repository/$pkg*.pkg.tar.xz
        lyes | pacman -Scc && pacman -Sy
      else
        echo "$pkg failed to build" | tee -a $mainlog
      fi
    popd
    # uninstall no longer needed packages
    lyes | pacman -Rscnd $(pacman -Qtdq) mingw-w64
  done
}


# install dependencies function
install_deps() {
  # run file so that we get the variables
  source ./PKGBUILD
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
  # install all needed packages as dependencies for easy removal later
  pacman --sync --asdeps --needed --noconfirm ${depts[@]}
}


create_updatelist() {
  unset updatelist
  # loop to download and extract all packages
  cd $checkdir
  $normal_user rm -fR "$checkdir/"*
  for pkg in ${pkglist[@]}; do
    $normal_user curl -O "https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz"
    $normal_user tar xzvf "$pkg.tar.gz"
    rm "$pkg.tar.gz"
  done

  # loop to check for packages that are outdated
  for pkg in ${pkglist[@]}; do
    source "$pkg/PKGBUILD"
    curver=`pacman -Si $pkg | grep Version | tr -d ' ' | sed -e "s/Version://"`

    # manual changes to some packages to make them not auto update
    if [ "$pkg" = "mingw-w64-headers-svn" ]; then
      if [ "$pkgver-$pkgrel" = "5792-1" ]; then pkgver="5882"; fi
    fi

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
      unset depends optdepends makedepends
      source "$checkdir/$dep/PKGBUILD"
      for rdep in "${depends[@]}" "${optdepends[@]}" "${makedepends[@]}"; do
        # remove description from dependency
        i=`expr index "${rdep}" : - 1`
        if [ "$i" -eq '-1' ]; then i="${#rdep}"; fi
        # if package in reverse dependencies then add to build list
        if [ "${rdep:0:$i}" == "$pkg" ]; then buildlist+=($dep) ;fi
      done
    done
    build="${pkg}_`date "+%Y%m%d-%H%M"`"
    $normal_user mkdir -p "$builddir/$build"
    pushd "$builddir/$build"
      echo "package build job: ${buildlist[@]}" | tee -a $mainlog
      compile "${buildlist[@]}"
    popd
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
  while read pkg; do pkglist+=($pkg); done < "$builddir/scripts/builtlist.txt"

  create_updatelist
  create_compilejobs

  # remove lock
  echo "Building packages completed at `date`" | tee -a $mainlog
  $normal_user rm -R "$checkdir/"*
  rm "$builddir/update.lock"
fi
