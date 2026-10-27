#' Empty format object, distinct from an array
#' @noRd
character_object <- function() {
  structure(list(), names = character())
}

#' Recursively merge objects, replacing arrays and named definitions atomically
#'
#' With `rule` (the schema rule at `path`) and `definitions`, an `x_` key of a
#' fixed-field object is an extension key: the override's value replaces the
#' base's whole, never merged into it. In a map an `x_` key is an ordinary id
#' and merges like any other. Without a rule no key is treated as an extension.
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_format_merge <- function(base, override, path = "$", rule = NULL, definitions = NULL) {
  if (!is.list(base) || !is.list(override) || is.null(names(base)) || is.null(names(override))) {
    return(override)
  }
  atomic <- grepl("[.](gestures|palettes|shapes|eye_styles|brow_styles|mouth_styles)$", path) ||
    grepl("[.]styles[.](eyes|brows|mouth)$", path)
  if (!is.null(rule$ref)) {
    rule <- definitions[[rule$ref]]
  }
  fixed <- identical(rule$type, "object")
  result <- base
  for (key in names(override)) {
    child <- if (fixed) {
      rule$fields[[key]]
    } else if (identical(rule$type, "map")) {
      rule$values
    }
    result[key] <- list(
      if (atomic || key == "kit_definition" || (fixed && startsWith(key, "x_")) || !key %in% names(base)) {
        override[[key]]
      } else {
        character_format_merge(base[[key]], override[[key]], paste0(path, ".", key), child, definitions)
      }
    )
  }
  result
}

#' Keys of a fixed-field object that are about the object itself: its note and extension keys
#' @noRd
character_format_own_keys <- function(x) {
  checkmate::assert_list(x, null.ok = TRUE)
  keys <- as.character(names(x))
  keys[keys == "note" | startsWith(keys, "x_")]
}

#' Canonical content identity without a hash or a registry side effect
#' @noRd
character_format_identity <- function(x) {
  checkmate::assert_list(x)
  as.character(jsonlite::toJSON(character_format_canonical(x), auto_unbox = TRUE, null = "null", digits = NA))
}

#' Canonical form of a value: names sorted at every level, values otherwise kept
#'
#' A `json` class is dropped from every value, so text that claims to be JSON
#' is always written as text.
#' @noRd
character_format_canonical <- function(value) {
  checkmate::assert(checkmate::check_list(value, null.ok = TRUE), checkmate::check_atomic(value))
  character_canonical_node(value)
}

#' One level of `character_format_canonical()`, recursing into every element
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_canonical_node <- function(value) {
  if (!is.list(value)) {
    return(if (inherits(value, "json")) unclass(value) else value)
  }
  if (!is.null(names(value))) {
    value <- value[order(names(value), method = "radix")]
  }
  for (index in seq_along(value)) {
    value[index] <- list(character_canonical_node(value[[index]]))
  }
  value
}

#' A character source's identity, made once and put into a mount specification's identity
#'
#' Only `mascot_spec_identity()` writes this piece as it is, and only at the
#' character source; anywhere else it is text like any other.
#' @noRd
character_identity_piece <- function(x) {
  checkmate::assert_list(x)
  structure(character_format_identity(x), class = c("mascot_identity_piece", "json"))
}

#' Load authoring kit defaults from the installed package
#' @noRd
character_format_kits <- function() {
  ids <- c("classic", "screen")
  stats::setNames(
    lapply(ids, function(id) {
      jsonlite::fromJSON(
        system.file("format", "kits", paste0(id, ".json"), package = "mascot", mustWork = TRUE),
        simplifyVector = FALSE
      )
    }),
    ids
  )
}

#' Resolve a parsed source to a self-contained recipe, without certifying it
#'
#' `parsed = TRUE` skips the structural parse when the caller has just parsed
#' `x` (the checker does); the resolved result is always parsed again.
#' @noRd
character_format_resolve <- function(x, families = character_object(), kits = character_format_kits(), parsed = FALSE) {
  checkmate::assert_list(x, names = "unique")
  checkmate::assert_list(families, names = "unique")
  checkmate::assert_list(kits, names = "unique")
  checkmate::assert_flag(parsed)
  schema <- character_format_schema()
  parsed <- if (parsed) x else character_format_parse(x)
  core <- c("idle", "thinking", "happy", "worried", "celebrating")
  for (id in core) {
    if (!id %in% names(parsed$moods)) {
      character_format_abort(
        "missing_reference",
        paste0("$.moods.", id),
        id,
        "Declare every core mood in this character."
      )
    }
  }
  resolved <- isTRUE(parsed$resolved)
  definition <- parsed$family_definition
  known <- families[[parsed$family]]
  validate_family <- function(family) {
    checkmate::assert_list(family)
    result <- character_format_node(family, schema$definitions$family, "$.family_definition", schema$definitions)
    if (!identical(result$id, parsed$family)) {
      character_format_abort("family", "$.family_definition.id", result$id, "Match the character's family id.")
    }
    for (id in names(result$defaults$gestures)) {
      for (target in names(result$defaults$gestures[[id]]$tracks)) {
        if (!target %in% c("root.rotate", "root.lift", "root.scale_x", "root.scale_y")) {
          character_format_abort(
            "invalid_channel",
            paste0("$.family_definition.defaults.gestures.", id, ".tracks.", target),
            target,
            "Use only anatomical-independent root tracks in a family default."
          )
        }
      }
      if (length(result$defaults$gestures[[id]]$needs)) {
        character_format_abort(
          "family",
          paste0("$.family_definition.defaults.gestures.", id, ".needs"),
          NULL,
          "Family gestures cannot require member-specific parts."
        )
      }
    }
    result
  }
  if (resolved) {
    if (is.null(definition)) {
      character_format_abort("family", "$.family_definition", NULL, "Embed the family metadata snapshot.")
    }
    definition <- validate_family(definition)
    if (length(setdiff(names(definition$defaults), character_format_own_keys(definition$defaults)))) {
      character_format_abort("family", "$.family_definition.defaults", NULL, "A resolved snapshot has empty defaults.")
    }
    if (!"palette_sources" %in% names(parsed)) {
      character_format_abort(
        "input_type",
        "$.palette_sources",
        NULL,
        "Embed palette provenance, including an empty object."
      )
    }
    result <- parsed
  } else {
    if ("palette_sources" %in% names(parsed)) {
      character_format_abort(
        "input_type",
        "$.palette_sources",
        NULL,
        "Palette provenance is output from resolution, not a source field."
      )
    }
    if (!is.null(known)) {
      known <- validate_family(known)
    }
    if (!is.null(definition)) {
      definition <- validate_family(definition)
    }
    if (is.null(definition)) {
      definition <- known
    }
    if (is.null(definition)) {
      character_format_abort("family", "$.family", parsed$family, "Supply a known family or its complete definition.")
    }
    if (!is.null(known) && !identical(character_format_identity(known), character_format_identity(definition))) {
      character_format_abort(
        "family",
        "$.family_definition",
        parsed$family,
        "Do not replace a registered family's definition."
      )
    }
    defaults <- if (is.null(definition$defaults)) character_object() else definition$defaults
    # The defaults' own note and x_ keys describe the defaults: they stay in the family snapshot and are not
    # merged into the character.
    own <- names(defaults) %in% character_format_own_keys(defaults)
    result <- character_format_merge(defaults[!own], parsed, "$", schema$definitions$character, schema$definitions)
    palettes <- if (is.null(defaults$palettes)) character_object() else defaults$palettes
    sources <- stats::setNames(as.list(rep("family", length(palettes))), names(palettes))
    for (id in names(parsed$palettes)) {
      if (is.null(parsed$palettes[[id]])) {
        if (!id %in% names(palettes)) {
          character_format_abort(
            "missing_reference",
            paste0("$.palettes.", id),
            id,
            "Omit only a palette inherited from this family."
          )
        }
        palettes[id] <- NULL
        sources[id] <- NULL
      } else {
        palettes[id] <- list(parsed$palettes[[id]])
        sources[id] <- list("character")
      }
    }
    result$palettes <- palettes
    result$palette_sources <- sources
    # The snapshot keeps the family's metadata and its extension keys, and of its defaults only their own note
    # and extension keys: the defaults themselves are merged into the character.
    result$family_definition <- c(
      list(
        id = definition$id,
        name = definition$name,
        description = definition$description,
        defaults = if (any(own)) defaults[own] else character_object()
      ),
      definition[startsWith(names(definition), "x_")]
    )
    result$resolved <- TRUE
  }
  palettes <- if (is.null(result$palettes)) character_object() else result$palettes
  styles <- c("minimal", "pastel", "vivid", "corporate", "earthy", "night")
  reserved <- intersect(names(palettes), c("original", styles))
  if (length(reserved)) {
    character_format_abort(
      "input_type",
      paste0("$.palettes.", reserved[[1]]),
      reserved[[1]],
      paste(
        "Choose a palette id other than original or a reserved style alias",
        "(minimal, pastel, vivid, corporate, earthy, night)."
      )
    )
  }
  if (!is.null(result$native_palette) && result$native_palette %in% styles) {
    character_format_abort(
      "input_type",
      "$.native_palette",
      result$native_palette,
      paste(
        "Choose a native_palette other than original or a reserved style alias",
        "(minimal, pastel, vivid, corporate, earthy, night)."
      )
    )
  }
  if (
    !is.null(result$native_palette) &&
      (result$native_palette == "original" || result$native_palette %in% names(palettes))
  ) {
    character_format_abort(
      "duplicate_id",
      "$.native_palette",
      result$native_palette,
      "Name the character's own colours differently from \"original\" and from every palette."
    )
  }
  if (!setequal(names(result$palette_sources), names(palettes)) || any(vapply(palettes, is.null, logical(1)))) {
    character_format_abort(
      "input_type",
      "$.palette_sources",
      NULL,
      "Match every materialised non-null palette with its provenance."
    )
  }
  if (!is.null(result$face)) {
    face <- result$face
    if (is.null(face$kit)) {
      character_format_abort("missing_reference", "$.face.kit", NULL, "Select a face kit.")
    }
    kit <- face$kit_definition
    if (is.null(kit) && !resolved) {
      kit <- kits[[face$kit]]
    }
    if (is.null(kit)) {
      character_format_abort("missing_reference", "$.face.kit_definition", NULL, "Embed the complete face kit.")
    }
    kit <- character_format_node(kit, schema$definitions$kit, "$.face.kit_definition", schema$definitions)
    if (!identical(kit$id, face$kit)) {
      character_format_abort("missing_reference", "$.face.kit_definition.id", kit$id, "Match the selected kit id.")
    }
    face$kit_definition <- kit
    result$face <- face
  }
  # Resolution can expand a small source; it receives the same bounded parser.
  character_format_parse(result)
}
