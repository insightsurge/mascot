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
#' @param position `"inline"` (the default) to sit where the mascot is placed in
#'   the UI, or a corner to float it: `"top-left"`, `"top-right"`,
#'   `"bottom-left"` or `"bottom-right"`. `NULL` is not accepted.
#' @param minimise A logical flag, defaulting to `FALSE`, to show a minimise
#'   control. `TRUE` needs a corner `position`. `NULL` is not accepted.
#' @returns A `mascot_placement` object with `position` and `minimise` elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_placement()
#' mascot_placement("top-left")
#' mascot_placement("bottom-right", minimise = TRUE)
mascot_placement <- function(position = "inline", minimise = FALSE) {
  checkmate::assert_string(position)
  checkmate::assert_flag(minimise)
  if (!position %in% placement_positions()) {
    abort_choice(position, placement_positions(), "position", "position", environment())
  }
  if (minimise && position == "inline") {
    cli::cli_abort(c(
      "{.arg minimise} needs a corner {.arg position}; an inline mascot cannot be minimised.",
      "i" = "Use {.code mascot_placement(\"bottom-right\", minimise = TRUE)}."
    ))
  }
  structure(list(position = position, minimise = minimise), class = "mascot_placement")
}

#' The shared corner vocabulary
#' @noRd
placement_corners <- function() {
  c("top-left", "top-right", "bottom-left", "bottom-right")
}

#' Every position a helper accepts
#' @noRd
placement_positions <- function() {
  c("inline", placement_corners())
}

#' Validate placement shortcuts and helper contents without throwing
#' @noRd
placement_problem <- function(x) {
  # Union input deliberately uses check_* for warning-only runtime validation.
  choices <- c("inline", "floating", placement_corners())
  if (isTRUE(checkmate::check_string(x)) && x %in% choices) {
    return(NULL)
  }
  fields <- c("position", "minimise")
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
      ", a named list with position and minimise fields, or a mascot_placement() object; got ",
      paste(deparse(x, width.cutoff = 60L), collapse = " "),
      "."
    ))
  }
  if ("position" %in% names(x) && !isTRUE(checkmate::check_choice(x$position, placement_positions()))) {
    return(paste0(
      "`placement$position` must be one of ",
      paste(encodeString(placement_positions(), quote = '\"'), collapse = ", "),
      "."
    ))
  }
  if ("minimise" %in% names(x) && !isTRUE(checkmate::check_flag(x$minimise))) {
    return("`placement$minimise` must be TRUE or FALSE.")
  }
  if (isTRUE(x$minimise) && (is.null(x$position) || x$position == "inline")) {
    return("`placement` minimise needs a corner position, such as \"bottom-right\".")
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
  if (x == "floating") {
    return(mascot_placement("bottom-right"))
  }
  mascot_placement(x)
}

#' The browser's placement fields: floating, the corner (bottom-right when inline) and minimise
#' @noRd
placement_wire <- function(x) {
  checkmate::assert_class(x, "mascot_placement")
  floating <- x$position != "inline"
  list(floating = floating, position = if (floating) x$position else "bottom-right", minimise = x$minimise)
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
