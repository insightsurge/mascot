#' Internal authoring constructors for the character format
#'
#' These build typed source components and a source specification. They are not
#' exported (the format is not frozen), touch no registry and write no files.
#' Each component is checked structurally with the same schema the reader uses,
#' so a cross-reference (an anchor's part, a gesture's needs) is checked only
#' when the assembled character goes through `character_check()`.
#'
#' Growth rule: required arguments come first, every optional argument comes
#' after `...` and is named, and an unknown argument is an error (never ignored).
#' A new optional field is a new named argument that is omitted from the output
#' unless the caller supplies it, so existing callers and saved files are
#' unaffected. Only arguments the caller supplied are written, so a family
#' default is never overridden by an R default.
#' @name character-build
#' @noRd
NULL

character_build_discrete <- c("visible", "variant", "eyes", "mouth", "brows", "blush", "sparkle", "flip")

#' Reject arguments this version does not know
#' @noRd
character_build_dots <- function(..., .path) {
  checkmate::assert_string(.path, min.chars = 1)
  if (...length() > 0L) {
    labels <- names(list(...))
    labels <- if (is.null(labels)) rep("<unnamed>", ...length()) else ifelse(nzchar(labels), labels, "<unnamed>")
    character_format_abort(
      "unknown_key",
      .path,
      labels,
      "Name only arguments this version supports; optional arguments must be named."
    )
  }
  invisible(NULL)
}

#' Keep supplied, non-empty fields in the declared order
#' @noRd
character_build_fields <- function(values, given) {
  checkmate::assert_list(values, names = "unique")
  checkmate::assert_character(given, any.missing = FALSE)
  values <- values[names(values) %in% given]
  values[!vapply(values, function(value) is.null(value) || length(value) == 0L, logical(1))]
}

#' Check one value against a structural definition and wrap it as a component
#' @noRd
character_build_component <- function(kind, value, definition, path, id = NULL) {
  checkmate::assert_string(kind, min.chars = 1)
  checkmate::assert_list(value)
  checkmate::assert_string(definition, min.chars = 1)
  checkmate::assert_string(path, min.chars = 1)
  checkmate::assert_string(id, min.chars = 1, null.ok = TRUE)
  schema <- character_format_schema()
  checked <- character_format_node(value, schema$definitions[[definition]], path, schema$definitions)
  structure(
    list(kind = kind, id = id, value = checked),
    class = c(paste0("mascot_character_", kind), "mascot_character_component")
  )
}

#' Unwrap components of one kind, rechecking each (class membership is not proof)
#' @noRd
character_build_unwrap <- function(items, kind, definition, path, optional_id = FALSE) {
  checkmate::assert_list(items)
  checkmate::assert_string(kind, min.chars = 1)
  checkmate::assert_string(definition, min.chars = 1)
  checkmate::assert_string(path, min.chars = 1)
  checkmate::assert_flag(optional_id)
  schema <- character_format_schema()
  lapply(seq_along(items), function(index) {
    item <- items[[index]]
    where <- paste0(path, "[", index - 1L, "]")
    if (!inherits(item, paste0("mascot_character_", kind)) || !identical(item$kind, kind)) {
      character_format_abort("input_type", where, class(item)[[1L]], paste0("Supply a ", kind, " component."))
    }
    if (is.null(item$id) && !optional_id) {
      character_format_abort("input_type", where, NULL, paste0("Give this ", kind, " an id."))
    }
    character_format_node(item$value, schema$definitions[[definition]], where, schema$definitions)
  })
}

#' Stop on a repeated component id
#' @noRd
character_build_unique <- function(ids, path) {
  checkmate::assert_character(ids, any.missing = FALSE)
  checkmate::assert_string(path, min.chars = 1)
  repeated <- ids[duplicated(ids)]
  if (length(repeated)) {
    character_format_abort("duplicate_id", path, repeated[[1L]], "Use each id once.")
  }
  invisible(ids)
}

#' Turn a character vector or list into a named list for a map field
#' @noRd
character_build_map <- function(x) {
  checkmate::assert(checkmate::check_character(x), checkmate::check_list(x))
  as.list(x)
}

#' A family definition (id, name, description and optional shared defaults)
#'
#' `defaults$gestures`, `$moods` and `$palettes` may be lists of gesture, mood
#' or palette components (unnamed, or named by each component's own id); they
#' become keyed maps.
#' @noRd
character_author_family <- function(id, name, description, ..., defaults = list()) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(name, min.chars = 1)
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert_list(defaults, names = "unique")
  character_build_dots(..., .path = "$.family_definition")
  given <- names(match.call())
  for (key in intersect(names(defaults), c("gestures", "moods", "palettes"))) {
    entries <- defaults[[key]]
    if (length(entries) && all(vapply(entries, inherits, logical(1), "mascot_character_component"))) {
      kind <- c(gestures = "gesture", moods = "mood", palettes = "palette")[[key]]
      path <- paste0("$.family_definition.defaults.", key)
      values <- character_build_unwrap(unname(entries), kind, kind, path)
      ids <- vapply(entries, function(entry) entry$id, character(1))
      character_build_unique(ids, path)
      if (!is.null(names(entries)) && !identical(names(entries), unname(ids))) {
        character_format_abort(
          "identity",
          path,
          names(entries)[names(entries) != ids][[1L]],
          "Name each entry by its own id, or leave the list unnamed."
        )
      }
      defaults[[key]] <- stats::setNames(values, ids)
    }
  }
  value <- c(
    list(id = id, name = name, description = description),
    character_build_fields(list(defaults = defaults), given)
  )
  character_build_component("family", value, "family", "$.family_definition", id)
}

#' One item: a shape plus how to paint it
#'
#' `geometry` holds the shape's own keys (`x`, `r`, `points`, ...). Fills and
#' strokes are named colour roles (or `list(paint = id)` for a fill).
#' @noRd
character_author_shape <- function(
  type,
  geometry,
  ...,
  id = NULL,
  fill = NULL,
  stroke = NULL,
  width = 2.5,
  alpha = 1,
  outline = FALSE,
  clip = NULL,
  lod = NULL,
  transform = NULL,
  cap = "round",
  join = "round"
) {
  schema <- character_format_schema()
  checkmate::assert_choice(type, names(schema$definitions$item$variants))
  checkmate::assert_list(geometry, names = "unique", min.len = 1)
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert(
    checkmate::check_string(fill, pattern = "^[a-z][a-z0-9_]*$"),
    checkmate::check_list(fill, names = "unique"),
    checkmate::check_null(fill)
  )
  checkmate::assert_string(stroke, pattern = "^[a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert_number(width, finite = TRUE)
  checkmate::assert_true(width > 0, .var.name = "width > 0")
  checkmate::assert_number(alpha, lower = 0, upper = 1)
  checkmate::assert_flag(outline)
  checkmate::assert_string(clip, pattern = "^[a-z][a-z0-9_]*[.][a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert(
    checkmate::check_null(lod),
    checkmate::check_subset(lod, c("full", "small", "micro"), empty.ok = FALSE)
  )
  checkmate::assert_numeric(transform, len = 3, any.missing = FALSE, finite = TRUE, null.ok = TRUE)
  checkmate::assert_choice(cap, c("butt", "round", "square"))
  checkmate::assert_choice(join, c("miter", "round", "bevel"))
  character_build_dots(..., .path = "$.shape")
  taken <- intersect(
    names(geometry),
    c("shape", "id", "fill", "stroke", "width", "alpha", "outline", "clip", "lod", "transform", "cap", "join")
  )
  if (length(taken)) {
    character_format_abort(
      "unknown_key",
      "$.shape.geometry",
      taken,
      "Pass painting options as arguments, not in geometry."
    )
  }
  given <- names(match.call())
  fields <- character_build_fields(
    list(
      id = id,
      fill = fill,
      stroke = stroke,
      width = width,
      alpha = alpha,
      outline = outline,
      cap = cap,
      join = join,
      transform = transform,
      clip = clip,
      lod = lod
    ),
    given
  )
  character_build_component(
    "shape",
    c(list(shape = type), geometry, fields),
    "item",
    "$.shape",
    id
  )
}

#' One entry of `parts`
#' @noRd
character_author_part <- function(
  id,
  items,
  ...,
  parent = "root",
  at = c(0, 0),
  rotate = 0,
  scale = 1,
  layer = 0,
  variants = list(),
  switch = NULL,
  visible = TRUE,
  opacity = 1,
  glow = NULL,
  keep_upright = FALSE,
  no_flip = FALSE,
  lod = NULL
) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_list(items)
  checkmate::assert_string(parent, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_numeric(at, len = 2, any.missing = FALSE, finite = TRUE)
  checkmate::assert_number(rotate, finite = TRUE)
  checkmate::assert_numeric(scale, min.len = 1, max.len = 2, any.missing = FALSE, finite = TRUE)
  checkmate::assert_number(layer, finite = TRUE)
  checkmate::assert_list(variants, names = "unique")
  checkmate::assert_list(switch, names = "unique", null.ok = TRUE)
  checkmate::assert_flag(visible)
  checkmate::assert_number(opacity, lower = 0, upper = 1)
  checkmate::assert_list(glow, names = "unique", null.ok = TRUE)
  checkmate::assert_flag(keep_upright)
  checkmate::assert_flag(no_flip)
  checkmate::assert(
    checkmate::check_null(lod),
    checkmate::check_subset(lod, c("full", "small", "micro"), empty.ok = FALSE)
  )
  character_build_dots(..., .path = paste0("$.parts.", id))
  if (id %in% c("root", "face", "effects")) {
    character_format_abort("identity", "$.parts.id", id, "Do not use a reserved channel prefix as a part id.")
  }
  path <- paste0("$.parts.", id)
  shapes <- character_build_unwrap(items, "shape", "item", paste0(path, ".items"), optional_id = TRUE)
  ids <- unlist(lapply(shapes, function(item) item$id))
  character_build_unique(as.character(ids), paste0(path, ".items"))
  alternatives <- lapply(names(variants), function(name) {
    entries <- variants[[name]]
    checkmate::assert_list(entries)
    character_build_unwrap(entries, "shape", "item", paste0(path, ".variants.", name), optional_id = TRUE)
  })
  names(alternatives) <- names(variants)
  given <- names(match.call())
  fields <- character_build_fields(
    list(
      parent = parent,
      at = at,
      rotate = rotate,
      scale = scale,
      layer = layer,
      visible = visible,
      opacity = opacity,
      keep_upright = keep_upright,
      no_flip = no_flip,
      lod = lod,
      variants = alternatives,
      switch = switch,
      glow = glow
    ),
    given
  )
  value <- c(list(id = id), fields, list(items = shapes))
  character_build_component("part", value, "part", path, id)
}

#' One entry of `anchors`: a named attachment point on a real part
#'
#' The owning part is checked when the whole character is checked.
#' @noRd
character_author_anchor <- function(
  id,
  part,
  ...,
  at = c(0, 0),
  rotate = 0,
  scale = 1,
  side = NULL,
  description = id,
  variants = list()
) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(part, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_numeric(at, len = 2, any.missing = FALSE, finite = TRUE)
  checkmate::assert_number(rotate, finite = TRUE)
  checkmate::assert_number(scale, finite = TRUE)
  checkmate::assert_true(scale > 0, .var.name = "scale > 0")
  checkmate::assert_choice(side, c("l", "r"), null.ok = TRUE)
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert_list(variants, names = "unique")
  character_build_dots(..., .path = paste0("$.anchors.", id))
  given <- c(names(match.call()), "description")
  fields <- character_build_fields(
    list(at = at, rotate = rotate, scale = scale, side = side, description = description, variants = variants),
    given
  )
  character_build_component(
    "anchor",
    c(list(part = part), fields),
    "anchor",
    paste0("$.anchors.", id),
    id
  )
}

#' The `face` block; `kit` is a known kit id or an embedded kit definition
#' @noRd
character_author_face <- function(
  kit,
  part,
  ...,
  at = c(0, 0),
  scale = 1,
  clip = NULL,
  eyes = list(),
  mouth = list(),
  blush = NULL,
  colours = list(),
  tune = list(),
  styles = list(),
  caps = list(),
  layer = NULL
) {
  checkmate::assert(
    checkmate::check_string(kit, pattern = "^[a-z][a-z0-9_]*$"),
    checkmate::check_list(kit, names = "unique")
  )
  checkmate::assert_string(part, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_numeric(at, len = 2, any.missing = FALSE, finite = TRUE)
  checkmate::assert_number(scale, finite = TRUE)
  checkmate::assert_true(scale > 0, .var.name = "scale > 0")
  checkmate::assert_string(clip, pattern = "^[a-z][a-z0-9_]*[.][a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert_list(eyes, names = "unique")
  checkmate::assert_list(mouth, names = "unique")
  checkmate::assert_list(blush, names = "unique", null.ok = TRUE)
  checkmate::assert_list(colours, names = "unique")
  checkmate::assert_list(tune, names = "unique")
  checkmate::assert_list(styles, names = "unique")
  checkmate::assert_list(caps, names = "unique")
  checkmate::assert_number(layer, finite = TRUE, null.ok = TRUE)
  character_build_dots(..., .path = "$.face")
  given <- names(match.call())
  kit_fields <- if (is.list(kit)) {
    if (!is.character(kit$id) || length(kit$id) != 1L) {
      character_format_abort("input_type", "$.face.kit", NULL, "Give an embedded kit definition an id.")
    }
    list(kit = kit$id, part = part)
  } else {
    list(kit = kit, part = part)
  }
  fields <- character_build_fields(
    list(
      at = at,
      scale = scale,
      layer = layer,
      clip = clip,
      eyes = eyes,
      mouth = mouth,
      blush = blush,
      colours = colours,
      tune = tune,
      styles = styles,
      caps = caps
    ),
    given
  )
  value <- c(kit_fields, fields)
  if (is.list(kit)) {
    value$kit_definition <- kit
  }
  character_build_component("face", value, "face", "$.face")
}

#' One entry of `moods` (the authored definition, not the runtime selector)
#' @noRd
character_author_mood <- function(
  id,
  description,
  status,
  ...,
  fallback = NULL,
  pose = NULL,
  face = list(),
  channels = list(),
  recolour = list(),
  items = list(),
  effects = list(),
  reduced = NULL
) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert_string(status, min.chars = 1)
  checkmate::assert_string(fallback, pattern = "^[a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert_string(pose, pattern = "^[a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert_list(face, names = "unique")
  checkmate::assert_list(channels, names = "unique")
  checkmate::assert_list(recolour, names = "unique")
  checkmate::assert_list(items, names = "unique")
  checkmate::assert_list(effects, names = "unique")
  checkmate::assert_list(reduced, names = "unique", null.ok = TRUE)
  character_build_dots(..., .path = paste0("$.moods.", id))
  given <- names(match.call())
  fields <- character_build_fields(
    list(
      fallback = fallback,
      pose = pose,
      face = face,
      channels = channels,
      recolour = recolour,
      items = items,
      effects = effects,
      reduced = reduced
    ),
    given
  )
  character_build_component(
    "mood",
    c(list(description = description, status = status), fields),
    "mood",
    paste0("$.moods.", id),
    id
  )
}

#' One named track; `keys` is a list of list rows so nulls and mixed types survive
#'
#' A `NULL` mode derives `add` for numeric channels and `set` for discrete ones;
#' an explicit incompatible mode is an error.
#' @noRd
character_author_track <- function(channel, keys, ..., mode = NULL) {
  checkmate::assert_string(channel, pattern = "^[a-z][a-z0-9_]*[.][a-z][a-z0-9_]*$")
  checkmate::assert_list(keys, min.len = 2, any.missing = FALSE)
  checkmate::assert_choice(mode, c("add", "set"), null.ok = TRUE)
  character_build_dots(..., .path = paste0("$.tracks.", channel))
  discrete <- sub("^.*[.]", "", channel) %in% character_build_discrete
  if (is.null(mode)) {
    mode <- if (discrete) "set" else "add"
  } else if (discrete && mode != "set") {
    character_format_abort("invalid_channel", paste0("$.tracks.", channel), mode, "Discrete channels use set tracks.")
  }
  rows <- lapply(keys, function(row) {
    checkmate::assert_list(row, min.len = 2, max.len = 3)
    row
  })
  character_build_component(
    "track",
    list(mode = mode, keys = unname(rows)),
    "track",
    paste0("$.tracks.", channel),
    channel
  )
}

#' One entry of `gestures` (the authored definition, not the runtime selector)
#' @noRd
character_author_gesture <- function(
  id,
  description,
  frames,
  tracks,
  ...,
  needs = character(),
  fallback = NULL,
  effects = list()
) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert_count(frames, positive = TRUE)
  checkmate::assert_list(tracks)
  checkmate::assert_character(needs, any.missing = FALSE, unique = TRUE, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(fallback, pattern = "^[a-z][a-z0-9_]*$", null.ok = TRUE)
  checkmate::assert_list(effects)
  character_build_dots(..., .path = paste0("$.gestures.", id))
  path <- paste0("$.gestures.", id)
  built <- character_build_unwrap(tracks, "track", "track", paste0(path, ".tracks"))
  channels <- vapply(tracks, function(track) track$id, character(1))
  character_build_unique(channels, paste0(path, ".tracks"))
  given <- names(match.call())
  fields <- character_build_fields(list(needs = as.list(needs), fallback = fallback, effects = effects), given)
  character_build_component(
    "gesture",
    c(
      list(description = description, frames = as.integer(frames), tracks = stats::setNames(built, channels)),
      fields
    ),
    "gesture",
    path,
    id
  )
}

#' One entry of `palettes`; `dark = NULL` leaves dark mode to the character
#' @noRd
character_author_palette <- function(id, description, light, ..., dark = NULL) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert(
    checkmate::check_character(light, min.len = 1, names = "unique"),
    checkmate::check_list(light, min.len = 1, names = "unique")
  )
  checkmate::assert(
    checkmate::check_character(dark, min.len = 1, names = "unique"),
    checkmate::check_list(dark, min.len = 1, names = "unique"),
    checkmate::check_null(dark)
  )
  character_build_dots(..., .path = paste0("$.palettes.", id))
  given <- names(match.call())
  fields <- character_build_fields(
    list(light = character_build_map(light), dark = if (!is.null(dark)) character_build_map(dark)),
    c(given, "light")
  )
  character_build_component(
    "palette",
    c(list(description = description), fields),
    "palette",
    paste0("$.palettes.", id),
    id
  )
}

#' One entry of `accessories`: a named template attached to an anchor
#' @noRd
character_author_accessory <- function(id, description, anchor, parts, ..., slot = id, colours = list(), lod = NULL) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert_string(anchor, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_list(parts, min.len = 1)
  checkmate::assert_string(slot, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_list(colours, names = "unique")
  checkmate::assert(
    checkmate::check_null(lod),
    checkmate::check_subset(lod, c("full", "small", "micro"), empty.ok = FALSE)
  )
  character_build_dots(..., .path = paste0("$.accessories.", id))
  path <- paste0("$.accessories.", id)
  built <- character_build_unwrap(parts, "part", "part", paste0(path, ".parts"))
  character_build_unique(vapply(parts, function(part) part$id, character(1)), paste0(path, ".parts"))
  given <- c(names(match.call()), "slot")
  fields <- character_build_fields(list(slot = slot, colours = colours, lod = lod), given)
  character_build_component(
    "accessory",
    c(list(description = description, anchor = anchor), fields, list(parts = built)),
    "accessory",
    path,
    id
  )
}

#' The `ground` block
#' @noRd
character_author_ground <- function(centre_height, ..., shadow = NULL) {
  checkmate::assert_number(centre_height, lower = 0, finite = TRUE)
  checkmate::assert_list(shadow, names = "unique", null.ok = TRUE)
  character_build_dots(..., .path = "$.ground")
  given <- names(match.call())
  character_build_component(
    "ground",
    c(list(centre_height = centre_height), character_build_fields(list(shadow = shadow), given)),
    "ground",
    "$.ground"
  )
}

#' Assemble a source specification from checked components
#'
#' The result is a plain format-shaped list with class `mascot_character_spec`.
#' Cross-references may still be unresolved, and `requires` holds only extra
#' capabilities the caller declares: the used ones are computed by
#' `character_check()` after resolution. Only that function produces checked
#' data. `family` is a known family id or a `character_author_family()` component.
#' `omit_family_palettes` writes a source-only null for each inherited palette id.
#' @noRd
character_author_build <- function(
  id,
  family,
  name,
  description,
  colours,
  ground,
  parts,
  moods,
  ...,
  anchors = list(),
  face = NULL,
  gestures = list(),
  poses = list(),
  palettes = list(),
  follows = list(),
  brand = list(),
  contrast = list(),
  modes = list(),
  outline = NULL,
  motion = list(),
  effects = list(),
  accessories = list(),
  wear = character(),
  lod = list(),
  paints = list(),
  shapes = list(),
  pronouns = NULL,
  colour_descriptions = list(),
  omit_family_palettes = character(),
  requires = character()
) {
  checkmate::assert_string(id, pattern = "^[a-z][a-z0-9_]{1,31}$")
  checkmate::assert(
    checkmate::check_string(family, pattern = "^[a-z][a-z0-9_]*$"),
    checkmate::check_class(family, "mascot_character_family")
  )
  checkmate::assert_string(name, min.chars = 1)
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert(
    checkmate::check_character(colours, min.len = 1, names = "unique"),
    checkmate::check_list(colours, min.len = 1, names = "unique")
  )
  checkmate::assert_class(ground, "mascot_character_ground")
  checkmate::assert_list(parts, min.len = 1)
  checkmate::assert_list(moods, min.len = 1)
  checkmate::assert_list(anchors)
  checkmate::assert_class(face, "mascot_character_face", null.ok = TRUE)
  checkmate::assert_list(gestures)
  checkmate::assert_list(poses, names = "unique")
  checkmate::assert_list(palettes)
  checkmate::assert_list(follows, names = "unique")
  checkmate::assert_list(brand, names = "unique")
  checkmate::assert_list(contrast)
  checkmate::assert_list(modes, names = "unique")
  checkmate::assert_list(outline, names = "unique", null.ok = TRUE)
  checkmate::assert_list(motion, names = "unique")
  checkmate::assert_list(effects, names = "unique")
  checkmate::assert_list(accessories)
  checkmate::assert_character(wear, any.missing = FALSE, unique = TRUE, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_list(lod, names = "unique")
  checkmate::assert_list(paints, names = "unique")
  checkmate::assert_list(shapes, names = "unique")
  checkmate::assert_string(pronouns, null.ok = TRUE)
  checkmate::assert_list(colour_descriptions, names = "unique")
  checkmate::assert_character(omit_family_palettes, any.missing = FALSE, unique = TRUE, pattern = "^[a-z][a-z0-9_]*$")
  checkmate::assert_character(requires, any.missing = FALSE, unique = TRUE)
  character_build_dots(..., .path = "$")
  given <- names(match.call())

  keyed <- function(items, kind, path) {
    values <- character_build_unwrap(items, kind, kind, path)
    ids <- vapply(items, function(item) item$id, character(1))
    character_build_unique(ids, path)
    stats::setNames(values, ids)
  }
  part_values <- character_build_unwrap(parts, "part", "part", "$.parts")
  character_build_unique(vapply(parts, function(part) part$id, character(1)), "$.parts")
  palette_values <- keyed(palettes, "palette", "$.palettes")
  clash <- intersect(names(palette_values), omit_family_palettes)
  if (length(clash)) {
    character_format_abort("duplicate_id", "$.palettes", clash[[1L]], "Define or omit a palette, not both.")
  }
  for (omitted in omit_family_palettes) {
    palette_values[omitted] <- list(NULL)
  }
  fields <- character_build_fields(
    list(
      pronouns = pronouns,
      colour_descriptions = colour_descriptions,
      follows = follows,
      brand = brand,
      contrast = unname(contrast),
      modes = modes,
      palettes = palette_values,
      paints = paints,
      shapes = shapes,
      outline = outline,
      anchors = keyed(anchors, "anchor", "$.anchors"),
      poses = poses,
      gestures = keyed(gestures, "gesture", "$.gestures"),
      motion = motion,
      effects = effects,
      lod = lod,
      accessories = keyed(accessories, "accessory", "$.accessories"),
      wear = as.list(wear)
    ),
    c(given, "palettes")
  )
  moods_value <- keyed(moods, "mood", "$.moods")
  face_value <- if (!is.null(face)) {
    character_build_unwrap(list(face), "face", "face", "$.face", optional_id = TRUE)[[1L]]
  }
  ground_value <- character_build_unwrap(list(ground), "ground", "ground", "$.ground", optional_id = TRUE)[[1L]]
  source <- c(
    list(format_version = 1L, id = id, name = name, family = if (is.character(family)) family else family$id),
    list(description = description),
    if (!is.character(family)) {
      list(family_definition = character_build_unwrap(list(family), "family", "family", "$.family_definition")[[1L]])
    },
    list(
      requires = as.list(requires),
      colours = character_build_map(colours),
      ground = ground_value,
      parts = part_values
    ),
    if (!is.null(face_value)) list(face = face_value),
    list(moods = moods_value),
    fields
  )
  schema <- character_format_schema()
  source <- character_format_node(source, schema$definitions$character, "$", schema$definitions)
  structure(source, class = c("mascot_character_spec", "list"))
}
