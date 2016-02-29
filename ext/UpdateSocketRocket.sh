#!/bin/bash

# A script to update SocketRocket from my branch's master
# and then mirror it into our repository. This is used as 
# a workaround for the fact that I hate git submodules.

cd `basename $0`
pwd
pushd .

GTMP=`mktemp -d /tmp/SocketRocketXXXXX`
cd $GTMP
git clone https://github.com/james-howard/SocketRocket.git
cd SocketRocket
mkdir ../SocketRocketArchive
git archive master | tar -x -C ../SocketRocketArchive

popd
if [ ! -e "SocketRocket" ] ; then
    mkdir SocketRocket
fi

rsync -rav $GTMP/SocketRocketArchive/* ./SocketRocket/

rm -rf $GTMP
