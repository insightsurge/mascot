#' List the bundled example apps
#'
#' Lists the example apps included with mascot. Start with the studio to
#' explore every function interactively. Other examples provide copyable
#' Shiny apps for common scenarios. All examples run offline and use the
#' `bslib` package.
#' @returns A data frame with character columns `name`, `title` and `description`,
#'   in teaching order. `name` is accepted by [mascot_example()].
#' @family mascot examples
#' @seealso [mascot_example()]
#' @export
#' @examples
#' mascot_examples()
mascot_examples <- function() {
  data.frame(
    name = c("studio", "form-check", "long-task", "modules", "branding"),
    title = c("Mascot studio", "Check a form", "Show task progress", "Work in modules", "Personalise Tessa"),
    description = c(
      "Every function and argument, live, with explanations and the code to copy.",
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
#' Launches a bundled example app in your browser or returns the file path
#' to its source code. Pass `run = FALSE` to inspect the code or run it with
#' [shiny::runApp()].
#' @param name A string from [mascot_examples()]'s `name` column. `NULL` is
#'   not accepted.
#' @param run A logical flag. `TRUE` (the default) launches the app in an
#'   interactive session. `FALSE` returns its `app.R` path without launching it.
#'   `NULL` is not accepted.
#' @returns With `run = FALSE`, an absolute path to the existing `app.R` file.
#'   With `run = TRUE`, the value returned by [shiny::runApp()] after the app stops.
#' @family mascot examples
#' @seealso [mascot_examples()]
#' @export
#' @examples
#' basename(mascot_example("form-check", run = FALSE))
#' @examplesIf interactive()
#' mascot_example("studio")
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
