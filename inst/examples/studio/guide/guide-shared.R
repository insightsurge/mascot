# Functions that both the studio (R/data.R) and the guide pages (guide-helpers.R) use, so each exists once.
# Standalone: base R and mascot:: only.

# Which bslib colour slots (primary, secondary, ...) a character's colour roles feed, as slot = role.
guide_brand_roles <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  roles <- mascot::mascot_colour_roles(character)
  roles <- roles[!is.na(roles$brand), ]
  result <- list()
  for (i in seq_len(nrow(roles))) {
    for (slot in strsplit(roles$brand[i], ", ", fixed = TRUE)[[1]]) {
      result[[slot]] <- roles$role[i]
    }
  }
  result
}
