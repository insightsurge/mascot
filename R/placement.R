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
#' motion keeps only the glow.
#'
#' @section Dragging:
#' With `drag = "snap"` or `drag = "free"`, visitors can drag a floating mascot
#' by its drawing, with a mouse, pen or finger. A click without movement still
#' opens the mascot's menu; the minimise and restore buttons, the bubble's close
#' button and links in the bubble do not start a drag, and a minimised mascot
#' cannot be dragged. The bubble and menu move with the mascot.
#'
#' * `"snap"`: on release the mascot moves to the nearest corner, which becomes
#'   its `position`, so its bubble opens towards the page centre. Reduced motion,
#'   or `motion = FALSE`, makes the move instant.
#' * `"free"`: the mascot stays where it is dropped, at least 1rem inside the
#'   window, and stays inside when the window is resized.
#'
#' In Shiny each drop sets `input$<id>_position`, read in the module that owns
#' the mascot, like `input$<id>_menu`: the corner name, such as `"top-left"`,
#' after a snap, or a list with `x` and `y`, the mascot's top-left corner in
#' CSS pixels from the window's top-left, after a free drop. A later
#' [updateMascot()] with `placement` replaces the dragged position. Dragging
#' has no keyboard alternative; the minimise control stays reachable by keyboard.
#' Remembering a position between visits is the app's job: for example, save
#' the corner and pass it back as `position` next time.
#' @param position `"inline"` (the default) to sit where the mascot is placed in
#'   the UI, or a corner to float it: `"top-left"`, `"top-right"`,
#'   `"bottom-left"` or `"bottom-right"`. `NULL` is not accepted.
#' @param minimise A logical flag, defaulting to `FALSE`, to show a minimise
#'   control. `TRUE` needs a corner `position`. `NULL` is not accepted.
#' @param drag `FALSE` (the default) for no dragging, `"snap"` to let visitors
#'   drag the mascot and move it to the nearest corner on release, or `"free"`
#'   to keep it where it is dropped. Needs a corner `position`. `TRUE` and
#'   `NULL` are not accepted. See the Dragging section.
#' @returns A `mascot_placement` object with `position`, `minimise` and `drag`
#'   elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_placement()
#' mascot_placement("top-left")
#' mascot_placement("bottom-right", minimise = TRUE)
#' mascot_placement("bottom-right", drag = "snap")
#' mascot(id = "helper", placement = list(position = "top-left", drag = "free"))
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(
#'     mascot(id = "helper", placement = mascot_placement("bottom-right", drag = "snap")),
#'     shiny::textOutput("where")
#'   ),
#'   function(input, output, session) {
#'     output$where <- shiny::renderText(paste("Dropped in", input$helper_position))
#'   }
#' )
mascot_placement <- function(position = "inline", minimise = FALSE, drag = FALSE) {
  checkmate::assert_string(position)
  checkmate::assert_flag(minimise)
  # drag is a union (FALSE or a mode); the wording for a wrong value comes from abort_drag().
  checkmate::assert(checkmate::check_flag(drag), checkmate::check_string(drag), .var.name = "drag")
  if (!position %in% placement_positions()) {
    abort_choice(position, placement_positions(), "position", "position", environment())
  }
  if (!identical(drag, FALSE) && !isTRUE(drag %in% placement_drags())) {
    abort_drag(drag, environment())
  }
  if (minimise && position == "inline") {
    cli::cli_abort(c(
      "{.arg minimise} needs a corner {.arg position}; an inline mascot cannot be minimised.",
      "i" = "Use {.code mascot_placement(\"bottom-right\", minimise = TRUE)}."
    ))
  }
  if (!identical(drag, FALSE) && position == "inline") {
    cli::cli_abort(c(
      "{.arg drag} needs a corner {.arg position}; an inline mascot cannot be dragged.",
      "i" = "Use {.code mascot_placement(\"bottom-right\", drag = \"{drag}\")}."
    ))
  }
  structure(list(position = position, minimise = minimise, drag = drag), class = "mascot_placement")
}

#' Report an invalid drag mode, explaining that TRUE is not a mode
#' @noRd
abort_drag <- function(drag, call) {
  checkmate::assert(checkmate::check_flag(drag), checkmate::check_string(drag), .var.name = "drag")
  checkmate::assert_environment(call)
  cli::cli_abort(
    c(
      "{.arg drag} must be {.code FALSE}, {.val snap} or {.val free}.",
      "x" = if (isTRUE(drag)) {
        "{.code TRUE} is not accepted: choose how the mascot behaves when dropped."
      } else {
        "{.val {drag}} is not a drag mode."
      },
      "i" = "Use {.val snap} to move to the nearest corner or {.val free} to stay where dropped."
    ),
    call = call
  )
}

#' The drag modes besides FALSE
#' @noRd
placement_drags <- function() {
  c("snap", "free")
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
  fields <- c("position", "minimise", "drag")
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
      ", a named list with position, minimise and drag fields, or a mascot_placement() object; got ",
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
  if ("drag" %in% names(x) && !isFALSE(x$drag) && !isTRUE(checkmate::check_choice(x$drag, placement_drags()))) {
    return(paste0(
      "`placement$drag` must be FALSE, \"snap\" or \"free\"; got ",
      paste(deparse(x$drag, width.cutoff = 60L), collapse = " "),
      if (isTRUE(x$drag)) ". Use \"snap\" to move to the nearest corner or \"free\" to stay where dropped." else "."
    ))
  }
  if (isTRUE(x$minimise) && (is.null(x$position) || x$position == "inline")) {
    return("`placement` minimise needs a corner position, such as \"bottom-right\".")
  }
  if (!is.null(x$drag) && !isFALSE(x$drag) && (is.null(x$position) || x$position == "inline")) {
    return("`placement` drag needs a corner position, such as \"bottom-right\"; an inline mascot cannot be dragged.")
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

#' The browser's placement fields: floating, the corner (bottom-right when inline), minimise and drag
#' @noRd
placement_wire <- function(x) {
  checkmate::assert_class(x, "mascot_placement")
  floating <- x$position != "inline"
  list(
    floating = floating,
    position = if (floating) x$position else "bottom-right",
    minimise = x$minimise,
    drag = x$drag
  )
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
