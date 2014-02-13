#!/usr/bin/env python3
import os
import sys

TEST_DIR = '/srv/http/archlinux/mingw-w64-testing/os/x86_64'
REPO_DIR = '/srv/http/archlinux/mingw-w64/os/x86_64'
PKG_END = '.pkg.tar.xz'


def fix_name(name):
    name = name.replace(':', '_')
    pkgname = name.replace(PKG_END, '')
    _max = -1
    for file in os.listdir(TEST_DIR) + os.listdir(REPO_DIR):
        if file.startswith(pkgname):
            p = file.replace(pkgname, '')
            p = p.replace(PKG_END, '')
            try:
                p = int(p.replace('_', ''))
            except:
                p = 0
            if p > _max:
                _max = p
    if _max == -1:
        return name
    else:
        return '{}_{}{}'.format(pkgname, _max + 1, PKG_END)


nname = fix_name(sys.argv[1])
print(nname)
