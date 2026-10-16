#' List a character's colour roles
#'
#' Lists a character's colour roles (its colour parts) with their own colours,
#' before any theme is applied. Roles are written in snake case in R. Follow
#' rules list leaders in priority order. A colour you supply for a role always
#' wins; otherwise the role follows the first supplied or filled leader. With no
#' available leader, the role keeps its original colour.
#' @param character A character, defaulting to `"tessa"`: an id string or a
#'   [mascot_character()] helper. `NULL` is not accepted.
#' @returns A data frame with character columns `role`, `colour`, `follows`
#'   (comma-separated leaders), `shade` (`same`, `lighter` or `darker`),
#'   `description` (what the role colours) and `brand` (the brand slots the role
#'   fills, `primary` and `secondary`, comma-separated).
#'   Roles without a follow rule have `NA` in `follows` and `shade`; roles that
#'   fill no brand slot have `NA` in `brand`.
#'   A base data frame. Columns may be added at the end in later versions; existing columns keep their
#'   names and types. The first column is the value you pass to the matching function.
#' @family mascot helpers
#' @seealso [mascot_theme()], [mascot()]
#' @export
#' @examples
#' mascot_colour_roles()
#' mascot_colour_roles("tessa")
mascot_colour_roles <- function(character = "tessa") {
  with_mascot_asserts({
    character_catalogue_assert(character)
  })
  data <- character_catalogue_resolve(character, environment())
  roles <- names(data$colours)
  follows <- shade <- brand <- rep(NA_character_, length(roles))
  for (role in names(data$follows)) {
    rule <- data$follows[[role]]
    follows[roles == role] <- paste(colour_role_names(unlist(rule$from)), collapse = ", ")
    shade[roles == role] <- if (is.null(rule$shade)) "same" else rule$shade
  }
  for (slot in intersect(c("primary", "secondary"), names(data$brand))) {
    target <- roles == data$brand[[slot]]
    brand[target] <- ifelse(is.na(brand[target]), slot, paste(brand[target], slot, sep = ", "))
  }
  described <- vapply(
    roles,
    function(role) {
      text <- data$colour_descriptions[[role]]
      if (is.null(text)) colour_role_description(role) else text
    },
    character(1),
    USE.NAMES = FALSE
  )
  data.frame(
    role = colour_role_names(roles),
    colour = unname(unlist(data$colours)),
    follows = follows,
    shade = shade,
    description = described,
    brand = brand
  )
}

#' A plain description made from a role name, used when the author wrote none
#' @noRd
colour_role_description <- function(role) {
  checkmate::assert_string(role, min.chars = 1)
  words <- gsub("_", " ", role, fixed = TRUE)
  paste0(toupper(substr(words, 1, 1)), substring(words, 2))
}

#' Read the character's colour metadata from the same description the mascot uses
#' @noRd
character_colour_data <- function(id) {
  character_catalogue_assert(id)
  if (is.character(id) && id %in% builtin_characters()$id) {
    return(jsonlite::fromJSON(character_json(id), simplifyVector = FALSE))
  }
  character_catalogue_resolve(id, environment())
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
  character_catalogue_assert(character, nullable = TRUE)
  if (!is.null(character)) {
    return(colour_role_names(names(character_colour_data(character)$colours)))
  }
  unique(unlist(lapply(builtin_characters()$id, function(id) {
    colour_role_names(names(character_colour_data(id)$colours))
  })))
}
