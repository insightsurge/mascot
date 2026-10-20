#' Place a mascot in a floating corner or inline
#'
#' Floating mascots sit in a window corner (by default, `"bottom-right"`), 1rem
#' from the window edges, above fixed navigation bars and below modals.
#' Bottom-right mascots move above Shiny notifications while they are visible.
#' Floating mascots hide with their original tab or container. Inline mascots sit
#' where `mascot()` is placed in the page flow. Switching back to inline returns
#' the mascot to its original place in the UI.
#'
#' Floating mascots show a minimise control by default; set `minimise = FALSE`
#' to hide it. The neutral control appears on hover or keyboard focus. Touch
#' screens keep it visible; an open mascot menu hides it. Its border has a quiet
#' glow. A minimised mascot is a round restore button in the character's colours.
#' Its status remains available to screen readers. Updates still apply; bubble
#' countdowns pause until restored. Click, Enter or Space restores the mascot.
#' Hover and keyboard focus add a glow and a small growth transition to the
#' restore button; reduced motion keeps only the glow.
#'
#' @section Dragging:
#' With `drag = "snap"` or `drag = "free"`, visitors can drag a floating mascot
#' by its drawing, with a mouse, pen or finger. A click without movement still
#' opens the mascot's menu. While minimised, drag the round restore button:
#' a click without movement restores the mascot, but a drag never restores it.
#' After a snap, restoring shows the mascot in the new corner. The minimise
#' button, the bubble's close button and links in the bubble do not start a
#' drag. The bubble and menu move with the mascot.
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
#' [update_mascot()] with `placement` replaces the dragged position. Dragging
#' has no keyboard alternative; the minimise control stays reachable by keyboard.
#' Remembering a position between visits is the app's job: for example, save
#' the corner and pass it back as `position` next time.
#' In Shiny, minimising or restoring sets `input$<id>_minimised` to a logical
#' flag in the module that owns the mascot.
#'
#' @param position A corner to float the mascot (`"bottom-right"`, the default;
#'   `"top-left"`, `"top-right"` or `"bottom-left"`), or `"inline"` to sit
#'   where the mascot is placed in the UI. `NULL` is not accepted.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param minimise A logical flag, defaulting to `TRUE`, to show a minimise
#'   control on a floating mascot. Has no effect inline: an explicitly supplied
#'   value gives an informational message; the default stays silent.
#'   `NULL` is not accepted.
#' @param drag `"none"` (the default) for no dragging, `"snap"` to let visitors
#'   drag the mascot and move it to the nearest corner on release, or `"free"`
#'   to keep it where it is dropped, including while minimised.
#'   \ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{%
#'   \out{<span class='badge text-bg-warning'>Experimental</span>}}}{%
#'   \strong{[Experimental]}}
#'   `"free"` is experimental: the position it reports and how to restore it
#'   may change. Has no effect inline: an
#'   explicitly supplied value gives an informational message. `TRUE`, `FALSE` and
#'   `NULL` are not accepted. See the Dragging section.
#' @returns A `mascot_placement` object with `position`, `minimise` and `drag`
#'   elements.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()], [update_mascot()]
#' @evalRd paste0(
#'   "\\section{Experimental free dragging}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\n\"free\" is experimental: the position it reports and how to restore ",
#'   "it may change.\n}"
#' )
#' @export
#' @examples
#' mascot_placement()
#' mascot_placement("top-left")
#' mascot_placement("bottom-right", minimise = TRUE)
#' mascot_placement("bottom-right", drag = "snap")
#' ui <- mascot("helper", placement = list(position = "top-left", drag = "free"))
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(
#'     mascot("helper", placement = mascot_placement("bottom-right", drag = "snap")),
#'     shiny::textOutput("where")
#'   ),
#'   function(input, output, session) {
#'     output$where <- shiny::renderText(paste("Dropped in", input$helper_position))
#'   }
#' )
mascot_placement <- function(position = "bottom-right", ..., minimise = TRUE, drag = "none") {
  with_mascot_asserts({
    checkmate::assert_string(position)
    checkmate::assert_flag(minimise)
    # Check logical values here so abort_drag() can give the migration hint.
    checkmate::assert(checkmate::check_flag(drag), checkmate::check_string(drag), .var.name = "drag")
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("minimise", "drag"), environment())
  }
  if (!position %in% placement_positions()) {
    abort_choice(position, placement_positions(), "position", "position", environment())
  }
  if (!isTRUE(drag %in% placement_drags())) {
    abort_drag(drag, environment())
  }
  if (position == "inline") {
    explicit <- c("minimise", "drag")[c(!missing(minimise), !missing(drag))]
    inform_placement_ignored(explicit)
    minimise <- FALSE
    drag <- "none"
  }
  structure(list(position = position, minimise = minimise, drag = drag), class = "mascot_placement")
}

#' Tell developers which explicitly supplied controls have no effect inline
#' @noRd
inform_placement_ignored <- function(args) {
  checkmate::assert_character(args, any.missing = FALSE)
  for (arg in args) {
    cli::cli_inform(
      "{.arg {arg}} has no effect on an inline mascot.",
      class = c("mascot_placement_ignored", "mascot_message")
    )
  }
}

#' Report an invalid drag mode, explaining that TRUE is not a mode
#' @noRd
abort_drag <- function(drag, call) {
  checkmate::assert(checkmate::check_flag(drag), checkmate::check_string(drag), .var.name = "drag")
  checkmate::assert_environment(call)
  cli::cli_abort(
    c(
      "{.arg drag} must be one of {.or {.val {placement_drags()}}}.",
      "x" = "{.val {drag}} is not a drag mode{if (isTRUE(drag)) ' (TRUE is not accepted)' else ''}.",
      "i" = paste0(
        'Use drag = "none" for no dragging: "none" disables dragging, ',
        '"snap" moves to the nearest corner, and "free" stays where dropped.'
      )
    ),
    call = call,
    class = c("mascot_error_choice", "mascot_error"),
    argument = "drag",
    choices = placement_drags(),
    value = drag
  )
}

#' The public drag modes
#' @noRd
placement_drags <- function() {
  c("none", "snap", "free")
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
  choices <- placement_positions()
  if (identical(x, "floating")) {
    return('`placement = "floating"` is not accepted; use placement = "bottom-right".')
  }
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
  if ("drag" %in% names(x) && !isTRUE(checkmate::check_choice(x$drag, placement_drags()))) {
    return(paste0(
      "`placement$drag` must be \"none\", \"snap\" or \"free\"; got ",
      paste(deparse(x$drag, width.cutoff = 60L), collapse = " "),
      '. Use drag = "none" for no dragging.'
    ))
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
    if (identical(x$position, "inline")) {
      inform_placement_ignored(intersect(c("minimise", "drag"), names(x)))
      return(mascot_placement("inline"))
    }
    return(do.call(mascot_placement, x))
  }
  mascot_placement(x)
}

#' The browser's placement settings: floating, the corner (bottom-right when inline), minimise and drag
#' @noRd
placement_wire <- function(x) {
  checkmate::assert_class(x, "mascot_placement")
  floating <- x$position != "inline"
  list(
    floating = floating,
    position = if (floating) x$position else "bottom-right",
    minimise = if (floating) x$minimise else FALSE,
    drag = if (floating && x$drag != "none") x$drag else FALSE
  )
}

#' @export
#' @noRd
format.mascot_placement <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_placement")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_placement <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_placement")
  })
  cli::cat_line(format(x))
  invisible(x)
}
