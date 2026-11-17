---
paths:
  - ".github/**"
---

# CI and the gate

Reasons and sources: `docs/standards.md`. What each workflow runs and when, which test files run where, the gate mode
that reproduces each one locally and the CI report comment: `.github/workflows/README.md`. The gate: `tools/README.md`.

- The checks and the quality gate are launchR's (<https://github.com/insightsurge/launchR>). Each workflow here except
  `release.yml` is a short caller that runs one of launchR's reusable workflows at a release tag (`@vX.Y.Z`, the same
  tag in every caller). A caller says only when and where its check runs: the `on:` block, and `platforms`,
  `timeout-minutes`, `test-time-limit` and `ci-report` under `with:`. What a check does, and every step of the gate,
  is changed in launchR, never in a copy here; mascot's choices live in `DESCRIPTION` (`Config/quality-gate/*`),
  `air.toml`, `.lintr` and `biome.json`.
- R-CMD-check fails on any note and mimics CRAN (`NOT_CRAN: false`, so the browser, snapshot and extended tests skip).
  On Ubuntu with R release it also fails when the tests take longer than 180 s. `r-cmd-check-extended.yaml` (weekly
  and on demand, a workflow of its own so it can't turn R-CMD-check's badge red) runs R CMD check on macOS (R release)
  and Windows (R release and 4.1) with `EXTENDED_TESTS: true`. The tests CRAN skips (browser, snapshot and extended
  tests, in `test-*-browser.R`, `test-*-snap.R` and `test-*-extended.R`) run in `full-tests.yaml` on Linux with R
  release and R 4.1. The coverage job runs the tests without Chrome (`NOT_CRAN: false`, `EXTENDED_TESTS: true`) and
  reads the coverage limit from `DESCRIPTION` (on a pull request, the higher of the base branch's and the PR's own).
- Pull requests trigger every check with no branch filter, so a pull request stacked on another branch is checked too.
- The site is built **from `main` only, never on pull requests** (a rule, #127: a site build may need packages that
  outside contributors' pull requests can't install). It deploys from `main` to GitHub Pages (#115).
- Every caller: the least permissions it needs (the write scopes only where launchR's jobs ask for them: the CI
  report needs `pull-requests: write`, the site `pages: write` and `id-token: write`) and a `concurrency` group (with
  `cancel-in-progress` for pull requests only). A `timeout-minutes` of 0 keeps launchR's default; set a number where
  mascot's runs are longer.
- `release.yml` is mascot's own. It runs only when started by hand on `main` (never on merge or push: a published tag
  can't move, and CRAN may ask for changes after a merge). Its checks and the tag are in
  `.github/scripts/release-check.sh`; after changing either, run `bash .github/scripts/test-release-check.sh`
  (throwaway repositories, no network). Checkout there keeps no credentials; only the release job has
  `contents: write`. Every job has a `timeout-minutes`, Ubuntu is pinned, actions go by major tag and third-party
  actions by commit SHA with a version comment.
- Keep new checks on Ubuntu unless the platform is the point (macOS minutes count 10x, Windows 2x), as in
  `r-cmd-check-extended.yaml`.
- The tests run in two processes at once (`Config/testthat/parallel: true` in `DESCRIPTION`; two is testthat's
  default and CRAN's limit), and `tests/testthat.R` lowers a higher `Ncpus` to two. Never more than two. R CMD check
  notes CPU time over 2.5 times elapsed time, as CRAN does (`_R_CHECK_TEST_TIMING_CPU_TO_ELAPSED_THRESHOLD_`).
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the package creator.
- A new check, or a fix to one, goes to launchR first (an issue there), then reaches mascot when the callers move to
  the release that has it. Dependabot proposes that move for minor and major releases.
- The gate's `new_lines` step (every added `R/` line run by a test) has no CI job: it needs the branch's base, which a
  shallow CI checkout lacks, so it runs locally. The coverage part of the CI report still lists the added `R/` lines
  the coverage job's tests don't run, as information.
