#' Probe a suggested package
#'
#' @param x A number.
#' @returns A number.
#' @examples\n#' probe_fn(covr::percent_coverage)\n#' @export
probe_fn <- function(x) {
  invisible(x)
  x
}
