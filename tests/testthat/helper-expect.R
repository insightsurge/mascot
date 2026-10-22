# Passes when `object` is within `within` of `expected`, an absolute distance in the values' own units (pixels, alpha
# levels). expect_equal(tolerance =) is relative once the expected value is larger than the tolerance: there,
# expect_equal(gap, 8, tolerance = 1) accepts any gap between 0 and 16, while expect_near(gap, 8, 1) accepts 7 to 9.
expect_near <- function(object, expected, within) {
  checkmate::assert_numeric(object, any.missing = FALSE, min.len = 1L)
  checkmate::assert_numeric(expected, any.missing = FALSE, len = length(object))
  checkmate::assert_number(within, lower = 0, finite = TRUE)
  label <- paste(deparse(substitute(object), width.cutoff = 500L), collapse = " ")
  testthat::expect(
    all(abs(object - expected) <= within),
    sprintf(
      "%s is %s, not within %s of %s.",
      label,
      paste(format(object, digits = 7L), collapse = ", "),
      format(within),
      paste(format(expected, digits = 7L), collapse = ", ")
    )
  )
  invisible(object)
}
