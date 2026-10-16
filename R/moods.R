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

#' List mascot moods
#'
#' Every character has the five shared moods, in this order, and may add more
#' of its own. With no `character`, the list is the shared vocabulary; with one,
#' it is what that character declares: the shared moods first, then its own in
#' the order its author wrote them.
#' @param character `NULL` (the default) for the shared moods, or a character:
#'   an id string such as `"tessa"` or a [mascot_character()] helper.
#' @returns A data frame with character columns `name` (the value you pass to
#'   [mascot_mood()]), `description`, `status` (the text shown beside the mascot
#'   for that mood), `fallback` (the mood used instead when this one is not
#'   available, or `NA`), and a logical column `shared` (`TRUE` for the five
#'   shared moods). Shared moods have no `fallback`.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot()], [mascot_mood()]
#' @export
#' @examples
#' mascot_moods()
#' mascot_moods("tessa")
mascot_moods <- function(character = NULL) {
  with_mascot_asserts({
    character_catalogue_assert(character, nullable = TRUE)
  })
  if (is.null(character)) {
    ids <- mood_table()$name
    return(data.frame(
      name = ids,
      description = mood_table()$description,
      status = vapply(ids, mood_label, character(1), USE.NAMES = FALSE),
      shared = rep(TRUE, length(ids)),
      fallback = rep(NA_character_, length(ids))
    ))
  }
  data <- character_catalogue_resolve(character, environment())
  declared <- names(data$moods)
  ids <- c(intersect(mood_table()$name, declared), setdiff(declared, mood_table()$name))
  data.frame(
    name = ids,
    description = vapply(ids, function(id) data$moods[[id]]$description, character(1), USE.NAMES = FALSE),
    status = vapply(ids, function(id) data$moods[[id]]$status, character(1), USE.NAMES = FALSE),
    shared = ids %in% mood_table()$name,
    fallback = vapply(
      ids,
      function(id) if (is.null(data$moods[[id]]$fallback)) NA_character_ else data$moods[[id]]$fallback,
      character(1),
      USE.NAMES = FALSE
    )
  )
}

#' Choose a mascot mood
#'
#' Set how the mascot feels and looks. You can use this helper or a plain mood
#' name in [mascot()] and [update_mascot()].
#' @param name A non-empty mood id: a lowercase letter followed by lowercase
#'   letters, digits or underscores. Defaults to `"idle"`; `NULL` is not accepted.
#'   See [mascot_moods()] for the available moods.
#' @returns A `mascot_mood` object with a `name` element.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @details
#' This helper checks only the form of the id. [mascot()], [update_mascot()]
#' and [mascot_preview()] check whether the chosen character declares that mood.
#' If it does not, their diagnostic lists that character's available moods.
#' @family mascot helpers
#' @seealso [mascot()]
#' @export
#' @examples
#' mascot_mood()
#' mascot_mood("happy")
mascot_mood <- function(name = "idle") {
  with_mascot_asserts({
    checkmate::assert_string(name, min.chars = 1, pattern = "^[a-z][a-z0-9_]*$")
  })
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
