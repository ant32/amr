#!/usr/bin/bash

testmingw() {
 while read pkg; do
   maint=false; repo=false
   [[ "`yaourt -Si aur/$pkg | grep Maintainer`" = "Maintainer     : -" ]] && maint=true
   [[ "`yaourt -Si $pkg | grep Repository`" = "Repository     : mingw-w64"* ]] && repo=true
   $maint && $repo && echo "$pkg is no longer maintained"
   ! $maint && ! $repo && echo "$pkg is not in the repository"
 done
}

yaourt -Ssqm mingw-w64 | testmingw
