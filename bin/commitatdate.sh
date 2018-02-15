#!/bin/bash

set -e

if [ -z ${GIT_DATE_DELTA+x} ]; then
    echo "var is unset"
else 
    export GIT_COMMITTER_DATE=$(date -v $GIT_DATE_DELTA)
    export GIT_AUTHOR_DATE=$(date -v $GIT_DATE_DELTA)
    echo "dates are now set"
    echo "GIT_COMMITTER_DATE=$GIT_COMMITTER_DATE" 
    echo "GIT_AUTHOR_DATE=$GIT_AUTHOR_DATE" 
fi

git commit "$@"

