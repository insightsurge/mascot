#' Watch a reactive value and update a mascot automatically
#'
#' Bind a Shiny reactive expression or [shiny::reactiveVal()] to a mascot so
#' changes update the mascot automatically through [update_mascot()].
#'
#' @evalRd paste0(
#'   "\\section{Experimental}{\n",
#'   sub("\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}",
#'       "\\out{<span class='badge text-bg-warning'>Experimental</span>}",
#'       lifecycle::badge("experimental"), fixed = TRUE),
#'   "\nIts arguments, map structure and return value may change in a later release.\n}"
#' )
#' @inheritParams update_mascot
#' @param source A reactive expression (such as [shiny::reactive()] or
#'   [shiny::eventReactive()]) or a [shiny::reactiveVal()].
#' @param map A non-empty named character vector (values are mood ids) or a
#'   non-empty named list mapping scalar keys to [update_mascot()] updates.
#'   Each list entry can be a mood string, a [mascot_mood()] helper, or a named
#'   list containing any subset of [update_mascot()] update fields
#'   (`character`, `mood`, `status`, `bubble`, `size`, `placement`, `theme`,
#'   `motion`, `click`, `gesture`).
#' @param ... Must be empty. Supply arguments after `map` by name so a typo fails
#'   instead of matching silently.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @returns Invisibly returns the [shiny::observe()] observer that drives the
#'   updates. Call `$destroy()` on it to stop watching early.
#' @details
#' Each time `source()` evaluates to a non-`NA`, length-1 atomic value,
#' `watch_mascot()` converts it with `as.character()` and looks it up in `map`
#' (`TRUE`/`FALSE` match `"TRUE"`/`"FALSE"`, numbers match `"0"`, `"1"`, and
#' so on). Values that are `NULL`, `NA`, non-scalar, non-atomic, or absent from
#' `map` leave the mascot unchanged.
#'
#' Updates are dispatched via [update_mascot()], so manual `update_mascot()`
#' calls and watchers follow the same path: whichever runs last wins. Inside a
#' Shiny module, pass the module's local mascot `id` (the same as in
#' [update_mascot()]).
#' @family mascots in Shiny
#' @seealso [update_mascot()], [watch_mascot_task()], [watch_mascot_validator()], [mascot_server_state()]
#' @export
#' @examples
#' shiny::testServer(
#'   function(input, output, session) {
#'     ready <- shiny::reactive(isTRUE(input$ready))
#'     watch_mascot(
#'       "helper",
#'       ready,
#'       list(
#'         "TRUE" = list(mood = "happy", status = "Ready to submit"),
#'         "FALSE" = list(mood = "worried", status = "Check required fields")
#'       )
#'     )
#'   },
#'   {
#'     session$setInputs(ready = FALSE)
#'     session$flushReact()
#'     mascot_server_state("helper")$mood
#'     session$setInputs(ready = TRUE)
#'     session$flushReact()
#'     mascot_server_state("helper")$mood
#'   }
#' )
watch_mascot <- function(
  id,
  source,
  map,
  ...,
  session = shiny::getDefaultReactiveDomain()
) {
  if (missing(id)) {
    cli::cli_abort(
      c(
        "{.arg id} is missing; supply the mascot id to watch.",
        "i" = "For example, {.code watch_mascot(\"helper\", ready, c(\"TRUE\" = \"happy\"))}."
      ),
      class = "mascot_error"
    )
  }
  if (missing(source)) {
    cli::cli_abort("{.arg source} is missing; supply a reactive expression or reactiveVal.", class = "mascot_error")
  }
  if (missing(map)) {
    cli::cli_abort("{.arg map} is missing; supply a named mood vector or update map list.", class = "mascot_error")
  }
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
    checkmate::assert_class(source, "reactive")
    checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  })
  assert_watch_map_container(map, environment())
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      "session",
      environment()
    )
  }
  if (is.null(session)) {
    cli::cli_abort(
      "{.fn watch_mascot} must be called inside a Shiny server function or module.",
      class = "mascot_error"
    )
  }
  entries <- as_watch_map(map, environment())
  read_source <- source
  force(id)
  force(read_source)
  force(session)
  obs <- shiny::observe(
    {
      val <- read_source()
      if (is.null(val) || !is.atomic(val) || length(val) != 1L || is.na(val)) {
        return(invisible())
      }
      key <- as.character(val)
      if (!(key %in% names(entries))) {
        return(invisible())
      }
      watch_mascot_dispatch(id, entries[[key]], session)
    },
    domain = session
  )
  invisible(obs)
}

#' Assert that a user-supplied watch map is a non-empty unique character vector or list
#' @noRd
assert_watch_map_container <- function(map, call = parent.frame()) {
  checkmate::assert_environment(call)
  with_mascot_asserts(
    {
      checkmate::assert_false(is.object(map), .var.name = "map")
      checkmate::assert(
        checkmate::check_character(map, any.missing = FALSE, names = "unique", min.len = 1),
        checkmate::check_list(map, names = "unique", min.len = 1)
      )
    },
    call = call
  )
}

#' Merge wrapper defaults with optional key-wise user overrides
#' @noRd
merge_watch_map <- function(defaults, map, fn_name, call = parent.frame()) {
  checkmate::assert_list(defaults, names = "unique", min.len = 1)
  checkmate::assert_string(fn_name, min.chars = 1)
  checkmate::assert_environment(call)
  if (is.null(map)) {
    return(defaults)
  }
  assert_watch_map_container(map, call = call)
  unknown <- setdiff(names(map), names(defaults))
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "{cli::qty(unknown)}Unknown {.arg map} key{?s} for {.fn {fn_name}}: {.val {unknown}}.",
        "i" = "Allowed keys: {.val {names(defaults)}}."
      ),
      class = "mascot_error",
      call = call
    )
  }
  overrides <- as_watch_map(map, call = call)
  out <- defaults
  for (nm in names(overrides)) {
    entry <- overrides[[nm]]
    if (length(entry) == 0L) {
      # An explicit empty list silences that key completely instead of inheriting defaults.
      out[[nm]] <- list()
    } else {
      base <- out[[nm]]
      for (field in names(entry)) {
        base[[field]] <- entry[[field]]
      }
      out[[nm]] <- base
    }
  }
  out
}

#' Apply a resolved mascot update patch if non-empty
#' @noRd
watch_mascot_dispatch <- function(id, patch, session) {
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  checkmate::assert_list(patch)
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  if (length(patch) > 0L) {
    do.call(update_mascot, c(list(id = id, session = session), patch))
  }
  invisible()
}

#' Validate and normalise a `watch_mascot()` lookup map
#' @noRd
as_watch_map <- function(map, call = parent.frame()) {
  # map's container type, uniqueness of names, and non-emptiness are asserted by watch_mascot().
  checkmate::assert_names(names(map), type = "unique")
  checkmate::assert_environment(call)
  out <- vector("list", length(map))
  names(out) <- names(map)
  for (nm in names(map)) {
    entry <- map[[nm]]
    if ((is.character(entry) && length(entry) == 1L && !is.na(entry)) || inherits(entry, "mascot_mood")) {
      problem <- arg_problem(entry, "mood")
      if (!is.null(problem)) {
        cli::cli_abort("{problem}", class = "mascot_error", call = call)
      }
      out[[nm]] <- list(mood = entry)
      next
    }
    if (is.list(entry) && !is.object(entry)) {
      if (length(entry) > 0L) {
        with_mascot_asserts(
          checkmate::assert_names(
            names(entry),
            type = "unique",
            subset.of = mascot_state_fields,
            .var.name = paste0("map$", nm)
          ),
          call = call
        )
        entry <- Filter(Negate(is.null), entry)
        for (field in names(entry)) {
          problem <- arg_problem(entry[[field]], field)
          if (!is.null(problem)) {
            cli::cli_abort("{problem}", class = "mascot_error", call = call)
          }
        }
      }
      out[[nm]] <- entry
      next
    }
    cli::cli_abort(
      paste0(
        "Map entry {.field {nm}} must be a mood string, {.fn mascot_mood}, or a ",
        "named list of {.fn update_mascot} arguments."
      ),
      class = "mascot_error",
      call = call
    )
  }
  out
}
