# tools/

Scripts for working on mascot. None of them ship with the package (`tools/` is in `.Rbuildignore`).

| File or folder | What it is |
|---|---|
| `cran-gate.R` | The quality gate: one command that says whether the package would pass CRAN's checks and the house rules |
| `test-cran-gate.R` | The gate's self-test: plants one defect per check and makes sure the gate catches it |
| `build-site.R` | Builds the pkgdown site into `site/` |
| `character-coverage.R` | Line coverage of the character files only, without the full tests run |
| `stress/` | Shiny apps that try to break the mascot, run by hand in Chrome (see `stress/README.md`) |

Run every script from the package root, for example `Rscript tools/cran-gate.R`.

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

`lint.yaml` and `check-no-suggests.yaml` run the gate itself; the other jobs run R CMD check or covr directly. The last column is the gate
mode that checks the same thing locally, which is the evidence when CI can't run (no Actions minutes).

| Workflow | What it runs | Locally |
|---|---|---|
| `R-CMD-check.yaml` | `R CMD check --as-cran`, failing on any note, with `NOT_CRAN` false (browser, snapshot and extended tests skip, as on CRAN) and the whole test output when a test fails; on Ubuntu with R release it also fails when the tests take longer than 180 s. On every pull request, push to `main`, every Monday and on demand: macOS and Windows (R release) and Ubuntu (R devel, release, previous release and 4.1). Every Monday and on demand, the `extended` job also checks macOS and Windows (R release and 4.1) with `MASCOT_EXTENDED_TESTS: true`, outside the `R-CMD-check` summary check | the `check_full` step of `full` |
| `test-coverage.yaml` | The tests without Chrome (`NOT_CRAN` false), the extended tests included (`MASCOT_EXTENDED_TESTS: true`), under covr, and the coverage limit from `DESCRIPTION` (on a pull request, the higher of the base branch's limit and the PR's own, so a pull request cannot lower the limit by editing `DESCRIPTION`; changes to this workflow are reviewed like any other change) | `tests` (a superset: it runs the browser tests too, under covr, so its coverage is higher) |
| `off-cran-tests.yaml` | The test files that hold the tests CRAN skips (the browser tests in `test-*-browser.R`, the snapshot tests in `test-*-snap.R` and the example apps' detailed tests in `test-*-extended.R`), with Chrome and `NOT_CRAN: true`, on Ubuntu with R release and R 4.1, one line per test file as it finishes; fails when a test fails, one of those tests skips or a file reports no test. The `off-cran-tests` check passes only when both R versions pass | `tests` |
| `check-no-suggests.yaml` | The gate in `nosuggests` mode on a library with only the hard dependencies (plus rcmdcheck, testthat, knitr and rmarkdown): R CMD check with only what the check needs on the library path, so a Suggests package that is installed but not needed stays hidden; a skipped check fails the job | `nosuggests` |
| `lint.yaml` | The gate in `lint` mode, with Air and Biome at pinned versions | `lint` |
| `gate-self-test.yaml` | The gate's self-test, when the gate, its self-test, `.lintr`, `air.toml` or `biome.json` change (and on demand) | `Rscript tools/test-cran-gate.R` |
| `pkgdown.yaml` | `pkgdown::check_pkgdown()` and the site build, from `main` only | `Rscript tools/build-site.R` |
| `gitleaks.yml` | A scan for committed secrets | |
| `release.yml` | Started by hand on `main`, after CRAN accepts the version: checks that `DESCRIPTION`, the `NEWS.md` heading and the engine changelog heading agree and the NEWS section has text, then tags `vX.Y.Z` and creates the GitHub release (never on merge) | `bash .github/scripts/test-release-check.sh` |

**Releasing.** The release pull request (version, NEWS, `cran-comments.md`) stays open while CRAN reviews; CRAN's
comments become commits on it. After CRAN accepts and the pull request is merged, start the workflow by hand: Actions,
release, Run workflow, branch `main`, and leave the commit empty (the tip of `main`) or give the accepted commit's SHA.
The workflow's logic is `.github/scripts/release-check.sh`: a commit that is not on `main`, versions or headings that
disagree, an empty NEWS section or an existing tag on another commit fail before anything is published. A re-run after
a failed release step creates the missing release from the existing tag; a re-run after success does nothing. Tags
and releases are never moved or deleted: a fix after publication gets a new version. A development version
(`X.Y.Z.9000`) is published as a pre-release, with the heading `# mascot (development version)`.

A pull request that changes only documentation (the README, `docs/`, the website's articles and settings, the issue
forms and the repository's notes) starts the R jobs and skips their steps (`.github/scripts/r-changes.sh`), so every
check still reports. Dependabot keeps the actions current. The gate's `new_lines` step has
no CI job: it needs the branch's base, which CI's shallow checkout lacks, so it runs locally.

**The CI report comment.** On a pull request, one comment, rewritten as each workflow finishes, sums up what CI found,
in a Tests and a Code style section:

- `R-CMD-check.yaml`: whether every platform passed, and how long the tests took on Ubuntu with R release against the
  180 s limit.
- `test-coverage.yaml`: the line coverage without the browser tests, the limit from `DESCRIPTION` and the
  difference from the latest successful run on `main`; the added `R/` lines that the job's tests don't run (a report,
  not a check: a browser test may run them, and the gate's `new_lines` step is the check); or why nothing was measured.
- `off-cran-tests.yaml`, per R version: the counts, with the tests in browser, snapshot and extended files, the failing
  and skipped tests, the slowest test files and the files much slower than on `main` (at least 25% and 10 seconds).
- `lint.yaml`: passed or failed. lintr's findings show inline in the pull request's "Files changed".

Each job writes its part to its job summary (on the run's page) and keeps it as an artifact; a small `report` job at the
end of each of those workflows gathers the parts of the pull request's commit into the comment
(`.github/actions/pr-report-comment`, set up in `.github/pr-report.json`). Pull requests from forks and from
Dependabot get the job summaries only: their token can't write to the pull request. The figures from `main` are
artifacts that its runs keep for 90 days; when there is none, the comment says so. A re-run job replaces its part;
when a re-run job stops before it writes one (a failed checkout, say), the earlier attempt's part stays, and the
footer's run state (failure, cancelled) is the sign.

### Changing the gate

After changing the gate, `.lintr`, `air.toml` or `biome.json`, run the self-test:
`Rscript tools/test-cran-gate.R` (`unit` alone takes seconds). A new check needs a probe that plants its defect. The
self-test also fails when this README misses a mode or an option that `--help` lists.

Details: `Rscript tools/cran-gate.R --help`. Rules: the "Quality gate" section of `AGENTS.md` and
`.claude/rules/ci.md`.
