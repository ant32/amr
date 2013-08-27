amr - Arch Linux MinGW-w64 Repository
===

This project contains the code that is used to automatically recompile mingw packages.

Package names in buildlist.txt should be in order that they would need to be compiled if
compiled from scratch meaning that dependencies of a package should come first in the list.

This code is extremely dangerous. It has been designed to run in a virtual machine or chroot
with no inmportant or personal/confidential information on it.

This repository is to be used with an up to date 64bit archlinux instalation. To use this
repository add the following lines to /etc/pacman.conf

    [mingw-w64]
    SigLevel = Optional TrustAll
    Server = http://arch.linuxx.org/archlinux/$repo/os/$arch

During the automatic build process the packeges will be placed in the following repo.
You may wish to use it to help with the testing process.

    [mingw-w64-testing]
    SigLevel = Optional TrustAll
    Server = http://arch.linuxx.org/archlinux/$repo/os/$arch

Virtual Machine / chroot for these scripts
--------

To use these scripts I've created helper scripts to get you up and running fast. The first
two scripts are to create a Virtual machine. The first script will farmat the hard drive
and download/execute the second script. You'll then need to reboot and run the third script.
If you buy a virtual machine from digital ocean you only need to execute the third script.

My recommended method now is to build in a chroot. All you need is to create a chroot with
only base-devel installed in it. To do this you'll need ot install devtools
`pacman -S devtools`. Next execute `mkarchroot chrootdir base-devel` where chrootdir
is the directory where you want to have your chroot directory. Root into your newly created
chroot `arch-chroot chrootdir`. Download the script
`curl https://raw.github.com/ant32/amr/master/install/chroot.sh > /root/setup.sh`
and execute it `bash /root/setup.sh`. You are then ready to execute the build script wich
the last successful build for me took aproximatly 48 hours. `/build/scripts/update.sh`

Once I have more spare time I want to rewrite the scripts a bit to more closely use
https://wiki.archlinux.org/index.php/DeveloperWiki:Building_in_a_Clean_Chroot. I also
want to look into what yaourt uses which I think is pkg-query to try simplify and speed
up the dependency resolution etc. I have dreamed of creating something like launchpad for
Arch Linux. Also I would really like to contribute in a project where we'd freeze Arch
Linux every 2 years and create a 5 year stable version to use in servers and company
workstations.

Web file server
--------

1 To set up web file server install nginx `pacman -S nginx`  
2 edit nginx.conf `nano /etc/nginx/nginx.conf` and edit the `location / {}` section   

    location / {
            root   /srv/http;
            autoindex on;
        }

3 enable and start nginx `systemctl enable nginx && systemctl start nginx`
