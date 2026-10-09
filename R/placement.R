#' Place a mascot inline or in a floating corner
#'
#' Inline mascots sit where they are placed in the UI. Floating mascots sit
#' 1rem from the window's edges, above fixed navigation bars and below modals.
#' Bottom-right mascots move above Shiny notifications while they are visible.
#' Floating mascots hide with their original tab or container. Switching back to
#' inline returns the mascot to its original place in the UI.
#'
#' The neutral minimise control appears on hover or keyboard focus. Touch screens
#' keep it visible; an open mascot menu hides it. Its border has a quiet glow.
#' A minimised mascot is a round restore button in the character's colours.
#' Its status remains available to screen readers. Updates still apply; bubble
#' countdowns pause until restored. Click, Enter or Space restores the mascot.
#' Hover and keyboard focus add a glow and a small growth transition; reduced
#' motion keeps only the glow. Dragging and snapping are not supported.
#' @param floating A logical flag, defaulting to `FALSE`, to keep the mascot
#'   inline. `TRUE` floats it in a corner. `NULL` is not accepted.
#' @param position A string naming `"top-left"`, `"top-right"`, `"bottom-left"`
#'   or `"bottom-right"` (the default). Supplying this argument explicitly
#'   requires `floating = TRUE`. `NULL` is not accepted.
#' @param minimise A logical flag, defaulting to `FALSE`, to show a minimise
#'   control. Supplying this argument explicitly requires `floating = TRUE`.
#'   `NULL` is not accepted.
#' @returns A `mascot_placement` object with `floating`, `position` and
#'   `minimise` elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_placement()
#' mascot_placement(floating = TRUE, position = "top-left")
#' mascot_placement(floating = TRUE, minimise = TRUE)
mascot_placement <- function(floating = FALSE, position = "bottom-right", minimise = FALSE) {
  checkmate::assert_flag(floating)
  checkmate::assert_string(position)
  checkmate::assert_flag(minimise)
  if (!position %in% placement_corners()) {
    abort_choice(position, placement_corners(), "position", "position", environment())
  }
  if (!floating && (!missing(position) || !missing(minimise))) {
    cli::cli_abort(
      if (!missing(position)) {
        "{.arg position} only works with {.code floating = TRUE}."
      } else {
        "{.arg minimise} only works with {.code floating = TRUE}."
      }
    )
  }
  structure(list(floating = floating, position = position, minimise = minimise), class = "mascot_placement")
}

#' The shared corner vocabulary
#' @noRd
placement_corners <- function() {
  c("top-left", "top-right", "bottom-left", "bottom-right")
}

#' Validate placement shortcuts and helper contents without throwing
#' @noRd
placement_problem <- function(x) {
  # Union input deliberately uses check_* for warning-only runtime validation.
  choices <- c("inline", "floating", placement_corners())
  if (isTRUE(checkmate::check_string(x)) && x %in% choices) {
    return(NULL)
  }
  fields <- c("floating", "position", "minimise")
  helper <- inherits(x, "mascot_placement")
  if (
    !isTRUE(checkmate::check_list(x, names = "unique")) ||
      any(!names(x) %in% fields) ||
      (helper && (length(x) != length(fields) || !setequal(names(x), fields))) ||
      (length(x) > 0L && is.null(names(x)))
  ) {
    return(paste0(
      "`placement` must be one of ",
      paste(encodeString(choices, quote = '\"'), collapse = ", "),
      ", a named list with floating, position and minimise fields, or a mascot_placement() object; got ",
      paste(deparse(x, width.cutoff = 60L), collapse = " "),
      "."
    ))
  }
  if ("floating" %in% names(x) && !isTRUE(checkmate::check_flag(x$floating))) {
    return("`placement$floating` must be TRUE or FALSE.")
  }
  if ("position" %in% names(x) && !isTRUE(checkmate::check_choice(x$position, placement_corners()))) {
    return(paste0(
      "`placement$position` must be one of ",
      paste(encodeString(placement_corners(), quote = '\"'), collapse = ", "),
      "."
    ))
  }
  if ("minimise" %in% names(x) && !isTRUE(checkmate::check_flag(x$minimise))) {
    return("`placement$minimise` must be TRUE or FALSE.")
  }
  if (
    !isTRUE(x$floating) &&
      (if (helper) x$position != "bottom-right" || x$minimise else any(c("position", "minimise") %in% names(x)))
  ) {
    return("`placement` position or minimise only works with floating = TRUE.")
  }
  NULL
}

#' Accept an inline/floating shortcut, a corner, a list or a helper
#' @noRd
as_placement_arg <- function(x, call) {
  checkmate::assert_environment(call)
  check_arg(x, "placement", call)
  if (inherits(x, "mascot_placement")) {
    return(x)
  }
  if (is.list(x)) {
    return(do.call(mascot_placement, x))
  }
  if (x == "inline") {
    return(mascot_placement())
  }
  if (x == "floating") {
    return(mascot_placement(TRUE))
  }
  mascot_placement(TRUE, x)
}

#' @export
#' @noRd
format.mascot_placement <- function(x, ...) {
  checkmate::assert_class(x, "mascot_placement")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_placement <- function(x, ...) {
  checkmate::assert_class(x, "mascot_placement")
  cli::cat_line(format(x))
  invisible(x)
}
