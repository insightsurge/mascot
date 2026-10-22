#' Launch the interactive mascot studio
#'
#' Explore the package's functions, try their controls with live feedback, and
#' copy the working R code into your own app. The studio is
#' experimental and may change in a later release. Choices belong to the returned
#' app; no global options are changed.
#' @param view Which view to open: `"studio"` (the default) for the studio, one
#'   page per function, `"examples"` for the gallery of bundled examples, or `"theme"`
#'   to theme one character.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param fn A function name in the studio's Guide, without parentheses.
#'   `NULL` starts with `mascot_mood()`. Used in the studio view only.
#' @param character A built-in character id string from the studio's character
#'   selector, or a [mascot_character()] helper for a built-in character.
#'   Defaults to the default character of [mascot()]. A checked character object
#'   or a helper carrying one is refused with advice to use [mascot_preview()]
#'   or [mascot()] to display it. Checked objects come from
#'   [mascot_read_character()] or [mascot_check_character()].
#' @param run A logical flag. `TRUE` launches in an interactive R session;
#'   `FALSE` returns the app without launching it.
#' @returns With `run = FALSE`, a `shiny.appobj` object. With `run = TRUE`,
#'   the value returned by [shiny::runApp()] after the app stops.
#' @family mascot examples
#' @seealso [mascot_example()]
#' @evalRd paste0(
#'   "\\section{Experimental interface}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\n}"
#' )
#' @export
#' @examplesIf requireNamespace("bslib", quietly = TRUE) && utils::packageVersion("bslib") >= "0.6.0"
#' app <- mascot_studio(fn = "mascot_theme", run = FALSE)
#' inherits(app, "shiny.appobj")
mascot_studio <- function(view = "studio", ..., fn = NULL, character = "tessa", run = TRUE) {
  with_mascot_asserts({
    checkmate::assert_string(view)
    checkmate::assert_string(fn, min.chars = 1, null.ok = TRUE)
    character_catalogue_assert(character)
    checkmate::assert_flag(run)
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("fn", "character", "run"), environment())
  }
  if (inherits(character, "mascot_character_data") || inherits(character, "mascot_character")) {
    resolved <- as_character_arg(character, environment())
    if (!is.null(resolved$data)) {
      cli::cli_abort(
        paste0(
          "The studio needs a built-in character id from its selector (or a helper for one). ",
          "Use {.fn mascot_preview} or {.fn mascot} with this checked character object ",
          "or its mascot_character() helper."
        ),
        class = "mascot_error"
      )
    }
    character <- resolved$id
  }
  path <- dirname(mascot_example("studio", run = FALSE))
  guide <- new.env(parent = baseenv())
  sys.source(file.path(path, "R", "guide.R"), envir = guide)
  # The characters the app offers, from its shared data (mascot's public listing only).
  data <- new.env(parent = baseenv())
  sys.source(file.path(path, "R", "shared-data.R"), envir = data)
  views <- new.env(parent = baseenv())
  sys.source(file.path(path, "R", "views.R"), envir = views)
  # These choices are available only after loading the studio data.
  for (arg in c("view", "fn", "character")) {
    value <- get(arg)
    valid <- switch(
      arg,
      view = names(views$studio_view_titles),
      fn = names(guide$playground_guide),
      character = unname(data$studio_characters())
    )
    if (!is.null(value) && !value %in% valid) abort_choice(value, valid, arg, arg, environment())
  }
  app <- shiny::shinyAppDir(path)
  handler <- app$httpHandler
  # A function the caller named opens on its Guide; without one the studio starts on the canvas.
  initial <- list(
    view = view,
    fn = if (is.null(fn)) "mascot_mood" else fn,
    character = character,
    open = if (is.null(fn) || view != "studio") "" else "guide"
  )
  # The page request carries per-app defaults to its UI. Explicit navigation links
  # override them; the mounted inputs carry them to the WebSocket session.
  app$httpHandler <- function(request) {
    checkmate::assert(checkmate::check_list(request), checkmate::check_environment(request), .var.name = "request")
    query <- shiny::parseQueryString(if (is.null(request$QUERY_STRING)) "" else request$QUERY_STRING)
    values <- utils::modifyList(initial, query)
    request$QUERY_STRING <- paste(
      names(values),
      vapply(values, utils::URLencode, character(1), reserved = TRUE),
      sep = "=",
      collapse = "&"
    )
    handler(request)
  }
  if (!run) {
    return(app)
  }
  if (!example_interactive()) {
    cli::cli_abort(
      c(
        "Running {.fn mascot_studio} needs an interactive R session.",
        "i" = "Use {.code mascot_studio(run = FALSE)} to return the app."
      ),
      class = "mascot_error"
    )
  }
  shiny::runApp(app)
}
