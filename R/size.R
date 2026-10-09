#' Set a mascot's size
#'
#' Percentage sizes follow the parent's content width when inline, and the window
#' width when floating. The rendered canvas is never smaller than 24 CSS pixels.
#' Screens at most 575.98 CSS pixels wide use `small_screen`, if supplied.
#' Below 72 CSS pixels the character uses its small-size drawing by default.
#' This keeps the face readable at 48 pixels; smaller drawings lose detail.
#' @param size A finite number of CSS pixels, at least `24`, or a positive
#'   percentage string such as `"20%"`. Defaults to `160`; `NULL` is not accepted.
#' @param small_screen A size in the same forms as `size`, or `NULL` (the default)
#'   to use `size` at every screen width.
#' @param simplify_when_small A logical flag, defaulting to `TRUE`, to use the
#'   character's small-size drawing below 72 CSS pixels. `FALSE` keeps every layer,
#'   which may be hard to read. `NULL` is not accepted.
#' @returns A `mascot_size` object with `size`, `small_screen` and
#'   `simplify_when_small` elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_size()
#' mascot_size("20%")
#' mascot_size(120, small_screen = 48)
mascot_size <- function(size = 160, small_screen = NULL, simplify_when_small = TRUE) {
  # Sizes are a union of pixels and percentages; share non-throwing checks with updates.
  check_size_value(size, "size", environment())
  if (!is.null(small_screen)) {
    check_size_value(small_screen, "small_screen", environment())
  }
  checkmate::assert_flag(simplify_when_small)
  structure(
    list(size = size, small_screen = small_screen, simplify_when_small = simplify_when_small),
    class = "mascot_size"
  )
}

#' A size-value problem shared by helpers and runtime updates
#' @noRd
size_value_problem <- function(x, arg) {
  checkmate::assert_string(arg)
  # x deliberately uses check_*: bad runtime data must warn rather than throw.
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
  paste0(
    "`",
    arg,
    "` must be a finite number of pixels at least 24 or a positive percentage such as \"20%\"; got ",
    paste(deparse(x, width.cutoff = 60L), collapse = " "),
    "."
  )
}

#' Check the union accepted by each size argument
#' @noRd
check_size_value <- function(x, arg, call) {
  checkmate::assert_string(arg)
  checkmate::assert_environment(call)
  # Validation is shared with arg_problem(), including malformed helper objects.
  problem <- size_value_problem(x, arg)
  if (!is.null(problem)) {
    cli::cli_abort("{problem}", call = call)
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
  fields <- c("size", "small_screen", "simplify_when_small")
  if (
    !isTRUE(checkmate::check_list(x, names = "unique")) ||
      length(x) != length(fields) ||
      !setequal(names(x), fields)
  ) {
    return("`size` must be a mascot_size() object with size, small_screen and simplify_when_small fields.")
  }
  problem <- size_value_problem(x$size, "size")
  if (!is.null(problem)) {
    return(problem)
  }
  if (!is.null(x$small_screen)) {
    problem <- size_value_problem(x$small_screen, "small_screen")
    if (!is.null(problem)) return(problem)
  }
  if (!isTRUE(checkmate::check_flag(x$simplify_when_small))) {
    return("`simplify_when_small` must be TRUE or FALSE; use mascot_size().")
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
  checkmate::assert_class(x, "mascot_size")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_size <- function(x, ...) {
  checkmate::assert_class(x, "mascot_size")
  cli::cat_line(format(x))
  invisible(x)
}
