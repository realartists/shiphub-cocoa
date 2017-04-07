#!/bin/bash

#  clonepr.sh
#  Ship 2
#
#  Copyright © 2017 Real Artists, Inc. All rights reserved.

#  Clones and configures a git working copy for a Pull Request

# --- VARIABLES

REPO_NAME=''
REPO_PATH=''
REMOTE_URL=''
REF_NAME=''
BRANCH_NAME=''
BASE_REV=''
HEAD_REV=''

# --- END VARIABLES

cd /tmp && \
cd `mktemp -d "${REPO_NAME}.XXXXXX"` && \
git clone -q -l -n -o file "${REPO_PATH}" "${REPO_NAME}" && \
cd "${REPO_NAME}" && \
git remote add origin "${REMOTE_URL}" && \
git pull -q file "${REF_NAME}:${BRANCH_NAME}" && \
git checkout -q "${BRANCH_NAME}" && \
git remote remove file && \
git branch -q -d master

if [ $? -ne "0" ] ; then
    echo '!!! Git Clone Failed :('
    exit 1
fi

alias prsummary="git diff --summary --stat ${BASE_REV}...${HEAD_REV}"

printf "\n${BRANCH_NAME} checked out\n"
printf "\tBASE_REV=${BASE_REV}\n"
printf "\tHEAD_REV=${HEAD_REV}\n"
printf "\tTo see a summary of changes in this PR, run \`prsummary\`\n"
printf "\tRun \`git fetch origin\` to fetch from github\n\n"
