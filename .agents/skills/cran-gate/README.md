# cran-gate

One command that tells you whether an R package would pass CRAN's checks, before you submit it. It is a skill for
Claude Code (and other coding assistants that read skill folders), built around a plain R script that also runs
without any assistant.

```text
── CRAN gate: fast ──────────────────────────────────────────
PASS tools      (  0s): .libPaths()[1] = /path/to/library
PASS air        (  0s)
SKIP biome      (  0s): no biome.json: the package doesn't use Biome
PASS docs       (  0s)
PASS lintr      (  1s)
FAIL value      (  0s): no \value (add @returns) for: my_function
PASS spelling   (  0s)
PASS check_fast ( 15s): 0 errors, 0 warnings, 0 notes
FAILED: value
```

## Why it exists

- `R CMD check` is what CRAN runs, but it doesn't catch everything CRAN's reviewers send packages back for (a
  missing return-value section, help pages that no longer match the roxygen comments, typos).
- `devtools::check()` is not quite what CRAN runs: it sets `NOT_CRAN=true`, so tests behind `skip_on_cran()` run on
  your machine and are skipped on CRAN's. The gate runs the check the way CRAN does.
- A full check log is long. One line per step is quick to read for a person and cheap to read for an assistant.
- A check that can't fail protects nothing, so the gate ships with a test of itself.

## What is in the folder

| File | What it is |
|---|---|
| `SKILL.md` | Instructions for the assistant: when to run the gate, which mode, how to fix each failing step, how to report |
| `scripts/cran-gate.R` | The gate. Plain R; run it yourself or let the assistant run it |
| `scripts/test-cran-gate.R` | The gate's self-test: plants one defect per step in a copy of your package and checks the gate catches it |
| `README.md` | This file, for people |

## Install

Copy the `cran-gate` folder to one of these places:

| Where | Effect |
|---|---|
| `<your package>/.claude/skills/cran-gate/` | Everyone who works on that package with Claude Code gets it; the gate's version travels with the package |
| `~/.claude/skills/cran-gate/` | You get it in every project on your machine |
| `<your package>/.agents/skills/cran-gate/` | For assistants that read `.agents/` (for example Codex and Gemini) |

If the folder lives inside the package, keep it out of the built package, or `R CMD check` reports a note about
hidden files:

```r
usethis::use_build_ignore(c(".claude", ".agents"))
```

R packages the gate needs: `checkmate`, `cli`, `devtools`, `spelling`, and for the steps that use them `roxygen2`,
`lintr`, `covr`, `withr`, `pkgbuild` (the self-test also needs `processx`). The first step of every run names
anything that is missing.

```r
install.packages(c("checkmate", "cli", "devtools", "spelling", "roxygen2", "lintr", "covr", "withr", "pkgbuild"))
```

## Use

With an assistant: ask "is this ready for CRAN?", "run R CMD check", "run the tests", or type `/cran-gate`. The
assistant runs the gate, reads the summary, fixes what failed and runs it again.

Without one, from the package root:

```sh
Rscript .claude/skills/cran-gate/scripts/cran-gate.R          # fast
Rscript .claude/skills/cran-gate/scripts/cran-gate.R tests
Rscript .claude/skills/cran-gate/scripts/cran-gate.R full
```

| Mode | What runs | When |
|---|---|---|
| `fast` (default) | style, docs in sync, return values, spelling, `R CMD check --as-cran` without the tests | before every commit |
| `tests` | the tests (including those CRAN skips) and coverage | before a pull request that changes code or tests |
| `full` | everything, plus the CRAN-like check with tests and the built package's size and contents | before a release or a CRAN submission |
| `lint` | the quick static steps only, no `R CMD check` | while editing |

The gate prints `PASS`, `FAIL` or `SKIP` for each step, then a summary, and exits with status 1 if anything failed
(so it works in CI and scripts). Details go to a log file whose path is printed.

## What it checks, and why

"CRAN" means CRAN's machines or reviewers would object. "Good practice" means CRAN won't, but the check keeps the
package healthy and makes the CRAN checks less likely to surprise you.

| Step | What it does | Kind |
|---|---|---|
| `tools` | The needed R packages and tools are installed. A missing tool is a failure, never a silent skip | - |
| `check_fast`, `check_full` | `R CMD check --as-cran` with `NOT_CRAN=false`; any error, warning or **note** fails | CRAN |
| `value` | Every exported function has a help page with a `\value` section (roxygen: `@returns`) | CRAN (asked for in review) |
| `docs` | `man/` and `NAMESPACE` match the roxygen comments: runs `devtools::document()` and fails if anything changed | CRAN (stale help pages cause check warnings) |
| `spelling` | No unknown words in help pages, `DESCRIPTION` and vignettes; known names go in `inst/WORDLIST` | CRAN (reviewers flag typos in `DESCRIPTION`) |
| `tarball` | The built package is under the size limit, and every file in `inst/` is really inside it | CRAN (size) and good practice (contents) |
| `tests` | The test suite with `NOT_CRAN=true`, so tests behind `skip_on_cran()` run too | good practice |
| `coverage` | Line coverage with covr is at least the limit | good practice (CRAN does not measure coverage) |
| `air` | R code is formatted with [Air](https://posit-dev.github.io/air/) | good practice |
| `lintr` | No lints, using the package's own `.lintr` | good practice |
| `biome` | JS and CSS under `inst/` pass [Biome](https://biomejs.dev) | good practice |

Steps adapt to the package, so the gate works on a package that uses none of the optional tools:

| Step | Runs when | Otherwise |
|---|---|---|
| `air` | the package has `air.toml` | SKIP |
| `lintr` | the package has `.lintr` | SKIP |
| `biome` | the package has `biome.json` and JS or CSS in `inst/` | SKIP |
| `docs` | the package uses roxygen2 | SKIP |
| `tests`, `coverage` | the package has `tests/` (`tests/testthat/` for the tests step) | SKIP |

A `SKIP` always says why, so nothing is left out quietly.

## Settings

Optional lines in the package's `DESCRIPTION`. R CMD check accepts fields that start with `Config/`.

```text
Config/cran-gate/coverage: 80
Config/cran-gate/tarball-mb: 5
Config/cran-gate/extra-dirs: tools, data-raw
```

| Field | Default | Meaning |
|---|---|---|
| `Config/cran-gate/coverage` | `70` | Lowest line coverage allowed, in percent. `0` reports coverage without a limit |
| `Config/cran-gate/tarball-mb` | `5` | Largest built package allowed, in MB, from `5` to `9`. CRAN asks for under 10; above 5 MB installed, CRAN's checks add a note that you explain in `cran-comments.md` |
| `Config/cran-gate/extra-dirs` | none | More folders to format-check and lint, comma separated |

A value outside its range stops the run with `FAIL settings`.

## What a pass doesn't tell you

The gate checks your package on your machine, with your version of R. Before submitting, also cover:

- **Other platforms and R versions.** CRAN checks on Windows, macOS and Linux with R-devel, R-release and R-oldrel.
  Use CI (the `r-lib/actions` check workflows), or the win-builder and R-hub services.
- **No `Suggests`.** CRAN also checks with only the required packages installed. A CI job that installs hard
  dependencies only catches an unguarded use of a suggested package.
- **What a person reads.** Reviewers read the `DESCRIPTION` title and description, the references, the authors and
  copyright holders, and the examples. No tool checks those fully.
- **CRAN's incoming checks**, which need the network (for example whether URLs resolve), are off, as they are in
  `devtools::check()` by default.

A simple setup: the gate locally before commits and pull requests; in CI, one job that runs the gate in `lint`
mode and the standard `R CMD check` workflow across platforms.

## Recommended assistant settings

The gate tells you when something is wrong. These settings stop an assistant from taking the few actions that are
hard to undo or that bypass the checks. They go in the package's `.claude/settings.json`:

```json
{
  "permissions": {
    "ask": [
      "Bash(gh pr merge *)"
    ],
    "deny": [
      "Bash(git push *--force*)",
      "Bash(git push -f *)",
      "Bash(git push * -f)",
      "Bash(git push * -f *)",
      "Bash(git push * +*)",
      "Bash(git push * main)",
      "Bash(git push *:main)",
      "Bash(git push *--no-verify*)",
      "Bash(git commit *--no-verify*)",
      "Edit(NAMESPACE)",
      "Edit(man/**)"
    ]
  }
}
```

- **deny** blocks the action outright: force-pushes, pushing straight to `main`, skipping git hooks, and editing
  `NAMESPACE` or `man/` by hand (roxygen writes those; a hand edit is lost on the next `document()` and makes the
  `docs` step fail).
- **ask** makes the assistant stop and get your confirmation each time: here, merging a pull request.
- Two more worth an **ask** rule, written for however you run them: adding words to the spelling dictionary
  (`--update-wordlist`, because a typo added there is hidden for good) and anything that submits to CRAN
  (`devtools::submit_cran()`, `devtools::release()`), which should always be a person's decision.

These are guard rails, not the gate: they narrow what an assistant can do by accident, while the checks still come
from the gate and CI. Try each rule once after adding it, so you know it matches the commands you use.

**Hooks.** None are needed. A line in the project's instructions file does the same job with nothing to maintain:

```markdown
## Quality gate
Run `/cran-gate` instead of calling `devtools::check()`, lintr or Air yourself.
- `fast` before every commit; `tests` before a pull request that touches `R/` or `tests/`; `full` before a release.
- After editing R files, run `air format .` (the gate fails on unformatted code).
- New spelling words go into `inst/WORDLIST` only after I agree.
- Never weaken a check or change a `Config/cran-gate` setting to get a pass.
```

## The self-test

```sh
Rscript .claude/skills/cran-gate/scripts/test-cran-gate.R          # all probes, about a minute on a small package
Rscript .claude/skills/cran-gate/scripts/test-cran-gate.R static   # the quick ones, seconds
```

Each probe copies your package to a temporary folder, plants one defect (an unformatted file, code with lints, a
misspelt word, an export without a return value, a failing test, untested code, a check note, a file in `inst/` that
the build leaves out, a missing tool, a bad setting) and runs the gate on the copy. The probe passes when the gate
fails for the step that should catch it. A clean copy must pass. Your package is never changed, and probes for steps
your package doesn't use are skipped.

Run it from a package that already passes the gate, after you change the gate or the settings it reads (`.lintr`,
`air.toml`, `biome.json`, the `Config/cran-gate` fields). If you add a step to the gate, add a probe for it.

## Good to know

- The `docs` step runs `devtools::document()`, so it can rewrite `man/`, `NAMESPACE` and `DESCRIPTION`. When it
  fails, the files are already regenerated: review the diff and keep it, and the next run passes.
- `--update-wordlist` rewrites `inst/WORDLIST`. Look at the unknown words first.
- Nothing else is written outside R's temporary folder.
- If the `tools` step says a package is missing although you installed it, R is using a different library: the line
  prints which one. In a git worktree of a project that uses renv, set `R_LIBS` to the main checkout's library.
- Developed on macOS and written to run on Linux as well. It has not been tried on Windows.
