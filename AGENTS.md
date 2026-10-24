# mascot

Rules for everyone working in this repository, person or AI. Codex and Antigravity (agy) read this file
directly; Claude reads it through the `@AGENTS.md` import at the top of `CLAUDE.md`. Edit the rules here.

An R package for **live, mood-driven mascots** in Shiny apps and Quarto sites: a character drawn in code shows a
mood and animates when the mood changes (a short wiggle, then the new face). Scope, target users and releases:
`docs/scope.md`. Status: before 0.1.0, the first CRAN release. The author, maintainer and copyright holder (the
**package creator**) is Harsh Verma; `Authors@R` in `DESCRIPTION` is the source for names and roles.

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
- **house:** tests in BDD style (`describe()`/`it()`), one test file per R file (its browser tests in
  `test-<name>-browser.R`, its snapshot tests in `test-<name>-snap.R`), every checkmate assertion tested,
  shinytest2 for what a user sees (skipped on CRAN), coverage at least 70%.
- **house:** the engine is plain, unminified JS/CSS in `inst/www/`, deterministic (seeded, no clock), with status
  text beside every mascot (the mood never carries meaning alone) and `prefers-reduced-motion` honoured.
- **house:** wording in docs and UI: no hype; "built for GxP work", never "validated" or "GxP compliant"; never name
  an employer, client or internal system; no unmeasured numbers; British English. Say what the package is now: no
  words that compare with an earlier version ("redesign", "the new studio", "v2") in names, comments or docs.
- **house:** a user-facing change adds its `NEWS.md` bullet in the same PR, under `# mascot (development version)`
  (style in `description-news.md`); a change in `inst/www/` also adds an entry to
  `vignettes/articles/engine-changelog.Rmd`. Don't change the version number or the release headings: the package
  creator decides releases.

## Public text
Tracked files, commits, branch names, issues, pull requests and comments are public.
- **No AI attribution in commits, PR descriptions or comments:** commits carry a person's own name and email; no
  `Co-authored-by` line naming an AI tool, no session links, no "Generated with" lines.
- No machine paths, no pointers to untracked notes, no names of private people or repositories.
- Describe the work and the checks run, not who or what did them; status lines such as "pushed as …" or
  "authorised to …" don't belong in an issue.

## Quality gate
Run the gate, `Rscript tools/cran-gate.R [fast|tests|full|lint|nosuggests]`, instead of calling `devtools::check()`,
lintr or Air yourself. **Which mode when, every option, the exit codes, the run folder and what each CI job runs:
`tools/README.md`.** In short: `fast` before every commit, `tests` before a PR that touches `R/` or `tests/`.
- `tests` fails when a runnable line the branch adds in `R/` is run by no test (`new_lines`). Test the line, or mark a
  justified one `# nocov` with a comment saying why. The 70% total stays as well.
- **Evidence** is a `tests` (or `full`) run that exits 0. Runs marked PARTIAL (`--steps`, `--filter`,
  `--no-coverage`) are not; exit code 3 (every failing test passed on its re-run: a probable flake) is not either,
  unless the package creator accepts it.
- Format R code with Air before you commit (the version is in `.github/CONTRIBUTING.md`); the gate and CI check it.
  JS and CSS in `inst/` are formatted and linted with Biome.
- The gate is generic (any R package can use it as it is): keep anything mascot-specific out of it. After changing
  the gate, `.lintr`, `air.toml` or `biome.json`, run `Rscript tools/test-cran-gate.R`; a new check needs a probe.
- CI must be green. Never `continue-on-error` or weaken a check to get green.
- Never force-push, push to `main`, use `--no-verify`, or edit `NAMESPACE`, `man/`, `renv/` or `LICENSE` by hand.

## Keep mascot studio up to date
- `inst/examples/studio/` (`mascot_studio()`) demonstrates every exported function and argument, function by
  function, for every character.
- **Rule: a PR that adds, removes or changes an exported function or an argument (its name, values, default or
  behaviour) also updates the studio in the same PR.** No studio follow-up PRs. The places to change, in
  `inst/examples/studio/`: controls (`R/panels.R`), control map (`R/data.R`), code builders (`R/code.R`), studio-only
  guide data (`R/guide.R`) and, where needed, pictures (`R/ui.R`) and server code (`app.R`). Explanations come from
  the help pages (`R/shared-help.R` reads them), so update the roxygen, never copy it into the studio.
- The completeness tests in `tests/testthat/test-examples.R` catch a missing function or argument; they do not catch
  a changed default or behaviour, so try the change in the studio before the PR and say so in its checks.

## Known users: never break them
- **Every known user is listed in `docs/consumers.md`**: what it uses, since which version, and how to check it
  still works. Read it before changing anything exported or anything a user can see (moods, arguments, defaults,
  the Quarto shortcode, colours, sizes).
- A change that may affect a known user gets the `consumer-impact` label and a line in the PR on how each
  affected user was checked. A change to the public API gets `breaking-change`, a `NEWS.md` entry and a
  deprecation first (`lifecycle::deprecate_warn()` for at least one release) unless the API is still before 0.1.0.

## Website
The pkgdown site builds with `Rscript tools/build-site.R` (into `site/`; it keeps `CLAUDE.md` and `AGENTS.md` out of
the site). Before a PR that changes docs, exports or examples, run `pkgdown::check_pkgdown()` and look at the site in
light and dark. Link to files in `docs/` with full GitHub URLs (they aren't part of the site). Screenshot-heavy
articles go in `vignettes/articles/` (website only, not shipped); compress PNGs and prefer SVG for diagrams.

## Workflow
- **Every change starts with an issue** (goal and a "done when" checklist), opened with one of the issue forms.
- One branch per issue, from `main`. Conventional Commits, short messages.
- The PR description starts with **"In brief"**: one plain sentence on what it does and why, then a few bullets for a
  reader with no context; then `Closes #<n>` and the template's sections (delete those that do not apply). Its checks
  list only checks anyone can re-run from the repo. Stacked PRs are fine (base on the branch below).
- Labels: one type (`enhancement`, `bug`, `documentation`, `chore`) and one or more `area: *`. Suggest them in the PR
  if you can't set them; the package creator applies them (release notes are built from PR labels).
- CI green, then **the package creator merges**. `main` is protected by a ruleset (a pull request and the required
  checks); pull requests are squash-merged, so the PR title becomes the commit message.

## Issues and pull requests
- One issue per piece of work. When a decision changes the plan (scope, a rename, a dropped item), edit the issue
  description so it says the current plan; add dated comments for progress and other updates.
- Your PR ticks the boxes it delivers. When it closes an issue, say in one line which boxes stay open and where they
  went.
- Paste check results as their summary lines, without local paths (home folder, R library, temporary files).

## Working as an agent
- Work only in the worktree or branch you were given. Don't commit, push, merge or open PRs unless the task says
  so; never force-push.
- Before the first commit, check `git config user.name` and `user.email`: if they name an AI tool, stop and say so.
- Before you report done, run the gate and paste its summary lines: `Rscript tools/cran-gate.R` (fast) and the same
  command with `tests` (coverage at least 70%, not lower than before your change). Say plainly what you did not run
  and why. A self-reported pass never counts: the gate and CI are the evidence (and screenshots for visual work).
- In a git worktree, set `R_LIBS` to what `Rscript -e 'cat(.libPaths()[1])'` prints in the main checkout (renv
  keeps a package project's library outside the repo).
- Never add words to `inst/WORDLIST` yourself: list unknown words in your report.
- Don't patch installed packages or mock dependencies to make a check pass.
