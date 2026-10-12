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

#' List the built-in mascot moods
#'
#' Every character uses these moods, in this order.
#' @returns A data frame with character columns `name` and `description`.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot()], [mascot_mood()]
#' @export
#' @examples
#' mascot_moods()
mascot_moods <- function() {
  mood_table()
}

#' Choose a mascot mood
#'
#' Set how the mascot feels and looks. You can use this helper or a plain mood
#' name in [mascot()] and [update_mascot()].
#' @param name A non-empty string naming a mood from [mascot_moods()]. Defaults
#'   to `"idle"`; `NULL` is not accepted.
#' @returns A `mascot_mood` object with a `name` element.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()]
#' @export
#' @examples
#' mascot_mood()
#' mascot_mood("happy")
mascot_mood <- function(name = "idle") {
  with_mascot_asserts({
    checkmate::assert_string(name, min.chars = 1)
  })
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
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_mood")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_mood <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_mood")
  })
  cli::cat_line(format(x))
  invisible(x)
}
