#!/bin/bash

CMAKE=`which cmake`
if [ ! $CMAKE ] ; then
  echo "You need cmake to do this. Try installing it with homebrew."
  exit 1
fi

cd `dirname "$0"`

if [ "$#" -ne "1" ] ; then
  echo "Usage $0 libgit2-release-tag"
  exit 1
fi

TAG="$1"

rm -rf ./libgit2src
git clone https://github.com/libgit2/libgit2 libgit2src
cd libgit2src
git checkout "$TAG"
if [ $? -ne "0" ] ; then
  echo "Could not find tag $TAG"
  exit 1
fi

mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=`pwd`/install
cmake --build . --target install

if [ $? -ne "0" ] ; then
  echo "cmake failed :("
  exit 1
fi

cd ../..
cp -L libgit2src/build/install/lib/libgit2.dylib ./
install_name_tool -id @executable_path/../Frameworks/libgit2.dylib libgit2.dylib

rm -rf libgit2_include
cp -R libgit2src/build/install/include ./libgit2_include

rm -rf ./libgit2src

echo "libgit2 Updated Successfully"
