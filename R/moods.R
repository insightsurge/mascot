#' The shared mood vocabulary
#' @noRd
mood_table <- function() {
  data.frame(
    name = c("idle", "thinking", "happy", "worried", "celebrating"),
    description = c(
      "At rest; the starting mood.",
      "Working on something, such as a long calculation.",
      "Something went well.",
      "Something needs attention, such as an invalid field.",
      "A big success, such as a finished task."
    )
  )
}

#' List the mascot moods
#'
#' Every character uses these moods, in this order.
#' @returns A data frame with character columns `name` and `description`.
#' @family mascot helpers
#' @seealso [mascot()]
#' @export
#' @examples
#' mascot_moods()
mascot_moods <- function() {
  mood_table()
}

#' Choose a mascot mood
#'
#' Use this helper or a plain mood name in [mascot()] and [updateMascot()].
#' @param name A non-empty string naming a mood from [mascot_moods()]. Defaults
#'   to `"idle"`; `NULL` is not accepted.
#' @returns A `mascot_mood` object with a `name` element.
#' @family mascot helpers
#' @seealso [mascot()]
#' @export
#' @examples
#' mascot_mood()
#' mascot_mood("happy")
mascot_mood <- function(name = "idle") {
  checkmate::assert_string(name, min.chars = 1)
  if (!name %in% mood_table()$name) {
    abort_choice(name, mood_table()$name, "name", "mood", environment())
  }
  structure(list(name = name), class = "mascot_mood")
}

#' A plain status label for a mood
#' @noRd
mood_label <- function(name) {
  checkmate::assert_choice(name, mood_table()$name)
  paste0(toupper(substr(name, 1, 1)), substring(name, 2))
}

#' @export
#' @noRd
format.mascot_mood <- function(x, ...) {
  checkmate::assert_class(x, "mascot_mood")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_mood <- function(x, ...) {
  checkmate::assert_class(x, "mascot_mood")
  cli::cat_line(format(x))
  invisible(x)
}
