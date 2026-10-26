# The skip every test-<name>-extended.R file starts with (tests/README.md): the extended tests run where NOT_CRAN is
# true or EXTENDED_TESTS is "true", and skip on CRAN and in R CMD check.
skip_unless_extended <- function() {
  if (!identical(Sys.getenv("EXTENDED_TESTS"), "true")) {
    testthat::skip_on_cran()
  }
}
