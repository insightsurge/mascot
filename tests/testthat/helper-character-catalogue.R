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
  store <- character_data_store
  before <- list(items = store$items, order = store$order)
  withr::defer(
    {
      store$items <- before$items
      store$order <- before$order
    },
    envir = env
  )
  store$items <- list()
  store$order <- character()
}
