character_data_store <- new.env(parent = emptyenv())
character_data_store$items <- list()
character_data_store$order <- character()

#' Character ids reserved for built-in characters, shipped or planned
#'
#' Includes the 0.1.0 candidates so a custom character registered now cannot
#' collide with a built-in added later.
#' @noRd
character_data_reserved <- function() {
  unique(c(builtin_characters()$id, "tessa", "neer", "alpha_visor", "knurl"))
}

#' Verify internal checked character data
#'
#' Re-runs semantic character format verification and reconstructs the derived
#' manifest. Caller-supplied classes, resolved flags and manifest attributes are
#' never trusted.
#' @noRd
character_data_verify <- function(x) {
  checkmate::assert_class(x, "mascot_character_data")
  character_format_check(x)
}

#' Register checked character data in the internal store
#'
#' Registers a verified character recipe for the lifetime of the R process.
#' Registration inside an active reactive domain is rejected. Re-registering
#' identical content is idempotent; conflicting content with an existing custom
#' or reserved built-in identifier raises an error. This is the only place the
#' store is written, so entries are verified exactly once.
#' @noRd
character_data_register <- function(x) {
  checkmate::assert_class(x, "mascot_character_data")
  if (!is.null(shiny::getDefaultReactiveDomain())) {
    character_format_abort(
      code = "registry",
      path = "$",
      value = NULL,
      fix = "Register characters during process setup, not inside an active reactive domain."
    )
  }
  verified <- character_data_verify(x)
  id <- verified$id
  if (id %in% character_data_reserved()) {
    character_format_abort(
      code = "identity",
      path = "$.id",
      value = id,
      fix = "Do not replace a built-in character id."
    )
  }
  identity <- attr(verified, "mascot_manifest")$identity
  if (id %in% names(character_data_store$items)) {
    existing <- character_data_store$items[[id]]
    existing_identity <- attr(existing, "mascot_manifest")$identity
    if (!identical(identity, existing_identity)) {
      character_format_abort(
        code = "identity",
        path = "$.id",
        value = id,
        fix = "Do not replace a registered character with different content."
      )
    }
    return(invisible(verified))
  }
  character_data_store$items[[id]] <- verified
  character_data_store$order <- c(character_data_store$order, id)
  invisible(verified)
}

#' Retrieve verified checked character data from the internal store
#'
#' Returns the entry verified at registration. R copies a list when it is
#' modified, so a caller changing the returned value cannot change the store;
#' re-running the full check here would only add latency to every session.
#' @noRd
character_data_get <- function(id) {
  checkmate::assert_string(id, min.chars = 1, pattern = "^[a-z][a-z0-9_]{1,31}$")
  if (!id %in% names(character_data_store$items)) {
    character_format_abort(
      code = "missing_reference",
      path = "$.id",
      value = id,
      fix = "Supply a registered custom character id."
    )
  }
  character_data_store$items[[id]]
}

#' List registered custom character ids in deterministic registration order
#' @noRd
character_data_ids <- function() {
  character_data_store$order
}

#' Snapshot the internal character data store
#' @noRd
character_data_snapshot <- function() {
  list(
    items = character_data_store$items,
    order = character_data_store$order
  )
}

#' Reset or restore the internal character data store
#' @noRd
character_data_reset <- function(state = NULL) {
  checkmate::assert_list(state, names = "unique", null.ok = TRUE)
  if (is.null(state)) {
    character_data_store$items <- list()
    character_data_store$order <- character()
  } else {
    checkmate::assert_names(names(state), identical.to = c("items", "order"))
    checkmate::assert_list(state$items, names = "unique")
    checkmate::assert_character(state$order, any.missing = FALSE, unique = TRUE)
    if (length(state$items) || length(state$order)) {
      checkmate::assert_names(names(state$items), identical.to = state$order)
    }
    state$items <- lapply(state$items, character_data_verify)
    character_data_store$items <- state$items
    character_data_store$order <- state$order
  }
  invisible(NULL)
}
