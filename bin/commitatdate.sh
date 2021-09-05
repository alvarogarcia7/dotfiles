#!/bin/bash

set -e

if [ -z ${GIT_DATE_DELTA+x} ]; then
    echo "date delta not set"
else 
  # Detect the operating system.
  # Source: https://stackoverflow.com/questions/394230/how-to-detect-the-os-from-a-bash-script
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then #linux
    # An example:
    # export GIT_DATE_DELTA="2 hours ago"
    export GIT_COMMITTER_DATE=$(date --date="$GIT_DATE_DELTA")
    export GIT_AUTHOR_DATE=$(date --date="$GIT_DATE_DELTA")
  elif [[ "$OSTYPE" == "darwin"* ]]; then # Mac OSX
    # An example:
    # export GIT_DATE_DELTA="-2H"
    if [ -z ${TZ+x} ]; then
      # TZ is unset
      export GIT_COMMITTER_DATE=$(date -v "$GIT_DATE_DELTA")
    else
      export GIT_COMMITTER_DATE=$(TZ=$TZ date -v "$GIT_DATE_DELTA")
    fi
    export GIT_AUTHOR_DATE="$GIT_COMMITTER_DATE"
  else
    echo "This script is not supported for this operating system '$OSTYPE'"
    exit -1 
  fi
fi

# For normal usage
git commit "$@"

# For amending / rebasing
#git commit --allow-empty --amend --date "$GIT_COMMITTER_DATE"

