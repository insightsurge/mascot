---
paths:
  - ".github/**"
  - "tools/cran-gate.R"
  - "tools/test-cran-gate.R"
---

# CI and the gate

Reasons and sources: `docs/standards.md`. What each workflow runs, and the gate mode that reproduces it locally:
`tools/README.md` ("The gate and CI").

- The gate (`tools/cran-gate.R`) is the single source of the lint steps: CI's lint job runs it in `lint` mode.
  Change a check in the script, not in a workflow. The script is generic and self-contained (other packages copy it
  as it is): nothing mascot-specific goes into it; mascot's choices live in `DESCRIPTION` (`Config/cran-gate/*`),
  `air.toml`, `.lintr` and `biome.json`.
- R-CMD-check fails on any note (`error-on: '"note"'`) and mimics CRAN (`NOT_CRAN` unset, so Chrome tests skip);
  only the remote CRAN-incoming checks are off. The coverage job runs the tests with `NOT_CRAN: true` and reads the
  coverage limit from `DESCRIPTION` (on a pull request, the base branch's, so a PR can't lower its own limit). Keep
  `lint.yaml`'s and `gate-self-test.yaml`'s Air and Biome versions equal to the local installs and `biome.json`'s
  schema.
- The site is built **from `main` only, never on pull requests** (a rule, #127: a site build may need packages that
  outside contributors' pull requests can't install). While the repo is private it deploys from `main` to a
  temporary host; GitHub Pages takes over when it goes public (#115).
- Every workflow: the least permissions it needs (`permissions: read-all`, or only the write scopes its jobs use), a
  `concurrency` group (with `cancel-in-progress`, except where a cancelled run on `main` would leave pushed commits
  unscanned or a release half done), a `timeout-minutes` on every job (a few times its longest recent run), Ubuntu pinned (`ubuntu-26.04`), actions by major tag (dependabot keeps them current), third-party actions
  outside `actions/` and `r-lib/` by commit SHA with a version comment.
- Keep new jobs on Ubuntu unless the platform is the point (macOS minutes count 10x, Windows 2x).
- Never `continue-on-error`, never weaken a check to get green: fix the cause, or ask the package creator.
- A new check goes into the gate first, with a probe in `test-cran-gate.R` (same folder) that plants a defect and
  expects that step to FAIL, then runs in CI. After changing the gate, `.lintr`, `air.toml` or `biome.json`, run
  `Rscript tools/test-cran-gate.R` (a few minutes: the static probes copy mascot, the heavy ones use a tiny
  generated package; `unit` alone takes seconds, and `heavy tests,coverage` runs only the probes for those steps): it
  works on copies in `tempdir()` and must end with "All probes behaved as expected". Its "copies in step" check runs
  only when `CRAN_GATE_COPY_DIR` names another copy of the gate to compare with.
- The gate's `new_lines` step (every added `R/` line run by a test) has no CI job: it needs the branch's base, which a
  shallow CI checkout lacks, so it SKIPs there and runs locally.
