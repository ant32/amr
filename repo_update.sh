#!/bin/bash
testing="/srv/http/archlinux/mingw-w64-testing/os/x86_64"
repo="/srv/http/archlinux/mingw-w64/os/x86_64"

rm "$testing/mingw-w64-testing.db"*
rm "$testing/dummy-1-1-any.pkg.tar.xz"
scp "$testing/"* ant32@frs.sourceforge.net:/home/frs/project/mingw-w64-archlinux/x86_64
mv "$testing/"* $repo
rm "$repo/mingw-w64.db"*
repo-add "$repo/mingw-w64.db.tar.gz" "$repo/"*
scp "$repo/mingw-w64.db"* ant32@frs.sourceforge.net:/home/frs/project/mingw-w64-archlinux/x86_64
cp /scripts/dummy-1-1-any.pkg.tar.xz "$testing"
repo-add "$testing/mingw-w64-testing.db.tar.gz" "$testing/"*
