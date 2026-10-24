---
paths:
  - ".github/**"
  - "tools/cran-gate.R"
  - "tools/test-cran-gate.R"
---

# CI and the gate

Reasons and sources: `docs/standards.md`. What each workflow runs, and the gate mode that reproduces it locally:
`tools/README.md` ("The gate and CI").

- The gate (`tools/cran-gate.R`) is the single source of the lint steps: CI's lint job runs it in `lint` mode, and
  the check-no-suggests job runs it in `nosuggests` mode.
  Change a check in the script, not in a workflow. The script is generic and self-contained (other packages copy it
  as it is): nothing mascot-specific goes into it; mascot's choices live in `DESCRIPTION` (`Config/cran-gate/*`),
  `air.toml`, `.lintr` and `biome.json`.
- R-CMD-check fails on any note (`error-on: '"note"'`) and mimics CRAN (`NOT_CRAN: false`, so the browser tests
  skip; `setup-r` would set it to true); only the remote CRAN-incoming checks are off. The tests CRAN skips (browser and
  snapshot tests, in `test-*-browser.R` and `test-*-snap.R`) run in `browser-tests.yaml` on Linux with R release
  and R 4.1 (its summary job, `browser-tests`, is one stable check name for both). The coverage job runs the
  tests without Chrome (`NOT_CRAN: false`) and reads the coverage limit from `DESCRIPTION` (on a pull request, the higher of the base branch's and the PR's own, so a pull request cannot lower the limit by editing `DESCRIPTION`; changes to this workflow are reviewed like any other change). Keep
  `lint.yaml`'s and `gate-self-test.yaml`'s Air and Biome versions equal to the local installs and `biome.json`'s
  schema.
- The site is built **from `main` only, never on pull requests** (a rule, #127: a site build may need packages that
  outside contributors' pull requests can't install). It deploys from `main` to GitHub Pages
  (#115).
- Every workflow: the least permissions it needs (`permissions: read-all`, or only the write scopes its jobs use), a
  `concurrency` group (with `cancel-in-progress`, except where a cancelled run on `main` would leave pushed commits
  unscanned or a release half done), a `timeout-minutes` on every job (a few times its longest recent run), Ubuntu pinned (`ubuntu-26.04`), actions by major tag (dependabot keeps them current), third-party actions
  outside `actions/` and `r-lib/` by commit SHA with a version comment.
- The CI report comment (`tools/README.md`): the `report` jobs in `test-coverage.yaml`, `browser-tests.yaml` and
  `lint.yaml` are the only jobs with `pull-requests: write`. They run no R and no code from the parts, only the
  composite actions in `.github/actions/`, which stay generic (no mascot code: they are to move to a shared
  repository, #522). A new part: write it with `pr-report-part`, add its workflow to `.github/pr-report.json` and give
  that workflow a `report` job like the others. No `workflow_run` workflow: it runs only from `main`, so the pull
  request that changes it can't try it.
- Keep new jobs on Ubuntu unless the platform is the point (macOS minutes count 10x, Windows 2x).
- The tests run in two processes at once (`Config/testthat/parallel: true` in `DESCRIPTION`; two is testthat's
  default and CRAN's limit). R CMD check and the coverage job get two because their tests run without the site
  profile; `browser-tests.yaml` sets setup-r's `Ncpus: 2`, because setup-r's default of 1 means one process. Never more
  than two. R CMD check notes CPU time over 2.5 times elapsed time, as CRAN does
  (`_R_CHECK_TEST_TIMING_CPU_TO_ELAPSED_THRESHOLD_`).
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the package creator.
- A new check goes into the gate first, with a probe in `test-cran-gate.R` (same folder) that plants a defect and
  expects that step to FAIL, then runs in CI. After changing the gate, `.lintr`, `air.toml` or `biome.json`, run
  `Rscript tools/test-cran-gate.R` (a few minutes: the static probes copy mascot, the heavy ones use a tiny
  generated package; `unit` alone takes seconds, and `heavy tests,coverage` runs only the probes for those steps): it
  works on copies in `tempdir()` and must end with "All probes behaved as expected". Its "copies in step" check runs
  only when `CRAN_GATE_COPY_DIR` names another copy of the gate to compare with.
- The gate's `new_lines` step (every added `R/` line run by a test) has no CI job: it needs the branch's base, which a
  shallow CI checkout lacks, so it SKIPs there and runs locally.
