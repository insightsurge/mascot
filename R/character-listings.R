#' List the characters you can use
#'
#' Lists the characters shipped with the package. Pass an `id` to the `character` argument of [mascot()], or to the
#' other listings, such as [mascot_moods()].
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param family `NULL` (the default) for every character, or a family `id`
#'   from [mascot_families()] to list only its members.
#' @returns A data frame with character columns `id` (the value you pass to
#'   `character`), `name` (the display name), `description` and `family` (the
#'   family `id`), and logical columns `is_default` (`TRUE` only for the
#'   character [mascot()] uses when you name none) and `built_in` (`TRUE` for
#'   characters shipped with the package), and `lifecycle` (`"stable"` or
#'   `"experimental"` for built-in characters, or `NA` for a registered
#'   custom character), and `palettes` (comma-separated palette ids).
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @details Stable built-ins keep their id, name, five shared moods, gesture
#'   names, colour-role names and palette names in every release; their drawing,
#'   motion and exact palette colours may be polished. Experimental built-ins
#'   may change in any way and are not removed without a warning in the release
#'   before removal. The character file format and authoring functions are
#'   experimental too.
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
  builtins <- builtin_characters()
  data.frame(
    id = ids,
    name = vapply(items, function(item) item$name, character(1)),
    description = vapply(items, function(item) item$description, character(1)),
    family = vapply(items, function(item) item$family, character(1)),
    is_default = ids == default,
    built_in = vapply(ids, character_catalogue_is_builtin, logical(1), USE.NAMES = FALSE),
    lifecycle = vapply(
      ids,
      function(id) {
        index <- match(id, builtins$id)
        if (is.na(index)) NA_character_ else builtins$lifecycle[[index]]
      },
      character(1),
      USE.NAMES = FALSE
    ),
    palettes = vapply(
      items,
      function(item) paste(character_palette_names(item), collapse = ", "),
      character(1)
    )
  )
}

#' List the character families
#'
#' A family is a group of characters that share a body plan, such as hexagonal
#' bodies. Use a family `id` to filter [mascot_characters()].
#' @returns A data frame with character columns `id` (the value you pass to the
#'   `family` argument of [mascot_characters()]), `name`, `description` and
#'   `character` (the id of the character supplying a family snapshot, or `NA`
#'   for a built-in family). The family of the default character comes first.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_characters()]
#' @export
#' @examples
#' mascot_families()
mascot_families <- function() {
  ids <- character_catalogue_ids()
  items <- lapply(ids, character_catalogue_get)
  definitions <- list()
  owners <- character()
  for (index in seq_along(items)) {
    item <- items[[index]]
    builtin <- character_catalogue_is_builtin(ids[[index]])
    key <- if (builtin) item$family else paste0(item$family, ":", item$id)
    if (is.null(definitions[[key]])) {
      definitions[[key]] <- item$family_definition
      owners <- c(owners, if (builtin) NA_character_ else item$id)
    }
  }
  data.frame(
    id = vapply(definitions, function(definition) definition$id, character(1), USE.NAMES = FALSE),
    name = vapply(definitions, function(definition) definition$name, character(1), USE.NAMES = FALSE),
    description = vapply(definitions, function(definition) definition$description, character(1), USE.NAMES = FALSE),
    character = owners
  )
}

#' List a character's anchors
#'
#' Anchors are named points on a character where effects such as sweat and
#' sparkles, gesture effects and accessories attach. They are listed in the
#' order the author wrote them. A character may have no anchors.
#' @param character A character, defaulting to `"tessa"`: an id string or a
#'   [mascot_character()] helper. `NULL` is not accepted.
#' @returns A data frame with character columns `name` (the anchor id),
#'   `description`, `part` (the body part the anchor belongs to) and `side`
#'   (`"l"` or `"r"`, or `NA` for an anchor on neither side).
#'   A character with no anchors returns a zero-row data frame with the same
#'   columns and column types.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the anchor name.
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
#' mode. The first row stands for the character's own colours with no palette
#' applied. It is called `"original"`, unless the character names its own
#' colours (Tessa's are `"night_teal"`); `"original"` then still selects the
#' same colours.
#' @param character An id string or [mascot_character()] helper. `NULL`
#'   (the default) lists every character, with a `character` column at the end.
#' @returns A data frame with character columns `name` (the palette id),
#'   `description` and `source`: `"native"` for the character's own colours,
#'   `"character"` for a palette the character defines and `"family"` for one
#'   it takes from its family. The character's own palettes follow in the
#'   order its author wrote them. With `character = NULL`, a final `character` column names each id.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_colour_roles()], [mascot_theme()]
#' @export
#' @examples
#' mascot_palettes()
#' mascot_palettes("tessa")
#' mascot("helper", character = "tessa", theme = "coral_navy")
mascot_palettes <- function(character = NULL) {
  with_mascot_asserts({
    character_catalogue_assert(character, nullable = TRUE)
  })
  if (is.null(character)) {
    rows <- lapply(character_catalogue_ids(), function(id) {
      value <- mascot_palettes(id)
      value$character <- id
      value
    })
    return(do.call(rbind, rows))
  }
  data <- character_catalogue_resolve(character, environment())
  palettes <- character_palettes(data)
  ids <- as.character(names(palettes))
  data.frame(
    name = c(character_palette_names(data)[[1L]], ids),
    description = c(
      "The character's own colours, with no palette applied.",
      vapply(ids, function(id) palettes[[id]]$description, character(1), USE.NAMES = FALSE)
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
