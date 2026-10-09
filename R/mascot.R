#' Add a mascot to a page
#'
#' Draw a character with a mood, a status line and an optional message bubble. The status shows the
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
#' @param bubble A non-empty string, an `htmltools` tag or tag list, or a
#'   [mascot_bubble()] object. `NULL` (the
#'   default) shows no bubble. A string uses the helper's five-second duration
#'   and close button. Plain text is escaped; [htmltools::HTML()] or tags supply
#'   HTML. Tags with dependencies or head content are not supported.
#' @param size A finite number of CSS pixels (at least `24`), a positive percentage
#'   string such as `"20%"`, or a [mascot_size()] object. Defaults to `160`.
#'   Percentages follow the parent width when inline and window width when floating,
#'   with a 24-pixel floor. `NULL` is not accepted.
#' @param placement `"inline"` (the default), `"floating"` (bottom-right), a corner
#'   such as `"top-left"`, a named list such as `list(position = "top-left",
#'   minimise = TRUE)`, or a [mascot_placement()] object. `minimise` needs a
#'   corner. `NULL` is not accepted.
#' @param theme A named list of colour roles, a [bslib::bs_theme()] or a
#'   [mascot_theme()] object. `NULL` (the default) keeps the character's own
#'   colours. Unset roles keep their original colours in both modes.
#' @param motion A logical flag or [mascot_motion()] object. `TRUE` (the default)
#'   allows animation while honouring the visitor's reduced-motion preference.
#'   `FALSE` stops animation. `NULL` is not accepted.
#' @param popup_menu A named character vector of item labels or a
#'   [mascot_popup_menu()] object. `NULL` (the default) shows no menu.
#'   A choice sets `input$<id>_menu` to the item id, including repeated choices.
#'   In a module, use `ns("helper")` in the UI and read `input$helper_menu` in
#'   that module's server. Enter and Space operate the focused menu toggle;
#'   see [mascot_popup_menu()] for the module example and guidance.
#' @returns An `htmltools` tag with its engine dependency attached.
#' @family mascots in Shiny
#' @seealso [updateMascot()]
#' @details
#' Use the always visible status line for a short description of the current state.
#' Use a bubble for a message about something that happened; it may time out.
#' Use `mascot_bubble(..., duration = Inf)` for a message the user must act on,
#' such as an invalid form, because a timed message can vanish before it is read.
#'
#' When minimised, the status remains available to screen readers. See
#' [mascot_placement()] for restore controls and message timing.
#'
#' In Shiny the mascot uses an input binding. Its input value (`input$<id>`) is an
#' internal record that tells the server the mascot appeared; do not rely on its contents.
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
#' mascot(id = "small", size = 96, placement = "bottom-right")
#' mascot(id = "responsive", size = mascot_size(120, small_screen = 48))
#' mascot(id = "still", motion = FALSE)
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   ui = shiny::fluidPage(mascot(id = "helper")),
#'   server = function(input, output, session) {}
#' )
mascot <- function(
  character = "tessa",
  id,
  mood = "idle",
  status = NULL,
  bubble = NULL,
  size = 160,
  placement = "inline",
  theme = NULL,
  motion = TRUE,
  popup_menu = NULL
) {
  if (missing(id)) {
    # mascot("helper") is the usual slip for Shiny users, who expect the id first.
    looks_like_id <- isTRUE(checkmate::check_string(character)) && !character %in% builtin_characters()$id
    cli::cli_abort(c(
      "{.arg id} is missing; every mascot needs one.",
      "i" = if (looks_like_id) {
        "The first argument is the character. To set the id, name it: {.code mascot(id = \"{character}\")}."
      } else {
        "Supply it by name, such as {.code mascot(id = \"helper\")}."
      }
    ))
  }
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  character <- as_character_arg(character, environment())
  mood <- as_mood_arg(mood, environment())
  status <- as_status_arg(status, environment())
  bubble <- as_bubble_arg(bubble, environment())
  size <- as_size_arg(size, environment())
  placement <- as_placement_arg(placement, environment())
  theme <- as_theme_arg(theme, environment(), character$id)
  motion <- as_motion_arg(motion, environment())
  popup_menu <- as_popup_menu_arg(popup_menu, environment())
  mode <- if (is.null(status$text)) "mood" else "custom"
  tag <- htmltools::tags$div(
    class = "mascot",
    id = id,
    tabindex = "-1",
    `data-character` = character$id,
    `data-mood` = mood$name,
    `data-status` = mode,
    `data-size` = size$size,
    `data-small-screen` = size$small_screen,
    `data-simplify-when-small` = tolower(as.character(size$simplify_when_small)),
    `data-floating` = tolower(as.character(placement_wire(placement)$floating)),
    `data-position` = placement_wire(placement)$position,
    `data-minimise` = tolower(as.character(placement$minimise)),
    `data-reduced` = if (is.null(motion$reduced)) "auto" else "true",
    `data-swap` = tolower(as.character(motion$swap)),
    htmltools::tags$script(
      type = "application/json",
      `data-mascot-character` = character$id,
      htmltools::HTML(character_json(character$id))
    ),
    theme_tag(theme),
    popup_menu_tag(popup_menu),
    htmltools::tags$canvas(
      class = "mascot-canvas",
      role = "img",
      tabindex = "0",
      `aria-label` = paste0(character$name, ", ", mood$name)
    ),
    htmltools::tags$div(
      class = "mascot-status",
      role = "status",
      if (mode == "mood") mood_label(mood$name) else status$text
    ),
    bubble_tag(bubble)
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
  checkmate::assert_choice(
    arg,
    c("character", "mood", "status", "bubble", "gesture", "size", "placement", "theme", "motion", "popup_menu")
  )
  checkmate::assert_environment(call)
  # x is checked by arg_problem(), shared with warning-only runtime validation.
  problem <- arg_problem(x, arg)
  if (is.null(problem)) {
    return(invisible(NULL))
  }
  if (arg %in% c("character", "mood", "gesture") && isTRUE(checkmate::check_string(x, min.chars = 1))) {
    valid <- switch(arg, character = builtin_characters()$id, mood = mood_table()$name, gesture = gesture_table()$name)
    abort_choice(x, valid, arg, arg, call)
  }
  cli::cli_abort("{problem}", call = call)
}

#' A plain-text problem, or NULL for a valid shortcut or helper
#' @noRd
arg_problem <- function(x, arg) {
  checkmate::assert_choice(
    arg,
    c("character", "mood", "status", "bubble", "gesture", "size", "placement", "theme", "motion", "popup_menu")
  )
  # check_* deliberately replaces assert_* for x: runtime values must only warn.
  if (arg == "popup_menu") {
    return(popup_menu_problem(x))
  }
  if (arg == "motion") {
    return(motion_problem(x))
  }
  if (arg == "theme") {
    return(theme_problem(x))
  }
  if (arg == "size") {
    return(size_problem(x))
  }
  if (arg == "placement") {
    return(placement_problem(x))
  }
  helper <- paste0("mascot_", arg)
  if (inherits(x, "mascot_bubble") && arg == "bubble") {
    if (
      !is.list(x) ||
        length(x) != 4L ||
        !setequal(names(x), c("text", "html", "duration", "closable")) ||
        !isTRUE(checkmate::check_string(x$text, min.chars = 1, null.ok = TRUE)) ||
        !isTRUE(checkmate::check_flag(x$html)) ||
        !isTRUE(checkmate::check_number(x$duration, lower = 0)) ||
        x$duration == 0 ||
        !isTRUE(checkmate::check_flag(x$closable))
    ) {
      return("`bubble` must be a mascot_bubble() object with valid text, html, duration and closable fields.")
    }
    return(NULL)
  }
  if (inherits(x, "mascot_gesture") && arg == "gesture") {
    if (!is.list(x) || !isTRUE(checkmate::check_choice(x$name, gesture_table()$name))) {
      return(paste0(
        "`gesture` must name one of ",
        paste(encodeString(gesture_table()$name, quote = '"'), collapse = ", "),
        "; use mascot_gesture()."
      ))
    }
    return(NULL)
  }
  if (arg == "bubble" && inherits(x, c("shiny.tag", "shiny.tag.list"))) {
    return(tryCatch(
      {
        render_bubble_text(x)
        NULL
      },
      error = function(error) conditionMessage(error)
    ))
  }
  if (inherits(x, helper)) {
    return(NULL)
  }
  if (arg %in% c("status", "bubble") && is.null(x)) {
    return(NULL)
  }
  if (!isTRUE(checkmate::check_string(x, min.chars = 1))) {
    if (arg == "bubble") {
      return("`bubble` must be a non-empty string, an htmltools tag or tag list, or a mascot_bubble() object.")
    }
    suffix <- if (arg == "status") "; use mascot_status() to follow the mood" else ""
    return(paste0("`", arg, "` must be a non-empty string or a ", helper, "() object", suffix, "."))
  }
  if (arg %in% c("status", "bubble")) {
    return(NULL)
  }
  valid <- switch(arg, character = builtin_characters()$id, mood = mood_table()$name, gesture = gesture_table()$name)
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
