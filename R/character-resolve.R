#' Empty format object, distinct from an array
#' @noRd
character_object <- function() {
  structure(list(), names = character())
}

#' Recursively merge objects, replacing arrays and named definitions atomically
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_format_merge <- function(base, override, path = "$") {
  if (!is.list(base) || !is.list(override) || is.null(names(base)) || is.null(names(override))) {
    return(override)
  }
  atomic <- grepl("[.](gestures|palettes|shapes|eye_styles|brow_styles|mouth_styles)$", path) ||
    grepl("[.]styles[.](eyes|brows|mouth)$", path)
  result <- base
  for (key in names(override)) {
    result[key] <- list(
      if (atomic || key == "kit_definition" || !key %in% names(base)) {
        override[[key]]
      } else {
        character_format_merge(base[[key]], override[[key]], paste0(path, ".", key))
      }
    )
  }
  result
}

#' Canonical content identity without a hash or a registry side effect
#' @noRd
character_format_identity <- function(x) {
  checkmate::assert_list(x)
  canonical <- function(value) {
    checkmate::assert(checkmate::check_list(value, null.ok = TRUE), checkmate::check_atomic(value))
    if (!is.list(value)) {
      return(value)
    }
    if (!is.null(names(value))) {
      value <- value[order(names(value), method = "radix")]
    }
    for (index in seq_along(value)) {
      value[index] <- list(canonical(value[[index]]))
    }
    value
  }
  as.character(jsonlite::toJSON(canonical(x), auto_unbox = TRUE, null = "null", digits = NA))
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
    if (length(definition$defaults)) {
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
    result <- character_format_merge(defaults, parsed)
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
    result$family_definition <- list(
      id = definition$id,
      name = definition$name,
      description = definition$description,
      defaults = character_object()
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
