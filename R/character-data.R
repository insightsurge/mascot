character_data_store <- new.env(parent = emptyenv())
character_data_store$items <- list()
character_data_store$order <- character()

# Verified content cache: canonical resolved content only, never visitor ids or provenance.
character_data_verified <- new.env(parent = emptyenv())
character_data_verified$items <- list()
# Objects already verified, each with its result; an exact copy of one is not checked again.
character_data_verified$seen <- list()
# JSON text written for verified objects, so a custom character's text is written once per object.
character_data_verified$texts <- list()

#' Character ids a custom character cannot use: the built-in ids
#' @noRd
character_data_reserved <- function() {
  builtin_characters()$id
}

#' Verify internal checked character data
#'
#' Checks structure and canonical content at every boundary. An object
#' identical to one verified before (every value, attribute and number bit for
#' bit) returns that result without parsing it again; any edit makes a
#' different object, which is checked. A bounded cache reuses semantic checks
#' and derived manifests by complete content identity; a cache miss
#' reconstructs them. Caller-supplied classes, resolved flags and derived
#' manifest fields never bypass verification.
#' @noRd
character_data_verify <- function(x) {
  checkmate::assert_class(x, "mascot_character_data")
  for (entry in character_data_verified$seen) {
    if (identical(x, entry$input, num.eq = FALSE)) {
      return(entry$verified)
    }
  }
  parsed <- character_format_parse(x)
  identity <- character_format_identity(parsed)
  # Shipped data may use the reserved id only when it matches the package copy.
  if (
    isTRUE(checkmate::check_string(x$id)) &&
      x$id %in% builtin_characters()$id &&
      identical(identity, character_format_identity(character_catalogue_builtin(x$id)))
  ) {
    return(character_data_seen(x, character_catalogue_builtin(x$id)))
  }
  items <- character_data_verified$items
  hit <- which(vapply(items, function(item) identical(attr(item, "mascot_manifest")$identity, identity), logical(1)))
  if (length(hit) && identical(attr(x, "mascot_manifest")$identity, identity)) {
    return(character_data_seen(x, items[[hit[[1L]]]]))
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
  character_data_seen(x, verified)
}

#' Remember an object that passed verification, with its result
#' @noRd
character_data_seen <- function(x, verified) {
  checkmate::assert_class(x, "mascot_character_data")
  checkmate::assert_class(verified, "mascot_character_data")
  entry <- list(input = x, verified = verified)
  character_data_verified$seen <- utils::tail(c(character_data_verified$seen, list(entry)), 16L)
  verified
}

#' JSON text of verified data, written once for each object
#' @noRd
character_data_json <- function(verified) {
  checkmate::assert_class(verified, "mascot_character_data")
  for (entry in character_data_verified$texts) {
    if (identical(verified, entry$verified, num.eq = FALSE)) {
      return(entry$json)
    }
  }
  json <- character_json_write(verified)
  entry <- list(verified = verified, json = json)
  character_data_verified$texts <- utils::tail(c(character_data_verified$texts, list(entry)), 16L)
  json
}

#' Register checked character data in the internal store
#'
#' Registers a verified character recipe for the lifetime of the R process.
#' Registration inside an active reactive domain is rejected. Re-registering
#' identical content is idempotent; conflicting content with an existing custom
#' or reserved built-in identifier raises an error. Registration verifies each
#' entry once.
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
