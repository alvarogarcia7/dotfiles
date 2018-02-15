#!/bin/bash

set -e

if [ -z ${GIT_DATE_DELTA+x} ]; then
    echo "date delta not set"
else 
    export GIT_COMMITTER_DATE=$(date -v $GIT_DATE_DELTA)
    export GIT_AUTHOR_DATE=$(date -v $GIT_DATE_DELTA)
fi

git commit "$@"

