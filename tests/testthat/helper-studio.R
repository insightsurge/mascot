# The optional packages a view of the studio app needs to build its page: bslib for every view, and knitr for the
# studio and examples views (the studio's page checks for its guide pages). The theme view does not need knitr.
skip_without_studio_packages <- function(view = "studio") {
  checkmate::assert_choice(view, c("studio", "examples", "theme"))
  testthat::skip_if_not_installed("bslib")
  if (view != "theme") {
    testthat::skip_if_not_installed("knitr")
  }
  invisible(TRUE)
}
