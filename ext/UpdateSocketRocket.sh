#!/bin/bash

# A script to update SocketRocket from my branch's master
# and then mirror it into our repository. This is used as 
# a workaround for the fact that I hate git submodules.

cd `dirname $0`
pwd
pushd .

GTMP=`mktemp -d /tmp/SocketRocketXXXXX`
cd $GTMP
git clone https://github.com/facebook/SocketRocket.git
cd SocketRocket
git submodule init
git submodule update
mkdir ../SocketRocketArchive
git-archive-all SocketRocketArchive.tar
cat SocketRocketArchive.tar | tar -x -C ../
# git archive master | tar -x -C ../SocketRocketArchive

popd
if [ ! -e "SocketRocket" ] ; then
    mkdir SocketRocket
fi

rsync -rav $GTMP/SocketRocketArchive/* ./SocketRocket/ --delete

rm -rf $GTMP
