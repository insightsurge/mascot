# tools/

Scripts for working on mascot. None of them ship with the package (`tools/` is in `.Rbuildignore`).

| File or folder | What it is |
|---|---|
| `cran-gate.R` | The quality gate: one command that says whether the package would pass CRAN's checks and the house rules |
| `test-cran-gate.R` | The gate's self-test: plants one defect per check and makes sure the gate catches it |
| `build-site.R` | Builds the pkgdown site into `site/` |
| `build-sysdata.R` | Writes `R/sysdata.rda`, the built-in characters already checked (below) |
| `character-coverage.R` | Line coverage of the character files only, without the full tests run |
| `stress/` | Shiny apps that try to break the mascot, run by hand in Chrome (see `stress/README.md`) |

Run every script from the package root, for example `Rscript tools/cran-gate.R`.

## The stored built-in characters

The full check of a built-in character takes most of a second on a fast machine and several seconds on CRAN's
Windows machines, so the package ships the four built-ins already checked, in `R/sysdata.rda`, and reads them from
there. After editing a file in `inst/format/characters/` or the character checker, run
`Rscript tools/build-sysdata.R` and commit the new `R/sysdata.rda`. Until you do,
`tests/testthat/test-character-catalogue-extended.R` fails: it compares each stored character with a fresh check of
its file (it runs in the gate's `tests` mode and wherever the extended tests run, not on CRAN).

## The gate in plain words

The gate runs a fixed list of checks and prints one line per check, then a verdict:

```
PASS air        (  1s)
FAIL lintr      ( 23s): 2 lints: R/x.R:12 ...
SKIP biome      (  0s): no JS or CSS in inst/ yet
```

A SKIP always says why. Every run keeps a **run folder** (its path is printed): one log per check, `gate.json` (every
check's result, the commit and the tool versions) and, after the tests, `tests.json` with every failing test. `flakes.tsv`, one level up (shared by every run), lists the tests
that failed and were re-run, with the outcome. The folder survives the gate. You never need
to re-run the gate just to find out what failed.

### Which mode when

`Rscript tools/cran-gate.R <mode>`

| Mode | Run it | What it checks |
|---|---|---|
| `fast` (the default) | Before every commit | Formatting, lint, help pages in sync, a `\value` on every export, spelling, the pkgdown index, R CMD check without tests |
| `tests` | Before a PR that touches `R/` or `tests/` | The whole test suite (Chrome tests too) once under covr, coverage of at least 70%, and `new_lines`: every R line the branch adds since it left `origin/HEAD` (uncommitted work counts) is run by a test |
| `full` | Before a release | All of `fast` and `tests`, R CMD check with tests as CRAN runs it, the check without Suggests, and the package size |
| `lint` | For a quick style check, or to reproduce CI's lint job | The static checks only |
| `nosuggests` | When CI's no-Suggests job fails, or before a release | R CMD check with only the required packages, as CRAN also checks |

In short: `fast` while working, `tests` before a PR, `full` before a release.

### Options

| Option | Use it to | Merge evidence? |
|---|---|---|
| `--steps tests,coverage` | Run only some of the mode's checks, for example after an interrupted run | No: PARTIAL |
| `--filter studio` | Run only the test files whose names match, while fixing one test | No: PARTIAL |
| `--no-coverage` | Run the tests without covr, more quickly | No: PARTIAL |
| `--no-retry` | Skip the re-run of failing test files, to see the raw failure | Yes |
| `--out <folder>` | Put the run folder somewhere else (or set `CRAN_GATE_OUT`) | Yes |
| `--list` | Show each mode's checks and which ones this package skips | Nothing runs |
| `--help` | Show every option and the exit codes | Nothing runs |
| `--update-wordlist` | Add the unknown words to `inst/WORDLIST`, only after the package creator agrees to them | Yes |

A **PARTIAL** run is useful while working, but it isn't proof. Merge evidence is a full `tests` (or `full`) run that
exits with 0.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Every check passed, or skipped with a reason |
| 1 | A check failed: its line says what to fix |
| 2 | The gate couldn't judge the package: a tool is missing or a setting is wrong |
| 3 | Only tests failed, and every one passed when re-run: probably a flake. Never merge evidence without the package creator's word |

In `tests` and `full` the suite runs once, under covr, and that one run gives both the test results and the coverage.
The run sets `TESTTHAT_IS_CHECKING`, as testthat's `test_check()` does under R CMD check, so the tests behave as they
do there (shinytest2, for one, then loads the installed package in its app processes instead of the source).
If covr itself fails after the suite has run (while merging what it measured, say), the coverage line FAILs with
covr's message and points to `tests.log`; the gate does not run the suite a second time to get a percentage.

When tests fail, the gate re-runs the failing files once in a fresh R session. When one broken thing (a closed
browser, say) fails many tests with the same message, the line names it once as a "cascade".

### The gate and CI

`lint.yaml` and `check-no-suggests.yaml` run the gate itself and `gate-self-test.yaml` its self-test;
`off-cran-tests.yaml` runs testthat directly, and the other test workflows run R CMD check or covr.
What each workflow runs and when, which gate mode checks the same thing locally (the evidence when CI can't run),
which test files run where and the CI report comment on a pull request: [`.github/workflows/README.md`](../.github/workflows/README.md).

### Changing the gate

After changing the gate, `.lintr`, `air.toml` or `biome.json`, run the self-test:
`Rscript tools/test-cran-gate.R` (`unit` alone takes seconds). A new check needs a probe that plants its defect. The
self-test also fails when this README misses a mode or an option that `--help` lists.

Details: `Rscript tools/cran-gate.R --help`. Rules: the "Quality gate" section of `AGENTS.md` and
`.claude/rules/ci.md`.
