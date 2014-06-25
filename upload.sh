HOME=/build/amr
reponame=mingw-w64
testingreponame=mingw-w64-testing
repodir=$HOME/Dropbox/repo
testingrepodir=$HOME/Dropbox/repo-testing
# make sure dropbox is running ($HOME must have been defined)
dropboxd &
# remove testing repo file since we don't want to copy it
rm $testingrepodir/$testingreponame.db*
# copy all files to the main repo
mv $testingrepodir/* $repodir
repo-add $reponame.db.tar.gz *
#upload changes to sourceforge
rsync -e ssh -vLu $repodir/* ant32@frs.sourceforge.net:/home/frs/project/mingw-w64-archlinux/x86_64/
# create new testing repo
touch $testingrepodir/$testingreponame.db.tar.gz
ln -s $testingrepodir/$testingreponame.db.db.tar.gz $testingrepodir/$testingreponame.db
