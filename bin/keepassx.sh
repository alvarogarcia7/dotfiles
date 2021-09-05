#!/bin/bash

set -e

file=$1 #in absolute path

function backup {
  date=$(date +%Y%m%d-%H%M%S)
  ini=${date}-$(basename "$file")

  set +e
  git add . 
  git commit -m "${date}-ini"
  set -e
}

function backup_after {
  date=$(date +%Y%m%d-%H%M%S)
  destination=${date}-finsesion-$(basename "$file")

  set +e
  git add .
  git commit -m "${date}-finsesion"
  set -e
}

function update {
  git pull origin master
  #git pull codecommit master
}


function open {

  keepass=""
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then #linux
    keepass="keeweb"
  elif [[ "$OSTYPE" == "darwin"* ]]; then # Mac OSX
    #keepass="/Applications/KeePassX.app/Contents/MacOS/KeePassX"
    keepass="/Applications/KeeWeb.app/Contents/MacOS/KeeWeb"
  else
    echo "This script is not supported for this operating system '$OSTYPE'"
    exit -1
  fi

  $keepass "$file"
}

function push_backups {
  time git push origin
  time git push codecommit
}

cd "$(dirname "$file")"
update "$file"
backup "$file"
open "$file"
backup_after "$file"
push_backups 

