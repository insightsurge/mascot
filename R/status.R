#' Set a mascot's status text
#'
#' Displays an accessible text label next to the mascot. Text is always shown
#' as plain text (HTML tags are escaped). When no custom text is supplied (`NULL`),
#' the status text automatically shows the current mood name.
#' @param text A short string for the label (for example `"Saving..."`), or `NULL`
#'   (the default) to follow the current mood.
#' @returns A `mascot_status` object with one `text` element, which may be `NULL`.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_status("Saving")
#' mascot_status()
mascot_status <- function(text = NULL) {
  checkmate::assert_string(text, min.chars = 1, null.ok = TRUE)
  if (inherits(text, "html")) {
    text <- as.character(unclass(text))
  }
  structure(list(text = text), class = "mascot_status")
}

#' @export
#' @noRd
format.mascot_status <- function(x, ...) {
  checkmate::assert_class(x, "mascot_status")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_status <- function(x, ...) {
  checkmate::assert_class(x, "mascot_status")
  cli::cat_line(format(x))
  invisible(x)
}
