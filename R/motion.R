#' Control how the mascot animates
#'
#' Turn off all animations or only the transition when swapping characters.
#' If a visitor prefers reduced motion in their system settings, mascot always
#' respects that choice, even when `animate = TRUE`. Idle breathing and blinking
#' pause five seconds after the last action to save battery.
#' @param animate A logical flag, defaulting to `TRUE`, to allow animation when
#'   the visitor allows motion. `FALSE` makes all changes instant. `NULL` is not
#'   accepted.
#' @param swap A logical flag, defaulting to `TRUE`, to animate character changes.
#'   `FALSE` makes character changes instant while moods can still animate.
#'   With `animate = FALSE`, this setting has no effect. `NULL` is not accepted.
#' @returns A `mascot_motion` object with `animate` and `swap` elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_motion()
#' mascot_motion(animate = FALSE)
#' mascot_motion(swap = FALSE)
#' mascot(id = "still", motion = FALSE)
#' @examplesIf interactive()
#' # The app owns the switch; reset returns to the character's own colours.
#' shiny::shinyApp(
#'   shiny::fluidPage(
#'     shiny::checkboxInput("animate", "Animate mascot", TRUE),
#'     shiny::checkboxInput("dark", "Dark mascot colours", FALSE),
#'     shiny::actionButton("reset", "Use the character's colours"),
#'     mascot(id = "helper")
#'   ),
#'   function(input, output, session) {
#'     shiny::observeEvent(input$animate, {
#'       updateMascot("helper", motion = input$animate)
#'     })
#'     shiny::observeEvent(input$dark, {
#'       updateMascot("helper", theme = mascot_theme(
#'         light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"),
#'         mode = if (input$dark) "dark" else "light"
#'       ))
#'     }, ignoreInit = TRUE)
#'     shiny::observeEvent(input$reset, {
#'       updateMascot("helper", theme = mascot_theme())
#'     })
#'   }
#' )
mascot_motion <- function(animate = TRUE, swap = TRUE) {
  checkmate::assert_flag(animate)
  checkmate::assert_flag(swap)
  structure(list(animate = animate, swap = swap), class = "mascot_motion")
}

#' Validate a motion shortcut or helper without throwing
#' @noRd
motion_problem <- function(x) {
  # Union input deliberately uses check_* for warning-only runtime validation.
  if (inherits(x, "mascot_motion")) {
    fields <- c("animate", "swap")
    if (
      !isTRUE(checkmate::check_list(x, names = "unique")) ||
        length(x) != length(fields) ||
        !setequal(names(x), fields)
    ) {
      return("`motion` must be a mascot_motion() object with animate and swap fields.")
    }
    for (field in fields) {
      if (!isTRUE(checkmate::check_flag(x[[field]]))) {
        return(paste0(
          "`",
          field,
          "` must be TRUE or FALSE; got ",
          paste(deparse(x[[field]], width.cutoff = 60L), collapse = " "),
          "; use mascot_motion()."
        ))
      }
    }
    return(NULL)
  }
  if (isTRUE(checkmate::check_flag(x))) {
    return(NULL)
  }
  paste0(
    "`motion` must be TRUE, FALSE or a mascot_motion() object; got ",
    paste(deparse(x, width.cutoff = 60L), collapse = " "),
    "."
  )
}

#' Accept a motion flag or helper and map to the engine's settings
#' @noRd
as_motion_arg <- function(x, call) {
  checkmate::assert_environment(call)
  # Shared union validation keeps build-time errors and runtime warnings in step.
  check_arg(x, "motion", call)
  value <- if (inherits(x, "mascot_motion")) x else mascot_motion(animate = x)
  # NULL follows the visitor; FALSE must never override the visitor's preference.
  list(reduced = if (value$animate) NULL else TRUE, swap = value$swap)
}

#' @export
#' @noRd
format.mascot_motion <- function(x, ...) {
  checkmate::assert_class(x, "mascot_motion")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_motion <- function(x, ...) {
  checkmate::assert_class(x, "mascot_motion")
  cli::cat_line(format(x))
  invisible(x)
}
