# CI workflows

What each workflow runs, when, and how its results reach a pull request. The rules for changing them are in
`.claude/rules/ci.md`; how the tests are organised is in [`tests/README.md`](../../tests/README.md).

## In brief

- **R CMD check runs as CRAN does** (`R-CMD-check.yaml`, job `check`): `--as-cran`, `NOT_CRAN` false, any note fails.
  It runs only the plain test files, as CRAN will, and on Ubuntu with R release it fails when the tests take longer
  than 180 s.
- **Everything CRAN skips runs elsewhere:** the browser, snapshot and extended tests in `off-cran-tests.yaml` (with
  Chrome), the extended tests also in `test-coverage.yaml` and, once a week, on macOS and Windows (`extended-tests.yaml`).
- **One comment per pull request** sums up the results ("CI report"), rewritten as each workflow finishes.

## Which tests run where

The four kinds of test file are described in [`tests/README.md`](../../tests/README.md). `EXTENDED_TESTS` is the
switch for the extended tests.

| Where | When | `NOT_CRAN` / `EXTENDED_TESTS` | plain | browser | snapshot | extended |
|---|---|---|---|---|---|---|
| CRAN | on submission and in CRAN's daily checks | unset / unset | yes | | | |
| `R-CMD-check.yaml`, job `check`: macOS and Windows (R release), Ubuntu (R devel, release, previous release, 4.1) | every pull request, push to `main`, Mondays, by hand | false / unset | yes | | | |
| `extended-tests.yaml`: macOS (R release), Windows (R release and 4.1) | Mondays and by hand only | false / true | yes | | | yes |
| `test-coverage.yaml`: Ubuntu, R release, under covr | every pull request, push to `main`, by hand | false / true | yes | | | yes |
| `off-cran-tests.yaml`: Ubuntu, R release and 4.1, with Chrome | every pull request, push to `main`, Mondays, by hand | true / true | | yes | yes | yes |
| The gate's `tests` mode, locally | before a pull request | true / unset | yes | yes | yes | yes |

The CRAN-like job is `check`; locally, the gate's `full` mode runs the same check (its `check_full` step).

## The workflows

The last column is the gate mode that checks the same thing locally, which is the evidence when CI can't run.

| Workflow | What it runs | Locally |
|---|---|---|
| `R-CMD-check.yaml` | Job `check`: `R CMD check --as-cran`, failing on any note, with `NOT_CRAN` false (browser, snapshot and extended tests skip, as on CRAN) and the whole test output when a test fails; on Ubuntu with R release it also fails when `Running 'testthat.R'` takes longer than 180 s elapsed. On every pull request, push to `main`, every Monday and on demand: macOS and Windows (R release) and Ubuntu (R devel, release, previous release and 4.1); the `R-CMD-check` check passes only when all six pass. | the `check_full` step of `full` |
| `extended-tests.yaml` | Every Monday and on demand: the same R CMD check on macOS (R release) and Windows (R release and 4.1), with `EXTENDED_TESTS: true` and failing only on errors and warnings. A workflow of its own, so a failure here doesn't turn R-CMD-check's README badge red. macOS runs R release only: R 4.1 there has no ready-built packages, and building them from source broke on the runner's OpenSSL | `tests` (extended tests on this machine only) |
| `test-coverage.yaml` | The tests without Chrome (`NOT_CRAN` false), the extended tests included (`EXTENDED_TESTS: true`), under covr, and the coverage limit from `DESCRIPTION` (on a pull request, the higher of the base branch's limit and the PR's own, so a pull request cannot lower the limit by editing `DESCRIPTION`; changes to this workflow are reviewed like any other change) | `tests` (a superset: it runs the browser tests too, under covr, so its coverage is higher) |
| `off-cran-tests.yaml` | The test files that hold the tests CRAN skips (`test-*-browser.R`, `test-*-snap.R` and `test-*-extended.R`), with Chrome and `NOT_CRAN: true`, on Ubuntu with R release and R 4.1, one line per test file as it finishes; fails when a test fails, one of those tests skips or a file reports no test (a file skipped from its first line reports nothing). The `off-cran-tests` check passes only when both R versions pass | `tests` |
| `check-no-suggests.yaml` | The gate in `nosuggests` mode on a library with only the hard dependencies (plus rcmdcheck, testthat, knitr and rmarkdown): R CMD check with only what the check needs on the library path, so a Suggests package that is installed but not needed stays hidden; a skipped check fails the job | `nosuggests` |
| `lint.yaml` | The gate in `lint` mode, with Air and Biome at pinned versions | `lint` |
| `gate-self-test.yaml` | The gate's self-test, when the gate, its self-test, `.lintr`, `air.toml` or `biome.json` change (and on demand) | `Rscript tools/test-cran-gate.R` |
| `pkgdown.yaml` | `pkgdown::check_pkgdown()` and the site build, from `main` only | `Rscript tools/build-site.R` |
| `gitleaks.yml` | A scan for committed secrets | |
| `release.yml` | Started by hand on `main`, after CRAN accepts the version: checks that `DESCRIPTION`, the `NEWS.md` heading and the engine changelog heading agree and the NEWS section has text, then tags `vX.Y.Z` and creates the GitHub release (never on merge) | `bash .github/scripts/test-release-check.sh` |

A pull request that changes only documentation (the README, `docs/`, the website's articles and settings, the issue
forms and the repository's notes) starts the R jobs and skips their steps (`.github/scripts/r-changes.sh`), so every
check still reports. Dependabot keeps the actions current. The gate's `new_lines` step has no CI job: it needs the
branch's base, which CI's shallow checkout lacks, so it runs locally.

**The time limit.** CRAN asks for examples, vignettes and tests to take under 10 minutes together, and its Windows
machine has run tests more than twice as slowly as its Debian one. Every `check` job reads the tests' elapsed time
from `00check.log` (`.github/scripts/check-times.sh`); on Ubuntu with R release it fails above 180 s, so a pull request
that makes the tests CRAN runs slower moves detailed tests to an `-extended.R` file or speeds them up. R CMD check
prints the time only from 10 s; below that the report says "under 0.2 min".

**Releasing.** The release pull request (version, NEWS, `cran-comments.md`) stays open while CRAN reviews; CRAN's
comments become commits on it. After CRAN accepts and the pull request is merged, start the workflow by hand: Actions,
release, Run workflow, branch `main`, and leave the commit empty (the tip of `main`) or give the accepted commit's SHA.
The workflow's logic is `.github/scripts/release-check.sh`: a commit that is not on `main`, versions or headings that
disagree, an empty NEWS section or an existing tag on another commit fail before anything is published. A re-run after
a failed release step creates the missing release from the existing tag; a re-run after success does nothing. Tags
and releases are never moved or deleted: a fix after publication gets a new version. A development version
(`X.Y.Z.9000`) is published as a pre-release, with the heading `# <package> (development version)`.

## The CI report comment

On a pull request, one comment, rewritten as each workflow finishes, sums up what CI found, in a Tests and a Code
style section. Each workflow adds one part:

- `R-CMD-check.yaml`: how many platforms passed, how long the tests took on Ubuntu with R release against the limit,
  and a table with each platform's result, test time and whole check time, in minutes
  (`.github/scripts/check-times.sh`); "not run" for a documentation-only change.
- `test-coverage.yaml`: the line coverage without the browser and snapshot tests (the extended tests included), the
  limit from `DESCRIPTION` and the difference from the latest successful run on `main`; the added `R/` lines that the job's tests don't run (a report,
  not a check: a browser test may run them, and the gate's `new_lines` step is the check); or why nothing was measured.
- `off-cran-tests.yaml`, per R version: the counts, with the tests in browser, snapshot and extended files, the failing
  and skipped tests, the slowest test files and the files much slower than on `main` (at least 25% and 10 seconds).
- `lint.yaml`: passed, or the gate steps that failed with the first line of what each found (from the gate's
  `gate.json`). lintr's findings also show inline in the pull request's "Files changed".

Under the parts, the comment lists each failed job with a link and the step it failed at. Every part that can grow
long folds (`<details>`): tables of times, lists of tests or lines, and the failed jobs; lists of failures start
open. A summary job (one that only
sums up a matrix, named in `summary_jobs` in `.github/pr-report.json`) is listed only when it failed on its own.

It looks like this (figures from a real run; the ▸ lines are folded tables):

```
## ✅ CI report: passed · `abc1234`
### Tests
✅ R CMD check (as CRAN): 6 of 6 platforms passed · tests 2.1 min on ubuntu-26.04, R release (limit 3.0 min)
   ▸ Time per platform (the tests, and the whole check)
✅ Coverage: 98.3% of R lines, without the browser and snapshot tests · limit 70% (from `DESCRIPTION`) · +0.0 points from `main` at b469250 (98.3%)
✅ Off-CRAN tests, R 4.1: 879 passed · 0 failed · 0 skipped · 28.9 min · 570 in browser files, 52 in snapshot files, 257 in extended files
   ▸ Slowest test files, and the files much slower than on `main`
✅ Off-CRAN tests, R release: 879 passed · 0 failed · 0 skipped · 19.2 min · …
### Code style
✅ Lint: passed (Air, Biome, lintr, docs in sync, spelling).
```

Each job writes its part to its job summary (on the run's page) and keeps it as an artifact; a small `report` job at the
end of each of those workflows gathers the parts of the pull request's commit into the comment
(`.github/actions/pr-report-comment`, set up in `.github/pr-report.json`). A workflow's state in the comment comes from
its jobs other than the report jobs, so a report job that GitHub cancels while it waits for another doesn't mark
passing tests as cancelled. Pull requests from forks and from Dependabot get the job summaries only: their token can't
write to the pull request. The figures from `main` are artifacts that its runs keep for 90 days; when there is none,
the comment says so. A re-run job replaces its part; when a re-run job stops before it writes one (a failed checkout,
say), the earlier attempt's part stays, and the footer's run state (failure, cancelled) is the sign.

## Shared actions

`.github/actions/` holds three composite actions with no package-specific code, so other repositories can use them:
`pr-report-part` (keeps one part of the comment), `pr-report-comment` (gathers the parts into the comment) and
`main-baseline` (downloads an artifact from the latest successful run on `main`). Each explains its inputs at the top
of its `action.yml`. The workflows name no package either: they read it from `DESCRIPTION` where they need it.
