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

# Passes when no id appears twice in the page `html`, naming each one that does. bslib numbers every tab set with a
# random number from 1000 to 9999 and builds its tab and pane ids from it (`tab-4821-1`); the number comes from shiny's
# own random stream, so set.seed() does not fix it. Two tab sets on one page then share those ids about once in 9,000
# builds although the page is fine, so ids of that form are left out; every other id on the page is checked.
expect_unique_ids <- function(html) {
  checkmate::assert_string(html)
  ids <- sub('^ id="(.*)"$', "\\1", regmatches(html, gregexpr(' id="[^"]+"', html))[[1]])
  ids <- ids[!grepl("^tab-[0-9]{4}-[0-9]+$", ids)]
  duplicates <- unique(ids[duplicated(ids)])
  testthat::expect(
    length(duplicates) == 0L,
    sprintf("These ids appear more than once: %s.", paste(duplicates, collapse = ", "))
  )
  invisible(html)
}
