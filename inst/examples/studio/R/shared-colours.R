# Colour helpers that every view of the studio app shares. Plain R from mascot's listings: no Shiny state here.

# The colours a user changed: each role's value that differs from the role's listed colour, in lower case and
# named by role. values holds the pickers' values by role; a role with no value has no picker yet.
changed_colours <- function(values, roles) {
  checkmate::assert_list(values, types = c("character", "null"))
  if (length(values)) {
    checkmate::assert_names(names(values), type = "unique")
  }
  checkmate::assert_data_frame(roles)
  checkmate::assert_names(names(roles), must.include = c("role", "colour"))
  picked <- vapply(
    roles$role,
    function(role) {
      value <- values[[role]]
      if (is.null(value)) NA_character_ else value
    },
    character(1)
  )
  keep <- !is.na(picked) & tolower(picked) != tolower(roles$colour)
  stats::setNames(tolower(picked[keep]), roles$role[keep])
}

# A character's colour roles with a palette applied. Listing them takes a moment, and the palette cards and the
# colour groups ask for every palette, so each listing is kept for the R session (built-in characters and palettes
# do not change while an app runs).
palette_roles_cache <- new.env(parent = emptyenv())
palette_roles <- function(character, palette = "original") {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1)
  key <- paste(character, palette, sep = "\r")
  if (is.null(palette_roles_cache[[key]])) {
    palette_roles_cache[[key]] <- mascot::mascot_colour_roles(character, palette = palette)
  }
  palette_roles_cache[[key]]
}

# The leaders (roles that follow no other role) whose colour a palette changes, in the character's role order.
palette_leaders <- function(character, palette) {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1)
  own <- palette_roles(character)
  listed <- palette_roles(character, palette)
  changed <- tolower(listed$colour[match(own$role, listed$role)]) != tolower(own$colour)
  own$role[is.na(own$follows) & changed]
}

# The parts a person changes first: the character's brand roles (the parts a bs_theme() colours), then the leaders
# that one of its palettes changes. A character with neither gets its leaders.
main_colour_roles <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  own <- palette_roles(character)
  palettes <- mascot::mascot_palettes(character)
  changed <- unlist(lapply(palettes$name[palettes$source != "native"], palette_leaders, character = character))
  brand <- own$role[!is.na(own$brand)]
  main <- c(brand, setdiff(own$role[own$role %in% changed], brand))
  if (length(main)) main else own$role[is.na(own$follows)]
}

# The colour pickers' groups: "Main colours" (main_colour_roles()), then "More parts": every other role, grouped by
# the name before its first underscore (body_shade and body_highlight under body), in the order of the roles.
colour_groups <- function(roles, character) {
  checkmate::assert_data_frame(roles)
  checkmate::assert_names(names(roles), must.include = "role")
  checkmate::assert_string(character, min.chars = 1)
  main <- intersect(main_colour_roles(character), roles$role)
  rest <- setdiff(roles$role, main)
  prefix <- sub("_.*$", "", rest)
  list(`Main colours` = main, `More parts` = split(rest, factor(prefix, levels = unique(prefix))))
}

# One card per palette in mascot_palettes() order: its name, the value a palette menu uses ("original" for the
# character's own colours), its description, and swatches named by role. The swatches are the brand roles, then the
# leaders the palette changes; the character's own colours show the main colours (main_colour_roles()).
palette_cards <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  palettes <- mascot::mascot_palettes(character)
  own <- palette_roles(character)
  brand <- own$role[!is.na(own$brand)]
  lapply(seq_len(nrow(palettes)), function(i) {
    native <- palettes$source[[i]] == "native"
    value <- if (native) "original" else palettes$name[[i]]
    listed <- palette_roles(character, value)
    parts <- if (native) main_colour_roles(character) else c(brand, setdiff(palette_leaders(character, value), brand))
    list(
      name = palettes$name[[i]],
      value = value,
      description = palettes$description[[i]],
      swatches = stats::setNames(listed$colour[match(parts, listed$role)], parts)
    )
  })
}
