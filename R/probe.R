#' Probe untested code
#'
#' @param x A number.
#' @returns A number.
#' @export
probe_fn <- function(x) {
  checkmate::assert_number(x)
  y <- x + 1\n  z <- y * 2\n  w <- z - 3\n  w
}
