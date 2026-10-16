#' List the characters you can use
#'
#' Lists every character this R session knows, with the shipped characters
#' first. Pass an `id` to the `character` argument of [mascot()], or to the
#' other listings, such as [mascot_moods()].
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param family `NULL` (the default) for every character, or a family `id`
#'   from [mascot_families()] to list only its members.
#' @returns A data frame with character columns `id` (the value you pass to
#'   `character`), `name` (the display name), `description` and `family` (the
#'   family `id`), and logical columns `is_default` (`TRUE` only for the
#'   character [mascot()] uses when you name none) and `built_in` (`TRUE` for
#'   characters shipped with the package).
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_character()], [mascot_families()]
#' @export
#' @examples
#' mascot_characters()
#' mascot_characters(family = "hexonians")
mascot_characters <- function(..., family = NULL) {
  with_mascot_asserts({
    checkmate::assert_string(family, min.chars = 1, null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("family"), environment())
  }
  ids <- character_catalogue_ids()
  items <- lapply(ids, character_catalogue_get)
  families <- vapply(items, function(item) item$family, character(1))
  if (!is.null(family)) {
    if (!family %in% families) {
      abort_choice(family, unique(families), "family", "family", environment())
    }
    ids <- ids[families == family]
    items <- items[families == family]
  }
  default <- formals(mascot)$character
  data.frame(
    id = ids,
    name = vapply(items, function(item) item$name, character(1)),
    description = vapply(items, function(item) item$description, character(1)),
    family = vapply(items, function(item) item$family, character(1)),
    is_default = ids == default,
    built_in = vapply(ids, character_catalogue_is_builtin, logical(1), USE.NAMES = FALSE)
  )
}

#' List the character families
#'
#' A family is a group of characters that share a body plan, such as hexagonal
#' bodies. Use a family `id` to filter [mascot_characters()].
#' @returns A data frame with character columns `id` (the value you pass to the
#'   `family` argument of [mascot_characters()]), `name` and `description`. The
#'   family of the default character comes first.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_characters()]
#' @export
#' @examples
#' mascot_families()
mascot_families <- function() {
  items <- lapply(character_catalogue_ids(), character_catalogue_get)
  definitions <- list()
  for (item in items) {
    # The first character that carries a family names it; a later snapshot never renames it.
    if (is.null(definitions[[item$family]])) {
      definitions[[item$family]] <- item$family_definition
    }
  }
  data.frame(
    id = names(definitions),
    name = vapply(definitions, function(definition) definition$name, character(1), USE.NAMES = FALSE),
    description = vapply(definitions, function(definition) definition$description, character(1), USE.NAMES = FALSE)
  )
}

#' List a character's anchors
#'
#' Anchors are the named attachment points on a character, such as a hand or a
#' badge position. They are listed in the order the author wrote them.
#' @param character A character, defaulting to `"tessa"`: an id string, a
#'   [mascot_character()] helper or checked character data. `NULL` is not
#'   accepted.
#' @returns A data frame with character columns `name` (the anchor id),
#'   `description`, `part` (the body part the anchor belongs to) and `side`
#'   (`"l"` or `"r"`, or `NA` for an anchor on neither side).
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_characters()]
#' @export
#' @examples
#' mascot_anchors()
#' mascot_anchors("tessa")
mascot_anchors <- function(character = "tessa") {
  with_mascot_asserts({
    character_catalogue_assert(character)
  })
  data <- character_catalogue_resolve(character, environment())
  ids <- names(data$anchors)
  text <- function(field) {
    vapply(
      ids,
      function(id) if (is.null(data$anchors[[id]][[field]])) NA_character_ else data$anchors[[id]][[field]],
      character(1),
      USE.NAMES = FALSE
    )
  }
  data.frame(
    name = as.character(ids),
    description = text("description"),
    part = text("part"),
    side = text("side")
  )
}

#' List a character's colour palettes
#'
#' A palette is a ready-made set of colours for a character, in light and dark
#' mode. The first row, `"original"`, stands for the character's own colours
#' with no palette applied.
#' @param character A character, defaulting to `"tessa"`: an id string, a
#'   [mascot_character()] helper or checked character data. `NULL` is not
#'   accepted.
#' @returns A data frame with character columns `name` (the palette id),
#'   `description` and `source`: `"native"` for `"original"`, `"character"` for
#'   a palette the character defines and `"family"` for one it takes from its
#'   family. The character's own palettes follow in the order its author wrote
#'   them.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_colour_roles()], [mascot_theme()]
#' @export
#' @examples
#' mascot_palettes()
#' mascot_palettes("tessa")
mascot_palettes <- function(character = "tessa") {
  with_mascot_asserts({
    character_catalogue_assert(character)
  })
  data <- character_catalogue_resolve(character, environment())
  ids <- as.character(names(data$palettes))
  data.frame(
    name = c("original", ids),
    description = c(
      "The character's own colours, with no palette applied.",
      vapply(ids, function(id) data$palettes[[id]]$description, character(1), USE.NAMES = FALSE)
    ),
    source = c(
      "native",
      vapply(
        ids,
        function(id) if (is.null(data$palette_sources[[id]])) "character" else data$palette_sources[[id]],
        character(1),
        USE.NAMES = FALSE
      )
    )
  )
}
