# AGENTS.md

Instructions for Codex, Gemini (agy) and any other coding agent working in this repo.

**Read `CLAUDE.md` first, then every file in `.claude/rules/`: all of it applies to you too** (known users, CRAN
and house rules, documentation, tests, the UI engine, bundled files, CI, releases, issues and PRs, no AI
attribution, handoffs). Claude Code loads the rules files by path; you don't, so read them all before you start.
`docs/standards.md` has the reasons and sources. This file only adds what differs for you.

- Skills live in `.agents/skills/` (a copy of `.claude/skills/`). Don't edit the copy: change `.claude/skills/`,
  then copy, and check with `diff -r`.
- Work only in the worktree or branch you were given. Don't commit, push, merge or open PRs unless the task says
  so; never force-push.
- Every function you write starts with checkmate assertions for its arguments; every behaviour gets a BDD-style
  test (`describe()` / `it()`), and Shiny behaviour a shinytest2 test (`.claude/rules/tests.md`).
- Before you report done, run the gate and paste its summary lines: `Rscript tools/cran-gate.R` (fast: format,
  docs in sync, lint, `@returns`, spelling, R CMD check `--as-cran` without tests, 0/0/0) and
  `Rscript tools/cran-gate.R tests` (tests and coverage of at least 90%, not lower than before your change). In a
  git worktree, set `R_LIBS` first (see CLAUDE.md, "Quality gate"). Say plainly what you did not run and why.
- Never add words to `inst/WORDLIST` yourself: list unknown words in your report for the founder.
- Don't install software or change the R library outside the project; don't patch installed packages or mock
  dependencies to make a check pass.
