#' Watch a Shiny input validator and update a mascot automatically
#'
#' Bind a `shinyvalidate::InputValidator` to a mascot so form validation
#' updates the mascot automatically through [update_mascot()].
#'
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts arguments, default map and return value may change in a later release.\n}"
#' )
#' @inheritParams update_mascot
#' @param validator A `shinyvalidate::InputValidator` object created with
#'   `shinyvalidate::InputValidator$new()`.
#' @param ... Must be empty. Supply `map` and `session` by name so a typo fails
#'   instead of matching silently.
#' @param map Optional overrides for the default state map, given as a named
#'   character vector of mood ids or a named list of [update_mascot()] update
#'   lists (same entry format as [watch_mascot()]). Allowed keys are `"valid"`
#'   and `"invalid"`. Provided keys merge field-by-field onto the defaults; pass
#'   an empty `list()` for a key (for example `list(valid = list())`) to leave
#'   the mascot unchanged in that state.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @returns Invisibly returns the [shiny::observe()] observer that drives the
#'   updates. Call `$destroy()` on it to stop watching early.
#' @details
#' `watch_mascot_validator()` requires the suggested package `shinyvalidate`.
#'
#' Each time `validator$validate()` evaluates:
#'
#' - If the validator has no rules yet (returns an empty `list()`), the mascot
#'   is left unchanged.
#' - If all checked fields pass (`NULL` in `validator$validate()`), the
#'   `"valid"` entry is used (default `mood = "happy"`, `status = "All fields
#'   look good"`).
#' - If one or more fields fail, the `"invalid"` entry is used (default `mood =
#'   "worried"`). Unless `map$invalid` supplies its own `status` (or sets
#'   `invalid = list()`), `status` is set dynamically to `"1 field needs
#'   attention"` or `"<n> fields need attention"`.
#'
#' Overrides in `map` apply per key and per field. Passing
#' `c(invalid = "sad")` keeps the dynamic failing-field count in `status` while
#' replacing only `mood`. Passing `list(invalid = list(status = "Fix errors"))`
#' overrides the dynamic count while keeping `mood = "worried"`.
#'
#' Updates are dispatched via [update_mascot()], so manual `update_mascot()`
#' calls and watchers follow the same path: whichever runs last wins. Inside a
#' Shiny module, pass the module's local mascot `id` (the same as in
#' [update_mascot()]).
#' @family mascots in Shiny
#' @seealso [watch_mascot()], [watch_mascot_task()], [update_mascot()],
#'   [mascot_server_state()]
#' @export
#' @examplesIf requireNamespace("shinyvalidate", quietly = TRUE)
#' shiny::testServer(
#'   function(input, output, session) {
#'     iv <- shinyvalidate::InputValidator$new()
#'     iv$add_rule("email", shinyvalidate::sv_required())
#'     iv$enable()
#'     watch_mascot_validator("helper", iv)
#'   },
#'   {
#'     session$setInputs(email = "")
#'     session$flushReact()
#'     mascot_server_state("helper")[c("mood", "status")]
#'     session$setInputs(email = "user@example.com")
#'     session$flushReact()
#'     mascot_server_state("helper")[c("mood", "status")]
#'   }
#' )
watch_mascot_validator <- function(
  id,
  validator,
  ...,
  map = NULL,
  session = shiny::getDefaultReactiveDomain()
) {
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; supply the mascot id to watch.",
        "i" = "For example, {.code watch_mascot_validator(\"helper\", validator)}."
      ),
      class = "mascot_error"
    )
  }
  if (missing(validator)) {
    cli::cli_abort(
      "{.arg validator} is missing; supply a {.cls InputValidator} object.",
      class = "mascot_error"
    )
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
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
      "{.fn watch_mascot_validator} must be called inside a Shiny server function or module.",
      class = "mascot_error"
    )
  }
  entries <- merge_watch_map(validator_default_map(), map, "watch_mascot_validator", environment())
  if (!validator_has_shinyvalidate()) {
    cli::cli_abort(
      c(
        "{.pkg shinyvalidate} is needed for {.fn watch_mascot_validator}.",
        "i" = "Install it with {.code install.packages(\"shinyvalidate\")}."
      ),
      class = "mascot_error"
    )
  }
  # nocov start
  # Reaching InputValidator assertions and live observation requires shinyvalidate in Suggests.
  with_mascot_asserts({
    checkmate::assert_class(validator, "InputValidator")
  })
  force(id)
  force(validator)
  force(session)
  obs <- shiny::observe(
    {
      patch <- validator_resolve_patch(validator$validate(), entries)
      watch_mascot_dispatch(id, patch, session)
    },
    domain = session
  )
  invisible(obs)
  # nocov end
}

#' Check whether the optional `shinyvalidate` package is installed
#' @noRd
validator_has_shinyvalidate <- function() {
  requireNamespace("shinyvalidate", quietly = TRUE)
}

#' Default state-to-update map for `watch_mascot_validator()`
#' @noRd
validator_default_map <- function() {
  list(
    valid = list(mood = "happy", status = "All fields look good"),
    invalid = list(mood = "worried")
  )
}

#' Format the default failing-field status text for `watch_mascot_validator()`
#' @noRd
validator_invalid_status <- function(n) {
  checkmate::assert_count(n, positive = TRUE)
  if (n == 1L) "1 field needs attention" else paste0(n, " fields need attention")
}

#' Resolve an `InputValidator$validate()` list into a mascot update patch
#' @noRd
validator_resolve_patch <- function(results, entries) {
  checkmate::assert_list(results)
  checkmate::assert_list(entries, names = "unique")
  if (length(results) == 0L) {
    return(list())
  }
  n_invalid <- sum(!vapply(results, is.null, logical(1), USE.NAMES = FALSE))
  if (n_invalid == 0L) {
    return(entries[["valid"]] %||% list())
  }
  patch <- entries[["invalid"]] %||% list()
  if (length(patch) > 0L && !("status" %in% names(patch))) {
    patch$status <- validator_invalid_status(n_invalid)
  }
  patch
}
