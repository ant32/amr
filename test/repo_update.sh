#!/bin/bash
testing="/srv/http/archlinux/mingw-w64-testing/os/x86_64"
repo="/srv/http/archlinux/mingw-w64/os/x86_64"

rm "$testing/mingw-w64-testing.db"*
rm "$testing/dummy-1-1-any.pkg.tar.xz"
mv "$testing/"* $repo
rm "$repo/mingw-w64.db"*
repo-add "$repo/mingw-w64.db.tar.gz" "$repo/"*
cp /scripts/dummy-1-1-any.pkg.tar.xz "$testing"
repo-add "$testing/mingw-w64-testing.db.tar.gz" "$testing/"*
