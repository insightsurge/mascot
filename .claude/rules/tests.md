---
paths:
  - "tests/**"
---

# Tests

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **house:** coverage of at least 70% of lines (`Rscript tools/cran-gate.R tests`; the limit is
  `Config/cran-gate/coverage` in `DESCRIPTION`, which CI reads too; CRAN itself does not check coverage); a PR never
  lowers it. `# nocov` only for code that truly can't run in a test, with the reason beside it.
- **house:** testthat 3rd edition, BDD style: one test file per R file (`R/moods.R` → `tests/testthat/test-moods.R`);
  `describe("update_mascot()", { it("changes the mood after the wiggle", { ... }) })`, with `describe()` naming the
  function or behaviour and `it()` stating the expected behaviour in plain words; `# Given / # When / # Then`
  where it helps. Cover the happy path, every checkmate assertion (a test that it fails with a clear message),
  edge cases and every bug fix.
- **house:** `expect_snapshot()` for printed output, generated HTML and error messages; review snapshot changes
  in the PR like code. Keep snapshots small (text, not images).
- **house:** `shiny::testServer()` for server logic; **shinytest2** for every behaviour a user sees (renders, mood
  change, bubble, validator, busy, placement, dismiss, light/dark): apps in `tests/testthat/apps/<name>/app.R` or a
  function passed to `AppDriver$new()`; `withr::defer(app$stop())`. Assert on values, DOM state, `data-*`
  attributes, the `role="status"` text and engine state read with `app$get_js()`; screenshots only when nothing
  else can show it.
- **CRAN:** every shinytest2 or chromote test starts with `testthat::skip_on_cran()`,
  `testthat::skip_if_not_installed("shinytest2")` and a skip when `chromote::find_chrome()` is `NULL`. CRAN has
  asked that no package uses Chrome when tested on CRAN. CI runs them in the `browser-tests` job (`NOT_CRAN: true`).
- **CRAN:** tests use only declared packages and guard Suggests (`skip_if_not_installed()`); no network; files go
  to `withr::local_tempdir()`; nothing is left behind; at most 2 cores.
- **house:** keep JS logic small and push decisions into R, where they can be unit-tested.
