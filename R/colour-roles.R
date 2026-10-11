#' List a character's colour roles
#'
#' Lists the colour parts of a character and their default colours before
#' applying a theme. When you customise colours, follower parts automatically
#' derive their shade from the first leader part you set, unless you customise
#' them directly. Without a matching leader, parts keep their original colours.
#' @param character A built-in character name, defaulting to `"tessa"`.
#'   `NULL` is not accepted.
#' @returns A data frame with character columns `role`, `colour`, `follows`
#'   (comma-separated leaders) and `shade` (`same`, `lighter` or `darker`).
#'   Roles without a follow rule show `NA` in `follows` and `shade`.
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
  follows <- shade <- rep(NA_character_, length(engine))
  for (role in names(description$follows)) {
    rule <- description$follows[[role]]
    follows[engine == role] <- paste(colour_role_names(unlist(rule$from)), collapse = ", ")
    shade[engine == role] <- if (is.null(rule$shade)) "same" else rule$shade
  }
  data.frame(
    role = colour_role_names(engine),
    colour = unname(unlist(description$colours)),
    follows = follows,
    shade = shade
  )
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
