#' Expand addressable accessory part ids for semantic checks
#' @noRd
character_format_parts <- function(x) {
  checkmate::assert_list(x, names = "unique")
  parts <- x$parts
  paths <- paste0("$.parts[", seq_along(parts) - 1L, "]")
  for (id in names(x$accessories)) {
    accessory <- x$accessories[[id]]
    local_ids <- vapply(accessory$parts, `[[`, character(1), "id")
    if (anyDuplicated(local_ids)) {
      character_format_abort("input_type", paste0("$.accessories.", id, ".parts"), NULL, "Keep local part ids unique.")
    }
    for (index in seq_along(accessory$parts)) {
      part <- accessory$parts[[index]]
      parent <- if (is.null(part$parent)) "root" else part$parent
      path <- paste0("$.accessories.", id, ".parts[", index - 1L, "]")
      if (parent != "root" && !parent %in% local_ids) {
        character_format_abort("missing_reference", paste0(path, ".parent"), parent, "Name a local accessory parent.")
      }
      part$id <- paste0("wear_", id, "_", part$id)
      part$parent <- if (parent == "root") "root" else paste0("wear_", id, "_", parent)
      attr(part, "accessory") <- id
      parts[[length(parts) + 1L]] <- part
      paths <- c(paths, path)
    }
  }
  if (length(parts) > character_format_policy()$input$declared_parts) {
    character_format_abort(
      "budget",
      "$.parts",
      length(parts),
      "Reduce the total declared parts, including accessory templates."
    )
  }
  ids <- vapply(parts, `[[`, character(1), "id")
  for (index in seq_along(ids)) {
    if (ids[[index]] %in% c("root", "face", "effects") || ids[[index]] %in% ids[seq_len(index - 1L)]) {
      character_format_abort(
        "input_type",
        paste0(paths[[index]], ".id"),
        ids[[index]],
        "Use unique, non-reserved expanded part ids."
      )
    }
  }
  names(parts) <- ids
  names(paths) <- ids
  for (id in names(x$anchors)) {
    if (!x$anchors[[id]]$part %in% ids) {
      character_format_abort(
        "missing_reference",
        paste0("$.anchors.", id, ".part"),
        x$anchors[[id]]$part,
        "Name a declared anchor-owning part."
      )
    }
  }
  # Mark a dependency only after its parent and attachment owner were visited.
  parents <- vapply(
    parts,
    function(part) {
      checkmate::assert_list(part)
      parent <- if (is.null(part$parent)) "root" else part$parent
      accessory <- attr(part, "accessory")
      if (!is.null(accessory) && parent == "root") {
        anchor <- x$anchors[[x$accessories[[accessory]]$anchor]]
        if (is.null(anchor)) {
          character_format_abort(
            "missing_reference",
            paste0("$.accessories.", accessory, ".anchor"),
            NULL,
            "Name a declared anchor."
          )
        }
        parent <- anchor$part
      }
      parent
    },
    character(1)
  )
  for (id in ids) {
    if (parents[[id]] != "root" && !parents[[id]] %in% ids) {
      character_format_abort(
        "missing_reference",
        paste0(paths[[id]], ".parent"),
        parents[[id]],
        "Name a declared parent part."
      )
    }
  }
  order <- character()
  pending <- ids
  while (length(pending)) {
    ready <- pending[parents[pending] %in% c("root", order)]
    if (!length(ready)) {
      character_format_abort(
        "missing_reference",
        paste0(paths[[pending[[1L]]]], ".parent"),
        NULL,
        "Remove the part/anchor dependency cycle."
      )
    }
    order <- c(order, ready)
    pending <- setdiff(pending, ready)
  }
  list(parts = parts, paths = paths, order = order, parents = parents)
}

#' Apply numeric tuning only to existing leaves and fixed-size arrays
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_format_tune <- function(base, tune, path = "$.face.tune") {
  if (is.numeric(base)) {
    values <- unlist(tune, use.names = FALSE)
    if (!is.numeric(values) || length(values) != length(base) || any(!is.finite(values))) {
      character_format_abort("input_type", path, NULL, "Tune an existing numeric leaf without changing its length.")
    }
    return(values)
  }
  if (!is.list(tune) || is.null(names(base)) != is.null(names(tune))) {
    character_format_abort("input_type", path, NULL, "Retain the existing numeric structure.")
  }
  if (is.null(names(base))) {
    if (length(tune) != length(base)) {
      character_format_abort("input_type", path, NULL, "Retain the numeric array length.")
    }
    keys <- seq_along(base)
  } else {
    keys <- names(tune)
    unknown <- setdiff(keys, names(base))
    if (length(unknown)) {
      character_format_abort(
        "unknown_key",
        paste0(path, ".", unknown[[1L]]),
        NULL,
        "Tune only existing numeric leaves."
      )
    }
  }
  result <- base
  for (key in keys) {
    if (!is.numeric(base[[key]]) && !is.list(base[[key]])) {
      character_format_abort("input_type", paste0(path, ".", key), NULL, "Only numeric leaves can be tuned.")
    }
    result[key] <- list(character_format_tune(base[[key]], tune[[key]], paste0(path, ".", key)))
  }
  result
}

#' Validate assembled part, item, anchor, paint and kit references
#' @noRd
character_format_references <- function(x) {
  checkmate::assert_list(x, names = "unique")
  graph <- character_format_parts(x)
  parts <- graph$parts
  roles <- names(x$colours)
  role <- function(id, path) {
    if (!id %in% roles) {
      character_format_abort("missing_reference", path, id, "Name a declared colour role.")
    }
    invisible(NULL)
  }
  target <- function(id, path) {
    names <- strsplit(id, ".", fixed = TRUE)[[1L]]
    part <- parts[[names[[1L]]]]
    if (length(names) != 2L || is.null(part)) {
      character_format_abort("missing_reference", path, id, "Name a declared part and item.")
    }
    candidates <- c(list(default = if (is.null(part$items)) list() else part$items), part$variants)
    if (
      !any(vapply(
        candidates,
        function(items) {
          checkmate::assert_list(items)
          any(vapply(items, function(item) identical(item$id, names[[2L]]), logical(1)))
        },
        logical(1)
      ))
    ) {
      character_format_abort("missing_reference", path, id, "Name geometry present in the target part.")
    }
    invisible(NULL)
  }
  paint_role <- function(fill, path, mapper = character_object()) {
    checkmate::assert(checkmate::check_string(fill), checkmate::check_list(fill))
    checkmate::assert_string(path)
    checkmate::assert_list(mapper)
    if (is.character(fill)) {
      role(if (is.null(mapper[[fill]])) fill else mapper[[fill]], path)
    } else if (!fill$paint %in% names(x$paints)) {
      character_format_abort("missing_reference", paste0(path, ".paint"), fill$paint, "Name a declared paint.")
    }
    invisible(NULL)
  }
  item_check <- function(item, path, mapper = character_object()) {
    checkmate::assert_list(item)
    checkmate::assert_string(path)
    checkmate::assert_list(mapper)
    geometry <- character_geometry(item, if (is.null(x$shapes)) character_object() else x$shapes, path)
    resolved <- geometry$item
    if (!is.null(resolved$fill)) {
      paint_role(resolved$fill, paste0(path, ".fill"), mapper)
    }
    if (!is.null(resolved$stroke)) {
      paint_role(resolved$stroke, paste0(path, ".stroke"), mapper)
    }
    if (!is.null(resolved$clip)) {
      target(resolved$clip, paste0(path, ".clip"))
    }
    invisible(geometry)
  }
  for (id in names(x$colour_descriptions)) {
    role(id, paste0("$.colour_descriptions.", id))
  }
  for (id in names(x$modes$dark$colours)) {
    role(id, paste0("$.modes.dark.colours.", id))
  }
  for (id in names(x$brand)) {
    role(x$brand[[id]], paste0("$.brand.", id))
  }
  for (id in names(x$follows)) {
    role(id, paste0("$.follows.", id))
    for (leader in x$follows[[id]]$from) {
      role(leader, paste0("$.follows.", id, ".from"))
    }
  }
  for (id in names(x$palettes)) {
    for (mode in c("light", "dark")) {
      for (name in names(x$palettes[[id]][[mode]])) {
        role(name, paste0("$.palettes.", id, ".", mode, ".", name))
      }
    }
  }
  for (id in names(x$paints)) {
    paint <- x$paints[[id]]
    times <- vapply(paint$stops, function(stop) stop[[1L]], numeric(1))
    if (is.unsorted(times)) {
      character_format_abort("input_type", paste0("$.paints.", id, ".stops"), NULL, "Order gradient stops by offset.")
    }
    for (index in seq_along(paint$stops)) {
      role(paint$stops[[index]][[2L]], paste0("$.paints.", id, ".stops[", index - 1L, "][1]"))
    }
    if (paint$type == "radial" && (if (is.null(paint$r0)) 0 else paint$r0) > paint$r1) {
      character_format_abort(
        "input_type",
        paste0("$.paints.", id, ".r1"),
        NULL,
        "Keep the outer radius at least the inner radius."
      )
    }
  }
  for (id in names(x$shapes)) {
    item_check(x$shapes[[id]], paste0("$.shapes.", id))
  }
  for (id in names(parts)) {
    part <- parts[[id]]
    path <- graph$paths[[id]]
    at <- as.numeric(unlist(part$at))
    if (any(abs(at) > 4096)) {
      character_format_abort("input_type", paste0(path, ".at"), NULL, "Keep pivot coordinates within +/-4096.")
    }
    if (any(abs(as.numeric(unlist(part$scale))) > 16)) {
      character_format_abort("input_type", paste0(path, ".scale"), NULL, "Keep scales within [-16,16].")
    }
    candidates <- c(list(default = if (is.null(part$items)) list() else part$items), part$variants)
    if ("default" %in% names(part$variants)) {
      character_format_abort(
        "input_type",
        paste0(path, ".variants.default"),
        NULL,
        "Reserve default for the part's items array."
      )
    }
    for (variant in names(candidates)) {
      items <- candidates[[variant]]
      item_path <- if (variant == "default") paste0(path, ".items") else paste0(path, ".variants.", variant)
      ids <- vapply(items, function(item) if (is.null(item$id)) "" else item$id, character(1))
      if (anyDuplicated(ids[nzchar(ids)])) {
        character_format_abort("input_type", item_path, NULL, "Keep item ids unique within each variant.")
      }
      for (index in seq_along(items)) {
        item_check(items[[index]], paste0(item_path, "[", index - 1L, "]"))
      }
      if (!is.null(part$glow) && !part$glow$item %in% ids) {
        character_format_abort(
          "missing_reference",
          paste0(path, ".glow.item"),
          part$glow$item,
          "Keep the named emitter in each selectable variant."
        )
      }
    }
    if (!is.null(part$glow)) {
      role(part$glow$colour, paste0(path, ".glow.colour"))
    }
    if (!is.null(part$switch) && !part$switch$variant %in% names(candidates)) {
      character_format_abort(
        "missing_reference",
        paste0(path, ".switch.variant"),
        part$switch$variant,
        "Name a declared variant."
      )
    }
  }
  for (id in names(x$anchors)) {
    anchor <- x$anchors[[id]]
    path <- paste0("$.anchors.", id)
    if (!anchor$part %in% names(parts)) {
      character_format_abort("missing_reference", paste0(path, ".part"), anchor$part, "Name a declared part.")
    }
    variants <- c("default", names(parts[[anchor$part]]$variants))
    for (variant in names(anchor$variants)) {
      if (!variant %in% variants) {
        character_format_abort(
          "missing_reference",
          paste0(path, ".variants.", variant),
          variant,
          "Name an owning-part variant."
        )
      }
    }
    for (local in c(list(anchor), unname(anchor$variants))) {
      if (any(abs(as.numeric(unlist(local$at))) > 4096)) {
        character_format_abort("input_type", paste0(path, ".at"), NULL, "Keep anchor coordinates within +/-4096.")
      }
      if (!is.null(local$scale) && local$scale > 16) {
        character_format_abort("input_type", paste0(path, ".scale"), local$scale, "Keep anchor scale at most 16.")
      }
    }
  }
  slots <- character()
  for (id in x$wear) {
    if (!id %in% names(x$accessories)) {
      character_format_abort("missing_reference", "$.wear", id, "Name a declared accessory.")
    }
    slot <- x$accessories[[id]]$slot
    if (slot %in% slots) {
      character_format_abort("input_type", "$.wear", id, "Wear only one accessory in each slot.")
    }
    slots <- c(slots, slot)
  }
  for (id in names(x$accessories)) {
    if (!x$accessories[[id]]$anchor %in% names(x$anchors)) {
      character_format_abort(
        "missing_reference",
        paste0("$.accessories.", id, ".anchor"),
        NULL,
        "Name a declared anchor."
      )
    }
    for (name in names(x$accessories[[id]]$colours)) {
      role(name, paste0("$.accessories.", id, ".colours.", name))
    }
  }
  for (band in c("small", "micro")) {
    for (id in x$lod[[band]]$hide) {
      if (grepl(".", id, fixed = TRUE)) {
        target(id, paste0("$.lod.", band, ".hide"))
      } else if (!id %in% names(parts)) {
        character_format_abort(
          "missing_reference",
          paste0("$.lod.", band, ".hide"),
          id,
          "Name a declared part or item."
        )
      }
    }
    for (id in names(x$lod[[band]]$variants)) {
      if (!id %in% names(parts) || !x$lod[[band]]$variants[[id]] %in% c("default", names(parts[[id]]$variants))) {
        character_format_abort(
          "missing_reference",
          paste0("$.lod.", band, ".variants.", id),
          NULL,
          "Name a declared part variant."
        )
      }
    }
  }
  if (!is.null(x$ground$shadow)) {
    role(if (is.null(x$ground$shadow$colour)) "shadow" else x$ground$shadow$colour, "$.ground.shadow.colour")
  }
  for (outline in c(list(x$outline), lapply(x$lod, `[[`, "outline"))) {
    if (is.null(outline)) {
      next
    }
    if (!is.null(outline$colour)) {
      role(outline$colour, "$.outline.colour")
    }
    if (!is.null(outline$second)) role(outline$second$colour, "$.outline.second.colour")
  }
  kit <- NULL
  if (!is.null(x$face)) {
    if (any(abs(as.numeric(unlist(x$face$at))) > 4096)) {
      character_format_abort("input_type", "$.face.at", NULL, "Keep face coordinates within +/-4096.")
    }
    if (!is.null(x$face$scale) && x$face$scale > 16) {
      character_format_abort("input_type", "$.face.scale", x$face$scale, "Keep face scale at most 16.")
    }
    if (!x$face$part %in% names(parts)) {
      character_format_abort("missing_reference", "$.face.part", x$face$part, "Name a declared face-owning part.")
    }
    if (!is.null(x$face$clip)) {
      target(x$face$clip, "$.face.clip")
    }
    kit <- x$face$kit_definition
    groups <- c(eyes = "eye_styles", brows = "brow_styles", mouth = "mouth_styles")
    for (group in names(groups)) {
      for (id in names(x$face$styles[[group]])) {
        kit[[groups[[group]]]][id] <- list(x$face$styles[[group]][[id]])
      }
    }
    if (!is.null(x$face$tune)) {
      tuned <- character_format_tune(stats::setNames(kit[unname(groups)], names(groups)), x$face$tune)
      for (group in names(groups)) {
        kit[[groups[[group]]]] <- tuned[[group]]
      }
    }
    schema <- character_format_schema()
    kit <- character_format_node(kit, schema$definitions$kit, "$.face.kit_definition", schema$definitions)
    for (group in names(groups)) {
      if (!kit$defaults[[group]] %in% names(kit[[groups[[group]]]])) {
        character_format_abort(
          "missing_reference",
          paste0("$.face.kit_definition.defaults.", group),
          NULL,
          "Name a declared style."
        )
      }
    }
    if (!"closed" %in% names(kit$eye_styles)) {
      character_format_abort(
        "missing_reference",
        "$.face.kit_definition.eye_styles.closed",
        NULL,
        "Declare a closed eye style for blinking."
      )
    }
    if (
      !"none" %in% names(kit$brow_styles) ||
        (if (is.null(kit$brow_styles$none$width)) 3.5 else kit$brow_styles$none$width) != 0
    ) {
      character_format_abort(
        "input_type",
        "$.face.kit_definition.brow_styles.none",
        NULL,
        "Define an empty brow style with width zero."
      )
    }
    mapper <- if (is.null(x$face$colours)) character_object() else x$face$colours
    for (id in names(mapper)) {
      if (!id %in% unlist(kit$roles)) {
        character_format_abort("invalid_colour", paste0("$.face.colours.", id), id, "Map a role declared by the kit.")
      }
      role(mapper[[id]], paste0("$.face.colours.", id))
    }
    for (id in names(kit$eye_styles)) {
      style <- kit$eye_styles[[id]]
      path <- paste0("$.face.kit_definition.eye_styles.", id)
      if (style$op == "eye_ellipse") {
        if (style$pupil$r > min(style$rx, style$ry)) {
          character_format_abort(
            "input_type",
            paste0(path, ".pupil.r"),
            style$pupil$r,
            "Keep the pupil within the eye radii."
          )
        }
        if (!is.null(style$slant) && abs(style$slant) > style$ry) {
          character_format_abort("input_type", paste0(path, ".slant"), style$slant, "Keep lid slant within +/-ry.")
        }
        for (colour in c(
          if (is.null(style$fill)) "eye_white" else style$fill,
          if (style$pupil$r > 0) "feature" else character(),
          if (
            style$pupil$r > 0 &&
              (is.null(style$pupil$glints) || any(vapply(style$pupil$glints, function(glint) glint$r > 0, logical(1))))
          ) {
            "shine"
          } else {
            character()
          },
          "eyelid",
          style$outline$colour,
          style$lid_edge$colour
        )) {
          paint_role(colour, paste0(path, ".fill"), mapper)
        }
      } else {
        if (!is.null(style$d)) {
          character_path(style$d, paste0(path, ".d"))
        }
        paint_role(
          if (is.null(style$fill) && style$op != "eye_arc") {
            "feature"
          } else if (is.null(style$stroke)) {
            "feature"
          } else {
            style$stroke
          },
          paste0(path, ".fill"),
          mapper
        )
        if (!is.null(style$fill)) {
          paint_role(style$fill, paste0(path, ".fill"), mapper)
        }
        if (!is.null(style$stroke)) paint_role(style$stroke, paste0(path, ".stroke"), mapper)
      }
      if (!is.null(style$lashes)) paint_role("feature", paste0(path, ".lashes"), mapper)
    }
    for (id in names(kit$brow_styles)) {
      style <- kit$brow_styles[[id]]
      character_path(style$d, paste0("$.face.kit_definition.brow_styles.", id, ".d"))
      if (is.null(style$width) || style$width > 0) {
        paint_role(
          if (is.null(style$stroke)) "feature" else style$stroke,
          paste0("$.face.kit_definition.brow_styles.", id, ".stroke"),
          mapper
        )
      }
    }
    for (id in names(kit$mouth_styles)) {
      for (index in seq_along(kit$mouth_styles[[id]]$items)) {
        item_check(
          kit$mouth_styles[[id]]$items[[index]],
          paste0("$.face.kit_definition.mouth_styles.", id, ".items[", index - 1L, "]"),
          mapper
        )
      }
    }
    if (!is.null(x$face$eyes$iris)) {
      role(x$face$eyes$iris, "$.face.eyes.iris")
    }
    if (!is.null(x$face$blush)) {
      for (id in c("blush", "blush_strong")) {
        paint_role(id, "$.face.blush", mapper)
      }
    }
  }
  for (id in names(kit$effects)) {
    effect <- kit$effects[[id]]
    path <- paste0("$.face.kit_definition.effects.", id)
    character_effect_ranges(effect, path)
    for (index in seq_along(effect$items)) {
      character_geometry(
        effect$items[[index]],
        if (is.null(x$shapes)) character_object() else x$shapes,
        paste0(path, ".items[", index - 1L, "]")
      )
    }
    for (index in seq_along(effect$reduced_items)) {
      character_geometry(
        effect$reduced_items[[index]],
        if (is.null(x$shapes)) character_object() else x$shapes,
        paste0(path, ".reduced_items[", index - 1L, "]")
      )
    }
  }
  used_effects <- names(x$effects)
  for (gesture in x$gestures) {
    if (all(unlist(gesture$needs) %in% names(parts))) {
      used_effects <- union(used_effects, vapply(gesture$effects, `[[`, character(1), "effect"))
    }
  }
  for (id in used_effects) {
    effect <- kit$effects[[id]]
    if (is.null(effect)) {
      character_format_abort(
        "missing_reference",
        paste0("$.effects.", id),
        id,
        "Name an effect declared by the face kit."
      )
    }
    if (!is.null(x$effects[[id]]) && !x$effects[[id]]$anchor %in% names(x$anchors)) {
      character_format_abort("missing_reference", paste0("$.effects.", id, ".anchor"), NULL, "Name a declared anchor.")
    }
    for (index in seq_along(effect$items)) {
      item_check(
        effect$items[[index]],
        paste0("$.face.kit_definition.effects.", id, ".items[", index - 1L, "]"),
        if (is.null(x$face$colours)) character_object() else x$face$colours
      )
    }
    if (
      effect$op == "sweat_drop" &&
        !effect$mode %in% c("progress", "track") ||
        effect$op == "sparkle_star" && !effect$mode %in% c("pulse", "track")
    ) {
      character_format_abort(
        "input_type",
        paste0("$.face.kit_definition.effects.", id, ".mode"),
        effect$mode,
        "Use a supported effect operation/mode pair."
      )
    }
    if (effect$mode == "progress" && "reduced_items" %in% names(effect)) {
      character_format_abort(
        "input_type",
        paste0("$.face.kit_definition.effects.", id, ".reduced_items"),
        NULL,
        "Progress effects retain their static geometry under reduction."
      )
    }
    if (effect$mode != "track" && any(c("frames", "tracks") %in% names(effect))) {
      character_format_abort(
        "input_type",
        paste0("$.face.kit_definition.effects.", id),
        NULL,
        "Only track-mode effects declare frames and tracks."
      )
    }
  }
  graph$kit <- kit
  graph
}

#' Validate a kit effect and bound its absolute local tracks
#' @noRd
character_effect_ranges <- function(effect, path = "$.effect") {
  checkmate::assert_list(effect)
  checkmate::assert_string(path)
  valid <- if (effect$op == "sweat_drop") c("progress", "track") else c("pulse", "track")
  if (!effect$mode %in% valid) {
    character_format_abort(
      "input_type",
      paste0(path, ".mode"),
      effect$mode,
      "Use a supported effect operation/mode pair."
    )
  }
  allowed <- c(
    "op",
    "mode",
    "at",
    "items",
    "note",
    if (effect$mode == "progress") {
      c("travel", "sway", "sway_rate", "fade_at")
    } else if (effect$mode == "pulse") {
      c("reduced_items", "amplitude", "rate")
    } else {
      c("reduced_items", "frames", "tracks")
    }
  )
  extra <- setdiff(names(effect), allowed)
  if (length(extra)) {
    character_format_abort(
      "input_type",
      paste0(path, ".", extra[[1L]]),
      NULL,
      "This field does not apply to the selected effect mode."
    )
  }
  ranges <- list(x = c(0, 0), y = c(0, 0), scale_x = c(1, 1), scale_y = c(1, 1), opacity = c(0, 1))
  if (effect$mode != "track") {
    return(ranges)
  }
  if (is.null(effect$frames) || is.null(effect$tracks)) {
    character_format_abort("input_type", path, NULL, "Track-mode effects require frames and tracks.")
  }
  for (id in names(effect$tracks)) {
    track <- effect$tracks[[id]]
    keys <- if (is.null(names(track))) track else track$keys
    mode <- if (is.null(track$mode)) "set" else track$mode
    if (mode != "set") {
      character_format_abort(
        "invalid_channel",
        paste0(path, ".tracks.", id),
        mode,
        "Effect tracks use absolute set values."
      )
    }
    times <- vapply(keys, function(key) key[[1L]], numeric(1))
    if (times[[1L]] != 0 || utils::tail(times, 1L) != 1 || any(diff(times) <= 0)) {
      character_format_abort(
        "invalid_channel",
        paste0(path, ".tracks.", id),
        NULL,
        "Keys must increase strictly from 0 to 1."
      )
    }
    values <- unlist(lapply(keys, function(key) key[[2L]]))
    limits <- if (id == "opacity") {
      c(0, 1)
    } else if (id %in% c("scale_x", "scale_y")) {
      c(-16, 16)
    } else {
      c(-4096, 4096)
    }
    if (!is.numeric(values) || any(!is.finite(values)) || any(values < limits[[1L]] | values > limits[[2L]])) {
      character_format_abort(
        "invalid_channel",
        paste0(path, ".tracks.", id),
        NULL,
        "Use finite numeric effect values within the channel range."
      )
    }
    ranges[[id]] <- range(c(ranges[[id]], values))
  }
  ranges
}
