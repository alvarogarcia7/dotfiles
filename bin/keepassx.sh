#!/bin/bash

set -e
set -x

source ~/.bashrc

file=$1 #in absolute path

function backup {
  date=`date +%Y%m%d-%H%M%S`
  ini=${date}-$(basename $file)

  set +e
  git add $file
  git commit -m "$ini"
  set -e
}

function backup_after {
  date=`date +%Y%m%d-%H%M%S`
  destination=${date}-finsesion-$(basename $file)

  set +e
  git add $file
  git commit -m "$destination"
  set -e
}


function open {
  keepass="keypass"

  if [[ -z $(which keepassx) ]]; then
    #keepass="/Applications/KeePassX.app/Contents/MacOS/KeePassX"
    keepass="/Applications/KeeWeb.app/Contents/MacOS/KeeWeb"
  fi

  $keepass $file
}

function push_backups {
  git push
}

cd $(dirname $file)
backup $file
open $file
backup_after $file
push_backups 

