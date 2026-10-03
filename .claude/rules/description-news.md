---
paths:
  - "DESCRIPTION"
  - "NEWS.md"
  - "cran-comments.md"
---

# DESCRIPTION, NEWS.md and cran-comments.md

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

## DESCRIPTION
- **CRAN:** Title in Title Case, no final full stop, not "A package for" or "in R"; Description of two or more
  sentences that doesn't start with the package name or "This package"; software, package and API names in single
  quotes ('Shiny', 'Quarto', 'JavaScript'); functions as `fn()`; URLs in `<...>`.
- **CRAN:** `Authors@R` names every copyright holder: Harsh Verma (`aut`, `cre`, `cph`), and one `cph` entry with a
  `comment` for each third party whose files ship (for example the font projects), plus `ctb` for contributors.
- **house:** `Language: en-GB` (British spelling in the docs); `License: MIT + file LICENSE` (the CRAN stub, never
  edited by hand); `Imports` minimal; version `x.y.z.9000` on `main`.

## NEWS.md (tidyverse style; the source of each GitHub release)
- **house:** every user-facing change adds its bullet in the same PR; internal changes (CI, refactors, tests) are
  left out unless users notice them.
- **CRAN:** R CMD check needs a version number in at least one heading, so **until 0.1.0** each heading is a
  development version (`# mascot 0.0.0.9001`, `.9002`, ...; the founder bumps it as features land, with `Version` in
  `DESCRIPTION`), and the 0.1.0 release PR collects them under `# mascot 0.1.0` by hand. After that:
  `# mascot (development version)` at the top; `usethis::use_version()` turns it into `# mascot x.y.z`.
  Never edit a released section except to fix a typo.
- **house:** one change per bullet, written for users, present tense, starting with the function or feature,
  ending with the issue or PR number: `` `updateMascot()` gains a `message` argument for a speech bubble (#30).``
  Credit outside contributors (`(@user, #123)`). With more than a handful of bullets, group under
  `## Breaking changes` (first, saying what to change), `## New features`, `## Minor improvements and fixes`,
  alphabetical by function within a group.

## cran-comments.md (build-ignored)
- **CRAN:** test environments, "0 errors | 0 warnings | 1 note" (the "New submission" note, explained), any
  acronym (GxP) explained, reverse dependencies (none for a first release).
