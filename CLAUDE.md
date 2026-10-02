@AGENTS.md

## Claude Code

`AGENTS.md`, imported above, holds this repository's rules for every AI; edit shared rules there. Claude-only:

- The files in `.claude/rules/` load by themselves when you read a matching file; still read the matching one
  before creating a new file in `R/`, `tests/`, `inst/` or `.github/`, because a new file doesn't trigger it.
- `.claude/settings.json` denies force-push, pushes to `main`, `--no-verify` and hand edits to `NAMESPACE`, `man/`,
  `renv/` and `LICENSE`, makes `gh pr merge` ask the founder for confirmation each time, and turns off attribution
  lines. It's a guard rail, not the gate; never work around it.
