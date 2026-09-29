#!/usr/bin/env python3
"""PostToolUse (Edit/Write): format and lint the file Claude just changed, and report problems back.

R files: `air format <file>`, then lintr on that file with the repo's .lintr. JS/CSS in inst/: `biome check
--write <file>`. Problems (lints, a missing tool) go to stderr with exit 2, so Claude sees them at once. The edit
itself has already happened; this is feedback, not a block.
"""

import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import git, mascot_root, read_input  # noqa: E402

LINT_R = (
    "f <- commandArgs(TRUE)[1]; "
    "if (!requireNamespace('lintr', quietly = TRUE)) { message('lintr is not installed'); quit(status = 3) }; "
    "l <- lintr::lint(f); if (length(l) > 0) { print(l); quit(status = 1) }"
)


def run(cmd, cwd):
    # renv's "project is out-of-sync" notice would only add noise to the feedback.
    env = dict(os.environ, RENV_CONFIG_SYNCHRONIZED_CHECK="FALSE")
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=120, env=env)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(cmd, 99, "", str(e))


def r_cwd(root):
    """Where to start Rscript: the main checkout, whose renv library has lintr (worktrees have none)."""
    common = git(["rev-parse", "--path-format=absolute", "--git-common-dir"], root)
    main = os.path.dirname(common) if common else root
    return main if os.path.exists(os.path.join(main, "renv", "activate.R")) else root


def main():
    payload = read_input()
    path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not path:
        sys.exit(0)
    path = os.path.realpath(os.path.join(payload.get("cwd") or os.getcwd(), path))
    root = mascot_root(path)
    if root is None or not os.path.isfile(path):
        sys.exit(0)
    rel = os.path.relpath(path, root)
    problems = []
    if path.endswith((".R", ".r")):
        if shutil.which("air"):
            res = run(["air", "format", path], root)
            if res.returncode != 0:
                problems.append("air could not format the file:\n" + (res.stderr or res.stdout).strip())
        else:
            problems.append("air is not installed, so this R file wasn't formatted (https://posit-dev.github.io/air/).")
        res = run(["Rscript", "-e", LINT_R, path], r_cwd(root))
        if res.returncode == 1:
            problems.append("lintr found problems (repo .lintr):\n" + res.stdout.strip())
        elif res.returncode != 0:
            problems.append("lintr didn't run: " + (res.stderr or res.stdout).strip()[-300:])
    elif rel.startswith("inst" + os.sep) and path.endswith((".js", ".css")):
        if shutil.which("biome"):
            res = run(["biome", "check", "--write", path], root)
            if res.returncode != 0:
                problems.append("biome found problems:\n" + (res.stdout + res.stderr).strip()[-2000:])
        else:
            problems.append("biome is not installed, so this JS/CSS file wasn't checked (https://biomejs.dev).")
    if problems:
        print(f"format-on-edit ({rel}):\n" + "\n\n".join(problems), file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
