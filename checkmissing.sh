#!/usr/bin/bash

testmingw() {
 while read pkg; do
   [ "`yaourt -Si $pkg | grep Maintainer`" = "Maintainer     : -" ] && maint=false || maint=true
   [ "`yaourt -Si $pkg | grep Repository`" = "Repository     : mingw-w64" ] && repo=true || repo=false
   ! $maint && $repo && echo "$pkg is no longer maintained"
   $maint && ! $repo && echo "$pkg is not in the repository"
 done
}

yaourt -Ssqm mingw-w64 | testmingw
