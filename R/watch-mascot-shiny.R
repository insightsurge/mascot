#' Make a mascot react to Shiny browser events automatically
#'
#' Connect a mascot in the UI to Shiny browser events so busy cycles,
#' output errors and lost connections show as temporary overlays without
#' overwriting what [update_mascot()] last set on the server.
#'
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts arguments, default map and return value may change in a later release.\n}"
#' )
#' @inheritParams update_mascot
#' @param ... Must be empty. Supply `map`, `delay` and `session` by name so a
#'   typo fails instead of matching silently.
#' @param map Optional overrides for the default browser event map, given as a
#'   named character vector of mood ids or a named list of overlay entries with
#'   `mood` and `status` (same entry format as [watch_mascot()]). Allowed keys
#'   are `"busy"`, `"idle"`, `"error"`, and `"disconnected"`. Provided keys
#'   merge field-by-field onto the defaults; pass an empty `list()` for a key
#'   (for example `list(error = list())`) to ignore that event.
#' @param delay Non-negative finite number of seconds Shiny must stay busy
#'   before showing the `"busy"` overlay, defaulting to `1`. A fast update that
#'   finishes before `delay` elapses leaves the mascot undisturbed. Use `0` to
#'   show `"busy"` immediately on `shiny:busy`.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @returns Called for its side effect in the browser; returns `NULL`
#'   invisibly.
#' @details
#' By default, `watch_mascot_shiny()` maps Shiny browser events as:
#'
#' - `"busy"` (`shiny:busy` after `delay` seconds): `mood = "thinking"`,
#'   `status = "Working..."`
#' - `"idle"` (`shiny:idle`): empty `list()`, clearing any active `"busy"`
#'   overlay so whatever [update_mascot()] or [mascot()] last set shows again
#' - `"error"` (`shiny:error`): `mood = "worried"`,
#'   `status = "An error occurred"` (stays active until every failed output
#'   produces a value again via `shiny:value`)
#' - `"disconnected"` (`shiny:disconnected`): `mood = "worried"`,
#'   `status = "Connection lost. Reload the page to continue."`
#'
#' When events overlap, overlays take priority in the order
#' `"disconnected"`, `"error"`, `"busy"`, `"idle"`, over the mascot's
#' server-side state. Because overlays are applied purely in the browser,
#' [mascot_server_state()] continues to reflect what R sent via
#' [update_mascot()].
#'
#' Inside a Shiny module, pass the module's local mascot `id` (the same as in
#' [update_mascot()]). Pages that do not call `watch_mascot_shiny()` keep
#' the default connection-loss behaviour on `shiny:disconnected` and ignore
#' busy and output error events.
#' @family mascots in Shiny
#' @seealso [watch_mascot()], [watch_mascot_task()], [watch_mascot_validator()],
#'   [update_mascot()], [mascot_server_state()]
#' @export
#' @examples
#' shiny::testServer(
#'   function(input, output, session) {
#'     watch_mascot_shiny(
#'       "helper",
#'       map = list(busy = list(status = "Running analysis")),
#'       delay = 0.5
#'     )
#'   },
#'   {
#'     session$flushReact()
#'     mascot_server_state("helper")$id
#'   }
#' )
watch_mascot_shiny <- function(
  id,
  ...,
  map = NULL,
  delay = 1,
  session = shiny::getDefaultReactiveDomain()
) {
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; supply the mascot id to watch.",
        "i" = "For example, {.code watch_mascot_shiny(\"helper\")}."
      ),
      class = "mascot_error"
    )
  }
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      "map, delay, session",
      environment()
    )
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
    checkmate::assert_number(delay, lower = 0, finite = TRUE)
    checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  })
  if (is.null(session)) {
    cli::cli_abort(
      "{.fn watch_mascot_shiny} must be called inside a Shiny server function or module.",
      class = "mascot_error"
    )
  }
  entries <- merge_watch_map(shiny_default_map(), map, "watch_mascot_shiny", environment())
  wire_map <- vector("list", length(entries))
  names(wire_map) <- names(entries)
  for (nm in names(entries)) {
    entry <- entries[[nm]]
    extra <- setdiff(names(entry), c("mood", "status"))
    if (length(extra) > 0L) {
      cli::cli_abort(
        "{.fn watch_mascot_shiny} supports only {.field mood} and {.field status} in {.arg map} entry {.field {nm}}.",
        class = "mascot_error"
      )
    }
    wire_map[[nm]] <- shiny_watch_wire(entry, environment())
  }
  key <- mascot_binding_id(session, id)
  mascot_id_state(session, key, namespaced = TRUE)
  mascot_shiny_watch(
    session,
    key,
    list(
      delay_ms = delay * 1000,
      map = wire_map
    )
  )
  invisible(NULL)
}

#' Default event-to-overlay map for `watch_mascot_shiny()`
#' @noRd
shiny_default_map <- function() {
  list(
    busy = list(mood = "thinking", status = "Working..."),
    idle = list(),
    error = list(mood = "worried", status = "An error occurred"),
    disconnected = list(mood = "worried", status = "Connection lost. Reload the page to continue.")
  )
}

#' Convert one validated overlay map entry into host wire form
#' @noRd
shiny_watch_wire <- function(entry, call = parent.frame()) {
  checkmate::assert_list(entry)
  checkmate::assert_environment(call)
  if (!length(entry)) {
    return(NULL)
  }
  patch <- list()
  if (!is.null(entry$mood)) {
    patch$mood <- if (inherits(entry$mood, "mascot_mood")) entry$mood$name else entry$mood
  }
  if (!is.null(entry$status)) {
    text <- as_status_arg(entry$status, call)$text
    patch$status <- if (is.null(text)) list(mode = "mood") else list(mode = "custom", text = text)
  }
  patch
}
