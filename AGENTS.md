# AGENTS.md

Instructions for Codex, Gemini (agy) and any other coding agent working in this repo.

**Read `CLAUDE.md` first: every rule there applies to you too** (known users, CRAN rules, package code,
releases, pkgdown, issues and PRs, no AI attribution, handoffs). It is the single source; this file only adds
what differs for you.

- Skills live in `.agents/skills/` (a copy of `.claude/skills/`). Don't edit the copy: change `.claude/skills/`,
  then copy, and check with `diff -r`.
- Work only in the worktree or branch you were given. Don't commit, push, merge or open PRs unless the task says
  so; never force-push.
- Every function you write starts with checkmate assertions for its arguments; every behaviour gets a BDD-style
  test (`describe()` / `it()`), and Shiny behaviour a shinytest2 test (CLAUDE.md, "Testing").
- Before you report done, run and paste the results of: `air format .`, `lintr::lint_package()`,
  `devtools::test()`, `covr::package_coverage()` (at least 90%, and not lower than before your change),
  `devtools::check(args = "--as-cran")` (0 errors, 0 warnings, 0 notes). Say plainly what you did not run and why.
- Don't install software or change the R library outside the project; don't patch installed packages or mock
  dependencies to make a check pass.
