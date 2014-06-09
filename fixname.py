#!/usr/bin/env python3
import os
import sys
import glob

TEST_DIR = '/build/amr/repo/*.pkg.tar.xz'
REPO_DIR = '/build/amr/sf/x86_64/*.pkg.tar.xz'
PKG_END = '.pkg.tar.xz'


def remove_dir(dirtext):
    return dirtext[dirtext.rfind("/")-len(dirtext)+1:]

def fix_name(name):
    name = name.replace(':', '_')
    pkgname = name.replace(PKG_END, '')
    _max = -1
    for file in glob.glob(TEST_DIR) + glob.glob(REPO_DIR):
        file = remove_dir(file)
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
