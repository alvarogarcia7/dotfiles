#!/usr/bin/env bash
# Lists the branch tips of the repo, newest first:
#   <local time> (<age>)  <short SHA>  <branch>
# A local branch whose remote-tracking branch is at the same commit is one line, marked
# (+ origin/ ). Remote branches without a local copy are listed on their own.
# Runs on bash 3.2 (macOS) and bash 4+ (Linux), with GNU or BSD date.
#
# Usage: scripts/branch-dates.sh          (from inside the repo)
#        git branch-dates                  (with the alias below)
#
# Alias:  branch-dates = !bash ~/bin/branch-dates.sh   (or the path to this script)
set -eu

now="$(date +%s)"
if date --version >/dev/null 2>&1; then
  format_date() { date -d "@$1" '+%Y-%m-%d %H:%M:%S %Z'; }
else
  format_date() { date -r "$1" '+%Y-%m-%d %H:%M:%S %Z'; }
fi

age() {
  local seconds=$((now - $1))
  [ "$seconds" -lt 0 ] && seconds=0
  if [ "$seconds" -lt 3600 ]; then
    echo "$((seconds / 60)) min ago"
  elif [ "$seconds" -lt 172800 ]; then
    echo "$((seconds / 3600)) h ago"
  else
    echo "$((seconds / 86400)) d ago"
  fi
}

git for-each-ref --sort=-committerdate \
    --format='%(committerdate:unix)%09%(refname)%09%(objectname:short)' \
    refs/heads refs/remotes |
  awk -F'\t' '
    $2 ~ /^refs\/heads\// {
      b = substr($2, 12)
      if (!(b in seen)) { seen[b] = 1; order[++n] = b }
      lts[b] = $1; lsha[b] = $3; has[b] = 1
      next
    }
    $2 ~ /^refs\/remotes\// {
      r = substr($2, 14)
      if (r ~ /\/HEAD$/) next
      s = index(r, "/")
      rem = substr(r, 1, s - 1)
      b = substr(r, s + 1)
      if (!(b in seen)) { seen[b] = 1; order[++n] = b }
      rts[b, rem] = $1; rsha[b, rem] = $3; rems[b] = rems[b] " " rem
      next
    }
    END {
      for (i = 1; i <= n; i++) {
        b = order[i]
        k = split(rems[b], list, " ")
        shown = ""
        for (j = 1; j <= k; j++) {
          rm = list[j]
          if (has[b] && rts[b, rm] == lts[b] && rsha[b, rm] == lsha[b]) shown = shown " " rm "/ )"
          else printf "%s\t%s\t%s\n", rts[b, rm], rm "/" b, rsha[b, rm]
        }
        if (has[b]) {
          label = (shown != "") ? b " (+" shown : b
          printf "%s\t%s\t%s\n", lts[b], label, lsha[b]
        }
      }
    }' |
  while IFS="$(printf '\t')" read -r ts label sha; do
    printf '%s  (%s)  %s  %s\n' "$(format_date "$ts")" "$(age "$ts")" "$sha" "$label"
  done
