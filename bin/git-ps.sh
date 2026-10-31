#!/usr/bin/env bash
# Pushes the current branch without starting CI.
#   GitHub remote: the last line of the last commit must contain [ci skip]. If it does not,
#                  an empty commit with that line is added first. The push itself is plain.
#   Other remotes: pushes with the GitLab push option ci.skip.
# Any arguments are passed to git push.
#
# Alias:  ps = !bash ~/bin/git-ps.sh
set -eu

marker="[ci skip]"

branch="$(git symbolic-ref --short HEAD)"
remote="$(git config --get "branch.$branch.pushRemote" || git config --get remote.pushDefault || git config --get "branch.$branch.remote" || echo origin)"
url="$(git config --get "remote.$remote.pushurl" || git config --get "remote.$remote.url" || true)"

case "$url" in
  *github.com[:/]*)
    last_line="$(git log -1 --format=%B | sed -e '/^[[:space:]]*$/d' | tail -n 1)"
    if [ "${last_line#*"$marker"}" = "$last_line" ]; then
      echo "git ps: last commit has no $marker line, adding an empty commit"
      git commit -q --allow-empty -m "Skip CI" -m "$marker"
    fi
    git push "$@"
    ;;
  *)
    git push --push-option=ci.skip "$@"
    ;;
esac
