#' Add a mascot to a page
#'
#' Draw a character with a mood and a status line. The status shows the
#' capitalised mood word until the app sets its own text. It follows the mood
#' again after [mascot_status()] is supplied without text.
#'
#' @param character A character name or [mascot_character()] object. Defaults
#'   to `"tessa"`. `NULL` is not accepted.
#' @param id A required non-empty string without whitespace, unique on the
#'   page. In a Shiny module use `ns("helper")` in the UI and `"helper"` in
#'   the server; [updateMascot()] adds the module namespace once.
#' @param mood A mood name or [mascot_mood()] object. Defaults to `"idle"`.
#'   See [mascot_moods()] for choices. `NULL` is not accepted.
#' @param status A non-empty string or [mascot_status()] object. `NULL` (the
#'   default) follows the mood. Text is escaped, including [htmltools::HTML()].
#' @returns An `htmltools` tag with its engine dependency attached.
#' @family mascots in Shiny
#' @seealso [updateMascot()]
#' @details
#' In Shiny the mascot uses an input binding with a `NULL` input value.
#' A module can put the mascot in its UI and update it from its server:
#' ```r
#' helper_ui <- function(id) {
#'   ns <- shiny::NS(id)
#'   mascot(id = ns("helper"))
#' }
#' helper_server <- function(id) {
#'   shiny::moduleServer(id, function(input, output, session) {
#'     updateMascot("helper", mood = "happy")
#'   })
#' }
#' ```
#' @export
#' @examples
#' mascot(id = "helper", mood = "happy")
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   ui = shiny::fluidPage(mascot(id = "helper")),
#'   server = function(input, output, session) {}
#' )
mascot <- function(character = "tessa", id, mood = "idle", status = NULL) {
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  character <- as_character_arg(character, environment())
  mood <- as_mood_arg(mood, environment())
  status <- as_status_arg(status, environment())
  mode <- if (is.null(status$text)) "mood" else "custom"
  tag <- htmltools::tags$div(
    class = "mascot",
    id = id,
    `data-character` = character$id,
    `data-mood` = mood$name,
    `data-status` = mode,
    htmltools::tags$script(
      type = "application/json",
      `data-mascot-character` = character$id,
      htmltools::HTML(character_json(character$id))
    ),
    htmltools::tags$canvas(
      class = "mascot-canvas",
      role = "img",
      `aria-label` = paste0(character$name, ", ", mood$name)
    ),
    htmltools::tags$div(
      class = "mascot-status",
      role = "status",
      if (mode == "mood") mood_label(mood$name) else status$text
    )
  )
  htmltools::attachDependencies(tag, mascot_dependency())
}

#' Accept a character shortcut or helper
#' @noRd
as_character_arg <- function(x, call) {
  checkmate::assert_environment(call)
  # Union arguments use the shared non-throwing checks so updates can warn instead.
  check_arg(x, "character", call)
  if (inherits(x, "mascot_character")) x else mascot_character(x)
}

#' Accept a mood shortcut or helper
#' @noRd
as_mood_arg <- function(x, call) {
  checkmate::assert_environment(call)
  # See as_character_arg(): this argument accepts a union of types.
  check_arg(x, "mood", call)
  if (inherits(x, "mascot_mood")) x else mascot_mood(x)
}

#' Accept plain text or a status helper
#' @noRd
as_status_arg <- function(x, call) {
  checkmate::assert_environment(call)
  # See as_character_arg(): this argument accepts a union of types.
  check_arg(x, "status", call)
  if (inherits(x, "mascot_status")) x else mascot_status(x)
}

#' Check a build-time argument with the public call attached
#' @noRd
check_arg <- function(x, arg, call) {
  checkmate::assert_choice(arg, c("character", "mood", "status"))
  checkmate::assert_environment(call)
  # x is checked by arg_problem(), shared with warning-only runtime validation.
  problem <- arg_problem(x, arg)
  if (is.null(problem)) {
    return(invisible(NULL))
  }
  if (arg != "status" && isTRUE(checkmate::check_string(x, min.chars = 1))) {
    valid <- if (arg == "character") builtin_characters()$id else mood_table()$name
    abort_choice(x, valid, arg, arg, call)
  }
  cli::cli_abort("{problem}", call = call)
}

#' A plain-text problem, or NULL for a valid shortcut or helper
#' @noRd
arg_problem <- function(x, arg) {
  checkmate::assert_choice(arg, c("character", "mood", "status"))
  # check_* deliberately replaces assert_* for x: runtime values must only warn.
  helper <- paste0("mascot_", arg)
  if (inherits(x, helper)) {
    return(NULL)
  }
  if (arg == "status" && is.null(x)) {
    return(NULL)
  }
  if (!isTRUE(checkmate::check_string(x, min.chars = 1))) {
    suffix <- if (arg == "status") "; use mascot_status() to follow the mood" else ""
    return(paste0("`", arg, "` must be a non-empty string or a ", helper, "() object", suffix, "."))
  }
  if (arg == "status") {
    return(NULL)
  }
  valid <- if (arg == "character") builtin_characters()$id else mood_table()$name
  if (!x %in% valid) {
    return(paste0(
      "`",
      arg,
      "` must be one of ",
      paste(encodeString(valid, quote = '"'), collapse = ", "),
      "; ",
      encodeString(x, quote = '"'),
      " is not a ",
      arg,
      "."
    ))
  }
  NULL
}

#' Offline runtime dependency
#' @noRd
mascot_dependency <- function() {
  htmltools::htmlDependency(
    name = "mascot",
    version = getNamespaceVersion("mascot")[[1]],
    src = "www",
    package = "mascot",
    script = c("mascot.js", "mascot-draw.js", "mascot-motion.js", "mascot-host.js"),
    stylesheet = "mascot.css",
    all_files = FALSE
  )
}
