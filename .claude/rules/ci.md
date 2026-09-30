---
paths:
  - ".github/**"
  - "tools/cran-gate.R"
  - "tools/test-cran-gate.R"
---

# CI and the gate

Reasons and sources: `docs/standards.md`.

- The gate (`tools/cran-gate.R`, skill `/cran-gate`) is the single source of the lint steps: CI's lint job runs
  `Rscript tools/cran-gate.R lint`. Change a check in the script, not in a workflow.
- Workflows and what each blocks:
  - `R-CMD-check.yaml`: `--as-cran`. **Pull requests run Ubuntu (R release) only; the full matrix (macOS/Windows
    release, Ubuntu devel/release/oldrel-1) runs on pushes to `main`, every Monday and on demand** (run it by hand
    on a PR branch before a release or for a platform-sensitive change); fails on any note
    (`error-on: '"note"'`); mimics CRAN (`NOT_CRAN` unset, so Chrome tests skip); only the remote CRAN-incoming
    checks are off.
  - `test-coverage.yaml`: tests with `NOT_CRAN: true` (Chrome tests run) and a 90% line-coverage gate; no Codecov
    while the repo is private.
  - `lint.yaml`: the gate's lint mode with Air and Biome at pinned versions (keep them equal to the local installs
    and `biome.json`'s schema).
  - `check-no-suggests.yaml`: R CMD check with hard dependencies only (CRAN checks without Suggests too).
  - `pkgdown.yaml`: `check_pkgdown()` and the site build (`tools/build-site.R`), uploaded as an artifact; no deploy
    until the repo is public.
  - `gate-self-test.yaml`: `Rscript tools/test-cran-gate.R all`, only when the gate, its self-test, `.lintr`,
    `air.toml` or `biome.json` change (and on demand); same Air and Biome versions as `lint.yaml`.
  - `gitleaks.yml` (secrets), `release.yml` (tag and GitHub release from `NEWS.md`), dependabot (action updates).
- Every workflow: `permissions: read-all` (or narrower), a `concurrency` group with `cancel-in-progress`, Ubuntu
  pinned (`ubuntu-26.04`), actions by major tag (dependabot keeps them current), third-party actions outside
  `actions/` and `r-lib/` by commit SHA with a version comment.
- **Temporary while the repo is private (#113):** the slim PR matrix, the `paths-ignore` filters and the site's path
  filter are workarounds for limited Actions minutes. When the repo goes public (before the CRAN submission) they are
  removed and every PR runs all five platforms again (#115). Until then, minutes are limited (macOS counts 10x,
  Windows 2x): PRs that only touch project docs, agent files or templates skip the R jobs (`paths-ignore`), and the
  site builds only when something it shows changes. Keep new jobs on Ubuntu unless the platform is the point.
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the founder.
- A new check goes into the gate first, with a probe in `tools/test-cran-gate.R` that plants a defect and expects
  that step to FAIL, then runs in CI. After changing the gate, `.lintr`, `air.toml` or `biome.json`, run
  `Rscript tools/test-cran-gate.R` (about a minute today; `static` alone takes seconds): it works on copies
  in `tempdir()` and must end with "All probes behaved as expected".
