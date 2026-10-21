# mascot

Rules for everyone working in this repository, person or AI. Codex and Antigravity (agy) read this file
directly; Claude reads it through the `@AGENTS.md` import at the top of `CLAUDE.md`. Edit the rules here.

An R package for **live, mood-driven mascots** in Shiny apps and Quarto sites: a character drawn in code shows a
mood and animates when the mood changes (a short wiggle, then the new face). Later: avatars and hex stickers, a
character builder, and trailers. Scope, target users and releases: `docs/scope.md`. Status: before 0.1.0; the
repo is private and goes public before the CRAN submission.

Author, maintainer and copyright holder: **Harsh Verma** (analyticswithharsh@gmail.com; GitHub `insightsurge`).
In `DESCRIPTION`: `person("Harsh", "Verma", email = "analyticswithharsh@gmail.com", role = c("aut", "cre", "cph"))`.

## Rules: where they live
The detailed rules are in `.claude/rules/` and, with reasons and sources, in `docs/standards.md`. Claude loads a
rules file when it reads a matching file; **every other agent reads the matching rules files itself before it
starts** (all of them apply to you). Each rule is **CRAN** (policy, Writing R Extensions, R CMD check) or **house**
(ours; a justified exception needs a comment saying why). **Before creating a file** in `R/`, `tests/`, `inst/` or
`.github/`, read the matching rules file, because a new file doesn't trigger it:
- `r-code.md` (`R/`, `tools/`, including the gate): checkmate, cli, dependencies, behaviour, names
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
- **house:** every function starts with `checkmate::assert_*()` for each argument; per-node/recursive helpers
  may reuse caller-checked inputs as specified in `r-code.md` (top-level helpers need a comment; inner closures
  may reuse the enclosing function's checked inputs). Other messages and errors use cli; call other packages as
  `pkg::fn()`; no `library()`, `print()` or `cat()` in package code.
- **CRAN/house:** roxygen2 with markdown; every export has `@returns` and offline `@examples`; never edit `man/` or
  `NAMESPACE` by hand.
- **house:** a helper per argument: each `mascot()` argument takes a plain shortcut or a `mascot_*()` helper; every
  helper starts with `mascot_`.
- **house:** tests in BDD style (`describe()`/`it()`), one test file per R file, every checkmate assertion tested,
  shinytest2 for what a user sees (skipped on CRAN), coverage at least 70%.
- **house:** the engine is plain, unminified JS/CSS in `inst/www/`, deterministic (seeded, no clock), with status
  text beside every mascot (the mood never carries meaning alone) and `prefers-reduced-motion` honoured.
- **house:** wording in docs and UI: no hype; "built for GxP work", never "validated" or "GxP compliant"; never name
  an employer, client or internal system; no unmeasured numbers; British English.

## Quality gate
Run the gate, `Rscript tools/cran-gate.R [fast|tests|full|lint|nosuggests]`, instead of calling `devtools::check()`,
lintr or Air yourself: it sets `NOT_CRAN` correctly per mode and prints one line per step (`--help` lists the options). The script is generic (any R
package can use it as it is); mascot's choices are in `DESCRIPTION`
(`Config/cran-gate/coverage: 70`, `extra-dirs`) and in `air.toml`, `.lintr` and `biome.json`.
- `fast` (default) before every commit; `tests` (the suite once under covr: tests and coverage) before a PR that
  touches `R/` or `tests/`; `full` before a release (it also runs CI's no-Suggests check); `lint` reproduces CI's
  lint job; `nosuggests` reproduces CI's check-no-suggests job without installing anything.
- `tests` and `full` also fail when a runnable line the branch adds in `R/` is run by no test (`new_lines`, compared
  with where the branch left `origin/HEAD`; uncommitted work counts). Test the line, or mark a justified one
  `# nocov` with a comment saying why. The 70% total stays as well.
- A failing run names the failing tests in its FAIL line and keeps a run folder (the path is printed; one log per
  step, `gate.json`, `tests.json`, `flakes.tsv` beside it) that survives the gate. After a failure the failing test
  files are re-run once in a fresh R process without covr (also when one message fails many files, a cascade such as
  a closed browser, which the FAIL line names once). **Exit code 3 means every failing test passed on that re-run (a
  probable flake): it is never merge evidence without the founder's word; 2 means a settings or tools problem; 1 a
  step failed.**
  `--steps`, `--filter` and `--no-coverage` give runs marked PARTIAL, which are not merge evidence either.
- New spelling words go into `inst/WORDLIST` only after the founder agrees (`--update-wordlist`).
- The gate has its own test: after changing the gate, `.lintr`, `air.toml` or `biome.json`, run
  `Rscript tools/test-cran-gate.R` (one planted defect per step; the heavy probes use a tiny generated package, so
  the whole run takes a few minutes); a new step needs a probe. Keep the gate free of anything mascot-specific. The
  gate and its self-test also live in the skill folder (`~/.agents/skills/cran-gate/scripts/`, the one real copy):
  the self-test's "copies in step" check fails when they differ, so copy a changed file to both places.
- CI must be green: R-CMD-check (fails on notes), test-coverage (70%, Chrome tests), lint (the gate),
  check-no-suggests, pkgdown, gitleaks. Never `continue-on-error` or weaken a check to get green.
- **Temporary while the repo is private** (limited Actions minutes, #113): PRs run R-CMD-check on Ubuntu only (all 5
  platforms on `main`, weekly and on demand), and docs-only PRs skip the R jobs. When the repo goes public, before the
  CRAN submission, these workarounds are removed and every PR runs the full matrix (#115).
- After editing R files, run `air format .` (the gate fails on unformatted code). Never force-push, push to `main`,
  use `--no-verify`, or edit `NAMESPACE`, `man/`, `renv/` or `LICENSE` by hand.
- In a git worktree, set `R_LIBS` to what `Rscript -e 'cat(.libPaths()[1])'` prints in the main checkout (renv
  keeps a package project's library outside the repo).

## Keep mascot studio up to date
- `inst/examples/studio/` (`mascot_studio()`) demonstrates every exported function and argument, function by
  function, for every character; the founder reviews the package through it.
- **Rule: a PR that adds, removes or changes an exported function or an argument (its name, values, default or
  behaviour) also updates the studio in the same PR.** No studio follow-up PRs. The places to change: controls
  (`R/panels.R`), control map (`R/data.R`), code builders (`R/code.R`), studio-only guide data (`R/guide.R`) and,
  where needed, pictures (`R/ui.R`) and server code (`app.R`). Explanations come from the help pages
  (`R/help.R` reads them), so update the roxygen, never copy it into the studio.
- The completeness tests in `tests/testthat/test-examples.R` catch a missing function or argument; they do not catch
  a changed default or behaviour, so try the change in the studio before the PR and say so in its checks.
- A tool for creating or remixing characters is a separate app, not part of the studio.
- After a merge to `main`, merge `main` into any open studio branch and restart a running studio before handing it
  back for review.

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
- Before 0.1.0, each milestone is a release `0.0.x` (0.0.1 skeleton, 0.0.2 engine, 0.0.3 R interface, ...) made only
  when the founder decides; between milestones `main` carries `0.0.x.9000`; 0.1.0 is the first CRAN release; after that
  the existing x.y.z / .9000 practice continues. A release is a PR that sets a release version
  (`usethis::use_version()`) and its `NEWS.md` section (`# mascot x.y.z`). When that reaches `main`, the `release`
  workflow tags `vx.y.z` and creates a GitHub release (the NEWS section plus notes generated from PR labels, grouped by
  `.github/release.yml`). Then bump back to `.9000`.
- Every user-facing change adds its `NEWS.md` bullet in the same PR (tidyverse style; details and the numbered
  heading until 0.1.0 in `.claude/rules/description-news.md`).
- GitHub milestones are releases (`0.1.0 Live mascot`, `0.2.0 ...`, `Later`); epics are the M0-M6 work areas.

## Package website
pkgdown with the playbook site's look (#25): brand colours as bslib variables in `_pkgdown.yml`; self-hosted Space
Grotesk and JetBrains Mono, the aurora background and the dark palette in `pkgdown/extra.css`; the aurora layer via
`template: includes`. Build with `Rscript tools/build-site.R` (into `site/`, because `docs/` holds our project notes;
it keeps `CLAUDE.md` and `AGENTS.md` out of the site). CI builds it **from `main` only, never on pull requests** (a rule, #127), and uploads it as
an artifact. The site deploys to Firebase from `main` until the repo is public (#195, #115); setup and the switch to
GitHub Pages are in `docs/deploy.md`. Keep `_pkgdown.yml` current (`pkgdown::check_pkgdown()`) and look at the site
in light and dark before a PR that changes docs, exports or examples. Link to files in `docs/` with full GitHub URLs
(they aren't part of the site). The brand's source of truth is the website repo's `brand/`; record where copied values
came from.
- **Recommended (not a gate): keep the package small.** The tarball is about 1.2 MB of CRAN's 5 MB, mostly vignette
  screenshots. Put screenshot-heavy articles on the website only (pkgdown articles in `vignettes/articles/`, which
  are not shipped in the package) and keep the package's own vignette short. Compress PNGs and prefer SVG for
  diagrams. On a release PR, check the gate's `tarball` line.

## Workflow
- **Every change starts with an issue** (goal + "done when" checklist, labels, milestone) placed in the epic tree:
  root **#1** → epics (M0 Setup #10, M1 Characters and themes #11, M2 Shiny #12, M3 Quarto #13, M4 Gallery and
  docs #14, M5 AI skills #15, M6 Release #16; Pharma #17, Static assets #18, Builder #19, Trailers #20, Palettes
  and packs #21) → issues. A new request mid-session gets its issue first. Link a child with
  `gh api -X POST repos/insightsurge/mascot/issues/<parent>/sub_issues -F sub_issue_id=<child id>`
  (the id is `gh api repos/insightsurge/mascot/issues/<n> --jq .id`); a child has one parent.
- Labels: one type (`enhancement`, `bug`, `documentation`, `chore`, `idea`, `question`, `Epic`), one or more
  `area: *`, a `priority: *` for planned work, `status: *` when blocked or waiting, plus `breaking-change`,
  `consumer-impact`, `skip-release-notes`. Label PRs too: release notes are built from PR labels.
- Branch → PR → CI green → **ask before merging** (unless the founder said to merge that PR). The PR description
  starts with **"In brief"**: one plain sentence on what it does and why, then a few bullets for a reader with no
  context (plain words, a light technical touch); then `Closes #<n>` and the template's sections: what's new and
  what's fixed (plain words first, then function and file names), before and after, try it (scenarios to run),
  details, not in this PR, and the checks (only checks anyone can re-run from the repo; one-off manual checks go in
  a short Notes line). Delete sections that do not apply. Stacked PRs
  are fine (base on the branch below). Conventional Commits, short messages, **no AI attribution** anywhere.
  Commit or push only when asked.
- `gh` must run as `insightsurge`: check `gh api user --jq .login` before any GitHub action.

## Delegation
The founder decides which person or AI does which part of the work. Whoever did the work, never trust a
self-reported pass: run the gate and CI, and look at the output (screenshots for visual work).

## Handoffs
- Local, gitignored working notes in `dev/handoffs/`, managed with the `handoff` skill (installed per user, not
  kept in this repository).
- Start a session with `dev/handoffs/README.md` and the skill's `status`, then `package/`. Update the handoff
  before a PR, before a compaction and at the end of a session; run the skill's `check`. Log the founder's asks and decisions (`dev/handoffs/decisions.md`); `dev/handoffs/api-review.md` is the one-page
  summary of the API review. Durable material goes into git (issues, `docs/`, ADRs).
- **External notes:** related repositories leave this one ideas, decisions and updates in
  `dev/handoffs/external-notes.md`. Triage them with the skill's inbox steps at the start of a session and in every
  handoff update: verify each entry, spread what holds into the areas here, open an issue for agreed work, and
  record the outcome (`handoff.sh set`). To tell another repository something, add an entry to its inbox
  (`handoff.sh note`); never edit its other notes, and touch its issues and PRs only when the founder asks.
- Work that spans both repos: also read `../r-engineering-playbook/dev/handoffs/README.md`.

## Working as an agent
- Work only in the worktree or branch you were given. Don't commit, push, merge or open PRs unless the task says
  so; never force-push.
- Before you report done, run the gate and paste its summary lines: `Rscript tools/cran-gate.R` (fast) and the
  same command with `tests` (coverage at least 70%, not lower than before your change). In a git worktree, set
  `R_LIBS` first (see "Quality gate"). Say plainly what you did not run and why.
- Never add words to `inst/WORDLIST` yourself: list unknown words in your report for the founder.
- Don't install software or change the R library outside the project; don't patch installed packages or mock
  dependencies to make a check pass.
