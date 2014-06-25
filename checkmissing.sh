#!/usr/bin/bash

testmingw() {
  while read pkg; do
    maint=false; repo=false
    pkgstr=$(yaourt -Si aur/$pkg)
    
    # get votes
    votes="$(echo "$pkgstr" | grep Votes)"
    votes=(${votes//:/ })
    votes=(${votes[1]})
    
    # get last updated
    updated="$(echo "$pkgstr" | grep 'Last update')"
    updated=(${updated//:/ })
    updated="${updated[3]} ${updated[4]} ${updated[5]}"
    
    [[ "$(echo "$pkgstr" | grep Maintainer)" = "Maintainer     : -" ]] && maint=true
    [[ "$(yaourt -Si $pkg | grep Repository)" = "Repository     : mingw-w64"* ]] && repo=true
    
    $maint && $repo && echo -e "$pkg\tOrphaned\t$votes\t$updated"
    ! $maint && ! $repo && echo -e "$pkg\tMissing\t$votes\t$updated"
  done
  
}

echo -e "Package\tStatus\tVotes\tUpdated"

# find deleted packages
while read pkg; do
  if [ "${pkg:0:1}" != "#" ]; then
    if ! yaourt -Si aur/$pkg >/dev/null 2>&1; then echo -e "$pkg\tDeleted"; fi
  fi
done < "buildlist.txt.bak"

yaourt -Ssqm mingw-w64 | testmingw
