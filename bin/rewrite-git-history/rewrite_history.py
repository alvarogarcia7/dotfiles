#!/usr/bin/env python3
"""Rewrite a branch's history from a given commit: remove Co-Authored-By
trailers and set the author and committer identity.

Every commit from --root to the branch tip is replayed with `git commit-tree`
(trees, dates and parent structure are kept), then the branch is moved to the
new tip. The working tree is never touched.

Each rewritten commit is recorded in a CSV file as `commit_before,commit_after`
so references to old commits (merge requests, notes, task files) can be updated.
Rows are appended, so the file keeps the mapping of every rewrite run.

A backup branch at the old tip is created first, unless --no-backup is given.

Examples:
    bin/rewrite-git-history/rewrite_history.py --root 1d6a82c \\
        --author-name "Alvaro Garcia" \\
        --author-email alvarogarcia7@users.noreply.github.com --dry-run
    bin/rewrite-git-history/rewrite_history.py --root 1d6a82c --author-name "Alvaro Garcia" \\
        --author-email alvarogarcia7@users.noreply.github.com --csv rewrite-map.csv
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import subprocess
import sys
import time
from collections.abc import Mapping
from typing import Any

COAUTHOR_RE = re.compile(r"^\s*co-authored-by:", re.IGNORECASE)
IDENTITY_RE = re.compile(r"^(author|committer) (.*) <([^>]*)> (\d+ [+-]\d{4})$")
CSV_HEADER = ["commit_before", "commit_after"]


class RewriteError(Exception):
    pass


def git(
    *args: str, input_bytes: bytes | None = None, env: Mapping[str, str] | None = None
) -> bytes:
    result = subprocess.run(
        ["git", *args],
        input=input_bytes,
        capture_output=True,
        env=env,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", "replace").strip()
        raise RewriteError(f"git {' '.join(args)} failed: {message}")
    return result.stdout


def is_ancestor(older: str, newer: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", older, newer], capture_output=True
    )
    return result.returncode == 0


def git_text(*args: str) -> str:
    return git(*args).decode("utf-8", "replace").strip()


def clean_message(message: str) -> str:
    """Message with Co-Authored-By lines removed and trailing blank lines dropped."""
    kept = [line for line in message.split("\n") if not COAUTHOR_RE.match(line)]
    text = "\n".join(kept).rstrip("\n")
    return text + "\n"


def parse_commit(sha: str) -> dict[str, Any]:
    """Tree, parents, author/committer timestamps and message of a commit."""
    raw = git("cat-file", "commit", sha).decode("utf-8", "surrogateescape")
    header, _, message = raw.partition("\n\n")
    tree: str | None = None
    parents: list[str] = []
    author: re.Match[str] | None = None
    committer: re.Match[str] | None = None
    for line in header.split("\n"):
        if line.startswith("tree "):
            tree = line[5:]
        elif line.startswith("parent "):
            parents.append(line[7:])
        elif line.startswith("author "):
            author = IDENTITY_RE.match(line)
        elif line.startswith("committer "):
            committer = IDENTITY_RE.match(line)
    if tree is None or author is None or committer is None:
        raise RewriteError(f"could not read commit {sha}")
    return {
        "tree": tree,
        "parents": parents,
        "author_date": author.group(4),
        "committer_date": committer.group(4),
        "message": message,
    }


def commits_to_rewrite(root: str, tip: str) -> list[str]:
    """Commits from root (inclusive) to tip, oldest first."""
    if not is_ancestor(root, tip):
        raise RewriteError(f"--root {root[:12]} is not an ancestor of the branch tip")
    parent_list = git_text("rev-list", "--parents", "-n", "1", root).split()[1:]
    args = ["rev-list", "--reverse", "--topo-order", tip]
    if parent_list:
        args += ["--not", *parent_list]
    return git_text(*args).split()


def rewrite(
    commits: list[str], author_name: str, author_email: str
) -> list[tuple[str, str]]:
    """Replay commits; returns the list of (old, new) pairs and the new tip."""
    mapping: dict[str, str] = {}
    pairs: list[tuple[str, str]] = []
    for old in commits:
        info = parse_commit(old)
        parents = [mapping.get(parent, parent) for parent in info["parents"]]
        identity = {
            "GIT_AUTHOR_NAME": author_name,
            "GIT_AUTHOR_EMAIL": author_email,
            "GIT_AUTHOR_DATE": info["author_date"],
            "GIT_COMMITTER_NAME": author_name,
            "GIT_COMMITTER_EMAIL": author_email,
            "GIT_COMMITTER_DATE": info["committer_date"],
        }
        env = {**os.environ, **identity}
        message = clean_message(info["message"])
        args = ["commit-tree", info["tree"]]
        for parent in parents:
            args += ["-p", parent]
        new_bytes = git(
            *args, input_bytes=message.encode("utf-8", "surrogateescape"), env=env
        )
        new = new_bytes.decode("ascii").strip()
        mapping[old] = new
        pairs.append((old, new))
    return pairs


def append_csv(path: str, pairs: list[tuple[str, str]]) -> None:
    is_new = not os.path.exists(path) or os.path.getsize(path) == 0
    with open(path, "a", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        if is_new:
            writer.writerow(CSV_HEADER)
        writer.writerows(pairs)


def current_branch() -> str:
    name = git_text("symbolic-ref", "--short", "-q", "HEAD")
    if not name:
        raise RewriteError("HEAD is detached; pass --branch NAME")
    return name


def working_tree_dirty() -> bool:
    return bool(git_text("status", "--porcelain", "--untracked-files=no"))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove Co-Authored-By trailers and set the author of commits "
        "from --root to the branch tip. Old and new commit IDs go to a CSV file."
    )
    parser.add_argument(
        "--root", required=True, help="first commit to rewrite (inclusive)"
    )
    parser.add_argument(
        "--branch", help="branch to rewrite (default: the current branch)"
    )
    parser.add_argument(
        "--author-name", required=True, help="name for author and committer"
    )
    parser.add_argument(
        "--author-email", required=True, help="email for author and committer"
    )
    parser.add_argument(
        "--csv",
        default="rewrite-map.csv",
        help="CSV file to append commit_before,commit_after rows to (default: rewrite-map.csv)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="show the plan, change nothing"
    )
    parser.add_argument(
        "--no-backup", action="store_true", help="do not create a backup branch"
    )
    parser.add_argument(
        "--allow-dirty",
        action="store_true",
        help="run with uncommitted tracked changes",
    )
    args = parser.parse_args()

    try:
        branch = args.branch or current_branch()
        ref = f"refs/heads/{branch}"
        old_tip = git_text("rev-parse", "--verify", ref)
        root = git_text("rev-parse", "--verify", f"{args.root}^{{commit}}")
        if working_tree_dirty() and not args.allow_dirty and not args.dry_run:
            raise RewriteError(
                "uncommitted changes; commit or stash them, or use --allow-dirty"
            )

        commits = commits_to_rewrite(root, old_tip)
        print(
            f"rewriting {len(commits)} commit(s) on {branch} from {root[:12]} to {old_tip[:12]}",
            file=sys.stderr,
        )
        if args.dry_run:
            for sha in commits:
                info = parse_commit(sha)
                trailers = sum(
                    1 for line in info["message"].split("\n") if COAUTHOR_RE.match(line)
                )
                print(f"{sha[:12]}  co-author lines: {trailers}")
            print("dry run: nothing changed", file=sys.stderr)
            return

        pairs = rewrite(commits, args.author_name, args.author_email)
        new_tip = dict(pairs)[old_tip]

        if not args.no_backup:
            stamp = time.strftime("%Y%m%d-%H%M%S")
            backup = f"backup/{branch}-before-rewrite-{stamp}"
            git("update-ref", f"refs/heads/{backup}", old_tip)
            print(f"backup branch: {backup}", file=sys.stderr)

        git("update-ref", ref, new_tip, old_tip)
        append_csv(args.csv, pairs)
    except RewriteError as error:
        sys.exit(f"error: {error}")

    print(f"{branch}: {old_tip[:12]} -> {new_tip[:12]}", file=sys.stderr)
    print(f"{len(pairs)} commit(s) recorded in {args.csv}", file=sys.stderr)


if __name__ == "__main__":
    main()
