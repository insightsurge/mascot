#' Probe untested code
#'
#' @param x A number.
#' @returns A number.
#' @export
probe_fn <- function(x) {
  checkmate::assert_number(x)
  y <- x + 1
  z <- y * 2
  w <- z - 3
  w
}
