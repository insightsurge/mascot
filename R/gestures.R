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
#' They are available only in [updateMascot()].
#' @returns A data frame with character columns `name` and `description`.
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
#' Play a single movement without altering the current mood. You can use this
#' helper or a plain gesture name in [updateMascot()].
#'
#' If a character or mood change is sent in the same call, that change happens
#' first, followed by the gesture. If you switch characters in the same call, the
#' gesture is skipped because the character switch already includes a wave.
#' Visitors who prefer reduced motion do not see the gesture animate. If you send
#' a gesture before the mascot appears, it waits and plays once as soon as the
#' mascot appears.
#' @param name Gesture name: `"nod"` acknowledges an action; `"wave"` greets
#'   (characters without arms rock instead). See [mascot_gestures()] for the full
#'   list. Required; `NULL` is not accepted.
#' @returns A `mascot_gesture` object with a `name` element.
#' @family mascot helpers
#' @seealso [updateMascot()]
#' @export
#' @examples
#' mascot_gesture("nod")
#' mascot_gesture("wave")
mascot_gesture <- function(name) {
  checkmate::assert_string(name, min.chars = 1)
  if (!name %in% gesture_table()$name) {
    abort_choice(name, gesture_table()$name, "name", "gesture", environment())
  }
  structure(list(name = name), class = "mascot_gesture")
}

#' @export
#' @noRd
format.mascot_gesture <- function(x, ...) {
  checkmate::assert_class(x, "mascot_gesture")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_gesture <- function(x, ...) {
  checkmate::assert_class(x, "mascot_gesture")
  cli::cat_line(format(x))
  invisible(x)
}
