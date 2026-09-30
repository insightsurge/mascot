---
name: cran-gate
description: Check whether an R package is ready for CRAN with one command, and fix what it finds. Runs R CMD check the way CRAN does (any error, warning or note fails), the things CRAN reviewers ask for that R CMD check misses (a return value documented for every exported function, help pages in sync with roxygen, spelling), the package's own style checks (Air, lintr, Biome), tests and coverage, and prints one PASS/FAIL line per step. Use it whenever you work in an R package and the user asks to run R CMD check or devtools::check(), asks "is it ready for CRAN?" or "can I submit/release this?", wants tests or coverage run, or a CI check or lint job failed; also on your own before a commit or pull request that changes R/, tests/, inst/, man/ or DESCRIPTION. Prefer it over calling devtools::check(), lintr or Air directly.
---

# /cran-gate

One command that says whether an R package would pass CRAN's checks, before it is submitted. The script
`scripts/cran-gate.R` (in this skill's folder) prints one `PASS`/`FAIL`/`SKIP` line per step, then a summary, and
exits 1 if anything failed. Reading that summary instead of raw check logs keeps the context small. It also sets
`NOT_CRAN` correctly for each mode, which a bare `devtools::check()` does not (it defaults to `NOT_CRAN=true`, so
tests that CRAN skips would run in a check that is meant to be CRAN-like).

```bash
Rscript <this skill's folder>/scripts/cran-gate.R [fast|tests|full|lint] [--update-wordlist]
```

Run it from the package root. `<this skill's folder>` is where this file lives: `.claude/skills/cran-gate` when the
skill is installed in the project (`.agents/skills/cran-gate` for Codex and Gemini), `~/.claude/skills/cran-gate`
when it is installed for all projects.

| Mode | Runs | Use it |
|---|---|---|
| `fast` (default) | tools, style, docs in sync, `\value`, spelling, `R CMD check --as-cran --no-tests` | before every commit |
| `tests` | tests with `NOT_CRAN=true` (so tests behind `skip_on_cran()` run) and coverage | before a pull request that touches `R/` or `tests/`, or when asked for tests or coverage |
| `full` | all of the above, the CRAN-like check with tests, and the built tarball (size, every `inst/` file shipped) | before a release or a CRAN submission, or when asked "is it ready for CRAN?" |
| `lint` | the quick static steps only (no R CMD check) | while editing, or to reproduce a failed lint job |

## What it checks
- **Always** (CRAN, or what its reviewers send packages back for): `R CMD check --as-cran` with 0 errors, 0 warnings
  and 0 notes; a `\value` section for every exported function; `man/` and `NAMESPACE` in sync with the roxygen
  comments; spelling; every file in `inst/` present in the built package; the package's size.
- **When the package has the tool's settings file** (otherwise the step says `SKIP` and why): `air.toml` → formatting
  with Air; `.lintr` → lintr with the package's rules; `biome.json` → Biome on JS and CSS in `inst/`.
- **Tests and coverage** when the package has `tests/`. Coverage is good practice, not a CRAN rule: CRAN never
  measures it.

## Settings (optional)
Fields in the package's `DESCRIPTION` (R CMD check accepts `Config/` fields):

| Field | Default | Meaning |
|---|---|---|
| `Config/cran-gate/coverage` | `70` | lowest line coverage allowed, in percent; `0` reports coverage without a limit. CRAN has no coverage rule: this one is good practice |
| `Config/cran-gate/tarball-mb` | `5` | largest built package allowed, in MB; `5` to `9` (CRAN asks for under 10, and its own checks note an installed size over 5, which then needs a line in `cran-comments.md`) |
| `Config/cran-gate/extra-dirs` | none | more folders to format-check and lint, comma separated, e.g. `tools` |

## First use in a package
- R packages needed: checkmate, cli, devtools, spelling; plus roxygen2, lintr, covr, withr and pkgbuild for the steps
  that use them. The `tools` step names anything missing and prints the library R is using.
- If this skill is installed inside the package (`.claude/`, `.agents/`), those folders must be in `.Rbuildignore`
  (`usethis::use_build_ignore(c(".claude", ".agents"))`), or R CMD check reports a note about hidden files.
- The first spelling run usually lists names and technical terms: see "Spelling words" below.

## Running it
1. Run the mode that fits (table above) from the package root.
2. Read the step lines and the summary. Open the log (its path is printed) only for a step that failed.
3. Fix the cause and re-run until it passes. Don't weaken a check or change a setting to get a pass without asking
   the user.

If `tools` fails with missing R packages although they are installed, R is looking in the wrong library (the line
prints which one). This is common in a git worktree of a project that uses renv: set `R_LIBS` to the library the
main checkout uses (`Rscript -e 'cat(.libPaths()[1])'` there).

## Fixing each step
| Step | What its FAIL means | Fix |
|---|---|---|
| `tools` | Air, Biome or an R package the run needs is missing | install it, or fix `R_LIBS` |
| `air` | R files not formatted | run the `air format ...` command the line shows |
| `biome` | JS or CSS in `inst/` not formatted or linted | `biome check --write inst` |
| `docs` | roxygen output was stale; **the gate has already regenerated it** | review the diff in `man/`, `NAMESPACE`, `DESCRIPTION` and keep it; the next run passes |
| `lintr` | a lint; the line names file, line and linter | fix it; `# nolint: <linter>.` only for a justified exception, with the reason |
| `value` | exported functions without `\value` or without a help page | add `@returns` (what the function returns, or "No return value, called for side effects") to each one named |
| `spelling` | unknown words | fix real typos; for names and technical terms see below |
| `check_fast` / `check_full` | an R CMD check error, warning or note; the first line is shown | open the log; every note counts |
| `tests` / `coverage` | a failing test, or coverage under the limit | fix the test or code; add tests for the lines `covr::zero_coverage()` lists |
| `tarball` | the built package is over the size limit, or an `inst/` file is left out of the build | shrink or drop assets, or fix `.Rbuildignore` |

**Spelling words:** `inst/WORDLIST` is the dictionary for every future check, so a typo added there is hidden for
good. Show the user the unknown words first and run `--update-wordlist` only for the ones they agree are real (names,
technical terms), then keep the changed `inst/WORDLIST`.

## What a pass does and doesn't tell you
A pass means this machine's R and operating system found nothing. CRAN also checks on Windows, macOS and Linux with
R-devel, R-release and R-oldrel, and without the packages in `Suggests`; cover those with CI or the win-builder and
R-hub services before submitting. Reviewers also read `DESCRIPTION` (title, description, references, authors) by
hand.

## Changing the gate itself
After editing `scripts/cran-gate.R` or the settings it reads (`.lintr`, `air.toml`, `biome.json`, the
`Config/cran-gate` fields), run `Rscript <this skill's folder>/scripts/test-cran-gate.R` (`static` for the quick
steps only). It copies the package to a temporary folder, plants one defect per step and must end with "All probes
behaved as expected"; probes for steps the package doesn't use are skipped. A new step needs a new probe there.

## Reporting
Say which modes ran and what they found, for example: "`/cran-gate` fast: all passed (biome skipped: no JS or CSS;
check 0 errors, 0 warnings, 0 notes). `/cran-gate tests`: 42 expectations, coverage 96.3%." Name anything that
failed or was skipped and why, and what a local pass doesn't cover (other platforms, R-devel, no-Suggests).
