#!/bin/bash

# A script to update HighlightedWebView from my branch's master
# and then mirror it into our repository. This is used as 
# a workaround for the fact that I hate git submodules.

cd `basename $0`
pwd
pushd .

GTMP=`mktemp -d /tmp/SocketRocketXXXXX`
cd $GTMP
git clone https://github.com/james-howard/HighlightedWebView.git
cd HighlightedWebView
mkdir ../HighlightedWebViewArchive
git archive master | tar -x -C ../HighlightedWebViewArchive

popd
if [ ! -e "HighlightedWebView" ] ; then
    mkdir HighlightedWebView
fi

rsync -rav $GTMP/HighlightedWebViewArchive/* ./HighlightedWebView/

rm -rf $GTMP
