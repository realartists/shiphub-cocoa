#!/bin/bash

set -o errexit
set -o nounset

NPM="/usr/local/bin/npm"

if [[ ! -x $NPM ]]; then
  echo "node and npm are required; run \`brew install node\`"
  exit 1
fi

cd "$PROJECT_DIR"/IssueWeb

if [[ ! -d node_modules ]]; then
    echo "node_modules dir missing; running npm install."
    $NPM install
fi

CHANGED_FILES_COUNT=$(git status --porcelain . | wc -l)
if [[ $CHANGED_FILES_COUNT -gt 0 || ! -d dist ]]; then
    echo "Running webpack..."

    TEMP_PATH=$(/usr/bin/mktemp -d -t webpack-out)
    trap "rm -rf \"$TEMP_PATH\"" EXIT

    if [[ $CONFIGURATION == "Debug" ]]; then
        "$($NPM bin)"/webpack --output-path "$TEMP_PATH"
    else
        # Production builds are way slower so only do them for Release.
        "$($NPM bin)"/webpack -p --output-path "$TEMP_PATH"
    fi

    # Only move into place if build was successful.
    rsync -avz -u --delete "$TEMP_PATH/" dist/
else
    echo "No changed files; skipping build."
fi
