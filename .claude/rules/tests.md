---
paths:
  - "tests/**"
---

# Tests

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`. How the tests are organised (the
four kinds of test file, their first lines, where each runs, how to run them): `tests/README.md`.

- **house:** coverage of at least 70% of lines (`Rscript tools/cran-gate.R tests`; the limit is
  `Config/cran-gate/coverage` in `DESCRIPTION`, which CI reads too; CRAN itself does not check coverage); a PR never
  lowers it. `# nocov` only for code that truly can't run in a test, with the reason beside it.
- **house:** testthat 3rd edition, BDD style: one test file per R file (`R/moods.R` → `tests/testthat/test-moods.R`),
  plus `test-moods-browser.R` for its browser tests and `test-moods-snap.R` for its snapshot tests when it has them,
  and `-extended.R` files for an example app's detailed tests and checks too slow for CRAN (the next bullets); `describe("update_mascot()", { it("changes the mood after the wiggle", { ... }) })`, with
  `describe()` naming the function or behaviour and `it()` stating the expected behaviour in plain words;
  `# Given / # When / # Then` where it helps. Cover the happy path, every checkmate assertion (a test that it fails with a clear message),
  edge cases and every bug fix.
- **house:** `expect_snapshot()` for printed output, generated HTML and error messages; review snapshot changes
  in the PR like code. Keep snapshots small (text, not images).
- **house:** `shiny::testServer()` for server logic; **shinytest2** for every behaviour a user sees (renders, mood
  change, bubble, validator, busy, placement, dismiss, light/dark): apps in `tests/testthat/apps/<name>/app.R` or a
  function passed to `AppDriver$new()`; `withr::defer(app$stop())`. Assert on values, DOM state, `data-*`
  attributes, the `role="status"` text and engine state read with `app$get_js()`; screenshots only when nothing
  else can show it.
- **house:** "do X, then Y at once": every action in a Shiny app the package ships (Copy, Download, Build, Check, a
  busy button) gets one browser test that changes something and fires the action without waiting for the server in
  between, then checks the action used the change (the rules it tests: `r-code.md`, "Shiny apps"). Example: set a
  colour picker and click Copy in one `app$run_js()` call, then expect the copied code to have the new colour. A test
  that waits for each step to settle can't catch these bugs. To widen the gap, hold back what the page sends or what
  the server answers (the studio tests' `hold_studio_inputs()` and `hold_studio_replies()`).
- **CRAN:** every shinytest2 or chromote test starts with `testthat::skip_on_cran()`,
  `testthat::skip_if_not_installed("shinytest2")` and a skip when `chromote::find_chrome()` is `NULL`. CRAN has
  asked that no package uses Chrome when tested on CRAN. CI runs them in the `off-cran-tests` job (`NOT_CRAN: true`).
- **house:** the tests CRAN skips live in files of their own, and nothing else does: browser tests (shinytest2,
  chromote, or any helper that starts Chrome) in `test-<name>-browser.R`, snapshot tests (`expect_snapshot()` skips
  itself on CRAN) in `test-<name>-snap.R`, and the detailed tests of the example apps (the studio and its views, and
  any app added later) and checks too slow for CRAN (such as comparing the stored built-in characters with a fresh
  check) in `test-<name>-extended.R`. A browser or extended file starts with its skip, as its first
  expression, so CRAN skips the whole file before any of its code runs: `skip_without_chrome()` or
  `skip_unless_extended()` (`helper-extended.R`: the extended tests run where `NOT_CRAN` is true or
  `EXTENDED_TESTS` is `"true"`). A snapshot file doesn't: skipped as a whole, it reports no snapshots and
  testthat deletes their saved files, so `expect_snapshot()` skips each test instead. The `off-cran-tests` job runs exactly those files and fails on any skip; R CMD
  check runs the rest. `test-helper-layout.R` fails when a test is in the wrong file or a file doesn't start with its
  skip (an argument check inside `expect_error()` may stay in the plain file: it fails before Chrome starts). A
  helper used only by one file's tests stays at the top of that file; one that several files need goes in
  `helper-<name>.R`, which loads for every test file.
- **house:** CRAN runs the package's own tests in full and only a smoke test of each example app (#568): its exported
  function's argument checks, each view builds, the page draws once with no duplicate ids, and one server update with
  its generated code. Everything else about an app (every control, palette, guide page and server scenario) goes in
  its `-extended.R` file. R CMD check on CI fails when the tests take longer than 180 s on Ubuntu with R release
  (`R-CMD-check.yaml`), so a pull request that makes them slower moves tests or speeds them up. The studio's main
  view is the exception: building its views and drawing its page take several seconds, so CRAN runs only
  `mascot_studio()`'s argument checks (`test-studio.R`), and its smoke test is in `test-studio-extended.R` (#563).
- **CRAN:** tests use only declared packages and guard Suggests (`skip_if_not_installed()`); no network; files go
  to `withr::local_tempdir()`; nothing is left behind; at most 2 cores (`tests/testthat.R` lowers `getOption("Ncpus")`,
  which testthat reads first, to two when a session has it higher).
- **house:** keep JS logic small and push decisions into R, where they can be unit-tested.
- **house:** each test file runs on its own: testthat runs the files in two processes at once
  (`Config/testthat/parallel`), in any order, so a file never relies on what another file set up or left behind.
