#' The shared gesture vocabulary
#' @noRd
gesture_table <- function() {
  data.frame(
    name = c("nod", "wave"),
    description = c(
      "A short nod, such as to acknowledge an action.",
      "A wave, such as a greeting; characters without arms rock instead."
    )
  )
}

#' List the mascot gestures
#'
#' Gestures play a quick movement once, without changing the mascot's mood.
#' They are available only in [update_mascot()].
#' @returns A data frame with character columns `name` and `description`.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_gesture()]
#' @export
#' @examples
#' mascot_gestures()
mascot_gestures <- function() {
  gesture_table()
}

#' Choose a one-off mascot gesture
#'
#' Play a single movement without changing the current mood. Use this helper or
#' a plain gesture name in [update_mascot()].
#'
#' A character or mood change in the same call applies first, then the gesture.
#' During a character swap the gesture is skipped: the wave within the swap
#' replaces it. Reduced motion skips the movement. A gesture sent before the
#' mascot appears is kept until it appears; only the latest early gesture plays,
#' once, after the queued character and mood are applied.
#' @param name A required non-empty string: `"nod"` acknowledges an action;
#'   `"wave"` greets (characters without arms rock instead). See
#'   [mascot_gestures()] for descriptions. There is no default; `NULL` is not
#'   accepted.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @returns A `mascot_gesture` object with a `name` element.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [update_mascot()]
#' @export
#' @examples
#' mascot_gesture("nod")
#' mascot_gesture("wave")
mascot_gesture <- function(name, ...) {
  with_mascot_asserts({
    checkmate::assert_string(name, min.chars = 1)
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("name"), environment())
  }
  if (!name %in% gesture_table()$name) {
    abort_choice(name, gesture_table()$name, "name", "gesture", environment())
  }
  structure(list(name = name), class = "mascot_gesture")
}

#' @export
#' @noRd
format.mascot_gesture <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_gesture")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_gesture <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_gesture")
  })
  cli::cat_line(format(x))
  invisible(x)
}
