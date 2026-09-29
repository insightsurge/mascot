"""Shared helpers for mascot's Claude Code hooks (stdlib only).

Hooks read one JSON object on stdin (tool_name, tool_input, cwd, ...). Exit 0 lets the tool call proceed;
exit 2 blocks it (PreToolUse) or shows stderr to Claude after the edit (PostToolUse). These hooks give fast
feedback while an agent works; they are not enforcement: CI and review stay the gate.
"""

import json
import os
import subprocess
import sys


def read_input():
    """The hook payload, or an empty dict when stdin isn't valid JSON."""
    try:
        return json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return {}


def block(reason):
    """Stop the tool call (PreToolUse) or send feedback (PostToolUse) with a reason Claude can act on."""
    print(reason, file=sys.stderr)
    sys.exit(2)


def git(args, cwd):
    """Output of a git command run in cwd, or '' when it fails (not a repo, git missing)."""
    try:
        out = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def mascot_root(path):
    """The git top level containing path if it is a mascot checkout (main or worktree), else None."""
    start = os.path.realpath(path)
    while start and not os.path.isdir(start):  # a file (or folder) that doesn't exist yet: use its parent
        parent = os.path.dirname(start)
        if parent == start:
            return None
        start = parent
    top = git(["rev-parse", "--show-toplevel"], start)
    if not top:
        return None
    try:
        with open(os.path.join(top, "DESCRIPTION"), encoding="utf-8") as f:
            return os.path.realpath(top) if "Package: mascot" in f.read() else None
    except OSError:
        return None
