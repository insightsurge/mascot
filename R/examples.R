#' List the bundled example apps
#'
#' Each example opens on its own, with a shared layout and separate scenario
#' code. All work offline. The branding example needs the optional `bslib` package;
#' the other examples use it for styling when available and otherwise use Shiny.
#' @returns A data frame with character columns `name`, `title` and `description`,
#'   in teaching order. `name` is accepted by [mascot_example()].
#' @family mascot examples
#' @seealso [mascot_example()]
#' @export
#' @examples
#' mascot_examples()
mascot_examples <- function() {
  data.frame(
    name = c("basic", "form-check", "long-task", "modules", "branding"),
    title = c("Meet your helper", "Check a form", "Show task progress", "Work in modules", "Personalise Tessa"),
    description = c(
      "Moods, status, bubbles, gestures, size, placement and motion.",
      "A worried helper names invalid fields and becomes happy when both pass.",
      "Thinking during a slow step, then success or a lasting error bubble.",
      "Two module helpers and a parent-owned floating helper.",
      "Brand colours, light/dark mode and an About menu. Requires bslib."
    ),
    stringsAsFactors = FALSE
  )
}

#' Run or locate a bundled example app
#'
#' Opens only the requested example, like [shiny::runExample()]. No files are
#' copied or written by this function. Use `run = FALSE` to read the app's code
#' or pass its directory to [shiny::runApp()]. A shared layout lives beside the
#' example directories; keep that file available when adapting an entire app.
#' @param name A required non-empty string from [mascot_examples()]'s `name`
#'   column. `NULL` is not accepted.
#' @param run A logical flag, defaulting to `TRUE`, to launch the app in an
#'   interactive R session. `FALSE` returns its `app.R` path without launching it.
#'   `NULL` is not accepted.
#' @returns With `run = FALSE`, an absolute path to the existing `app.R` file.
#'   With `run = TRUE`, the value returned by [shiny::runApp()] after the app stops.
#' @family mascot examples
#' @seealso [mascot_examples()]
#' @export
#' @examples
#' basename(mascot_example("basic", run = FALSE))
#' @examplesIf interactive()
#' mascot_example("basic")
mascot_example <- function(name, run = TRUE) {
  checkmate::assert_string(name, min.chars = 1)
  checkmate::assert_flag(run)
  valid <- mascot_examples()$name
  if (!name %in% valid) {
    abort_choice(name, valid, "name", "bundled example", environment())
  }
  path <- system.file("examples", name, "app.R", package = "mascot", mustWork = TRUE)
  if (!run) {
    return(path)
  }
  if (!example_interactive()) {
    cli::cli_abort(c(
      "Running {.fn mascot_example} needs an interactive R session.",
      "i" = "Use {.code mascot_example({.val {name}}, run = FALSE)} to get the app's path."
    ))
  }
  shiny::runApp(dirname(path))
}

#' Check whether an example can launch a browser
#' @noRd
example_interactive <- function() {
  # A package binding stays mockable when installed code is byte-compiled.
  interactive()
}
