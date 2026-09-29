#!/usr/bin/env python3
"""PreToolUse (Bash): stop a few risky git/gh commands in the mascot repo before they run.

Blocks: force pushes; pushes to main; commits or pushes while on main; `gh pr merge` (the founder merges);
`--no-verify`; Claude attribution in a commit message or PR body. Matching is on parsed command words, not
substrings, so a command that merely mentions these words (grep, echo, a PR body quoting them) isn't blocked.
It can't see into scripts or aliases: fast feedback, not enforcement.
"""

import os
import re
import shlex
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import block, git, mascot_root, read_input  # noqa: E402

PREFIX = "Blocked by .claude/hooks/guard-bash.py: "
ATTRIBUTION = re.compile(r"co-authored-by:[^\n]*(claude|anthropic)|generated with \[?claude", re.IGNORECASE)
SEPARATORS = {"&&", "||", ";", "|", "&", "\n"}


def segments(command):
    """Split a shell command into simple commands (lists of words), honouring quotes, one line at a time."""
    out = []
    for line in command.splitlines():
        out.extend(line_segments(line))
    return out


def line_segments(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|")
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        words = list(lexer)
    except ValueError:  # unbalanced quotes: fall back to a plain split
        words = command.split()
    out, current = [], []
    for w in words:
        if w in SEPARATORS or set(w) <= set(";&|"):
            if current:
                out.append(current)
            current = []
        else:
            current.append(w)
    if current:
        out.append(current)
    return out


def strip_env(words):
    """Drop leading VAR=value assignments and `env`/`command` prefixes."""
    while words and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]) or words[0] in ("env", "command")):
        words = words[1:]
    return words


def git_parts(words, cwd):
    """For `git [-C dir] [-c k=v] sub args...`, return (sub, args, dir)."""
    i, where = 1, cwd
    while i < len(words):
        if words[i] == "-C" and i + 1 < len(words):
            where = os.path.join(cwd, words[i + 1])
            i += 2
        elif words[i] == "-c" and i + 1 < len(words):
            i += 2
        elif words[i].startswith("-"):
            i += 1
        else:
            return words[i], words[i + 1:], where
    return "", [], where


def check_git(sub, args, where, command):
    branch = git(["rev-parse", "--abbrev-ref", "HEAD"], where)
    if "--no-verify" in args or (sub == "commit" and "-n" in args):
        block(PREFIX + "`--no-verify` skips the checks. Fix what fails instead.")
    if sub == "push":
        if any(a in ("--force", "-f") or a.startswith("--force-with-lease") or a.startswith("+") for a in args):
            block(PREFIX + "no force-push (it can overwrite pushed work or an open PR). Add a new commit instead.")
        targets = [a for a in args if not a.startswith("-")]
        refs = targets[1:] if targets else []
        if any(r in ("main", "master") or r.endswith(":main") or r.endswith("/main") for r in refs):
            block(PREFIX + "no pushes to main. Push a branch and open a PR.")
        if not refs and branch == "main":
            block(PREFIX + "you're on main. Create a branch, then push it.")
    if sub == "commit":
        if branch == "main":
            block(PREFIX + "no commits on main. Create a branch first (git switch -c <type>/<issue>-<topic>).")
        if ATTRIBUTION.search(command):
            block(PREFIX + "no AI attribution in commit messages (repo rule). Remove the trailer.")


def main():
    payload = read_input()
    command = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or os.getcwd()
    if not command or mascot_root(cwd) is None:
        sys.exit(0)
    for words in segments(command):
        words = strip_env(words)
        if not words:
            continue
        if words[0] == "cd" and len(words) > 1:  # `cd <worktree> && git commit` runs in <worktree>
            cwd = os.path.abspath(os.path.join(cwd, os.path.expanduser(words[1])))
        elif words[0] == "git":
            sub, args, where = git_parts(words, cwd)
            check_git(sub, args, where, command)
        elif words[0] == "gh" and words[1:3] == ["pr", "merge"]:
            block(PREFIX + "the founder merges PRs. Ask them (say which PR and that CI is green).")
        elif words[0] == "gh" and words[1:2] == ["pr"] and len(words) > 2 and words[2] in ("create", "edit"):
            if ATTRIBUTION.search(command):
                block(PREFIX + "no AI attribution in PR descriptions (repo rule). Remove that line.")
    sys.exit(0)


if __name__ == "__main__":
    main()
