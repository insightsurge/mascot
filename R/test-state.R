#' Read a mascot's settled state in a browser test
#'
#' Wait for a mascot element in a running `shinytest2::AppDriver` session to
#' mount and settle, then read the character, mood, status text, bubble and
#' minimised state currently shown in the browser. Intended for
#' `shinytest2` end-to-end tests.
#'
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts name, arguments and return structure may change in a later release.\n}"
#' )
#' @param app A `shinytest2::AppDriver` object for a running Shiny app.
#' @param id Non-empty character string giving the mascot's full DOM id in the
#'   rendered page (for example `"helper"` at the top level or `"form-helper"`
#'   inside a module with id `"form"`).
#' @param ... Must be empty. Supply `timeout` by name so a typo fails instead
#'   of matching silently.
#' @param timeout Maximum number of milliseconds to wait for the mascot to mount
#'   and finish any active transition, defaulting to `5000`.
#' @returns A named list with six elements reflecting what the visitor actually
#'   sees:
#'   - `id`: the mascot's DOM id string.
#'   - `character`: the shown character id string (such as `"tessa"`).
#'   - `mood`: the shown mood id string (including active browser overlays
#'     from [watch_mascot_shiny()]).
#'   - `status`: the status text displayed beside the mascot, or `NULL` if no
#'     status element was found.
#'   - `bubble`: `NULL` when no bubble is visible, or a list with `text`,
#'     `html`, `closable`, and `duration` (`Inf` for a lasting bubble).
#'   - `minimised`: logical flag indicating whether a floating mascot is
#'     currently minimised.
#' @details
#' Unlike [mascot_server_state()], which inspects R session state without a
#' browser, `mascot_test_state()` queries the mounted DOM and host controller in
#' headless Chrome via `app$wait_for_js()` and `app$get_js()`. Inside a Shiny
#' module, pass the namespaced DOM id (for example `"panel-helper"`).
#'
#' `shinytest2` is suggested rather than imported, so this function raises an
#' error if `shinytest2` is not installed. If no mascot with `id` settles within
#' `timeout` milliseconds, it raises a `mascot_error` naming both `id` and
#' `timeout`.
#' @family mascots in Shiny
#' @seealso [mascot_server_state()], [watch_mascot_shiny()], [update_mascot()]
#' @export
#' @examplesIf interactive()
#' app <- shinytest2::AppDriver$new(
#'   shiny::shinyApp(
#'     shiny::fluidPage(
#'       mascot("helper"),
#'       shiny::actionButton("save", "Save")
#'     ),
#'     function(input, output, session) {
#'       shiny::observeEvent(input$save, {
#'         update_mascot("helper", mood = "happy", status = "Saved")
#'       })
#'     }
#'   )
#' )
#' app$click("save")
#' state <- mascot_test_state(app, "helper", timeout = 5000)
#' state$mood
#' state$status
#' app$stop()
mascot_test_state <- function(
  app,
  id,
  ...,
  timeout = 5000
) {
  if (missing(app)) {
    cli::cli_abort(
      c(
        "{.arg app} is missing; supply a {.cls AppDriver} object.",
        "i" = "For example, {.code mascot_test_state(app, \"helper\")}."
      ),
      class = "mascot_error"
    )
  }
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; supply the mascot DOM id to inspect.",
        "i" = "For example, {.code mascot_test_state(app, \"helper\")}."
      ),
      class = "mascot_error"
    )
  }
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      "timeout",
      environment()
    )
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
    checkmate::assert_number(timeout, lower = 0, finite = TRUE)
  })
  if (!test_state_has_shinytest2()) {
    cli::cli_abort(
      c(
        "{.pkg shinytest2} is needed for {.fn mascot_test_state}.",
        "i" = "Install it with {.code install.packages(\"shinytest2\")}."
      ),
      class = "mascot_error"
    )
  }
  with_mascot_asserts({
    checkmate::assert_class(app, "AppDriver")
  })
  id_json <- as.character(jsonlite::toJSON(id, auto_unbox = TRUE))
  wait_script <- paste0(
    "(() => { const el = document.getElementById(",
    id_json,
    "); ",
    "const st = el && window.mascot && window.mascot.host ? window.mascot.host.state(el) : null; ",
    "return Boolean(st && st.character && (!st.current || !st.current.swapping)); })()"
  )
  tryCatch(
    app$wait_for_js(wait_script, timeout = timeout),
    error = function(error) {
      cli::cli_abort(
        c(
          "Mascot {.val {id}} did not settle in the browser within {timeout} ms.",
          "x" = "{conditionMessage(error)}"
        ),
        class = "mascot_error"
      )
    }
  )
  read_script <- paste0(
    "(() => { const el = document.getElementById(",
    id_json,
    "); ",
    "if (!el || !window.mascot || !window.mascot.host) return null; ",
    "const st = window.mascot.host.state(el); if (!st) return null; ",
    "const statusEl = el.querySelector('.mascot-status'); ",
    "return { ",
    "id: el.id, ",
    "character: st.current ? st.current.character : (el.dataset.shownCharacter || st.character || null), ",
    "mood: el.dataset.shownMood || (st.current ? st.current.mood : st.mood) || null, ",
    "status: statusEl ? statusEl.textContent : null, ",
    "bubble: st.bubble || null, ",
    "minimised: Boolean(st.minimised) ",
    "}; })()"
  )
  raw <- app$get_js(read_script)
  if (!is.list(raw) || is.null(raw$id)) {
    cli::cli_abort(
      "Mascot {.val {id}} is no longer mounted in the browser.",
      class = "mascot_error"
    )
  }
  bubble <- if (is.null(raw$bubble)) {
    NULL
  } else {
    list(
      text = raw$bubble$text,
      html = isTRUE(raw$bubble$html),
      closable = isTRUE(raw$bubble$closable),
      duration = if (is.null(raw$bubble$duration)) Inf else as.numeric(raw$bubble$duration)
    )
  }
  list(
    id = raw$id,
    character = raw$character,
    mood = raw$mood,
    status = raw$status,
    bubble = bubble,
    minimised = isTRUE(raw$minimised)
  )
}

#' @noRd
test_state_has_shinytest2 <- function() {
  requireNamespace("shinytest2", quietly = TRUE)
}
