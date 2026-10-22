#' Set a mascot's status text
#'
#' Sets the text label shown next to the mascot. Text is always shown as plain
#' text, even when supplied with [htmltools::HTML()]. With no text, the status
#' follows the shown mood.
#' @param text A non-empty string for the label (for example `"Saving..."`), or
#'   `NULL` (the default) to follow the mood.
#' @returns A `mascot_status` object. Its fields are internal; pass it on rather than reading them.
#' @family mascot helpers
#' @seealso [mascot()], [update_mascot()]
#' @export
#' @examples
#' mascot_status("Saving")
#' mascot_status()
mascot_status <- function(text = NULL) {
  with_mascot_asserts({
    checkmate::assert_string(text, min.chars = 1, null.ok = TRUE)
  })
  if (inherits(text, "html")) {
    text <- as.character(unclass(text))
  }
  structure(list(text = text), class = "mascot_status")
}

#' @export
#' @noRd
format.mascot_status <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_status")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_status <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_status")
  })
  cli::cat_line(format(x))
  invisible(x)
}
