#!/usr/bin/env bash

set -euo pipefail


function assert_ (){
  local variable_name="$1"
  local expected_value="$2"

  if [ "$variable_name" != "$expected_value" ]; then
    echo "variable '$variable_name' is not matching '$expected_value'"
    exit -1
  fi
}

function check_git_variables(){
  local work_email="$1"

  assert_ "$GIT_AUTHOR_EMAIL" "$work_email"
  assert_ "$GIT_COMMITTER_EMAIL" "$work_email"
}

check_git_variables "$1"
