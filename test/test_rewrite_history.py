"""Tests for scripts/rewrite_history.py.

Run with:  python3 -m unittest discover -s test -p 'test_rewrite_history.py' -v
"""

from __future__ import annotations

import csv
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, "..", "bin", "rewrite-git-history")
sys.path.insert(0, SCRIPTS)

from rewrite_history import clean_message  # noqa: E402

SCRIPT = os.path.join(SCRIPTS, "rewrite_history.py")
GIT_ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "Other",
    "GIT_AUTHOR_EMAIL": "other@example.com",
    "GIT_COMMITTER_NAME": "Other",
    "GIT_COMMITTER_EMAIL": "other@example.com",
}


class CleanMessageTest(unittest.TestCase):
    def test_removes_coauthor_lines_case_insensitively(self) -> None:
        message = (
            "Subject\n\nBody\n\nCo-Authored-By: A <a@x>\nco-authored-by: B <b@x>\n"
        )
        self.assertEqual(clean_message(message), "Subject\n\nBody\n")

    def test_keeps_other_trailers(self) -> None:
        message = "Subject\n\nSigned-off-by: A <a@x>\n"
        self.assertEqual(clean_message(message), message)

    def test_only_trailers_leaves_subject_free_message(self) -> None:
        self.assertEqual(clean_message("Co-Authored-By: A <a@x>\n"), "\n")


class RewriteRepoTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = os.path.realpath(self.tmp.name)
        self.git("init", "-q", "-b", "main")
        self.commit("first", "a.txt")
        self.git("checkout", "-qb", "feat")
        self.commit("second\n\nCo-Authored-By: Claude <noreply@anthropic.com>", "b.txt")
        self.commit("third\n\nCo-Authored-By: Someone <s@example.com>", "c.txt")
        csv_dir = tempfile.TemporaryDirectory()
        self.addCleanup(csv_dir.cleanup)
        self.csv = os.path.join(csv_dir.name, "map.csv")

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", *args],
            cwd=self.repo,
            env=GIT_ENV,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

    def commit(self, message: str, filename: str) -> None:
        with open(os.path.join(self.repo, filename), "w") as handle:
            handle.write(message)
        self.git("add", filename)
        self.git("commit", "-q", "-m", message)

    def run_script(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                SCRIPT,
                "--branch",
                "feat",
                "--author-name",
                "Alvaro Garcia",
                "--author-email",
                "alvarogarcia7@users.noreply.github.com",
                "--csv",
                self.csv,
                *extra,
            ],
            cwd=self.repo,
            capture_output=True,
            text=True,
        )

    def test_rewrites_authors_and_removes_trailers_from_root(self) -> None:
        root = self.git("rev-parse", "feat~1")
        before_tree = self.git("rev-parse", "feat^{tree}")
        result = self.run_script("--root", root, "--no-backup")
        self.assertEqual(result.returncode, 0, result.stderr)

        log = self.git("log", "--format=%an <%ae>%x00%B%x01", "main..feat")
        entries = [entry for entry in log.split("\x01") if entry.strip()]
        self.assertEqual(len(entries), 2)
        for entry in entries:
            self.assertIn(
                "Alvaro Garcia <alvarogarcia7@users.noreply.github.com>", entry
            )
            self.assertNotIn("co-authored-by", entry.lower())
        self.assertEqual(self.git("rev-parse", "feat^{tree}"), before_tree)

        with open(self.csv, newline="") as handle:
            rows = list(csv.reader(handle))
        self.assertEqual(rows[0], ["commit_before", "commit_after"])
        self.assertEqual(len(rows) - 1, 2)

    def test_dry_run_changes_nothing(self) -> None:
        before = self.git("rev-parse", "feat")
        result = self.run_script("--root", "main", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git("rev-parse", "feat"), before)
        self.assertFalse(os.path.exists(self.csv))

    def test_backup_branch_keeps_old_tip(self) -> None:
        before = self.git("rev-parse", "feat")
        result = self.run_script("--root", "main")
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = [
            b
            for b in self.git("branch", "--list", "backup/*").split()
            if b.startswith("backup/")
        ]
        self.assertEqual(len(backups), 1)
        self.assertEqual(self.git("rev-parse", backups[0]), before)

    def test_csv_is_appended_across_runs(self) -> None:
        first = self.run_script("--root", "main", "--no-backup")
        self.assertEqual(first.returncode, 0, first.stderr)
        # Second run starts from the rewritten "second" commit: 2 more rows.
        second_root = self.git("rev-parse", "feat~1")
        second = self.run_script("--root", second_root, "--no-backup")
        self.assertEqual(second.returncode, 0, second.stderr)
        with open(self.csv, newline="") as handle:
            rows = list(csv.reader(handle))
        self.assertEqual(rows[0], ["commit_before", "commit_after"])
        self.assertEqual(len(rows) - 1, 5)

    def test_root_not_on_branch_is_an_error(self) -> None:
        self.git("checkout", "-q", "main")
        self.commit("other", "d.txt")
        other = self.git("rev-parse", "main")
        self.git("checkout", "-q", "feat")
        result = self.run_script("--root", other)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not an ancestor", result.stderr)


if __name__ == "__main__":
    unittest.main()
