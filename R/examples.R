#' List the bundled example apps
#'
#' Start with the studio: every exported function and argument, live, with
#' explanations and the code to copy. The other examples are each one copyable
#' `app.R` for one scenario. All work offline and need the optional `bslib`
#' package.
#' @returns A data frame with character columns `name`, `title` and `description`,
#'   in teaching order. `name` is accepted by [mascot_example()].
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
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
#' Opens only the requested example, like [shiny::runExample()]. No files are
#' copied or written by this function. Use `run = FALSE` to read the app's code
#' or pass its directory to [shiny::runApp()]. Each scenario's `app.R` can be
#' copied alone into a project with Shiny, `bslib` and mascot installed; the
#' studio is a folder, with its helpers in `R/` and its styles in `www/`.
#' @param name A required non-empty string from [mascot_examples()]'s `name`
#'   column. `NULL` is not accepted.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param run A logical flag, defaulting to `TRUE`, to launch the app in an
#'   interactive R session. `FALSE` returns its `app.R` path without launching it.
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
mascot_example <- function(name, ..., run = TRUE) {
  with_mascot_asserts({
    checkmate::assert_string(name, min.chars = 1)
    checkmate::assert_flag(run)
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("run"), environment())
  }
  valid <- mascot_examples()$name
  if (!name %in% valid) {
    abort_choice(name, valid, "name", "bundled example", environment())
  }
  path <- system.file("examples", name, "app.R", package = "mascot", mustWork = TRUE)
  if (!run) {
    return(path)
  }
  if (!example_interactive()) {
    cli::cli_abort(
      c(
        "Running {.fn mascot_example} needs an interactive R session.",
        "i" = "Use {.code mascot_example({.val {name}}, run = FALSE)} to get the app's path."
      ),
      class = "mascot_error"
    )
  }
  shiny::runApp(dirname(path))
}

#' Check whether an example can launch a browser
#' @noRd
example_interactive <- function() {
  # A package binding stays mockable when installed code is byte-compiled.
  interactive()
}
