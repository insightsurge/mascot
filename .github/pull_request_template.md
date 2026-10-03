<!-- Fill in what applies and delete the rest: a section that does not apply is deleted, never left empty.
Keep every section short. Plain words first, then the technical names. British English. No hype. -->

## In brief
<!-- For a reader with no context: one plain sentence on what this PR does and why it matters, then 3-6 bullets. -->

Closes #

## What's new
<!-- One bullet per feature. Plain words first (what a user can now do), then the function, argument or file names
and what each does. Delete if nothing is new. -->

## What's fixed
<!-- One bullet per bug. First the symptom a user saw, in plain words. Then the cause, and what changed in which
function and file. Delete if nothing is fixed. -->

## Before and after
<!-- A small table (Before | After) or two short snippets showing the difference: R code and output, a command, or
a screenshot. Delete if nothing a user can see or run has changed. -->

## Try it
<!-- Numbered scenarios a reviewer can run: the R snippet or command, then what they should see. Delete for
changes with nothing to run. -->

## Details
<!-- For reviewers who want everything: one line per file or area, saying what changed there. May be wrapped in
<details><summary>Details</summary> ... </details> when long. -->

## Not in this PR
<!-- Follow-ups (with issue numbers) and known limits. Delete if none. -->

## Checks
<!-- Only checks anyone can re-run from the repo (the gate, CI, committed test scripts). One-off manual checks go
in a short Notes line under this list, not here. -->
- [ ] The gate's `fast` mode passes (`Rscript tools/cran-gate.R`): format, docs in sync, lint, `@returns`, spelling, R CMD check 0/0/0
- [ ] The gate's `tests` mode passes (same command with `tests`): tests and coverage of at least 70%, not lower than `main`
- [ ] New behaviour has BDD-style tests (`describe()` / `it()`); Shiny behaviour has shinytest2 tests
- [ ] Every new or changed function checks its arguments with checkmate, and those checks are tested
- [ ] `NEWS.md` bullet for any user-facing change, ending with `(#issue)`
- [ ] New files in `inst/` are listed in `inst/COPYRIGHTS` and ship in the tarball (the gate's `full` mode)
- [ ] `pkgdown::build_site()` looked at in light and dark (docs, exports or examples changed)
- [ ] Known users (`docs/consumers.md`) checked; `consumer-impact` label if any may be affected
- [ ] PR labelled (type + area) for the release notes; CI green
