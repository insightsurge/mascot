#' Checked data of a shipped character
#'
#' Returns the shipped version 1 recipe as checked with `builtin = TRUE`, stored
#' in `R/sysdata.rda` by `tools/build-sysdata.R`. The full check takes most of a
#' second, so listings, [mascot()] and update checks read the stored result.
#' @noRd
character_catalogue_builtin <- function(id) {
  checkmate::assert_choice(id, builtin_characters()$id)
  builtin_checked[[id]]
}

#' Ids of every character known to this R process, shipped ones first
#'
#' Shipped characters keep their listed order, then registered characters
#' follow in registration order.
#' @noRd
character_catalogue_ids <- function() {
  # Tessa leads the shipped characters, whatever order they are stored in.
  builtin <- builtin_characters()$id
  c(intersect("tessa", builtin), setdiff(builtin, "tessa"), character_data_ids())
}

#' Checked data for a character id
#' @noRd
character_catalogue_get <- function(id) {
  checkmate::assert_string(id, min.chars = 1)
  if (id %in% builtin_characters()$id) {
    return(character_catalogue_builtin(id))
  }
  character_data_get(id)
}

#' Whether a character id is shipped with the package
#' @noRd
character_catalogue_is_builtin <- function(id) {
  checkmate::assert_string(id, min.chars = 1)
  id %in% builtin_characters()$id
}

#' Check that a listing's `character` argument has an accepted type
#'
#' An id string, a `mascot_character()` helper or checked character data are
#' accepted. Called inside `with_mascot_asserts()`, so failures carry
#' `mascot_error`.
#' @noRd
character_catalogue_assert <- function(x, nullable = FALSE) {
  checkmate::assert_flag(nullable)
  checkmate::assert(
    checkmate::check_string(x, min.chars = 1, null.ok = nullable),
    checkmate::check_class(x, "mascot_character"),
    checkmate::check_class(x, "mascot_character_data"),
    .var.name = "character"
  )
}

#' Turn a listing's `character` argument into verified checked data
#'
#' Ids resolve through the catalogue; a helper resolves through its id; a
#' checked object is verified again before use because R lists can be changed
#' by the caller. An unknown id is reported at the public caller.
#' @noRd
character_catalogue_resolve <- function(x, call) {
  checkmate::assert_environment(call)
  character_catalogue_assert(x)
  if (inherits(x, "mascot_character_data")) {
    return(character_data_verify(x))
  }
  if (inherits(x, "mascot_character") && !is.null(x$data)) {
    return(character_data_verify(x$data))
  }
  if (inherits(x, "mascot_character") && !is.null(x$json)) {
    data <- character_format_check(x$json, from = "text")
    if (!identical(x$id, data$id) || !identical(x$name, data$name)) {
      character_format_abort("identity", "$.id", x$id, "Match the helper to its checked content.")
    }
    return(data)
  }
  id <- if (inherits(x, "mascot_character")) x$id else x
  known <- character_catalogue_ids()
  if (!isTRUE(checkmate::check_choice(id, known))) {
    abort_choice(id, known, "character", "character", call)
  }
  character_catalogue_get(id)
}

#' The status text a character shows for a mood
#'
#' The status is part of each mood in the checked data, so a host can show the
#' text of the character it draws instead of a shared label.
#' @noRd
character_catalogue_status <- function(data, mood) {
  checkmate::assert_class(data, "mascot_character_data")
  checkmate::assert_string(mood, min.chars = 1)
  if (!mood %in% names(data$moods)) {
    character_format_abort("missing_reference", paste0("$.moods.", mood), mood, "Name a mood the character declares.")
  }
  data$moods[[mood]]$status
}


#' Palette definitions shared by listings, themes and checked-format consumers
#'
#' Ids use the in-memory catalogue. Internal format checks may supply their
#' not-yet-classed data directly, avoiding recursion through the checker.
#' @noRd
character_palettes <- function(character) {
  checkmate::assert(
    checkmate::check_string(character, min.chars = 1),
    checkmate::check_list(character, names = "unique")
  )
  data <- if (is.character(character) || inherits(character, "mascot_character")) {
    character_catalogue_resolve(character, environment())
  } else {
    character
  }
  if (is.null(data$palettes)) character_object() else data$palettes
}

#' The palette ids of a character as listed: its own colours first, then its palettes
#'
#' A character's own colours answer to `"original"`; a character may also name
#' them (`native_palette`), and then that name leads the list. `"original"`
#' still selects the same colours, so the list shows one name for them.
#' @noRd
character_palette_names <- function(data) {
  checkmate::assert_list(data)
  c(
    if (is.null(data$native_palette)) "original" else data$native_palette,
    as.character(names(character_palettes(data)))
  )
}

#' Whether a palette id selects the character's own colours
#'
#' Both `"original"` and the character's `native_palette` name do.
#' @noRd
character_palette_is_native <- function(data, palette) {
  checkmate::assert_list(data)
  checkmate::assert_string(palette, min.chars = 1)
  palette == "original" || identical(palette, data$native_palette)
}

#' Ids of the other characters that have a palette of this name
#'
#' Used for the hint in an unknown-palette message: each palette belongs to its
#' own character, so a palette of this name can exist on another character only.
#' A character's own-colours name counts as a palette name.
#' @noRd
character_palette_owners <- function(palette, own_id) {
  checkmate::assert_string(palette, min.chars = 1)
  checkmate::assert_string(own_id, null.ok = TRUE)
  others <- setdiff(character_catalogue_ids(), own_id)
  owners <- vapply(
    others,
    function(id) {
      data <- character_catalogue_get(id)
      palette %in% setdiff(character_palette_names(data), "original")
    },
    logical(1)
  )
  others[owners]
}
