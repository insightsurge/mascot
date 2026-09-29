#' Probe a suggested package
#'
#' @param x A number.
#' @returns A number.
#' @examples
#' probe_fn(covr::percent_coverage(list()))
#' @export
probe_fn <- function(x) {
  checkmate::assert_number(x)
  x
}
