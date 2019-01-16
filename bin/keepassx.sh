#!/bin/bash

set -e

source ~/.bashrc

file=$1 #in absolute path

function backup {
  date=$(date +%Y%m%d-%H%M%S)
  ini=${date}-$(basename "$file")

  set +e
  git add "$file"
  git commit -m "$ini"
  set -e
}

function backup_after {
  date=$(date +%Y%m%d-%H%M%S)
  destination=${date}-finsesion-$(basename "$file")

  set +e
  git add "$file"
  git commit -m "$destination"
  set -e
}

function update {
  git pull origin master
  git pull codecommit master
}


function open {
  keepass="keypass"

  if [[ -z $(command -v keepassx) ]]; then
    #keepass="/Applications/KeePassX.app/Contents/MacOS/KeePassX"
    keepass="/Applications/KeeWeb.app/Contents/MacOS/KeeWeb"
  fi

  $keepass "$file"
}

function push_backups {
  git push origin
  git push codecommit
}

cd "$(dirname "$file")"
update "$file"
backup "$file"
open "$file"
backup_after "$file"
push_backups 

