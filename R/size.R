#' Set the mascot's size
#'
#' Control the size of the mascot in pixels or as a percentage. Percentage
#' sizes follow the parent's content width when inline, and the window width when
#' floating. The rendered canvas is never smaller than 24 CSS pixels.
#' Screens at most 575.98 CSS pixels wide use `small_screen` (floating mascots
#' scale down to a phone size by default). The full character is drawn at every
#' size; fine face details are harder to read at 32 and 24 pixels, so the status
#' text carries the meaning.
#' @param size A finite number of CSS pixels (at least `24`), or a positive
#'   percentage string such as `"20%"`. Defaults to `160`; `NULL` is not accepted.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param small_screen An optional size for small screens (at most 575.98 CSS
#'   pixels wide). `"auto"` (the default) scales floating mascots down on phones
#'   to at most 96 pixels while leaving inline mascots unchanged. `NULL` keeps
#'   the same size on every screen. A number of pixels or a percentage string
#'   sets the phone size explicitly for both floating and inline mascots.
#' @returns A `mascot_size` object with `size` and `small_screen` elements.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()], [update_mascot()]
#' @export
#' @examples
#' mascot_size()
#' mascot_size("20%")
#' mascot_size(120, small_screen = 48)
#' mascot_size(120, small_screen = NULL)
mascot_size <- function(size = 160, ..., small_screen = "auto") {
  # Sizes are a union of pixels and percentages; share non-throwing checks with updates.
  check_size_value(size, "size", environment())
  if (!is.null(small_screen)) {
    check_size_value(small_screen, "small_screen", environment(), allow_auto = TRUE)
  }
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("small_screen"), environment())
  }
  structure(list(size = size, small_screen = small_screen), class = "mascot_size")
}

#' A size-value problem shared by helpers and runtime updates
#' @noRd
size_value_problem <- function(x, arg, allow_auto = FALSE) {
  checkmate::assert_string(arg)
  checkmate::assert_flag(allow_auto)
  # x deliberately uses check_*: bad runtime data must warn rather than throw.
  if (allow_auto && identical(x, "auto")) {
    return(NULL)
  }
  if (isTRUE(checkmate::check_number(x, lower = 24, finite = TRUE))) {
    return(NULL)
  }
  if (
    isTRUE(checkmate::check_string(x)) &&
      grepl("^(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)%$", x, perl = TRUE)
  ) {
    number <- suppressWarnings(as.numeric(sub("%$", "", x)))
    if (is.finite(number) && number > 0) return(NULL)
  }
  valid <- if (allow_auto) {
    "\"auto\", a finite number of pixels at least 24 or a positive percentage such as \"20%\""
  } else {
    "a finite number of pixels at least 24 or a positive percentage such as \"20%\""
  }
  paste0(
    "`",
    arg,
    "` must be ",
    valid,
    "; got ",
    paste(deparse(x, width.cutoff = 60L), collapse = " "),
    "."
  )
}

#' Check the union accepted by each size argument
#' @noRd
check_size_value <- function(x, arg, call, allow_auto = FALSE) {
  checkmate::assert_string(arg)
  checkmate::assert_environment(call)
  checkmate::assert_flag(allow_auto)
  # Validation is shared with arg_problem(), including malformed helper objects.
  problem <- size_value_problem(x, arg, allow_auto = allow_auto)
  if (!is.null(problem)) {
    cli::cli_abort("{problem}", call = call, class = "mascot_error")
  }
  invisible(NULL)
}

#' Validate a size shortcut or helper without throwing
#' @noRd
size_problem <- function(x) {
  # Union input deliberately uses check_* for warning-only runtime validation.
  if (!inherits(x, "mascot_size")) {
    return(size_value_problem(x, "size"))
  }
  fields <- c("size", "small_screen")
  if (
    !isTRUE(checkmate::check_list(x, names = "unique")) ||
      length(x) != length(fields) ||
      !setequal(names(x), fields)
  ) {
    return("`size` must be a mascot_size() object with size and small_screen fields.")
  }
  problem <- size_value_problem(x$size, "size")
  if (!is.null(problem)) {
    return(problem)
  }
  if (!is.null(x$small_screen)) {
    problem <- size_value_problem(x$small_screen, "small_screen", allow_auto = TRUE)
    if (!is.null(problem)) return(problem)
  }
  NULL
}

#' Accept pixels, a percentage or a size helper
#' @noRd
as_size_arg <- function(x, call) {
  checkmate::assert_environment(call)
  # Union input uses the same validation boundary as the existing helpers.
  check_arg(x, "size", call)
  if (inherits(x, "mascot_size")) x else mascot_size(x)
}

#' @export
#' @noRd
format.mascot_size <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_size")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_size <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_size")
  })
  cli::cat_line(format(x))
  invisible(x)
}
