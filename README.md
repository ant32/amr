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

Virtual Machine for these scripts
--------

1 install packages packes `pacman -S base base-devel sudo openssh`  
2 enable and start ssd `systemctl enable sshd && systemctl start sshd`  
3 create the build user `useradd amr`  
4 create folders `mkdir -p /build/scripts /srv/http/archlinux/mingw-w64{-testing,}/os/x86_64`  
5 allow build user `chown -R amr /build /srv/http/archlinux`  
6 build and place dummy package https://aur.archlinux.org/packages/dummy/ into `/build/scripts` and `/srv/http/archlinux/mingw-w64{-testing,}/os/x86_64`  
7 copy and `buildlist.txt update.sh repo_update.ssh` into `/build/scripts`.  
8 Add the following to the end of /etc/pacman.conf

    [mingw-w64]
    SigLevel = Optional TrustAll
    Server = file:///srv/http/archlinux/$repo/os/$arch
    [mingw-w64-testing]
    SigLevel = Optional TrustAll
    erver = file:///srv/http/archlinux/$repo/os/$arch

9 also uncomment the following two lines in `/etc/pacman.conf`

    [multilib]
    Include = /etc/pacman.d/mirrorlist

10 execute `/build/scripts/repo_update.ssh`  
11 and you're ready to use `update.sh`  

Web file server
--------

1 To set up web file server install nginx `pacman -S nginx`  
2 edit nginx.conf `nano /etc/nginx/nginx.conf` and edit the `location / {}` section   

    location / {
            root   /srv/http;
            autoindex on;
        }

3 enable and start nginx `systemctl enable nginx && systemctl start nginx`
