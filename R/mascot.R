#' Add a mascot to a page
#'
#' Draw a character with a mood, a status line and an optional message bubble.
#' The status shows the character's line for the mood until the app sets its own
#' text (the `status` column of `mascot_moods(character)`).
#' It follows the mood again when [mascot_status()] is supplied without text.
#'
#' @param id A required non-empty string without whitespace, unique on the
#'   page. In a Shiny module use `ns("helper")` in the UI and `"helper"` in
#'   the server; [update_mascot()] adds the module namespace once.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param character A character id such as `"tessa"`, or a [mascot_character()]
#'   helper (Knurl and Neer are experimental). Defaults to `"tessa"`. `NULL` is not accepted.
#' @param mood A mood name or [mascot_mood()] object. Defaults to `"idle"`.
#'   See [mascot_moods()] for available choices. `NULL` is not accepted.
#' @param status A non-empty string or [mascot_status()] object. `NULL` (the
#'   default) follows the mood. Text is escaped, including [htmltools::HTML()].
#' @param bubble A non-empty string, an `htmltools` tag or tag list, or a
#'   [mascot_bubble()] object. `NULL` (the default) shows no bubble. A string
#'   uses the helper's five-second duration and close button. Plain text is
#'   escaped; [htmltools::HTML()] or tags supply HTML. Tags with dependencies or
#'   head content are not supported.
#' @param size A finite number of CSS pixels (at least `24`), a positive
#'   percentage string such as `"20%"`, or a [mascot_size()] object. Defaults to
#'   `160`. Percentages follow the parent width when inline and the window width
#'   when floating, with a 24-pixel floor. On screens at most 575.98 CSS pixels
#'   wide, floating mascots scale down to a phone size by default (`"auto"`),
#'   while inline mascots stay unchanged. Pass [mascot_size()] with
#'   `small_screen = NULL` to keep the same size everywhere. `NULL` is not
#'   accepted.
#' @param placement `"bottom-right"` (the default), `"inline"`, a corner
#'   such as `"top-left"`, a named list such as `list(position = "top-left",
#'   minimise = TRUE, drag = "snap")`, or a [mascot_placement()] object.
#'   Floating mascots show a minimise control by default; dragging is off.
#'   Inline mascots sit in the page flow and ignore `minimise` and `drag`, with an
#'   informational message for explicitly supplied values and silence for
#'   defaults. With `drag`, visitors can also drag the minimised restore button;
#'   each drop sets `input$<id>_position` to the corner (`"snap"`) or a list with
#'   `x` and `y` (`"free"`); saving it between visits is the app's job. See
#'   [mascot_placement()]. `NULL` is not accepted.
#' @param theme A palette id string from [mascot_palettes()], a named list of colour roles, a [bslib::bs_theme()] or a
#'   [mascot_theme()] object. `NULL` (the default) keeps the character's own
#'   colours. A palette supplies the base colours in both modes; `"original"`
#'   selects the character's own colours. Unset roles follow the character's rules.
#' @param motion A logical flag or [mascot_motion_settings()] object. `TRUE` (the default)
#'   allows movement while honouring the visitor's reduced-motion preference.
#'   `FALSE` stops all movement, including panels, drag snapping, minimising and
#'   restoring. `NULL` is not accepted.
#' @param click What a click on the mascot does in a Shiny app. `NULL` (the
#'   default) does nothing: the mascot is a picture, not a keyboard stop. One
#'   label containing a non-whitespace character, such as `"Open help"`, or a
#'   [mascot_action()] object makes it a button for one action of your app.
#'   A [mascot_popup_menu()] object makes it open a menu, whose choice sets
#'   `input$<id>_menu`. With a click, every
#'   action activation sets `input$<id>_click` (see Details).
#' @returns An `htmltools` tag with the mascot's web dependency attached.
#' @family mascots in Shiny
#' @seealso [update_mascot()]
#' @details
#' `NULL` means none or the default in [mascot()] and helpers where accepted,
#' and unchanged in [update_mascot()]. An empty helper (`mascot_bubble()`,
#' `mascot_status()`, `mascot_theme()`, `mascot_action()` or
#' `mascot_popup_menu()`) resets that setting.
#'
#' Building UI with [mascot()] or helpers errors on invalid values;
#' [update_mascot()] warns and leaves the mascot unchanged. See
#' [mascot-package] for condition classes.
#'
#' Use the always visible status line for a short description of the current state.
#' Use a bubble for a message about something that happened; it may time out.
#' Use `mascot_bubble(..., duration = Inf)` for a message the user must act on,
#' such as an invalid form, because a timed message can vanish before it is read.
#'
#' When minimised, the status remains available to screen readers. See
#' [mascot_placement()] for restore controls and message timing.
#'
#' In Shiny the mascot uses an input binding. Its input value (`input$<id>`) is an
#' internal value that tells the server the mascot appeared; do not rely on its contents.
#'
#' **In modules, `golem` and rhino apps.** Use the module's `ns()` in the UI and
#' its local id in the server. `session$ns("helper")` also works in the server;
#' the namespace is added once. In nested modules, namespace the child module's
#' id in the parent UI and call its server with the local child id. Inputs such
#' as `input$helper_menu`, `input$helper_click`, `input$helper_position` and
#' `input$helper_minimised` belong to that child module.
#' A module can put the mascot in its UI and update it from its server:
#' ```r
#' helper_ui <- function(id) {
#'   ns <- shiny::NS(id)
#'   mascot(ns("helper"))
#' }
#' helper_server <- function(id) {
#'   shiny::moduleServer(id, function(input, output, session) {
#'     update_mascot("helper", mood = "happy")
#'   })
#' }
#' ```
#'
#' The same pattern works in the function-built `app_ui()` of a `golem` app and in
#' rhino's `app/view/` modules using [shiny::moduleServer()]. The engine's
#' scripts and styles are attached through [htmltools::htmlDependency()],
#' including with [shiny::renderUI()], and shared by mascots on the page.
#' A built-in character's data travels the same way, once per page for each
#' character in use; a custom character's data stays inside its own tag.
#' No app-side copying of engine files is needed. Try
#' `mascot_example("golem")` (requires `golem`) or `mascot_example("rhino")`
#' (a plain Shiny structure without rhino or box).
#'
#' **Showing the mascot later.** To add the mascot only when it is needed, build
#' it in the server with [shiny::renderUI()] and place [shiny::uiOutput()] in the
#' UI. Updates sent before it appears are kept until it does, so the first
#' `update_mascot()` can run in the same observer:
#' ```r
#' library(shiny)
#' library(mascot)
#'
#' ui <- fluidPage(
#'   actionButton("start", "Start the review"),
#'   actionButton("finish", "Finish"),
#'   uiOutput("helper_ui")
#' )
#'
#' server <- function(input, output, session) {
#'   shown <- reactiveVal(FALSE)
#'   output$helper_ui <- renderUI({
#'     req(shown())
#'     mascot("helper", status = "Reviewing")
#'   })
#'   observeEvent(input$start, {
#'     shown(TRUE)
#'     # Sent before the mascot exists: kept until it appears.
#'     update_mascot("helper", mood = "thinking")
#'   })
#'   observeEvent(input$finish, {
#'     update_mascot("helper", mood = "happy", status = "Review complete")
#'   })
#' }
#'
#' shinyApp(ui, server)
#' ```
#' The `reactiveVal()` makes the mascot appear once: clicking **Start the
#' review** again does not rebuild it, so it keeps its mood and position.
#'
#' **Clicks.** With `click`, the mascot is a button: an action named by its
#' label, or a menu. Every action activation (a click or tap, Enter or Space while
#' it has keyboard focus, or a screen reader's activate command) sets
#' `input$<id>_click` to the number of activations since the mascot appeared, so
#' `shiny::observeEvent(input$helper_click, ...)` runs each time for an action.
#' Opening and closing a menu never sets this input. Dragging a floating mascot
#' never counts as a click. See [mascot_action()] and [mascot_popup_menu()].
#' @export
#' @examples
#' ui <- mascot("helper", mood = "happy")
#' ui <- mascot("small", size = 96, placement = "bottom-right")
#' ui <- mascot("responsive", size = mascot_size(120, small_screen = 48))
#' ui <- mascot("still", motion = FALSE)
#' ui <- mascot("helpful", click = "Open help")
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   ui = shiny::fluidPage(mascot("helper")),
#'   server = function(input, output, session) {}
#' )
mascot <- function(
  id,
  ...,
  character = "tessa",
  mood = "idle",
  status = NULL,
  bubble = NULL,
  size = 160,
  placement = "bottom-right",
  theme = NULL,
  motion = TRUE,
  click = NULL
) {
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; every mascot needs one.",
        "i" = "Supply an id, such as {.code mascot(\"helper\")}."
      ),
      class = "mascot_error"
    )
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  })
  character <- as_character_arg(character, environment())
  mood <- as_mood_arg(mood, environment(), character)
  known_moods <- mascot_moods(if (is.null(character$data)) character$id else character$data)$name
  if (!mood$name %in% known_moods) {
    abort_choice(mood$name, known_moods, "mood", "mood", environment())
  }
  status <- as_status_arg(status, environment())
  bubble <- as_bubble_arg(bubble, environment())
  size <- as_size_arg(size, environment())
  placement <- as_placement_arg(placement, environment())
  theme <- as_theme_arg(theme, environment(), if (is.null(character$data)) character$id else character$data)
  motion <- as_motion_arg(motion, environment())
  click <- as_click_arg(click, environment())
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      c("character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click"),
      environment()
    )
  }
  mode <- if (is.null(status$text)) "mood" else "custom"
  placement_fields <- placement_wire(placement)
  wire_character <- list(
    id = character$id,
    name = character$name,
    json = if (is.null(character$json)) character_json(character$id) else character$json
  )
  baseline <- list(
    character = wire_character,
    mood = mood$name,
    status = if (mode == "mood") list(mode = "mood") else list(mode = "custom", text = status$text),
    bubble = if (is.null(bubble$text)) {
      list(clear = TRUE)
    } else {
      list(
        text = bubble$text,
        html = bubble$html,
        closable = bubble$closable,
        duration = if (is.finite(bubble$duration)) bubble$duration else NULL
      )
    },
    size = unclass(size),
    placement = placement_fields,
    theme = if (is.null(theme)) mascot_empty_theme() else theme,
    motion = motion,
    click = if (is.null(click)) list(type = "none") else click
  )
  # UI mistakes fail during construction; only a validated ready establishes
  # this emitted specification as the session's baseline.
  public_call <- environment()
  prepared <- tryCatch(
    {
      mascot_wire_check(baseline)
      mascot_state_prepare(list(desired = list(), context = NULL), baseline)
    },
    error = function(error) {
      # Keep every field the original condition carries, not a fixed list.
      standard <- c("message", "trace", "parent", "rlang", "call", "use_cli_format", "body", "footer", "header")
      fields <- unclass(error)[setdiff(names(error), standard)]
      do.call(
        cli::cli_abort,
        c(
          list(
            "{conditionMessage(error)}",
            class = unique(c(class(error)[startsWith(class(error), "mascot_error")], "mascot_error")),
            call = public_call
          ),
          fields
        )
      )
    }
  )
  token <- mascot_mount_token(id, prepared$desired)
  shown_status <- if (mode == "mood") character_catalogue_status(prepared$context$data, mood$name) else status$text
  tag <- htmltools::tags$div(
    class = "mascot",
    id = id,
    tabindex = "-1",
    `data-mount-token` = token,
    `data-character` = character$id,
    `data-mood` = mood$name,
    `data-status` = mode,
    `data-size` = size$size,
    `data-small-screen` = size$small_screen,
    `data-floating` = tolower(as.character(placement_fields$floating)),
    `data-position` = placement_fields$position,
    `data-minimise` = tolower(as.character(placement_fields$minimise)),
    `data-drag` = tolower(as.character(placement_fields$drag)),
    `data-reduced` = if (is.null(motion$reduced)) "auto" else "true",
    `data-idle` = tolower(as.character(motion$idle)),
    `data-mood-change` = tolower(as.character(motion$mood_change)),
    `data-gestures` = tolower(as.character(motion$gestures)),
    `data-swap` = tolower(as.character(motion$swap)),
    `data-minimising` = tolower(as.character(motion$minimising)),
    `data-restoring` = tolower(as.character(motion$restoring)),
    `data-messages` = paste(unlist(motion$messages), collapse = ","),
    `data-others` = tolower(as.character(motion$others)),
    `data-mascot-version` = getNamespaceVersion("mascot")[[1]],
    # A custom character's data stays in its tag; a built-in one's arrives once per page with character_dependency().
    if (!is.null(character$json)) {
      htmltools::tags$script(
        type = "application/json",
        `data-mascot-character` = character$id,
        htmltools::HTML(gsub("</", "<\\/", character$json, fixed = TRUE))
      )
    },
    mascot_baseline_tag(prepared$desired, token),
    theme_tag(theme),
    click_tag(click),
    # A picture until a click makes it a button; the browser then wraps it in one.
    htmltools::tags$canvas(
      class = "mascot-canvas",
      role = "img",
      `aria-label` = paste0(character$name, ", ", shown_status)
    ),
    htmltools::tags$div(
      class = "mascot-status",
      role = "status",
      shown_status
    ),
    bubble_tag(bubble)
  )
  htmltools::attachDependencies(
    tag,
    c(list(mascot_dependency()), if (is.null(character$json)) list(character_dependency(character$id)))
  )
}

#' Add mascot's error class to checkmate assertion failures
#' @noRd
with_mascot_asserts <- function(code, call = parent.frame()) {
  checkmate::assert_environment(call)
  # code is a promise: evaluating it for validation would run the assertions twice.
  withCallingHandlers(
    code,
    error = function(error) {
      checkmate::assert_class(error, "error")
      # Checkmate uses simple errors, without a dedicated assertion class.
      # Match its assertion prefix so unrelated errors in promises pass through.
      message <- conditionMessage(error)
      assertion <- any(startsWith(message, c("Assertion on '", "One of the following assertions failed:")))
      if (!inherits(error, "simpleError") || !assertion) {
        return(invisible(NULL))
      }
      # No parent: the original message is displayed once. Each line of a multi-line union message
      # stays its own line; braces are escaped so cli shows them as text. checkmate's simpleError class
      # is dropped: placed before rlang_error, its conditionMessage() method would hide every line but
      # the first.
      lines <- strsplit(message, "\n", fixed = TRUE)[[1]]
      lines <- gsub("}", "}}", gsub("{", "{{", lines, fixed = TRUE), fixed = TRUE)
      names(lines) <- c("", rep(" ", length(lines) - 1L))
      cli::cli_abort(lines, class = "mascot_error", call = call)
    }
  )
}

#' Accept a character shortcut or helper
#' @noRd
as_character_arg <- function(x, call) {
  checkmate::assert_environment(call)
  with_mascot_asserts(character_catalogue_assert(x), call = call)
  data <- character_catalogue_resolve(if (inherits(x, "mascot_character") && !is.null(x$data)) x$data else x, call)
  if (character_catalogue_is_builtin(data$id)) {
    return(structure(list(id = data$id, name = data$name), class = "mascot_character"))
  }
  structure(
    list(id = data$id, name = data$name, data = data, json = character_json_write(data)),
    class = "mascot_character"
  )
}

#' Accept a mood shortcut or helper
#' @noRd
as_mood_arg <- function(x, call, character = NULL) {
  checkmate::assert_environment(call)
  if (!is.null(character)) {
    character_catalogue_assert(character)
  }
  # See as_character_arg(): this argument accepts a union of types.
  check_arg(x, "mood", call, character)
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
check_arg <- function(x, arg, call, character = NULL) {
  checkmate::assert_choice(arg, c("mood", "status", "bubble", "size", "placement", "theme", "motion", "click"))
  checkmate::assert_environment(call)
  if (!is.null(character)) {
    character_catalogue_assert(character)
  }
  # x is checked by arg_problem(), shared with warning-only runtime validation.
  problem <- arg_problem(x, arg)
  if (is.null(problem)) {
    return(invisible(NULL))
  }
  if (arg == "mood" && !is.null(character)) {
    valid <- mascot_moods(character)$name
    cli::cli_abort(
      c("{problem}", "i" = "Choose {.or {.val {valid}}}."),
      call = call,
      class = c("mascot_error_choice", "mascot_error"),
      argument = arg,
      choices = valid,
      value = x
    )
  }
  cli::cli_abort("{problem}", call = call, class = "mascot_error")
}

#' Stop when a helper's `...` caught arguments
#' @noRd
abort_dots <- function(extras, n, valid, call) {
  checkmate::assert_character(extras, null.ok = TRUE)
  checkmate::assert_count(n, positive = TRUE)
  checkmate::assert_character(valid, min.chars = 1, any.missing = FALSE, min.len = 1)
  checkmate::assert_environment(call)
  # Unnamed values have no name; positional values after `...` are the usual slip.
  extras <- if (is.null(extras)) rep("", n) else extras
  unnamed <- sum(!nzchar(extras))
  labels <- c(
    if (unnamed == 1L) {
      "an unnamed argument"
    } else if (unnamed > 1L) {
      paste(unnamed, "unnamed arguments")
    },
    encodeString(extras[nzchar(extras)], quote = '"')
  )
  message <- paste0(
    "Unexpected arguments: ",
    paste(labels, collapse = ", "),
    "."
  )
  message <- gsub("}", "}}", gsub("{", "{{", message, fixed = TRUE), fixed = TRUE)
  cli::cli_abort(
    c(message, "i" = "Name the optional arguments: {.arg {valid}}."),
    call = call,
    class = c("mascot_error_dots", "mascot_error"),
    names = extras
  )
}

#' A plain-text problem, or NULL for a valid shortcut or helper
#' @noRd
arg_problem <- function(x, arg) {
  checkmate::assert_choice(
    arg,
    c("character", "mood", "status", "bubble", "gesture", "size", "placement", "theme", "motion", "click")
  )
  # check_* deliberately replaces assert_* for x: runtime values must only warn.
  if (arg == "click") {
    return(click_problem(x))
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
  if (arg == "character") {
    return(tryCatch(
      {
        as_character_arg(x, environment())
        NULL
      },
      error = function(error) conditionMessage(error)
    ))
  }
  if (arg %in% c("mood", "gesture")) {
    value <- if (inherits(x, paste0("mascot_", arg))) x$name else x
    if (isTRUE(checkmate::check_string(value, pattern = "^[a-z][a-z0-9_]*$"))) {
      return(NULL)
    }
    if (!isTRUE(checkmate::check_string(value, min.chars = 1))) {
      return(paste0("`", arg, "` must be a non-empty string or a mascot_", arg, "() object."))
    }
    return(paste0("`", arg, "` must be a lowercase id; ", encodeString(value, quote = '"'), " is not a ", arg, "."))
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
  NULL
}

#' Offline runtime dependency
#'
#' The first script carries the package version in `data-mascot-version`, so the engine knows its own version
#' (`window.mascot.version`) on every page the dependency renders into: Shiny apps, `mascot_preview()` and Quarto or
#' R Markdown pages. Each `mascot()` element carries the same attribute, for pages that drop the script's attributes
#' (pandoc before 3.7.0.2 does when it embeds scripts in a self-contained page).
#' @noRd
mascot_dependency <- function() {
  version <- getNamespaceVersion("mascot")[[1]]
  files <- c(
    "mascot.js",
    "mascot-parts.js",
    "mascot-geometry.js",
    "mascot-faces.js",
    "mascot-motion.js",
    "mascot-player.js",
    "mascot-host.js"
  )
  scripts <- lapply(files, function(file) list(src = file))
  scripts[[1]]$`data-mascot-version` <- version
  htmltools::htmlDependency(
    name = "mascot",
    version = version,
    src = "www",
    package = "mascot",
    script = scripts,
    stylesheet = "mascot.css",
    all_files = FALSE
  )
}
