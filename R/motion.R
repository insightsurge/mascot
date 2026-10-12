#' Choose which parts of the mascot move
#'
#' This helper plays nothing; use [mascot_gesture()] to play a movement.
#' Idle breathing and blinking stop within five seconds of an action.
#' The visitor's
#' [reduced-motion setting](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion)
#' always wins over any `TRUE`.
#' Unnamed switches, including switches added in later versions, follow `others`;
#' named switches always win.
#' @param ... Must be empty; all settings must be named.
#' @param idle Logical flag or `NULL` (default): breathing and blinking.
#'   `NULL` follows `others`.
#' @param mood_change Logical flag or `NULL` (default): the wiggle or hop on a
#'   mood change. `NULL` follows `others`.
#' @param gestures Logical flag or `NULL` (default): nods, waves and other
#'   gestures. `NULL` follows `others`. Skipping a gesture leaves the mood,
#'   bubble and status of the same update intact.
#' @param swap Logical flag or `NULL` (default): character-change transitions.
#'   `NULL` follows `others`.
#' @param minimising Logical flag or `NULL` (default): movement to the round
#'   restore button. `NULL` follows `others`.
#' @param restoring Logical flag or `NULL` (default): movement back from the
#'   restore button. `NULL` follows `others`.
#' @param messages `TRUE` for all panels, `FALSE` for none, or a character vector
#'   of names from `c("bubble", "tooltip", "menu")` for only those panels.
#'   `NULL` (default) follows `others`. Panels still appear and work.
#' @param others Logical flag, default `TRUE`, for every unnamed switch.
#' @returns A `mascot_motion_settings` object. Its fields are internal; pass the
#'   object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()], [update_mascot()], [mascot_gesture()]
#' @export
#' @examples
#' mascot_motion_settings()
#' mascot_motion_settings(idle = FALSE)
#' mascot_motion_settings(messages = "menu", others = FALSE)
#' mascot("still", motion = FALSE)
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(
#'     shiny::checkboxInput("idle", "Allow idle movement", TRUE),
#'     shiny::checkboxInput("dark", "Dark mascot colours", FALSE),
#'     shiny::actionButton("reset", "Use the character's colours"),
#'     mascot("helper")
#'   ),
#'   function(input, output, session) {
#'     shiny::observeEvent(input$idle, {
#'       update_mascot("helper", motion = mascot_motion_settings(idle = input$idle))
#'     })
#'     shiny::observeEvent(input$dark, {
#'       update_mascot("helper", theme = mascot_theme(
#'         light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"),
#'         mode = if (input$dark) "dark" else "light"
#'       ))
#'     }, ignoreInit = TRUE)
#'     shiny::observeEvent(input$reset, {
#'       update_mascot("helper", theme = mascot_theme())
#'     })
#'   }
#' )
mascot_motion_settings <- function(
  ...,
  idle = NULL,
  mood_change = NULL,
  gestures = NULL,
  swap = NULL,
  minimising = NULL,
  restoring = NULL,
  messages = NULL,
  others = TRUE
) {
  with_mascot_asserts({
    if (...length() > 0L) {
      abort_dots(
        names(substitute(list(...)))[-1L],
        ...length(),
        c("idle", "mood_change", "gestures", "swap", "minimising", "restoring", "messages", "others"),
        environment()
      )
    }
    checkmate::assert_flag(idle, null.ok = TRUE)
    checkmate::assert_flag(mood_change, null.ok = TRUE)
    checkmate::assert_flag(gestures, null.ok = TRUE)
    checkmate::assert_flag(swap, null.ok = TRUE)
    checkmate::assert_flag(minimising, null.ok = TRUE)
    checkmate::assert_flag(restoring, null.ok = TRUE)
    checkmate::assert_flag(others)
    if (!is.null(messages) && !is.logical(messages)) {
      checkmate::assert_character(messages, any.missing = FALSE)
    } else {
      checkmate::assert_flag(messages, null.ok = TRUE)
    }
  })
  if (is.character(messages) && any(!messages %in% c("bubble", "tooltip", "menu"))) {
    cli::cli_abort(
      "{.arg messages} must use panel names: {.or {c('bubble', 'tooltip', 'menu')}}.",
      class = "mascot_error"
    )
  }
  structure(
    list(
      idle = idle,
      mood_change = mood_change,
      gestures = gestures,
      swap = swap,
      minimising = minimising,
      restoring = restoring,
      messages = messages,
      others = others
    ),
    class = "mascot_motion_settings"
  )
}

#' Validate a motion shortcut or helper without throwing
#' @noRd
motion_problem <- function(x) {
  # Union input deliberately uses check_* for warning-only runtime validation.
  if (inherits(x, "mascot_motion_settings")) {
    fields <- c("idle", "mood_change", "gestures", "swap", "minimising", "restoring", "messages", "others")
    if (
      !isTRUE(checkmate::check_list(x, names = "unique")) ||
        length(x) != length(fields) ||
        !setequal(names(x), fields)
    ) {
      return("`motion` must be a mascot_motion_settings() object with all motion fields.")
    }
    for (field in setdiff(fields, "messages")) {
      if (!isTRUE(checkmate::check_flag(x[[field]], null.ok = field != "others"))) {
        return(paste0(
          "`",
          field,
          "` must be TRUE or FALSE",
          if (field != "others") " or NULL",
          "; use mascot_motion_settings()."
        ))
      }
    }
    m <- x$messages
    panels_ok <- is.character(m) && !anyNA(m) && all(m %in% c("bubble", "tooltip", "menu"))
    if (!(is.null(m) || isTRUE(checkmate::check_flag(m)) || panels_ok)) {
      return("`messages` must be TRUE, FALSE, NULL or panel names: bubble, tooltip, menu.")
    }
    return(NULL)
  }
  if (isTRUE(checkmate::check_flag(x))) {
    return(NULL)
  }
  paste0(
    "`motion` must be TRUE, FALSE or a mascot_motion_settings() object; got ",
    paste(deparse(x, width.cutoff = 60L), collapse = " "),
    "."
  )
}

#' Resolve all switches for the browser
#' @noRd
as_motion_arg <- function(x, call) {
  checkmate::assert_environment(call)
  check_arg(x, "motion", call)
  value <- if (inherits(x, "mascot_motion_settings")) x else mascot_motion_settings(others = x)
  switches <- lapply(value[setdiff(names(value), c("messages", "others"))], function(flag) {
    checkmate::assert_flag(flag, null.ok = TRUE)
    if (is.null(flag)) value$others else flag
  })
  messages <- if (is.null(value$messages)) value$others else value$messages
  panels <- if (isTRUE(messages)) {
    c("bubble", "tooltip", "menu")
  } else if (identical(messages, FALSE)) {
    character()
  } else {
    messages
  }
  c(
    list(reduced = if (identical(x, FALSE)) TRUE else NULL),
    switches,
    list(messages = as.list(unique(panels)), others = value$others)
  )
}

#' @export
#' @noRd
format.mascot_motion_settings <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_motion_settings")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_motion_settings <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_motion_settings")
  })
  cli::cat_line(format(x))
  invisible(x)
}
