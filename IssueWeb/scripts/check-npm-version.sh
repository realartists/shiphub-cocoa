#!/bin/sh

VERSION=`npm --version`

if [ "$VERSION" != "3.7.3" ] ; then
  echo "npm version is ${VERSION} but must be exactly 3.7.3"
  echo "See IssueWeb/README.md for installation instructions"
  exit 1
fi

exit 0
