---
name: cran-gate
description: Run mascot's CRAN gate (tools/cran-gate.R) and act on its one-line-per-step summary. Use it whenever you need to know whether the package is CRAN-clean or ready to commit or PR, even if the user doesn't say "gate": "run R CMD check", "devtools::check", "is it ready for CRAN?", "run the tests / coverage", "why did the lint job fail?", /cran-gate. Also run it on your own after changing files in R/, tests/, inst/, man/ or DESCRIPTION and before every commit or PR in this repo. Prefer it over calling devtools::check(), lintr or air directly.
---

# /cran-gate

`tools/cran-gate.R` runs, in one go, the checks CRAN needs (R CMD check `--as-cran`) and the house checks R CMD
check doesn't do (formatting, lint, docs in sync with roxygen, `@returns` on exports, spelling, coverage). It
prints one `PASS`/`FAIL`/`SKIP` line per step, then a summary, and exits 1 if anything failed. Reading that summary
instead of raw check logs keeps the context small, and the script sets `NOT_CRAN` correctly for each mode, which a
bare `devtools::check()` does not (it defaults to `NOT_CRAN=true`, so Chrome tests would run in a "CRAN-like" check).

```bash
Rscript tools/cran-gate.R [fast|tests|full|lint] [--update-wordlist]
```

| Mode | Runs | Use it |
|---|---|---|
| `fast` (default, ~20 s now) | tools, Air, Biome, docs in sync, lintr, `\value`, spelling, `R CMD check --as-cran --no-tests` | before every commit |
| `tests` | tests with `NOT_CRAN=true` (shinytest2/Chrome tests run) and coverage ≥ 90% | before a PR touching `R/` or `tests/`, or when asked for tests/coverage |
| `full` | all of the above, the CRAN-like check with tests, and the built tarball (size, every `inst/` file shipped) | before a release, or when asked "is it ready for CRAN?" |
| `lint` | the static steps only: exactly what CI's lint job runs | to reproduce a failed lint job locally |

## Running it
1. Run from the package root. In a git worktree, R won't find the dev packages by itself (renv keeps a package
   project's library outside the repo), so first:
   `export R_LIBS=$(cd <main checkout> && Rscript -e 'cat(.libPaths()[1])' 2>/dev/null)`.
   The `tools` step prints `.libPaths()[1]`, so a wrong library shows up at once.
2. Read the step lines and the summary. Open the log (its path is printed) only for a step that failed.
3. Fix the cause and re-run until it passes.

## Fixing each step
| Step | What its FAIL means | Fix |
|---|---|---|
| `tools` | Air, Biome (once `inst/` has JS/CSS) or an R package is missing | install it, or fix `R_LIBS` |
| `air` | R files not formatted | `air format .` |
| `biome` | JS/CSS in `inst/` not formatted or linted | `biome check --write inst`; `SKIP` just means no JS/CSS exists yet |
| `docs` | roxygen output was stale; **the gate has already regenerated it** | review the diff in `man/`, `NAMESPACE`, `DESCRIPTION` and commit it; the next run passes |
| `lintr` | a lint; the line names file, line and linter | fix it; `# nolint: <linter>.` only for a justified exception such as `print()` inside a `print()` method, with the reason |
| `value` | exported functions without `\value` | add `@returns` to each one named |
| `spelling` | unknown words | fix real typos; for names and technical terms see below |
| `check_fast` / `check_full` | an R CMD check error, warning or note; the first line is shown | open the log; every note counts (the repo rule is 0/0/0) |
| `tests` / `coverage` | a failing test, or coverage under 90% | fix the test or code; add tests for the lines `covr::zero_coverage()` lists |
| `tarball` | over the 5 MB house target, or an `inst/` file left out of the build | shrink assets, or fix `.Rbuildignore` |

**Spelling words:** `inst/WORDLIST` is the dictionary for every future check, so a typo added there is hidden for
good. Show the founder the unknown words and run `--update-wordlist` only for the ones they agree are real (names
like Neer, technical terms), then commit `inst/WORDLIST`.

## Reporting
Say which modes ran and what they found, in the PR template's terms, for example: "`/cran-gate` fast: all passed
(biome skipped: no JS/CSS yet; check 0/0/0). `/cran-gate tests`: 42 expectations, coverage 96.3%." Name anything
that failed or was skipped and why. A local pass isn't the whole PR gate: CI also runs R CMD check on five
platforms, coverage with Chrome tests, and the no-Suggests check.
