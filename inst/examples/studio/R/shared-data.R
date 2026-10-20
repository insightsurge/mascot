# Data that every view of the studio app shares: the characters it offers, a character's palette menu, and the
# characters and palette of the swap demonstrations. Built from mascot's public listings only.

# Characters the studio can mount: the shipped ones, from the public listing.
studio_characters <- function() {
  listing <- mascot::mascot_characters()
  listing <- listing[listing$built_in, ]
  # Only experimental characters carry a marker; stable ones show their plain name.
  labels <- ifelse(listing$lifecycle %in% "experimental", paste0(listing$name, " (experimental)"), listing$name)
  stats::setNames(listing$id, labels)
}

# The palette menu: the character's own colours always carry the value "original" (no palette applied), whatever
# name the character gives them; the other palettes carry their own names.
studio_palette_choices <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  listed <- mascot::mascot_palettes(character)$name
  stats::setNames(c("original", listed[-1L]), listed)
}

# Keep the API names in studio_palette_choices(); humanise only the sentence's labels.
studio_palette_labels <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  choices <- studio_palette_choices(character)
  labels <- gsub("_", " ", names(choices), fixed = TRUE)
  names(choices) <- paste0(toupper(substr(labels, 1L, 1L)), substring(labels, 2L))
  native <- names(studio_palette_choices(character))[[1L]]
  names(choices)[[1L]] <- paste0(
    mascot::mascot_character(character)$name,
    "'s own colours",
    if (native != "original") paste0(" (", native, ")")
  )
  choices
}

# Named examples, independent of the studio default character.
# The first two characters share this palette id and the third has none of it. A test fails if a change to the
# palettes breaks that.
studio_palette_swap <- c(from = "tessa", kept = "sela", dropped = "knurl", palette = "coral_navy")
