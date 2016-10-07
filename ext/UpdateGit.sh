#!/bin/bash

cd `dirname "$0"`

if [ "$#" -ne "1" ] ; then
  echo "Usage $0 git-release-tag"
  exit 1
fi

TAG="$1"

rm -rf ./gitsrc
git clone https://github.com/git/git gitsrc
cd gitsrc
git checkout "$TAG"
if [ $? -ne "0" ] ; then
  echo "Could not find tag $TAG"
  exit 1
fi

make NO_GETTEXT=1 NO_OPENSSL=1 NO_DARWIN_PORTS=1 NO_FINK=1 prefix=/usr all

if [ $? -ne "0" ] ; then
  echo "Make failed :("
  exit 1
fi

cd ..
cp gitsrc/git ./
rm -rf ./gitsrc

echo "Git Updated Successfully"

./git --version
