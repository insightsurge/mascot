# mascot

An R package for **live, mood-driven mascots** in Shiny apps and Quarto sites: a character drawn in code shows a
mood and animates when the mood changes (a short wiggle, then the new face). Later: avatars and hex stickers, a
character builder, and trailers. Scope, target users and releases: `docs/scope.md`. Status: before 0.1.0; the
repo is private.

Author, maintainer and copyright holder: **Harsh Verma** (analyticswithharsh@gmail.com; GitHub `insightsurge`).
In `DESCRIPTION`: `person("Harsh", "Verma", email = "analyticswithharsh@gmail.com", role = c("aut", "cre", "cph"))`.

## Known users: never break them
- **Every known user is listed in `docs/consumers.md`**: what it uses, since which version, and how to check it
  still works. Read it before changing anything exported or anything a user can see (moods, arguments, defaults,
  the Quarto shortcode, colours, sizes). Add a row whenever a new app or site starts using the package.
- **The R Engineering Playbook site** (`../r-engineering-playbook`, insightsurge/r-engineering-playbook) is the
  first suggested user and where the engine was born (`tools/animate/`). The site keeps its own engine and the
  `/animate-it` skill until this package can replace them; it then switches, first from GitHub, later from CRAN,
  pinned by version. Its handoff `dev/handoffs/brand-ui/animation-engine-package.md` lists the site's uses of the
  engine: keep both lists in step.
- **The founder's own Shiny apps** will use the package too: each one gets a row in `docs/consumers.md` with a
  smoke test (the app starts, the mascot renders, a mood change works).
- A change that may affect a known user gets the `consumer-impact` label and a line in the PR on how each
  affected user was checked. A change to the public API gets `breaking-change`, a `NEWS.md` entry and a
  deprecation first (`lifecycle::deprecate_warn()` for at least one release) unless the API is still before 0.1.0.

## CRAN rules (non-negotiable)
- Before every PR: `devtools::check(args = "--as-cran")` (or `rcmdcheck::rcmdcheck(args = "--as-cran")`) with
  **0 errors, 0 warnings, 0 notes**. Explain any note that truly can't be removed in `cran-comments.md`; never
  ignore one.
- No network in examples, tests or vignettes. No writing outside `tempdir()` or a path the user passes; no side
  effects on load; no changing the user's options, working directory or graphics state without restoring them.
- Optional features use `Suggests` (chromote, av, shinyvalidate, shinytest2, quarto) and check with
  `rlang::check_installed()` or `requireNamespace()`. Tests that need Chrome skip when `chromote::find_chrome()`
  finds none (there is no `chromote::has_chrome()`). Keep examples fast (under a few seconds) and tests economical.
- Bundle everything the package draws with (JS, fonts) inside `inst/`, with licences recorded (OFL fonts); no CDN.
  Source tarball under 10 MB if at all possible.
- Documentation: roxygen2 with markdown; every export has `@examples` that run offline; `@returns` on every
  function.

## Package code
- **Few exports.** Prefer an argument over a new function. Names: `mascot()` is the main object; Shiny's
  convention for `mascotOutput()`, `renderMascot()`, `updateMascot()`; `use_*()` only for project setup
  (usethis style); otherwise short verbs without a prefix when they can't clash (`moods()`, `characters()`,
  `run_gallery()`, `watch_validator()`). Check a new name against base R, shiny, bslib and ggplot2 first.
- Messages and errors with `cli`; argument checks up front with clear, actionable errors.
- Tests: testthat 3rd edition; snapshot tests for output; shinytest2 for Shiny behaviour; every bug fix gets a test.
- The engine (JavaScript in `inst/`): deterministic (seeded RNG, no `Math.random` or clock time), drawn in code in
  the theme's colours, no AI images, no external requests. Moods must never carry meaning alone: status text
  sits beside them; `prefers-reduced-motion` is honoured.
- Before a PR that touches R: `air format .`, `lintr::lint_package()`, `devtools::test()`, `devtools::check()`.
- Wording in docs and UI: no hype; say "built for GxP work", never "validated" or "GxP compliant"; never name an
  employer, client or internal system; no unmeasured numbers.

## Versions and releases
- `main` carries a development version (`0.0.0.9000`, later `x.y.z.9000`). A release is a PR that sets a release
  version (`usethis::use_version()`) and its `NEWS.md` section (`# mascot x.y.z`). When that reaches `main`, the
  `release` workflow tags `vx.y.z` and creates a GitHub release (the NEWS section plus notes generated from PR
  labels, grouped by `.github/release.yml`). Then bump back to `.9000`.
- GitHub milestones are releases (`0.1.0 Live mascot`, `0.2.0 ...`, `Later`); epics are the M0-M6 work areas.

## NEWS.md (the changelog)
Follow the tidyverse style for NEWS files; `NEWS.md` is the source of each GitHub release and the website's
changelog.
- **Same PR:** every user-facing change adds its bullet to `NEWS.md` in the PR that makes it. Internal changes
  (CI, refactors, tests) are left out unless users notice them.
- **Headings:** `# mascot (development version)` at the top while developing; `usethis::use_version()` turns it
  into `# mascot x.y.z` at release. Never edit a released section except to fix a typo.
- **Bullets:** one change per bullet, written for users, present tense, starting with the function or feature
  (`` `updateMascot()` gains a `message` argument for a speech bubble (#30).``). End with the issue or PR
  number in parentheses; credit outside contributors with their handle (`(@user, #123)`).
- **Order:** once a release has more than a handful of bullets, group them under `## Breaking changes` (first,
  with what users must change), `## New features`, `## Minor improvements and fixes`; alphabetical by function
  name within a group.
- **Before a release:** read the section as a user would; merge duplicates; make sure every breaking change says
  what to do instead.

## Package website
Quarto website (via altdoc) or pkgdown: to decide in #25. Until then, the pkgdown notes below apply.

## pkgdown
- Keep `_pkgdown.yml` current: every export in the reference index (`pkgdown::check_pkgdown()`), articles for the
  vignettes, the README as the home page. Build locally (`pkgdown::build_site()`) before any PR that changes docs,
  exports or examples, and look at it (light and dark).
- Theme: the playbook site's look (brand colours and fonts), method to settle in #25 (bslib variables in
  `_pkgdown.yml` or its `_brand.yml`). The brand's source of truth is the website repo's `brand/`; don't copy
  values by hand without recording where they came from.
- Deploy to GitHub Pages from CI once the repo is public (Pages on a private repo needs a paid plan). Our own
  project docs live in `docs/`, so set pkgdown's `destination` elsewhere or build in CI only.

## Workflow
- **Every change starts with an issue** (goal + "done when" checklist, labels, milestone) placed in the epic tree:
  root **#1** → epics (M0 Setup #10, M1 Characters and themes #11, M2 Shiny #12, M3 Quarto #13, M4 Gallery and
  docs #14, M5 AI skills #15, M6 Release #16; Pharma #17, Static assets #18, Builder #19, Trailers #20, Theme
  packs #21) → issues. A new request mid-session gets its issue first. Link a child with
  `gh api -X POST repos/insightsurge/mascot/issues/<parent>/sub_issues -F sub_issue_id=<child id>`
  (the id is `gh api repos/insightsurge/mascot/issues/<n> --jq .id`); a child has one parent.
- Labels: one type (`enhancement`, `bug`, `documentation`, `chore`, `idea`, `question`, `Epic`), one or more
  `area: *`, a `priority: *` for planned work, `status: *` when blocked or waiting, plus `breaking-change`,
  `consumer-impact`, `skip-release-notes`. Label PRs too: release notes are built from PR labels.
- Branch → PR whose description says `Closes #<n>` → CI green → **ask before merging** (unless the founder
  said to merge that PR). Conventional Commits, short messages, **no AI attribution** anywhere. Commit or push
  only when asked.
- `gh` must run as `insightsurge`: `GH_CONFIG_DIR=/Users/harshverma/Documents/Projects/InsightSurge/.config/gh`;
  check `gh api user --jq .login` before any GitHub action.

## Delegation
Claude orchestrates, reviews and verifies. Never trust a self-reported pass: run check, tests and the examples
yourself, and look at the output (screenshots for visual work).
- **Codex CLI** (default for R code, tests, refactors, CI and check fixes), in its own worktree and branch:
  `codex exec -C <worktree> -m gpt-6-sol -c 'model_reasoning_effort="medium"' -s workspace-write -o <out.md> "<task>" < /dev/null`.
  Use `model_reasoning_effort="high"` for hard design or debugging. Give it the issue, the files and the checks
  to run; review the diff.
- **Gemini** via `agy-delegate --model "Gemini 3.8 Flash (High)" --dir <repo> [--yolo] -` (prompt on stdin):
  UI and UX direction, CSS, visual design of characters and theme packs, docs drafts, research.
  (`--tier flash` is broken on this machine.)
- **Claude Sonnet sub-agents** for drawing work in the JS engine (characters, moods, props) and parallel drafts.
- For visual work, offer a two-model bake-off (e.g. Sonnet and Gemini) and let the founder pick.

## Handoffs
- Local, gitignored working notes in `dev/handoffs/`, managed with the `/handoff` skill
  (`.claude/skills/handoff/`; Codex and Gemini read `.agents/skills/handoff/`: keep them identical with
  `diff -r`, change `.claude/` first, then copy).
- Start a session with `dev/handoffs/README.md` and `bash .claude/skills/handoff/scripts/handoff.sh status`, then
  `package/`. Update the handoff before a PR, before a compaction and at the end of a session; run
  `handoff.sh check`. Log the founder's asks and decisions (`overview/decisions.md`); durable material goes into
  git (issues, `docs/`, ADRs).
- Work that spans both repos: also read `../r-engineering-playbook/dev/handoffs/README.md`.
