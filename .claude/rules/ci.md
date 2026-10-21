---
paths:
  - ".github/**"
  - "tools/cran-gate.R"
  - "tools/test-cran-gate.R"
---

# CI and the gate

Reasons and sources: `docs/standards.md`.

- The gate (`tools/cran-gate.R`) is the single source of the lint steps: CI's lint job runs it in `lint` mode.
  Change a check in the script, not in a workflow. The script is generic and self-contained (other packages copy it
  as it is): nothing mascot-specific goes into it;
  mascot's choices live in `DESCRIPTION` (`Config/cran-gate/*`), `air.toml`, `.lintr` and `biome.json`.
- Workflows and what each blocks:
  - `R-CMD-check.yaml`: `--as-cran`. **Pull requests run Ubuntu (R release) only; the full matrix (macOS/Windows
    release, Ubuntu devel/release/oldrel-1) runs on pushes to `main`, every Monday and on demand** (run it by hand
    on a PR branch before a release or for a platform-sensitive change); fails on any note
    (`error-on: '"note"'`); mimics CRAN (`NOT_CRAN` unset, so Chrome tests skip); only the remote CRAN-incoming
    checks are off.
  - `test-coverage.yaml`: tests with `NOT_CRAN: true` (Chrome tests run) and a 70% line-coverage gate (the limit is read from `DESCRIPTION`); no Codecov
    while the repo is private.
  - `lint.yaml`: the gate's lint mode with Air and Biome at pinned versions (keep them equal to the local installs
    and `biome.json`'s schema).
  - `check-no-suggests.yaml`: R CMD check with hard dependencies only (CRAN checks without Suggests too).
  - `pkgdown.yaml`: `check_pkgdown()` and the site build (`tools/build-site.R`), uploaded as an artifact. **Built from
    `main` only, never on pull requests** (a rule, #127: the site will need a private theme package that outside
    contributors' pull requests can't install); no deploy
    until the repo is public.
  - `gate-self-test.yaml`: the gate's self-test (`test-cran-gate.R all`), only when the gate, its self-test, `.lintr`,
    `air.toml` or `biome.json` change (and on demand); same Air and Biome versions as `lint.yaml`.
  - `gitleaks.yml` (secrets), `release.yml` (tag and GitHub release from `NEWS.md`), dependabot (action updates).
- Every workflow: `permissions: read-all` (or narrower), a `concurrency` group with `cancel-in-progress`, Ubuntu
  pinned (`ubuntu-26.04`), actions by major tag (dependabot keeps them current), third-party actions outside
  `actions/` and `r-lib/` by commit SHA with a version comment.
- **Temporary while the repo is private (#113):** the slim PR matrix, and the `paths-ignore` filters are workarounds for
  limited Actions minutes. When the repo goes public (before the CRAN submission) they are
  removed and every PR runs all five platforms again (#115). Until then, minutes are limited (macOS counts 10x,
  Windows 2x): PRs that only touch project docs, agent files or templates skip the R jobs (`paths-ignore`). Keep new jobs on Ubuntu unless the platform is the point.
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the founder.
- A new check goes into the gate first, with a probe in `test-cran-gate.R` (same folder) that plants a defect and
  expects that step to FAIL, then runs in CI. After changing the gate, `.lintr`, `air.toml` or `biome.json`, run
  `Rscript tools/test-cran-gate.R` (a few minutes: the static probes copy mascot, the heavy ones use a tiny
  generated package; `unit` alone takes seconds, and `heavy tests,coverage` runs only the probes for those steps): it works on
  copies in `tempdir()` and must end with "All probes behaved as expected". Its "copies in step" check fails while the
  skill's copy of the gate differs from this one.
- How CI's jobs map to the gate: `lint.yaml` is `lint`; `R-CMD-check` is `check_full`; `test-coverage` is `tests`;
  `check-no-suggests` is `nosuggests`. When CI cannot run (Actions minutes used up), run these modes locally instead.
- PRs that only touch `.claude/` skip the lint and R jobs (`paths-ignore`). A change to the gate (`tools/`) runs
  them, plus `gate-self-test.yaml`, whose clean-copy probe runs the gate on the package.

## Character visual harness (#284)
- `engine-visual.yml` is mascot-specific and separate from the generic CRAN gate.
- Founder decision (2026-10-15): manual `workflow_dispatch` only while private (#113), on `ubuntu-24.04`,
  with a pre-provisioned Ubuntu 24.04 x86_64 image pinned by digest. This is an explicit exception to the usual
  `ubuntu-26.04` host. Do not trigger it until the founder authorises spending minutes.
- Missing/uncommitted/different canonical profile or baselines fail; no automatic regeneration or promotion.
- Job artifacts are review transport only: retain approved content-addressed archives on `design-assets`.
- Before public release (#115), add the reviewed engine/character PR path triggers and required visual policy.
  Existing checks are never weakened. Provisional macOS evidence cannot satisfy canonical acceptance.
