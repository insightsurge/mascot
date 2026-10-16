character_data_store <- new.env(parent = emptyenv())
character_data_store$items <- list()
character_data_store$order <- character()

# Verified content cache: canonical resolved content only, never visitor ids or provenance.
character_data_verified <- new.env(parent = emptyenv())
character_data_verified$items <- list()

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
#' Checks structure and canonical content at every boundary. A bounded cache
#' reuses semantic checks and derived manifests by complete content identity;
#' a cache miss reconstructs them. Caller-supplied classes, resolved flags and
#' derived manifest fields never bypass verification.
#' @noRd
character_data_verify <- function(x) {
  checkmate::assert_class(x, "mascot_character_data")
  parsed <- character_format_parse(x)
  identity <- character_format_identity(parsed)
  # Shipped data may use the reserved id only when it matches the package copy.
  if (
    isTRUE(checkmate::check_string(x$id)) &&
      x$id %in% builtin_characters()$id &&
      identical(identity, character_format_identity(character_catalogue_builtin(x$id)))
  ) {
    return(character_catalogue_builtin(x$id))
  }
  items <- character_data_verified$items
  hit <- which(vapply(items, function(item) identical(attr(item, "mascot_manifest")$identity, identity), logical(1)))
  if (length(hit) && identical(attr(x, "mascot_manifest")$identity, identity)) {
    return(items[[hit[[1L]]]])
  }
  verified <- character_format_check(x)
  if (!identical(attr(x, "mascot_manifest")$identity, attr(verified, "mascot_manifest")$identity)) {
    character_format_abort(
      "identity",
      "$",
      x$id,
      "Do not edit a checked object. Edit the source list or JSON and check it again."
    )
  }
  character_data_verified$items <- utils::tail(c(items, list(verified)), 16L)
  verified
}

#' Register checked character data in the internal store
#'
#' Registers a verified character recipe for the lifetime of the R process.
#' Registration inside an active reactive domain is rejected. Re-registering
#' identical content is idempotent; conflicting content with an existing custom
#' or reserved built-in identifier raises an error. Normal registration verifies
#' entries once; the internal reset helper also verifies restored snapshots.
#' @noRd
character_data_register <- function(x) {
  checkmate::assert_class(x, "mascot_character_data")
  if (!is.null(shiny::getDefaultReactiveDomain())) {
    character_format_abort(
      code = "registry",
      path = "$",
      value = NULL,
      fix = "Register characters during setup; pass the checked object instead inside an active reactive domain."
    )
  }
  verified <- character_data_verify(x)
  if (verified$id %in% character_data_reserved()) {
    character_format_abort(
      "identity",
      "$.id",
      verified$id,
      paste0(encodeString(verified$id, quote = '"'), " is a built-in character; give your character its own id.")
    )
  }
  attr(verified, "mascot_origin") <- attr(x, "mascot_origin")
  id <- verified$id
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
    for (id in state$order) {
      if (!identical(id, state$items[[id]]$id)) {
        character_format_abort("identity", "$.id", state$items[[id]]$id, "Match each snapshot key to its character id.")
      }
    }
    character_data_store$items <- state$items
    character_data_store$order <- state$order
  }
  invisible(NULL)
}
