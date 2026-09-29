#!/usr/bin/env python3
"""PreToolUse (Edit/Write): don't hand-edit files that tools generate or that must stay as they are.

NAMESPACE and man/ come from roxygen (edit the R source, run devtools::document()); renv/ and *.Rcheck/ are
local tool output; LICENSE is CRAN's two-line MIT stub. Bash writes aren't covered: the gate's docs step
catches generated files that drift.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import block, mascot_root, read_input  # noqa: E402

PREFIX = "Blocked by .claude/hooks/protect-paths.py: "


def reason_for(rel):
    parts = rel.split(os.sep)
    if rel == "NAMESPACE" or parts[0] == "man":
        return "roxygen generates this. Edit the roxygen comments in R/, then run devtools::document()."
    if parts[0] == "renv" or any(p.endswith(".Rcheck") for p in parts):
        return "this is local tool output, not source."
    if rel == "LICENSE":
        return "LICENSE is CRAN's MIT stub (YEAR / COPYRIGHT HOLDER); change it only if the founder asks."
    return None


def main():
    payload = read_input()
    path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not path:
        sys.exit(0)
    path = os.path.realpath(os.path.join(payload.get("cwd") or os.getcwd(), path))
    root = mascot_root(path)
    if root is None:
        sys.exit(0)
    reason = reason_for(os.path.relpath(path, root))
    if reason:
        block(PREFIX + reason)
    sys.exit(0)


if __name__ == "__main__":
    main()
