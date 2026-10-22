---
paths:
  - "R/**/*.R"
  - "man/**"
  - "NAMESPACE"
---

# Documentation (roxygen2)

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **house:** roxygen2 with markdown (`Roxygen: list(markdown = TRUE)`); never edit `man/` or `NAMESPACE` by hand.
  Run `devtools::document()` after any roxygen change and commit `man/` and `NAMESPACE` with it (the gate's
  `docs` step fails when they are stale).
- **CRAN (reviewers):** every exported function has `@returns` (the gate's `value` step checks it), including
  functions called for their side effects ("Called for its side effect; returns `x` invisibly.").
- **CRAN:** every export has `@examples` that run offline in a few seconds. Apps and anything that opens a browser
  go under `@examplesIf interactive()`; no `\dontrun{}` for code that can run; `\donttest{}` only for slow but
  correct examples, with a comment. Examples that write files use `tempdir()` and clean up.
- **CRAN:** `@param` for every argument (R CMD check warns otherwise); say the type, the default's meaning and what
  `NULL` means.
- **house:** internal functions use `@noRd` (documented in the source, no help page). Reuse parameter docs with
  `@inheritParams`; group related exports with `@family`; link with `[fn()]`.
- **house:** the package-level page lives in `R/mascot-package.R`, with the only `@importFrom` lines.
- **CRAN:** titles in sentence case without a final full stop; software names in single quotes in DESCRIPTION
  ('Shiny', 'Quarto'), and in backticks or links in Rd.
- **house:** wording: plain, British English; "built for GxP work", never "validated" or "GxP compliant"; never an
  employer, client or internal system; no unmeasured numbers. New words the spell check doesn't know go into
  `inst/WORDLIST` only after the package creator agrees they're real.
