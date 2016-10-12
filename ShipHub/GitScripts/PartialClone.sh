#!/bin/sh

#  PartialClone.sh
#  ShipHub
#
#  Created by James Howard on 10/11/16.
#  Copyright © 2016 Real Artists, Inc. All rights reserved.

#  Performs a partial clone of the requested git repo, checking out just the paths provided
#  The current working directory will contain the cloned repo when finished.

SCRIPT_PATH="$0"

usage() {
    echo "Usage: $SCRIPT_PATH <git executable path> <git url> <git ref> paths"
    exit 1
}

GIT="$1"; (shift || usage())
AUTH_TOKEN="$1"; (shift || usage())
URL="$1"; (shift || usage())
REF="$1"; (shift || usage())

echo "Cloning into $PWD"

"$GIT" init
"$GIT" remote add origin "$URL"

"$GIT" config core.sparseCheckout true

while (( "$#" )); do
    echo "$1" >> .git/info/sparse-checkout
    shift
done

"$GIT" pull "$URL" "$REF"
if [ $? -ne "0" ] ; then
    exit $?
fi

exit 0
