#!/bin/bash

set -e

if [ -z ${GIT_DATE_DELTA+x} ]; then
    echo "date delta not set"
else 
  # Detect the operating system.
  # Source: https://stackoverflow.com/questions/394230/how-to-detect-the-os-from-a-bash-script
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then #linux
    # An example:
    # export $GIT_DATE_DELTA="2 hours ago"
    export GIT_COMMITTER_DATE=$(date --date="$GIT_DATE_DELTA")
    export GIT_AUTHOR_DATE=$(date --date="$GIT_DATE_DELTA")
  elif [[ "$OSTYPE" == "darwin"* ]]; then # Mac OSX
    # An example:
    # export $GIT_DATE_DELTA="-2H"
    export GIT_COMMITTER_DATE=$(date -v $GIT_DATE_DELTA)
    export GIT_AUTHOR_DATE=$(date -v $GIT_DATE_DELTA)
  else
    echo "This script is not supported for this operating system '$OSTYPE'"
    exit -1 
  fi
fi

git commit "$@"

