@AGENTS.md

## Claude Code

The files in `.claude/rules/` load by themselves when you read a matching file; still read the matching one before
creating a new file in `R/`, `tests/`, `inst/` or `.github/`, because a new file doesn't trigger it.
`.claude/settings.json` is a guard rail, not the gate; never work around it.
