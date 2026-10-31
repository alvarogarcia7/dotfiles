#!/usr/bin/env bash
# Tests for bin/git-ps.sh. Each test builds a bare remote and a work clone in a temporary
# directory. The remote URL is a github.com or gitlab.com address rewritten to the local bare
# repository with url.<base>.insteadOf, so the script sees the real host name.
# Usage: test/git-ps.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/bin/git-ps.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

passed=0
failed=0

fail() {
  echo "  FAIL: $1"
  failed=$((failed + 1))
}

pass() {
  passed=$((passed + 1))
}

assert_eq() { # assert_eq <description> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass
  else
    fail "$1 (expected '$2', got '$3')"
  fi
}

# new_repo <remote host URL> : creates $TMP/<n>/remote.git and $TMP/<n>/work with one commit.
new_repo() {
  local dir="$TMP/$1"
  local url="$2"
  mkdir -p "$dir"
  git init -q --bare "$dir/remote.git"
  git -C "$dir/remote.git" config receive.advertisePushOptions true
  git init -q "$dir/work"
  git -C "$dir/work" commit -q --allow-empty -m "first"
  git -C "$dir/work" config "url.$dir/remote.git.insteadOf" "$url"
  git -C "$dir/work" remote add origin "$url"
  git -C "$dir/work" push -q -u origin HEAD
}

# run_ps [args]: runs the script inside $dir, the work clone of the current test.
run_ps() {
  (cd "$dir" && bash "$SCRIPT" "$@") >/dev/null 2>&1
}

commit_count() { git -C "$1" rev-list --count HEAD; }
last_subject() { git -C "$1" log -1 --format=%s; }
last_nonblank_line() { git -C "$1" log -1 --format=%B | sed -e '/^[[:space:]]*$/d' | tail -n 1; }
remote_head() { git -C "$1/remote.git" rev-parse HEAD; }
local_head() { git -C "$1" rev-parse HEAD; }

echo "github.com remote"

new_repo gh1 https://github.com/example/demo.git
dir="$TMP/gh1/work"
git -C "$dir" commit -q --allow-empty -m "feature work"
before="$(commit_count "$dir")"
run_ps
assert_eq "adds one commit when the marker is missing" "$((before + 1))" "$(commit_count "$dir")"
assert_eq "new commit subject" "Skip CI" "$(last_subject "$dir")"
assert_eq "last line of the new commit is [ci skip]" "[ci skip]" "$(last_nonblank_line "$dir")"
assert_eq "the commit is pushed" "$(local_head "$dir")" "$(remote_head "$TMP/gh1")"

new_repo gh2 https://github.com/example/demo.git
dir="$TMP/gh2/work"
git -C "$dir" commit -q --allow-empty -m "feature work" -m "[ci skip]"
before="$(commit_count "$dir")"
run_ps
assert_eq "adds nothing when the last line has the marker" "$before" "$(commit_count "$dir")"
assert_eq "pushes the existing commit" "$(local_head "$dir")" "$(remote_head "$TMP/gh2")"

new_repo gh3 https://github.com/example/demo.git
dir="$TMP/gh3/work"
git -C "$dir" commit -q --allow-empty -m "feature work" -m "[ci skip]" -m "Some text after the marker"
before="$(commit_count "$dir")"
run_ps
assert_eq "marker on a line that is not the last adds one commit" "$((before + 1))" "$(commit_count "$dir")"
assert_eq "last line is [ci skip] after the new commit" "[ci skip]" "$(last_nonblank_line "$dir")"

new_repo gh4 https://github.com/example/demo.git
dir="$TMP/gh4/work"
git -C "$dir" commit -q --allow-empty -m "feature work" -m "Notes" -m "[ci skip]"
before="$(commit_count "$dir")"
run_ps
assert_eq "marker as the last line with a body adds nothing" "$before" "$(commit_count "$dir")"

new_repo gh5 https://github.com/example/demo.git
dir="$TMP/gh5/work"
git -C "$dir" commit -q --allow-empty -m "feature work"
before="$(commit_count "$dir")"
remote_before="$(remote_head "$TMP/gh5")"
run_ps --dry-run
assert_eq "--dry-run adds the commit locally" "$((before + 1))" "$(commit_count "$dir")"
assert_eq "--dry-run leaves the remote unchanged" "$remote_before" "$(remote_head "$TMP/gh5")"

echo "other remote"

new_repo gl1 https://gitlab.com/example/demo.git
dir="$TMP/gl1/work"
git -C "$dir" commit -q --allow-empty -m "feature work"
before="$(commit_count "$dir")"
run_ps
assert_eq "adds no commit on a non-GitHub remote" "$before" "$(commit_count "$dir")"
assert_eq "pushes with the ci.skip push option" "$(local_head "$dir")" "$(remote_head "$TMP/gl1")"

echo
echo "passed: $passed, failed: $failed"
[ "$failed" -eq 0 ]
