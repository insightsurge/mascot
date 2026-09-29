#!/usr/bin/env python3
"""Self-test for mascot's Claude Code hooks: feeds each hook sample inputs and checks block (exit 2) or allow.

Run: python3 .claude/hooks/test-hooks.py   (CI's lint job runs it too). Builds throwaway git repos in a temp
directory: a mascot checkout on `main` with a feature branch worktree, and a repo of another package. The
format-on-edit cases are skipped when air, Rscript or lintr aren't available.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
failures = []


def sh(args, cwd):
    subprocess.run(args, cwd=cwd, check=True, capture_output=True)


def make_repo(path, package, branch=None):
    os.makedirs(path)
    sh(["git", "init", "-q", "-b", "main"], path)
    with open(os.path.join(path, "DESCRIPTION"), "w") as f:
        f.write(f"Package: {package}\nVersion: 0.0.0.9000\n")
    sh(["git", "add", "-A"], path)
    sh(["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init"], path)
    if branch:
        sh(["git", "switch", "-qc", branch], path)


def hook(name, payload):
    res = subprocess.run(
        [sys.executable, os.path.join(HERE, name)], input=json.dumps(payload), capture_output=True, text=True
    )
    return res.returncode, res.stderr


def expect(name, payload, want, label):
    code, err = hook(name, payload)
    ok = (code == 2) == (want == "block") and code in (0, 2)
    print(f"{'ok  ' if ok else 'FAIL'} {want:5} {name:17} {label}" + ("" if ok else f"  (exit {code}: {err.strip()})"))
    if not ok:
        failures.append(label)


def bash(cmd, cwd):
    return {"tool_name": "Bash", "tool_input": {"command": cmd}, "cwd": cwd}


def edit(path, cwd):
    return {"tool_name": "Edit", "tool_input": {"file_path": path}, "cwd": cwd}


def main():
    tmp = tempfile.mkdtemp(prefix="mascot-hooks-")
    try:
        on_main = os.path.join(tmp, "on-main")
        feature = os.path.join(tmp, "feature")
        other = os.path.join(tmp, "other")
        make_repo(on_main, "mascot")
        make_repo(feature, "mascot", branch="chore/1-x")
        make_repo(other, "notmascot")

        g = "guard-bash.py"
        # Allowed on a feature branch.
        for cmd in [
            "git status",
            "git commit -m 'feat: add moods'",
            "git push -u origin chore/1-x",
            "git log --oneline -3 && git diff",
            "echo 'git push --force' > notes.txt",
            "grep -rn 'Co-Authored-By' .",
            "gh pr create --title t --body 'Explains why we never force-push or merge ourselves'",
            "gh pr view 89 --json state",
            "git merge --no-edit chore/0-base",
        ]:
            expect(g, bash(cmd, feature), "allow", cmd)
        # Blocked on a feature branch.
        for cmd in [
            "git push --force",
            "git push -f origin chore/1-x",
            "git push --force-with-lease origin chore/1-x",
            "git push origin +chore/1-x",
            "git push origin HEAD:main",
            "git push origin main",
            "gh pr merge 89 --squash",
            "git commit --no-verify -m 'x'",
            "git commit -n -m 'x'",
            "git commit -m 'feat: x\n\nCo-Authored-By: Claude Opus <noreply@anthropic.com>'",
            "gh pr create --title t --body '🤖 Generated with [Claude Code](https://claude.com/claude-code)'",
            "cd /tmp && git status; git push --force",
            f"git -C {on_main} commit -m 'x'",
            f"cd {on_main} && git commit -m 'x'",
        ]:
            expect(g, bash(cmd, feature), "block", cmd.replace("\n", "\\n"))
        # On main.
        expect(g, bash("git commit -m 'x'", on_main), "block", "commit while on main")
        expect(g, bash("git push", on_main), "block", "push while on main")
        expect(g, bash("git pull --ff-only && git status", on_main), "allow", "pull on main")
        expect(g, bash(f"cd {feature} && git commit -m 'x'", on_main), "allow", "cd into a feature branch, then commit")
        # Another repo: the guard stays out of the way.
        expect(g, bash("git push --force", other), "allow", "force-push in a non-mascot repo")

        p = "protect-paths.py"
        for rel, want in [
            ("NAMESPACE", "block"),
            ("man/mascot.Rd", "block"),
            ("renv/activate.R", "block"),
            ("mascot.Rcheck/00check.log", "block"),
            ("LICENSE", "block"),
            ("LICENSE.md", "allow"),
            ("R/mood.R", "allow"),
            ("inst/www/mascot.js", "allow"),
        ]:
            expect(p, edit(os.path.join(feature, rel), feature), want, rel)
        expect(p, edit(os.path.join(other, "NAMESPACE"), other), "allow", "NAMESPACE in a non-mascot repo")

        f = "format-on-edit.py"
        lintr_ok = shutil.which("Rscript") and subprocess.run(
            ["Rscript", "-e", "quit(status = !requireNamespace('lintr', quietly = TRUE))"], capture_output=True
        ).returncode == 0
        if shutil.which("air") and lintr_ok:
            os.makedirs(os.path.join(feature, "R"))
            messy = os.path.join(feature, "R", "messy.R")
            with open(messy, "w") as fh:
                fh.write("add_one <- function(x){x+1}\n")
            expect(f, edit(messy, feature), "allow", "messy but lint-free R: formatted, no feedback")
            with open(messy) as fh:
                formatted = fh.read()
            ok = formatted != "add_one <- function(x){x+1}\n"
            print(f"{'ok  ' if ok else 'FAIL'} air   {f:17} file was reformatted")
            if not ok:
                failures.append("air reformat")
            bad = os.path.join(feature, "R", "bad.R")
            with open(bad, "w") as fh:
                fh.write("flag <- T\n")
            expect(f, edit(bad, feature), "block", "R file with a lint: feedback to Claude")
        else:
            print("skip  format-on-edit cases: air, Rscript or lintr not available")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if failures:
        print(f"\n{len(failures)} hook test(s) failed")
        sys.exit(1)
    print("\nAll hook tests passed")


if __name__ == "__main__":
    main()
