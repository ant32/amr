amr - Arch Mingw-w64 Repository
===

This project contains the code that is used to automatically recompile mingw packages.

Package names in buildlist.txt should be in order that they would need to be compiled if compiled from scratch meaning that dependencies of a package should come first in the list.

This code is currently extremely dangerous. It has been designed to run in a virtual machine with no inmportant information on it.

This repository is to be used with an up to date 64bit archlinux instalation. To use this repository add the following lines to /etc/pacman.conf

    [mingw-w64]
    SigLevel = Optional TrustAll
    Server = http://arch.linuxx.org/archlinux/$repo/os/$arch

During the automatic build process the packeges will be placed in the following repo. You may wish to use it to help with the testing process.

    [mingw-w64-testing]
    SigLevel = Optional TrustAll
    Server = http://arch.linuxx.org/archlinux/$repo/os/$arch
