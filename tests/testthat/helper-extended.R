# The detailed tests of the example apps (every control, palette, guide page and server scenario) live in
# `test-<name>-extended.R` files, which start with this skip; each app keeps a short smoke test in its plain file.
# They run wherever NOT_CRAN is true (the gate, devtools::test(), the off-CRAN job) or MASCOT_EXTENDED_TESTS is
# "true" (the coverage job and the weekly R CMD check, which keep NOT_CRAN false so the browser tests still skip).
# CRAN and R CMD check skip them, so the time CRAN spends on the tests does not grow with the apps.
skip_unless_extended <- function() {
  if (!identical(Sys.getenv("MASCOT_EXTENDED_TESTS"), "true")) {
    testthat::skip_on_cran()
  }
}
