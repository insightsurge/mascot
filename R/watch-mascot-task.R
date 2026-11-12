#' Watch a Shiny extended task and update a mascot automatically
#'
#' Bind a [shiny::ExtendedTask] to a mascot so its status transitions
#' (`"initial"`, `"running"`, `"success"`, and `"error"`) update the mascot
#' automatically through [update_mascot()].
#'
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts arguments, default map and return value may change in a later release.\n}"
#' )
#' @inheritParams update_mascot
#' @param task A [shiny::ExtendedTask] object created with
#'   [shiny::ExtendedTask]`$new()`.
#' @param ... Must be empty. Supply `map` and `session` by name so a typo fails
#'   instead of matching silently.
#' @param map Optional overrides for the default state map, given as a named
#'   character vector of mood ids or a named list of [update_mascot()] update
#'   lists (same entry format as [watch_mascot()]). Allowed keys are
#'   `"initial"`, `"running"`, `"success"`, and `"error"`. Provided keys merge
#'   field-by-field onto the defaults; pass an empty `list()` for a key (for
#'   example `list(initial = list())`) to leave the mascot unchanged in that
#'   state.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @returns Invisibly returns the [shiny::observe()] observer that drives the
#'   updates. Call `$destroy()` on it to stop watching early.
#' @details
#' By default, `watch_mascot_task()` maps `task$status()` as:
#'
#' - `"initial"`: `mood = "idle"`, `status = "Ready"`
#' - `"running"`: `mood = "thinking"`, `status = "Running task"`
#' - `"success"`: `mood = "happy"`, `status = "Task complete"`
#' - `"error"`: `mood = "worried"`, `status = "Task failed"`
#'
#' Overrides in `map` apply per key and per field. Passing
#' `c(success = "celebrating")` changes only the mood on success while keeping
#' `status = "Task complete"`; passing `list(running = list(status = "Fitting"))`
#' changes only the status text while keeping `mood = "thinking"`.
#'
#' Updates are dispatched via [update_mascot()], so manual `update_mascot()`
#' calls and watchers follow the same path: whichever runs last wins. Inside a
#' Shiny module, pass the module's local mascot `id` (the same as in
#' [update_mascot()]).
#' @family mascots in Shiny
#' @seealso [watch_mascot()], [update_mascot()], [mascot_server_state()]
#' @export
#' @examples
#' shiny::testServer(
#'   function(input, output, session) {
#'     task <- shiny::ExtendedTask$new(function() "done")
#'     watch_mascot_task(
#'       "helper",
#'       task,
#'       map = list(running = list(status = "Checking"))
#'     )
#'     shiny::observeEvent(input$run, task$invoke())
#'   },
#'   {
#'     session$flushReact()
#'     mascot_server_state("helper")[c("mood", "status")]
#'     session$setInputs(run = 1)
#'     session$flushReact()
#'     mascot_server_state("helper")[c("mood", "status")]
#'     if (requireNamespace("later", quietly = TRUE)) {
#'       while (!later::loop_empty()) later::run_now()
#'       session$flushReact()
#'       mascot_server_state("helper")[c("mood", "status")]
#'     }
#'   }
#' )
watch_mascot_task <- function(
  id,
  task,
  ...,
  map = NULL,
  session = shiny::getDefaultReactiveDomain()
) {
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; supply the mascot id to watch.",
        "i" = "For example, {.code watch_mascot_task(\"helper\", task)}."
      ),
      class = "mascot_error"
    )
  }
  if (missing(task)) {
    cli::cli_abort(
      "{.arg task} is missing; supply a {.cls ExtendedTask} object.",
      class = "mascot_error"
    )
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
    checkmate::assert_class(task, "ExtendedTask")
    checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      "map, session",
      environment()
    )
  }
  if (is.null(session)) {
    cli::cli_abort(
      "{.fn watch_mascot_task} must be called inside a Shiny server function or module.",
      class = "mascot_error"
    )
  }
  entries <- merge_watch_map(task_default_map(), map, "watch_mascot_task", environment())
  force(id)
  force(task)
  force(session)
  obs <- shiny::observe(
    {
      status <- task$status()
      if (is.character(status) && length(status) == 1L && !is.na(status) && status %in% names(entries)) {
        watch_mascot_dispatch(id, entries[[status]], session)
      }
    },
    domain = session
  )
  invisible(obs)
}

#' Default state-to-update map for `watch_mascot_task()`
#' @noRd
task_default_map <- function() {
  list(
    initial = list(mood = "idle", status = "Ready"),
    running = list(mood = "thinking", status = "Running task"),
    success = list(mood = "happy", status = "Task complete"),
    error = list(mood = "worried", status = "Task failed")
  )
}
