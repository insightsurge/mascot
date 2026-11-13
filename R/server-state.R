#' Inspect a mascot's server-side state
#'
#' Read the latest state recorded for a mascot on the Shiny server, including
#' updates queued before the mascot appears in the browser. Intended for
#' [shiny::testServer()] unit tests, where no browser mounts and
#' [update_mascot()] buffers calls in the session. This function is read-only
#' and leaves the session unchanged.
#'
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts name, arguments and return structure may change in a later release.\n}"
#' )
#' @inheritParams update_mascot
#' @param character An optional character id string such as `"tessa"`, or a
#'   [mascot_character()] helper, used only when the session does not yet know
#'   the mascot's character (for example, in [shiny::testServer()] before any
#'   UI mounts). `NULL` (the default) coalesces queued updates without
#'   checking character-specific mood, gesture or palette names.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @returns A named list with six elements:
#'   - `id`: the resolved binding id in `session` (including the module
#'     namespace when called inside a module).
#'   - `character`: the character id string if known (from a mounted mascot, an
#'     earlier `update_mascot(..., character = )` call, or the `character`
#'     fallback), or `NULL`.
#'   - `mood`: the last requested mood name, or `NULL` if none has been set.
#'   - `status`: the last custom status text, or `NULL` when no custom status is
#'     set or status follows the mood (via [mascot_status()]).
#'   - `bubble`: `NULL` when no bubble is active or after [mascot_bubble()]
#'     clears it; otherwise a list with `text`, `html`, `closable`, and
#'     `duration` (`Inf` for a lasting bubble).
#'   - `gesture`: the last pending gesture name, or `NULL` if none is pending.
#' @details
#' Inside a Shiny module, pass the local id (such as `"helper"`), just as in
#' [update_mascot()]; `session$ns("helper")` is also accepted without adding
#' the namespace twice. When testing a module with [shiny::testServer()], pass
#' `session = session` so the module's namespace proxy is used rather than the
#' outer mock session.
#'
#' If `id` has never been updated or mounted in `session`, the returned list has
#' the resolved `id` and `NULL` for all other fields. This avoids spurious
#' errors when testing an app path that has not updated the mascot yet.
#'
#' **Checking mood and gesture names in `testServer()`.** Without a mounted UI
#' or a `character` argument on [update_mascot()], Shiny does not know which
#' character the UI declared, so `update_mascot()` only checks lowercase id
#' syntax (`^[a-z][a-z0-9_]*$`) and buffers updates until a character is known.
#' Pass `character` here (such as `mascot_server_state("helper", character = "tessa")`)
#' to settle queued updates in memory against that character; invalid moods,
#' gestures or theme roles then emit the same `mascot_update_ignored` warning
#' as on mount and leave the settled state unchanged.
#' @family mascots in Shiny
#' @seealso [update_mascot()]
#' @export
#' @examples
#' shiny::testServer(
#'   function(input, output, session) {
#'     shiny::observeEvent(input$save, {
#'       update_mascot("helper", mood = "happy", status = "Saved")
#'     })
#'   },
#'   {
#'     session$setInputs(save = 1)
#'     state <- mascot_server_state("helper")
#'     state$mood
#'     state$status
#'   }
#' )
mascot_server_state <- function(
  id,
  ...,
  character = NULL,
  session = shiny::getDefaultReactiveDomain()
) {
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; supply the mascot id to inspect.",
        "i" = "For example, {.code mascot_server_state(\"helper\")}."
      ),
      class = "mascot_error"
    )
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
    character_catalogue_assert(character, nullable = TRUE)
    checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      c("character", "session"),
      environment()
    )
  }
  if (is.null(session)) {
    cli::cli_abort(
      "{.fn mascot_server_state} must be called inside a Shiny server function or module.",
      class = "mascot_error"
    )
  }
  fallback_character <- if (!is.null(character)) as_character_arg(character, environment())
  key <- mascot_binding_id(session, id)
  owner <- session$userData$mascot_protocol
  record <- if (is.null(owner)) NULL else owner$states[[key]]
  if (
    is.null(record) ||
      (is.null(record$context) && !length(record$desired) && !length(record$cold) && is.null(record$pending))
  ) {
    return(list(
      id = key,
      character = NULL,
      mood = NULL,
      status = NULL,
      bubble = NULL,
      gesture = NULL
    ))
  }
  fallback_used <- is.null(record$context) && !is.null(fallback_character)
  if (fallback_used) {
    wire <- list(
      id = fallback_character$id,
      name = fallback_character$name,
      json = if (is.null(fallback_character$json)) character_json(fallback_character$id) else fallback_character$json
    )
    record$context <- mascot_state_character(wire)
    record$desired <- mascot_state_defaults(wire)
    record <- mascot_state_settle(record, session, dev_overlay = FALSE)
  } else if (is.null(record$context)) {
    record <- mascot_state_coalesce_cold(record)
  }
  desired <- record$desired
  if (fallback_used && !"mood" %in% record$owned) {
    # The fallback character's default mood was never requested: report no mood, as for an unmounted mascot.
    desired$mood <- NULL
  }
  status <- if (identical(desired$status$mode, "custom")) desired$status$text else NULL
  bubble <- if (is.null(desired$bubble) || isTRUE(desired$bubble$clear)) {
    NULL
  } else {
    list(
      text = desired$bubble$text,
      html = desired$bubble$html,
      closable = desired$bubble$closable,
      duration = if (is.null(desired$bubble$duration)) Inf else desired$bubble$duration
    )
  }
  list(
    id = record$id,
    character = if (is.null(desired$character)) NULL else desired$character$id,
    mood = desired$mood,
    status = status,
    bubble = bubble,
    gesture = if (is.null(record$pending)) NULL else record$pending$name
  )
}

#' Coalesce queued cold-start updates in sequence order without a character context
#' @noRd
mascot_state_coalesce_cold <- function(record) {
  checkmate::assert_list(record, names = "unique")
  calls <- unlist(lapply(record$cold, function(bucket) unname(bucket$calls)), recursive = FALSE)
  if (!length(calls)) {
    return(record)
  }
  calls <- calls[order(vapply(calls, function(call) call$sequence, numeric(1)))]
  desired <- record$desired
  pending <- record$pending
  for (call in calls) {
    patch <- call$patch
    for (field in setdiff(names(patch), "gesture")) {
      desired[field] <- patch[field]
    }
    if (!is.null(patch$gesture)) {
      pending <- list(name = patch$gesture, revision = call$sequence)
    }
  }
  record$desired <- desired
  record$pending <- pending
  record
}
