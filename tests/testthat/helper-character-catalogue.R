# A copy of the Alpha Visor recipe under a custom id: it has an extra mood with a fallback and several
# gestures, and the reserved shipped id cannot be checked as custom data.
catalogue_alpha_two <- function() {
  recipe <- format_recipe("alpha_visor")
  recipe$id <- "alpha_two"
  recipe$name <- "Alpha Two"
  character_format_check(recipe)
}

# Run code with an empty process registry, restoring it afterwards.
local_empty_registry <- function(env = parent.frame()) {
  before <- character_data_snapshot()
  withr::defer(character_data_reset(before), envir = env)
  character_data_reset()
}
