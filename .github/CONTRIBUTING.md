# Contributing to mascot

Thank you for helping with mascot. It is an R package for live, mood-driven mascots in Shiny apps and Quarto sites:
a character drawn in code shows a mood and animates when the mood changes. What is in scope, and what is not, is in
[`docs/scope.md`](https://github.com/insightsurge/mascot/blob/main/docs/scope.md). To report a bug or suggest an idea, open an issue with one of the issue forms.

## Setup

- **R**: the current release is recommended. The package needs R 4.1 or later.
- **Dev packages**: from the package root, run `pak::local_install_dev_deps()` (or `devtools::install_dev_deps()`).
- **Air**, the formatter for R code: <https://posit-dev.github.io/air/>. Use version 0.11.0, the one CI uses.
- **Biome**, the formatter and linter for JavaScript and CSS in `inst/`: <https://biomejs.dev>. Use version 2.5.14.
- **The gate's packages**: devtools, roxygen2, lintr, spelling and jsonlite; also covr, callr and withr for the
  `tests` mode, and rcmdcheck, pkgbuild and processx for `full`. If one is missing, the gate stops and names it.
- **Google Chrome or Chromium**, for the shinytest2 tests.
- **Git worktrees**: if you use renv, it keeps a package project's library outside the repository, so in a worktree
  set `R_LIBS` to the path that `Rscript -e 'cat(.libPaths()[1])'` prints in the main checkout.

## Workflow

1. **Start with an issue.** State the goal and a "done when" checklist. Ask first if the change is large.
2. **Make a branch** from `main` for that issue.
3. **Commit with Conventional Commits**, short: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`.
   Commits carry your own name and email; no AI attribution in commits, PR descriptions or comments (no
   `Co-authored-by` line naming an AI tool, no "Generated with" lines). The full rules for people and coding
   assistants are in [`AGENTS.md`](https://github.com/insightsurge/mascot/blob/main/AGENTS.md).
4. **Open a pull request** that starts with an "In brief" section (one plain sentence and a few bullets, for a reader
   with no context), says `Closes #n` (`n` is the issue number), and fills in the template: what is new and what is
   fixed (plain words first, then function and file names), before and after, scenarios to try, and the checklist.
   Delete the sections that do not apply.
5. **Suggest labels** in the pull request: one type (`enhancement`, `bug`, `documentation`, `chore`) and one or more
   `area: *`. The package creator applies them; the release notes are built from them.
6. **The package creator merges** once CI is green. Pull requests are squash-merged, so the pull request title
   becomes the commit message on `main`: keep it a Conventional Commit.

`main` is protected by a ruleset: changes reach it only through a pull request, and the required checks must pass.
The first time you open a pull request from a fork, CI waits for a maintainer to approve the run; this is expected,
so there is no need to ask. Please leave "Allow edits by maintainers" on, so a maintainer can fix a small thing
(a typo, a failing format check) on your branch instead of asking you to.

Stacked pull requests are fine. Base the second one on the branch below it, and say so in its description.

## Before you open a pull request

Run the gate from the package root:

```sh
Rscript tools/cran-gate.R          # fast: before every commit
Rscript tools/cran-gate.R tests    # tests and coverage: before a pull request that touches R/ or tests/
Rscript tools/cran-gate.R full     # everything, including the built tarball: before a release
```

The gate is a plain R script in `tools/`; it needs the packages listed under Setup. Which mode to run when, every
option and the exit codes are in [`tools/README.md`](https://github.com/insightsurge/mascot/blob/main/tools/README.md).

- `fast` checks formatting (Air and Biome), that `man/` and `NAMESPACE` match the roxygen2 comments, lint, that every
  export has `@returns`, spelling, and `R CMD check --as-cran` without the tests.
- `tests` runs the tests with `NOT_CRAN=true`, so the Chrome tests run, and then measures coverage. Coverage must be
  at least 70%.
- The gate prints one `PASS`, `FAIL` or `SKIP` line for each step, then a summary, and keeps a run folder with one
  log per step (its path is printed). Open a log only for a failing step.
- **Spelling**: unknown words fail the gate. If a word is correct (a name or a technical term), list it in your pull
  request; it goes into `inst/WORDLIST` (the gate's `--update-wordlist`) once the package creator agrees. Do not add a
  misspelling.
- The docs step runs `devtools::document()`, so it may rewrite `man/`, `NAMESPACE` or `DESCRIPTION`. If it fails,
  review the regenerated files and commit them; the next run passes.
- If you change the gate itself (the script, `.lintr`, `air.toml` or `biome.json`), also run
  `Rscript tools/test-cran-gate.R`. It plants one defect per step in a temporary copy
  of the package and checks that the gate fails for each. The gate is generic (other packages use it as it is),
  so keep anything specific to mascot out of it.

CI must be green on every pull request, and `R CMD check` must give 0 errors, 0 warnings and 0 notes. The workflows,
and the gate mode that reproduces each one locally, are listed in `tools/README.md`. Passing the gate locally does
not replace CI.

## Code in short

The full list, with reasons, is in [`docs/standards.md`](https://github.com/insightsurge/mascot/blob/main/docs/standards.md).

- Every function starts by checking its arguments with checkmate, one check per argument.
- Messages, warnings and errors use cli.
- Call functions as `pkg::fn()`. Do not use `library()`, `print()` or `cat()` in package code.
- Document with roxygen2 (markdown). Every export has `@returns` and `@examples` that run offline.
- Never edit `man/` or `NAMESPACE` by hand. Change the roxygen2 comments and run `devtools::document()`.
- Keep JavaScript and CSS in `inst/` plain and readable. Bundle what the package needs; do not load anything from a
  CDN.
- Accessibility: a mood never carries meaning alone, so status text sits beside the mascot. Honour
  `prefers-reduced-motion`.

## Tests

- Use testthat 3rd edition in BDD style: `describe()` names the function or behaviour, and `it()` states the expected
  behaviour in plain words.
- One test file per R file: `R/moods.R` is tested in `tests/testthat/test-moods.R`.
- Cover the happy path, every argument check, edge cases and every bug fix.
- Use shinytest2 for anything a user can see in a Shiny app. These tests need Chrome and are skipped on CRAN.
- Use `shiny::testServer()` for server logic.
- Coverage must be at least 70%, and a pull request must not lower it.

## NEWS.md

Add one bullet for each user-facing change, in the same pull request. Write it for users, in the present tense, start
with the function or feature, and end with the issue number:

```md
* `update_mascot()` gains a `message` argument for a speech bubble (#30).
```

Until 0.1.0, bullets go under the heading `# mascot (development version)` at the top of `NEWS.md`; the milestone's
release PR renames that heading to the milestone's version. Leave out internal changes such as CI, refactors and
tests.

## Known users

Known users of mascot, current and planned, are listed in [`docs/consumers.md`](https://github.com/insightsurge/mascot/blob/main/docs/consumers.md), with a way to
check that each still works. Read it before you change anything that is exported or that a user can see: moods,
arguments, defaults, colours, sizes. If a change may affect a known user, add the `consumer-impact` label and say in
the pull request how you checked.

## Licence of contributions

Contributions are made under the package's MIT licence. Do not add third-party code, fonts or images without recording
their licence. See the section on bundled files in [`docs/standards.md`](https://github.com/insightsurge/mascot/blob/main/docs/standards.md).

## Conduct and data

Everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md). Be kind and patient, and give feedback on
the work, not the person. To report a security problem, do not open an issue: follow the [security policy](SECURITY.md).
For questions, use [Discussions](https://github.com/insightsurge/mascot/discussions) rather than an issue.

Never put real personal, patient or client data in code, tests, issues, examples or screenshots. Use synthetic data.
