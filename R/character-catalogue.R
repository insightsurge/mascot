character_catalogue_cache <- new.env(parent = emptyenv())

#' Checked data of a shipped character, verified once per R process
#'
#' Reads the shipped version 1 recipe and checks it with `builtin = TRUE`, the
#' only caller allowed to do so. The result is cached: the full check takes
#' most of a second, and a listing should not pay for it twice. Until the engine
#' draws from this data, the shipped recipe is read for listings only.
#' @noRd
character_catalogue_builtin <- function(id) {
  checkmate::assert_choice(id, builtin_characters()$id)
  if (is.null(character_catalogue_cache[[id]])) {
    path <- system.file("format", "characters", paste0(id, ".json"), package = "mascot", mustWork = TRUE)
    checked <- character_format_check(path, from = "file", builtin = TRUE)
    if (!identical(checked$id, id)) {
      character_format_abort("identity", "$.id", checked$id, "Ship each recipe under its own id.")
    }
    character_catalogue_cache[[id]] <- checked
  }
  character_catalogue_cache[[id]]
}

#' Ids of every character known to this R process, shipped ones first
#'
#' Shipped characters keep their listed order, then registered characters
#' follow in registration order.
#' @noRd
character_catalogue_ids <- function() {
  # Tessa leads the shipped characters (r-api-decisions section 11), whatever order they are stored in.
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
