#' List a character's colour roles
#'
#' Roles are written in snake case in R. Colours are the character's own colours,
#' before any theme is applied. Brand slots identify the roles filled by a
#' [bslib::bs_theme()] primary or secondary colour.
#' @param character A non-empty built-in character name, defaulting to `"tessa"`.
#'   `NULL` is not accepted.
#' @returns A data frame with character columns `role`, `colour` and `brand_slot`.
#'   A role without a brand slot has `NA` in `brand_slot`.
#' @family mascot helpers
#' @seealso [mascot_theme()], [mascot()]
#' @export
#' @examples
#' mascot_colour_roles()
#' mascot_colour_roles("tessa")
mascot_colour_roles <- function(character = "tessa") {
  checkmate::assert_string(character, min.chars = 1)
  id <- as_character_arg(character, environment())$id
  description <- character_colour_data(id)
  engine <- names(description$colours)
  slots <- rep(NA_character_, length(engine))
  for (slot in names(description$brandSlots)) {
    slots[engine %in% description$brandSlots[[slot]]] <- slot
  }
  data.frame(role = colour_role_names(engine), colour = unname(unlist(description$colours)), brand_slot = slots)
}

#' Read the character's colour metadata from the same description as the engine
#' @noRd
character_colour_data <- function(id) {
  checkmate::assert_choice(id, builtin_characters()$id)
  jsonlite::fromJSON(character_json(id), simplifyVector = FALSE)
}

#' Convert description names to the public R spelling
#' @noRd
colour_role_names <- function(names) {
  checkmate::assert_character(names, any.missing = FALSE)
  tolower(gsub("([a-z0-9])([A-Z])", "\\1_\\2", names))
}

#' Role names for a selected character, or every built-in character when unknown
#' @noRd
colour_role_registry <- function(character = NULL) {
  checkmate::assert_choice(character, builtin_characters()$id, null.ok = TRUE)
  ids <- if (is.null(character)) builtin_characters()$id else character
  unique(unlist(lapply(ids, function(id) colour_role_names(names(character_colour_data(id)$colours)))))
}
