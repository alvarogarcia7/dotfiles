#!/bin/bash

set -euo pipefail

# Tip: In IntelliJ, select multiple commits, then "copy revision number".
# Arguments:
#   [time_to_wait] commit_sha1 [commit_sha2 ...]
#   time_to_wait: optional integer, number of seconds to wait between pushes (default: 120)
#   commit_sha: one or more commit SHAs to push to the current branch
commits=()

push_commit() {
  local revision
  revision="$1"
  local branch
  branch="$2"
  local time_to_wait
  time_to_wait="$3"

  git push origin "${revision}":refs/heads/"${branch}" --force-with-lease
  sleep "$time_to_wait"
}


current_branch=$(git --no-pager branch | grep '*' | awk '{print $2}')

# Parse arguments: optional time_to_wait (integer) followed by commit SHAs
if [[ $# -gt 0 && "$1" =~ ^[0-9]+$ ]]; then
  time_to_wait="$1"
  shift
else
  time_to_wait=120
fi

# Parse commit SHAs from remaining arguments
if [[ $# -eq 0 ]]; then
  echo "Error: At least one commit SHA is required"
  exit 1
fi

commits=("$@")

echo "Waiting ${time_to_wait} seconds between pushes"
echo "Commits to push: ${commits[*]}"

gtr_name=pusher_$(date "+%Y-%m-%dT%H%M%S")

git gtr new "${gtr_name}" --from "$current_branch"

cd "$(git gtr go "${gtr_name}")"

for revision in "${commits[@]}"; do
  push_commit "$revision" "$current_branch" "$time_to_wait"
done

echo "Finished"

git gtr rm "${gtr_name}"
