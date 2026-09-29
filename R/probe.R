#' Probe the mascott
#'
#' @param x A number.
#' @returns A number.
#' @export
probe_fn <- function(x) {
  checkmate::assert_number(x)
  x
}
