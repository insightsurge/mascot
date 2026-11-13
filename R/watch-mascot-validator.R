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
#' @param delay Seconds to wait after the last change before the mascot
#'   reacts, a number of at least 0. The default, `0`, reacts at once, which
#'   suits choices made in one click (a select, a checkbox). For typed fields
#'   with a format rule (an email, a sample id, a date typed by hand), a value
#'   such as `1` waits until the person pauses typing, so the mascot does not
#'   turn worried at the first letter.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @returns Invisibly returns the [shiny::observe()] observer that drives the
#'   updates. Call `$destroy()` on it to stop watching early.
#' @details
#' `watch_mascot_validator()` requires the suggested package `shinyvalidate`.
#'
#' The first result is not shown: an empty form opens with the mood and status
#' the mascot starts with in [mascot()], and the mascot reacts from the first
#' change in the number of failing fields. After that, an update is sent only
#' when that number changes, so typing in a field that stays valid sends
#' nothing. To watch several forms, combine their validators into one with
#' `shinyvalidate`'s `add_validator()` and watch the parent: two watchers on one
#' mascot would overwrite each other.
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
#' `c(invalid = "thinking")` keeps the dynamic failing-field count in `status` while
#' replacing only `mood`. Passing `list(invalid = list(status = "Fix errors"))`
#' overrides the dynamic count while keeping `mood = "worried"`.
#'
#' Updates are dispatched via [update_mascot()], so manual `update_mascot()`
#' calls and watchers follow the same path: whichever runs last wins. Inside a
#' Shiny module, pass the module's local mascot `id` (the same as in
#' [update_mascot()]).
#' @family mascots in Shiny
#' @seealso [watch_mascot()], [watch_mascot_task()], [watch_mascot_shiny()],
#'   [update_mascot()], [mascot_server_state()]
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
  delay = 0,
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
    checkmate::assert_class(validator, "InputValidator")
    checkmate::assert_number(delay, lower = 0, finite = TRUE)
    checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      "map, delay, session",
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
  force(id)
  force(validator)
  force(session)
  results <- shiny::reactive(validator$validate(), domain = session)
  if (delay > 0) {
    results <- shiny::debounce(results, delay * 1000, domain = session)
  }
  obs <- watch_mascot_observe(
    function() validator_resolve(results(), entries),
    id,
    session,
    skip_first = TRUE
  )
  invisible(obs)
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
validator_resolve <- function(results, entries) {
  checkmate::assert_list(results)
  checkmate::assert_list(entries, names = "unique")
  if (length(results) == 0L) {
    return(NULL)
  }
  n_invalid <- sum(!vapply(results, is.null, logical(1), USE.NAMES = FALSE))
  if (n_invalid == 0L) {
    return(list(key = 0L, patch = if (is.null(entries$valid)) list() else entries$valid))
  }
  patch <- if (is.null(entries$invalid)) list() else entries$invalid
  if (length(patch) > 0L && !("status" %in% names(patch))) {
    patch$status <- validator_invalid_status(n_invalid)
  }
  list(key = n_invalid, patch = patch)
}
