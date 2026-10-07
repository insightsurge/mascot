#' Update a mascot in a Shiny app
#'
#' Apply a character, mood and status together. Invalid values warn and leave
#' the mascot unchanged. In Shiny development mode they also show a worried
#' mascot with the problem as its status; the next good update clears it.
#' Updates sent before a mascot appears are kept until it appears.
#'
#' @inheritParams mascot
#' @param character A character name or [mascot_character()] object. `NULL`
#'   (the default) leaves the character unchanged.
#' @param mood A mood name or [mascot_mood()] object. `NULL` (the default)
#'   leaves the mood unchanged.
#' @param status A non-empty string or [mascot_status()] object. `NULL`
#'   (the default) leaves the status unchanged; `mascot_status()` hands the
#'   status back to the mood. Text is always escaped.
#' @param ... Must be empty. Extra arguments are errors.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @details
#' In a module use `mascot(id = ns("helper"))` in the UI, and
#' `updateMascot("helper")` in its server. The session namespace is added once.
#' An invalid `id` type, missing session or extra argument is an error.
#' Calling with all update fields `NULL` does nothing.
#'
#' Updates sent before a mascot appears are kept for it, as long as one mascot is
#' already on the page. If every mascot in the app is created later (for example
#' by [shiny::renderUI()]), updates sent before the first one appears are lost;
#' keep one mascot in the static UI.
#' @returns Called for its side effect; returns `NULL` invisibly.
#' @family mascots in Shiny
#' @seealso [mascot()]
#' @export
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   ui = shiny::fluidPage(
#'     mascot(id = "helper"),
#'     shiny::actionButton("work", "Think"),
#'     shiny::actionButton("done", "Finish")
#'   ),
#'   server = function(input, output, session) {
#'     shiny::observeEvent(input$work, {
#'       updateMascot("helper", mood = "thinking", status = "Working")
#'     })
#'     shiny::observeEvent(input$done, {
#'       updateMascot("helper", mood = "happy", status = mascot_status())
#'     })
#'   }
#' )
updateMascot <- function(
  id,
  character = NULL,
  mood = NULL,
  status = NULL,
  ...,
  session = shiny::getDefaultReactiveDomain()
) {
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  if (...length() > 0L) {
    extras <- names(substitute(list(...)))[-1L]
    if (is.null(extras)) {
      extras <- rep("unnamed", ...length())
    }
    extras[extras == ""] <- "unnamed"
    cli::cli_abort(c(
      "Unexpected arguments: {.val {extras}}.",
      "i" = paste(
        "Use {.arg id}, {.arg character}, {.arg mood}, {.arg status} and {.arg session};",
        "{.arg session} must be named."
      )
    ))
  }
  if (is.null(session)) {
    cli::cli_abort("{.fn updateMascot} must be called inside a Shiny server function or module.")
  }
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  # Runtime values deliberately use check_* through arg_problem(): a bad value warns.
  values <- list(character = character, mood = mood, status = status)
  problems <- unlist(
    lapply(names(values), function(arg) {
      if (!is.null(values[[arg]])) arg_problem(values[[arg]], arg)
    }),
    use.names = FALSE
  )
  if (length(problems)) {
    cli::cli_warn(c(
      "{.fn updateMascot} left mascot {.val {id}} unchanged.",
      structure(paste0("{problems[[", seq_along(problems), "]]}"), names = rep("x", length(problems)))
    ))
    if (dev_mode()) {
      send_update(session, id, list(problem = paste0("mascot: ", paste(problems, collapse = "; "))))
    }
    return(invisible(NULL))
  }
  patch <- list()
  if (!is.null(character)) {
    ch <- as_character_arg(character, environment())
    patch$character <- list(id = ch$id, name = ch$name, json = character_json(ch$id))
  }
  if (!is.null(mood)) {
    patch$mood <- as_mood_arg(mood, environment())$name
  }
  if (!is.null(status)) {
    text <- as_status_arg(status, environment())$text
    patch$status <- if (is.null(text)) list(mode = "mood") else list(mode = "custom", text = text)
  }
  if (length(patch)) {
    send_update(session, id, patch)
  }
  invisible(NULL)
}

#' Send one update, applying the module namespace once
#' @noRd
send_update <- function(session, id, patch) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  checkmate::assert_list(patch, names = "unique")
  session$sendCustomMessage("mascot:update", list(id = session$ns(id), patch = patch))
}

#' Whether client-side problem messages should be shown
#' @noRd
dev_mode <- function() {
  shiny::in_devmode()
}
