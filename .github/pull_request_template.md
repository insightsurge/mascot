## In brief
<!-- For a reader with no context: one plain sentence on what this PR does and why it matters, then 3-6 bullets on
what changes for users or contributors. Plain words first, with a light technical touch (a file, a command) where
it helps. No jargon without a short explanation. -->

Closes #

## What changed

## Checks
<!-- Only checks anyone can re-run from the repo (the gate, CI, committed test scripts). One-off manual checks go
in a short Notes line under this list, not here. -->
- [ ] `Rscript tools/cran-gate.R` (fast) passes: format, docs in sync, lint, `@returns`, spelling, R CMD check 0/0/0
- [ ] `Rscript tools/cran-gate.R tests` passes: tests and coverage of at least 90%, not lower than `main`
- [ ] New behaviour has BDD-style tests (`describe()` / `it()`); Shiny behaviour has shinytest2 tests
- [ ] Every new or changed function checks its arguments with checkmate, and those checks are tested
- [ ] `NEWS.md` bullet for any user-facing change, ending with `(#issue)`
- [ ] New files in `inst/` are listed in `inst/COPYRIGHTS` and ship in the tarball (`tools/cran-gate.R full`)
- [ ] `pkgdown::build_site()` looked at in light and dark (docs, exports or examples changed)
- [ ] Known users (`docs/consumers.md`) checked; `consumer-impact` label if any may be affected
- [ ] PR labelled (type + area) for the release notes; CI green
