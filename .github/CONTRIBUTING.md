# Contributing to mascot

Thank you for helping with mascot. It is an R package for live, mood-driven mascots in Shiny apps and Quarto sites:
a character drawn in code shows a mood and animates when the mood changes. What is in scope, and what is not, is in
[`docs/scope.md`](https://github.com/insightsurge/mascot/blob/main/docs/scope.md). To report a bug or suggest an idea, open an issue with one of the issue forms.

## Setup

- **R**: the current release is recommended. The package needs R 4.1 or later.
- **Dev packages**: from the package root, run `pak::local_install_dev_deps()` (or `devtools::install_dev_deps()`).
- **Air**, the formatter for R code: <https://posit-dev.github.io/air/>. Use version 0.11.0, the one CI uses.
- **Biome**, the formatter and linter for JavaScript and CSS in `inst/`: <https://biomejs.dev>. Use version 2.5.14.
  You only need it once `inst/` holds JavaScript or CSS. Until then the gate skips it.
- **Google Chrome or Chromium**, for the shinytest2 tests.
- **renv (optional)**: the maintainer keeps the dev packages in a local renv that is not committed. For a package
  project, renv keeps the library outside the repository. In a git worktree, set `R_LIBS` to the path that
  `Rscript -e 'cat(.libPaths()[1])'` prints in the main checkout.

## Workflow

1. **Start with an issue.** State the goal and a "done when" checklist. Ask first if the change is large.
2. **Make a branch** from `main` for that issue.
3. **Commit with Conventional Commits**, short: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `ci:`, `refactor:`.
4. **Open a pull request** that starts with an "In brief" section (one plain sentence and a few bullets, for a reader
   with no context), says `Closes #n` (`n` is the issue number), and fills in the checklist in the template.
5. **Label the pull request** with one type (`enhancement`, `bug`, `documentation`, `chore`) and one or more
   `area: *` labels. The release notes are built from these labels.
6. **The maintainer merges** once CI is green.

Stacked pull requests are fine. Base the second one on the branch below it, and say so in its description.

## Before you open a pull request

Run the gate from the package root:

```sh
Rscript tools/cran-gate.R          # fast: before every commit
Rscript tools/cran-gate.R tests    # tests and coverage: before a pull request that touches R/ or tests/
Rscript tools/cran-gate.R full     # everything, including the built tarball: before a release
```

The gate is a plain R script in `tools/`; it needs nothing else installed beyond the package's development tools.

- `fast` checks formatting (Air and Biome), that `man/` and `NAMESPACE` match the roxygen2 comments, lint, that every
  export has `@returns`, spelling, and `R CMD check --as-cran` without the tests.
- `tests` runs the tests with `NOT_CRAN=true`, so the Chrome tests run, and then measures coverage. Coverage must be
  at least 70%.
- The gate prints one `PASS`, `FAIL` or `SKIP` line for each step, then a summary. It exits with status 1 if any
  step fails. The detailed output goes to a log file, and the path is printed. Open the log only for a failing step.
- **Spelling**: unknown words fail the gate. Check that a word is correct (a name or a technical term), then add it to
  `inst/WORDLIST` by running the gate with `--update-wordlist`. Do not add a misspelling.
- The docs step runs `devtools::document()`, so it may rewrite `man/`, `NAMESPACE` or `DESCRIPTION`. If it fails,
  review the regenerated files and commit them; the next run passes.
- If you change the gate itself (the script, `.lintr`, `air.toml` or `biome.json`), also run
  `Rscript tools/test-cran-gate.R`. It plants one defect per step in a temporary copy
  of the package and checks that the gate fails for each. The gate is generic (other packages use it as it is),
  so keep anything specific to mascot out of it.

CI runs these workflows, and all of them must be green: `R-CMD-check` (Ubuntu on pull requests; macOS, Windows, R-devel
and the previous R release as well on `main`, weekly and on demand), `check-no-suggests`, `lint`,
`test-coverage` and `gitleaks`. `R CMD check` must give 0 errors, 0 warnings and 0 notes. Passing the gate locally
does not replace CI.

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
- One test file per R file: `R/mood.R` is tested in `tests/testthat/test-mood.R`.
- Cover the happy path, every argument check, edge cases and every bug fix.
- Use shinytest2 for anything a user can see in a Shiny app. These tests need Chrome and are skipped on CRAN.
- Use `shiny::testServer()` for server logic.
- Coverage must be at least 70%, and a pull request must not lower it.

## NEWS.md

Add one bullet for each user-facing change, in the same pull request. Write it for users, in the present tense, start
with the function or feature, and end with the issue number:

```md
* `updateMascot()` gains a `message` argument for a speech bubble (#30).
```

Until 0.1.0, bullets go under the heading `# mascot 0.0.0.9000`. Leave out internal changes such as CI, refactors and
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

Be kind and patient. Give feedback on the work, not the person.

Never put real personal, patient or client data in code, tests, issues, examples or screenshots. Use synthetic data.
