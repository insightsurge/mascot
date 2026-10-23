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
#' They are available only in [update_mascot()]. With no `character`, it lists
#' the gestures every character shares, with their nominal lengths. With a
#' character, it lists that character's gestures: `"nod"` and `"wave"` first,
#' then its own in the order its author wrote them.
#' @param character `NULL` (the default) for the shared gestures, or a
#'   character: an id string such as `"tessa"` or a [mascot_character()] helper.
#' @returns A data frame with character columns `name` (the value you pass to
#'   [mascot_gesture()]), `description` and `fallback` (the gesture declared as
#'   the next choice when this one cannot play, or `NA`), and an integer column
#'   `frames`. Without a `character`, `frames` is the nominal length (18 for
#'   `"nod"`, 30 for `"wave"`) and `fallback` is `NA`. For a character, `frames`
#'   is the length of the movement that actually plays: a `"wave"` that falls
#'   back to a rock reports the length of the rock. Frames run at 30 per second.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types.
#' @family mascot helpers
#' @seealso [mascot_gesture()]
#' @export
#' @examples
#' mascot_gestures()
#' mascot_gestures("tessa")
mascot_gestures <- function(character = NULL) {
  with_mascot_asserts({
    character_catalogue_assert(character, nullable = TRUE)
  })
  if (is.null(character)) {
    table <- gesture_table()
    return(data.frame(
      name = table$name,
      description = table$description,
      fallback = rep(NA_character_, nrow(table)),
      frames = c(18L, 30L)
    ))
  }
  data <- character_catalogue_resolve(character, environment())
  declared <- names(data$gestures)
  ids <- c(intersect(gesture_table()$name, declared), setdiff(declared, gesture_table()$name))
  playable <- attr(data, "mascot_manifest")$playable
  data.frame(
    name = ids,
    description = vapply(ids, function(id) data$gestures[[id]]$description, character(1), USE.NAMES = FALSE),
    fallback = vapply(
      ids,
      function(id) if (is.null(data$gestures[[id]]$fallback)) NA_character_ else data$gestures[[id]]$fallback,
      character(1),
      USE.NAMES = FALSE
    ),
    frames = vapply(
      ids,
      function(id) as.integer(data$gestures[[playable[[id]]]]$frames),
      integer(1),
      USE.NAMES = FALSE
    )
  )
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
#' @param name A required non-empty gesture id: a lowercase letter followed by
#'   lowercase letters, digits or underscores. `"nod"` acknowledges an action;
#'   `"wave"` greets (characters without arms rock instead). See
#'   [mascot_gestures()] for descriptions. There is no default; `NULL` is not
#'   accepted.
#' @returns A `mascot_gesture` object. Its fields are internal; pass it on rather than reading them.
#' @details
#' This helper checks only the form of the id. [update_mascot()] checks whether
#' the chosen character declares that gesture. If it does not, the warning lists
#' that character's available gestures and leaves the mascot unchanged.
#' @family mascot helpers
#' @seealso [update_mascot()]
#' @export
#' @examples
#' mascot_gesture("nod")
#' mascot_gesture("wave")
mascot_gesture <- function(name) {
  with_mascot_asserts({
    checkmate::assert_string(name, min.chars = 1, pattern = "^[a-z][a-z0-9_]*$")
  })
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
