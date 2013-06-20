#!/usr/bin/bash
# Entry script to use with a cron job to automaticaly compile packages when updated.


# TODO:
# Create a text file wich states which packages where successfully compiled and combine
# that with the log files into a compressed archive.


# update variables
normal_user="sudo -u amr"
checkdir="/home/amr/checkdir"
builddir="/home/amr/build"
homedir="/home/amr"
temp_repository="/home/amr/pkgs"
mainlog="/home/amr/update.log"


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
      # update temp repository
      $normal_user cp $pkg*.pkg.tar.xz $temp_repository
      rm $temp_repository/temp.db*
      $normal_user repo-add $temp_repository/temp.db.tar.gz $temp_repository/*
      lyes | pacman -Scc && pacman -Sy
    popd
    # uninstall no longer needed packages
    lyes | pacman -Rscnd $(pacman -Qtdq)
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
    if [ "${pkgname}" = *qt5* ]; then
      if [ "${ndept}" = "mingw-w64-gcc" ]; then ndept="mingw-w64-gcc-qt5"; fi
    fi
    # add to new array
    depts+=("${ndept}")
  done
  # install all needed packages as dependencies for easy removal later
  lyes | pacman --sync --asdeps --needed ${depts[@]}
}


# check for lock file and create one if it does not exsist
if [ ! -f update.lock ]; then
  
  # create lock
  $normal_user touch "$homedir/update.lock"
  echo "STARTING UPDATE `date`" | tee -a $mainlog
  
  # update package cache
  lyes | pacman -Scc && pacman -Sy
  
  # create package list
  while read pkg; do pkglist+=($pkg); done < buildlist.txt
  
  # loop to download and extract all packages
  cd $checkdir
  rm -fR *
  for pkg in ${pkglist[@]}; do
    $normal_user curl -O "https://aur.archlinux.org/packages/${pkg:0:2}/$pkg/$pkg.tar.gz"
    $normal_user tar xzvf "$pkg.tar.gz"
    rm "$pkg.tar.gz"
  done
  
  # loop to check for packages that are outdated
  for pkg in ${pkglist[@]}; do
    source "$pkg/PKGBUILD"
    curver=`pacman -Si $pkg | grep Version | tr -d ' ' | sed -e "s/Version://"`
    if [ "$curver" != "$pkgver-$pkgrel" ]; then
      echo "updating $pkg from $curver to $pkgver-$pkgrel"
      updatelist+=($pkg)
    fi
  done
  
  # for each outdated package create a compile job
  for pkg in ${updatelist[@]}; do
    buildlist=($pkg)
    # check all packages and add the package to the list tath depends on pkg
    for dep in ${pkglist[@]}; do
      unset depends optdepends makedepends
      source "$dep/PKGBUILD"
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
  
  # remove lock
  rm -R "$checkdir/"*
  rm "$homedir/update.lock"
fi
