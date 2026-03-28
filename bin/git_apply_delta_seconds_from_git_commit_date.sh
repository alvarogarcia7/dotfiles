#!/bin/zsh

set -euxo pipefail

function main {
  if [[ "$#" -lt 2 ]]; then
    echo "usage: $0/git_apply_delta_seconds_from_git_commit_date git_commit_prefix time_delta_in_seconds [--force| dry run by default]"
    return 1
  fi
  git_commit_prefix="${1}"
  time_delta_in_seconds="${2}"
  dry_run="${3:-1}"
  if [[ "${dry_run}" = "--force" ]];then
    dry_run="0"
  fi
  previous_date=$(git log -n1 --format="%at" --date=raw)
  new_date=$(($previous_date + ${time_delta_in_seconds}))
  commit=$(git log -n1 --format="%H")
  #GIT_AUTHOR_DATE="$new_date" GIT_COMMITTER_DATE="$new_date" git commit --amend --date="$new_date" --reuse-message="$commit"
  subject_and_body=$(git log -n1 --format="%B")
  subject_and_body=$(echo "$subject_and_body" | grep -viE "Co-Authored|Haiku|Opus|Sonnet|Claude|Anthropic|Tonkotsu|Codex")
  if [[ $subject_and_body == $git_commit_prefix* ]]; then
    :
  else
    subject_and_body="${git_commit_prefix} ${subject_and_body}"
  fi
  echo -n "Body: "
  echo "$subject_and_body"
  echo -n "Date: "

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then #linux
      date_formatted=$(date --date=@"$new_date")
  elif [[ "$OSTYPE" == "darwin"* ]]; then # Mac OSX
    date_command="date -r \"$new_date\""
    set +u
    if [[ -n "${GIT_DATE_DELTA}" ]]; then
      date_command="$date_command -v \"$GIT_DATE_DELTA\""
    fi
    set -u
    if [ ! -z ${TZ+x} ]; then
	# TZ (timezone) is set
      date_command="TZ=$TZ $date_command"
    fi
    date_formatted="$(eval $date_command)"
  else
    echo "This script is not supported for this operating system '$OSTYPE'"
    return -1
  fi
  echo "$date_formatted"
  if [[ "${dry_run}" = "1" ]]; then
    echo "use --force to apply changes"
  else
    echo "$subject_and_body" | GIT_AUTHOR_DATE="$new_date" GIT_COMMITTER_DATE="$new_date" git commit --amend --date="$new_date" --reset-author -F -
  fi
}

main "$@"
