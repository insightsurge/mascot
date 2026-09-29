# mascot

An R package for **live, mood-driven mascots** in Shiny apps and Quarto sites: a character drawn in code shows a
mood and animates when the mood changes (a short wiggle, then the new face). Later: avatars and hex stickers, a
character builder, and trailers. Scope, target users and releases: `docs/scope.md`. Status: before 0.1.0; the
repo is private and goes public before the CRAN submission.

Author, maintainer and copyright holder: **Harsh Verma** (analyticswithharsh@gmail.com; GitHub `insightsurge`).
In `DESCRIPTION`: `person("Harsh", "Verma", email = "analyticswithharsh@gmail.com", role = c("aut", "cre", "cph"))`.

## Rules: where they live
The detailed rules are in `.claude/rules/` (they load when you read a matching file) and, with reasons and
sources, in `docs/standards.md`. Each rule is **CRAN** (policy, Writing R Extensions, R CMD check) or **house**
(ours; a justified exception needs a comment saying why). **Before creating a file** in `R/`, `tests/`, `inst/` or
`.github/`, read the matching rules file, because a new file doesn't trigger it:
- `r-code.md` (`R/`, `tools/`): checkmate, cli, dependencies, behaviour, names
- `roxygen.md` (`R/`, `man/`, `NAMESPACE`): documentation and examples
- `tests.md` (`tests/`): BDD tests, shinytest2, skips, coverage
- `js-css.md` (`inst/` JS, CSS, Lua): the UI engine, theming, accessibility
- `bundled-files.md` (`inst/`): licences, fonts, the acceptance checklist for shipped files
- `description-news.md` (`DESCRIPTION`, `NEWS.md`, `cran-comments.md`)
- `ci.md` (`.github/`, the gate)

## Rules that always apply
- **CRAN:** 0 errors, 0 warnings, 0 notes. No network in code, examples, tests or vignettes; write only to
  `tempdir()` or a path the user passes; no side effects on load; restore anything you change (options, working
  directory, graphics state). Everything the package draws with ships in `inst/`; no CDN.
- **house:** every function starts with `checkmate::assert_*()` for each argument; other messages and errors use
  cli; call other packages as `pkg::fn()`; no `library()`, `print()` or `cat()` in package code.
- **CRAN/house:** roxygen2 with markdown; every export has `@returns` and offline `@examples`; never edit `man/` or
  `NAMESPACE` by hand.
- **house:** tests in BDD style (`describe()`/`it()`), one test file per R file, every checkmate assertion tested,
  shinytest2 for what a user sees (skipped on CRAN), coverage at least 90%.
- **house:** the engine is plain, unminified JS/CSS in `inst/www/`, deterministic (seeded, no clock), with status
  text beside every mascot (the mood never carries meaning alone) and `prefers-reduced-motion` honoured.
- **house:** wording in docs and UI: no hype; "built for GxP work", never "validated" or "GxP compliant"; never name
  an employer, client or internal system; no unmeasured numbers; British English.

## Quality gate
Run `/cran-gate` (`Rscript tools/cran-gate.R [fast|tests|full|lint]`) instead of calling `devtools::check()`,
lintr or Air yourself: it sets `NOT_CRAN` correctly per mode and prints one line per step.
- `fast` (default) before every commit; `tests` (tests + coverage) before a PR that touches `R/` or `tests/`;
  `full` before a release; `lint` reproduces CI's lint job.
- New spelling words go into `inst/WORDLIST` only after the founder agrees (`--update-wordlist`).
- CI must be green: R-CMD-check (5 platforms, fails on notes), test-coverage (90%, Chrome tests), lint (the gate),
  check-no-suggests, gitleaks. Never `continue-on-error` or weaken a check to get green.
- In a git worktree, set `R_LIBS` to what `Rscript -e 'cat(.libPaths()[1])'` prints in the main checkout (renv
  keeps a package project's library outside the repo).

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

## Versions, releases and NEWS
- `main` carries a development version (`0.0.0.9000`, later `x.y.z.9000`). A release is a PR that sets a release
  version (`usethis::use_version()`) and its `NEWS.md` section (`# mascot x.y.z`). When that reaches `main`, the
  `release` workflow tags `vx.y.z` and creates a GitHub release (the NEWS section plus notes generated from PR
  labels, grouped by `.github/release.yml`). Then bump back to `.9000`.
- Every user-facing change adds its `NEWS.md` bullet in the same PR (tidyverse style; details and the numbered
  heading until 0.1.0 in `.claude/rules/description-news.md`).
- GitHub milestones are releases (`0.1.0 Live mascot`, `0.2.0 ...`, `Later`); epics are the M0-M6 work areas.

## Package website
pkgdown with the playbook site's look ported (colours, fonts, the aurora background via `pkgdown/extra.scss` and
`includes`; dark mode on `[data-bs-theme="dark"]`), to confirm in #25. Keep `_pkgdown.yml` current
(`pkgdown::check_pkgdown()`) and look at the built site in light and dark before a PR that changes docs, exports or
examples. The brand's source of truth is the website repo's `brand/`; record where copied values came from. Deploy
to GitHub Pages from CI once the repo is public; our own project docs live in `docs/`, so pkgdown's `destination`
goes elsewhere.

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
- Branch → PR → CI green → **ask before merging** (unless the founder said to merge that PR). The PR description
  starts with **"In brief"**: one plain sentence on what it does and why, then a few bullets for a reader with no
  context (plain words, a light technical touch); then `Closes #<n>`, what changed and the checks. Stacked PRs are fine (base on the branch below). Conventional Commits, short messages,
  **no AI attribution** anywhere. Commit or push only when asked.
- `gh` must run as `insightsurge`: `GH_CONFIG_DIR=/Users/harshverma/Documents/Projects/InsightSurge/.config/gh`;
  check `gh api user --jq .login` before any GitHub action.

## Delegation
The main Claude session (Opus) owns the package foundation (M0: skeleton, gate, CI, rules, hooks) and writes the
judgement-heavy parts itself. Small, well-scoped tasks (a doc drafted from given sources, a test script) may go to
Claude Sonnet sub-agents with a precise brief. Codex (`codex exec -C <worktree> -m gpt-6-sol ...`) or Gemini
(`agy-delegate --model "Gemini 3.8 Flash (High)"`) only when the founder asks for them (for example a named
review). Feature work may be delegated more widely later, with the founder's agreement. Whoever did the work, never
trust a self-reported pass: run the gate and CI, and look at the output (screenshots for visual work).

## Handoffs
- Local, gitignored working notes in `dev/handoffs/`, managed with the `/handoff` skill
  (`.claude/skills/handoff/`; Codex and Gemini read `.agents/skills/`: keep them identical with `diff -r`, change
  `.claude/` first, then copy).
- Start a session with `dev/handoffs/README.md` and `bash .claude/skills/handoff/scripts/handoff.sh status`, then
  `package/`. Update the handoff before a PR, before a compaction and at the end of a session; run
  `handoff.sh check`. Log the founder's asks and decisions (`overview/decisions.md`); durable material goes into
  git (issues, `docs/`, ADRs).
- Work that spans both repos: also read `../r-engineering-playbook/dev/handoffs/README.md`.
