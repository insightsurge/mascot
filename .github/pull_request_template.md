<!-- Keep the sections that apply and delete the rest. Keep each short. British English; plain words first.
Use public examples and made-up data. Remove private data, credentials, machine paths and private links from text,
output and screenshots. Describe the change and the checks, without tool credits or conversation links.
Read AGENTS.md and the matching .claude/rules/ files; CLAUDE.md points to the same contributor rules.
Contributors open issues and work on them. The package creator decides versions, releases and merges. -->

## In brief
<!-- One plain sentence on what changes and why, then a few bullets for a reader with no context. -->

Closes #

<!-- If this is stacked on another PR, name that PR and its base branch here. -->

## What's new
<!-- One bullet per capability: what a user can do, then the function, argument or file names. Delete if none. -->

## What's fixed
<!-- The symptom, its cause and the fix, in plain words, then the relevant function or file names. Delete if none. -->

## Before and after
<!-- A small example, table or screenshot showing the change. For instructions, a short wording example is enough.
Delete if nothing a user can see or run changes. -->

## Try it
<!-- Numbered scenarios: the R snippet or command to run, then what should happen.
For a visual change, give the browser and version and steps with reduced motion on and off.
Delete if nothing can be tried. -->

## Details
<!-- Only details needed to review the change. Include any changed defaults, compatibility or deprecation plan.
Delete if the sections above cover it. -->

## Not in this PR
<!-- Known limits and follow-ups, with public issue numbers where available. Delete if none. -->

## Checks
<!-- For each command you ran, report its result, exit code and any FAIL or SKIP summary lines.
Name checks you did not run and why. Do not mark an unrun check as passed.
Only repeatable checks belong in the table; one-off observations go in Notes below.
Run Rscript tools/cran-gate.R (fast mode) before every commit: format, docs in sync, lint, returns, spelling, pkgdown index,
R CMD check without tests: 0 errors, 0 warnings, 0 notes.
Rscript tools/cran-gate.R tests is required before a PR touching R/ or tests/: coverage at least 70%,
not lower than main, and every added runnable R line covered. PARTIAL runs are not merge evidence;
exit code 3 needs the package creator's decision. Merge evidence is a tests or full run exiting 0.
See tools/README.md.
The package creator handles release checks, including full mode; a contribution does not require a release. -->

| Command | Result and exit code, or not run and why |
| --- | --- |
| `Rscript tools/cran-gate.R` | |
| `Rscript tools/cran-gate.R tests` (if `R/` or `tests/` changed) | |

<!-- Keep applicable items. Check only completed items; leave pending work unchecked.
For labels you cannot apply, list the suggested labels in Notes so the package creator can apply them. -->

- [ ] The linked issue's done-when checklist is met.
- [ ] One type label and the relevant area labels are set or suggested in Notes; CI is green.
- [ ] I have reviewed the whole diff, understand the changes and can explain the checks reported above.
- [ ] User-facing changes have a `NEWS.md` bullet ending with `(#issue)`; release headings and versions are left to the package creator.
- [ ] Behaviour changes have BDD tests (`describe()` / `it()`); visible Shiny changes have shinytest2 tests. New or changed R argument checks use checkmate and are tested.
- [ ] Exports or argument changes include roxygen updates and the studio controls, control map, code builders, guide data and any affected UI/server changes in this PR; the changed behaviour has been tried in the studio.
- [ ] Known users in `docs/consumers.md` have been checked where affected; the PR records each result and has `consumer-impact` where needed. Public API changes have `breaking-change`, a NEWS entry and a deprecation plan where required by `AGENTS.md`.
- [ ] JS/CSS changes keep status text and honour reduced motion; the changed visual behaviour has been tried with reduced motion on and off.
- [ ] New `inst/` files have the required licence and `inst/COPYRIGHTS` entries; their presence in the built tarball has been checked using the gate's `full` mode.
- [ ] Docs, exports or examples changed: `Rscript tools/build-site.R` and `pkgdown::check_pkgdown()` have been run locally, and the site has been viewed in light and dark. Site CI runs from `main` only.
- [ ] Gate or formatter configuration changed: `Rscript tools/test-cran-gate.R` ends with `All probes behaved as expected`; new checks have a probe.
- [ ] Every text that describes the changed behaviour is updated (help pages, articles, NEWS, studio, workflow comments, `tools/README.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.github/CONTRIBUTING.md`), and public instructions hold only contributor-facing guidance. Search terms used for the old wording: 

Notes: <!-- One-off observations, browser/OS versions, screenshots, studio and affected-user results,
suggested labels, or spelling words needing the package creator's agreement. Do not add WORDLIST entries yourself. -->
