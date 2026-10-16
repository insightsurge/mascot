#' Empty deterministic drawing-work vector
#' @noRd
character_work_zero <- function() {
  stats::setNames(
    rep(0, 9L),
    c(
      "active_parts",
      "painted_items",
      "paint_passes",
      "path_numbers",
      "clip_applications",
      "gradient_uses",
      "glow_emitters",
      "blur_design_units",
      "inflated_glow_area_ratio"
    )
  )
}

#' Sum independent work, taking the maximum blur radius
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_work_sum <- function(costs) {
  result <- character_work_zero()
  for (cost in costs) {
    radius <- max(result[["blur_design_units"]], cost[["blur_design_units"]])
    result <- result + cost
    result[["blur_design_units"]] <- radius
  }
  result
}

#' Componentwise upper bound across mutually exclusive choices
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_work_max <- function(costs) {
  result <- character_work_zero()
  for (cost in costs) {
    result <- pmax(result, cost)
  }
  result
}

#' Resolve per-band outline policy independently for each band
#' @noRd
character_work_outline <- function(x, band) {
  checkmate::assert_list(x)
  checkmate::assert_choice(band, c("full", "small", "micro"))
  outline <- if (is.null(x$outline)) character_object() else x$outline
  for (override in list(outline$lod[[band]], x$lod[[band]]$outline)) {
    if (!is.null(override)) {
      for (key in names(override)) {
        outline[key] <- list(override[[key]])
      }
    }
  }
  outline
}

#' Count ordinary geometry once, and its actual paint invocations separately
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_work_item <- function(item, shapes, outline) {
  geometry <- character_geometry(item, shapes)
  style <- geometry$item
  result <- character_work_zero()
  if (!is.null(style$alpha) && style$alpha <= 0) {
    return(result)
  }
  fill <- !is.null(style$fill)
  stroke <- !is.null(style$stroke) && (is.null(style$width) || style$width > 0)
  primary <- isTRUE(style$outline) && !is.null(outline$width) && outline$width > 0
  second <- isTRUE(style$outline) && !is.null(outline$second$width) && outline$second$width > 0
  result[["paint_passes"]] <- sum(fill, stroke, primary, second)
  if (!result[["paint_passes"]]) {
    return(result)
  }
  result[["painted_items"]] <- 1
  result[["path_numbers"]] <- geometry$numbers
  result[["gradient_uses"]] <- as.integer(fill && is.list(style$fill))
  result
}

#' Bound every authored scale, including additive tracks and idle breathing
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_work_scale <- function(owner, x, graph, behaviour) {
  result <- 1
  repeat {
    ranges <- character_format_ranges(x, behaviour)
    extrema <- vapply(c("scale_x", "scale_y"), function(axis) max(abs(ranges[[paste0(owner, ".", axis)]])), numeric(1))
    result <- result * max(extrema)
    if (owner == "root") {
      break
    }
    part <- graph$parts[[owner]]
    accessory <- attr(part, "accessory")
    if (!is.null(accessory) && (is.null(part$parent) || part$parent == "root")) {
      anchor <- x$anchors[[x$accessories[[accessory]]$anchor]]
      result <- result *
        max(c(if (is.null(anchor$scale)) 1 else anchor$scale, unlist(lapply(anchor$variants, `[[`, "scale"))))
    }
    owner <- graph$parents[[owner]]
  }
  result
}

#' Conservative local box including stroke tips
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_work_box <- function(item, shapes, outline) {
  geometry <- character_geometry(item, shapes)
  item <- geometry$item
  widths <- if (is.null(item$stroke)) {
    0
  } else if (is.null(item$width)) {
    2.5
  } else {
    item$width
  }
  if (isTRUE(item$outline)) {
    widths <- c(widths, outline$width, outline$second$width)
  }
  width <- max(widths)
  ref <- attr(item, "ref_transform")
  if (!is.null(ref$scale)) {
    width <- width * max(abs(unlist(ref$scale)))
  }
  # Canvas's fixed default miterLimit is 10. Round/bevel tips need half a width.
  miter <- identical(item$join, "miter") || (isTRUE(item$outline) && identical(outline$join, "miter"))
  pad <- width * if (miter) 5 else 0.5
  geometry$box + c(-pad, -pad, pad, pad)
}

#' One bounded emission group, independent of translations/rotations
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_work_glow <- function(items, definition, owner, x, graph, behaviour, band, scale = 1) {
  result <- character_work_zero()
  enabled <- if (is.null(x$lod[[band]]$glow)) band != "micro" else x$lod[[band]]$glow
  if (!enabled || is.null(definition) || !length(items) || (!is.null(definition$alpha) && definition$alpha <= 0)) {
    return(result)
  }
  outline <- character_work_outline(x, band)
  boxes <- lapply(
    items,
    character_work_box,
    shapes = if (is.null(x$shapes)) character_object() else x$shapes,
    outline = outline
  )
  width <- max(vapply(boxes, `[[`, numeric(1), 3L)) - min(vapply(boxes, `[[`, numeric(1), 1L))
  height <- max(vapply(boxes, `[[`, numeric(1), 4L)) - min(vapply(boxes, `[[`, numeric(1), 2L))
  diameter <- sqrt(width^2 + height^2) * character_work_scale(owner, x, graph, behaviour) * scale
  has_fill <- any(vapply(items, function(item) !is.null(item$fill), logical(1)))
  has_stroke <- any(vapply(
    items,
    function(item) !is.null(item$stroke) && (is.null(item$width) || item$width > 0),
    logical(1)
  ))
  result[["glow_emitters"]] <- 1
  result[["paint_passes"]] <- if (has_fill && has_stroke) 2L else 1L
  result[["blur_design_units"]] <- definition$blur
  result[["inflated_glow_area_ratio"]] <- (diameter + 6 * definition$blur)^2 / 90000
  result[["gradient_uses"]] <- 0L
  result
}

#' Expand generic eye operations into their ordinary drawing items
#' @noRd
character_work_eye <- function(style, face, flags) {
  checkmate::assert_list(style)
  checkmate::assert_list(face)
  checkmate::assert_list(flags)
  items <- list()
  clip <- FALSE
  op <- style$op
  if (op == "eye_ellipse") {
    sclera <- list(
      shape = "ellipse",
      rx = style$rx,
      ry = style$ry,
      fill = if (is.null(style$fill)) "eye_white" else style$fill
    )
    if (!is.null(style$outline) && style$outline$width > 0) {
      sclera$stroke <- style$outline$colour
      sclera$width <- style$outline$width
    }
    items <- list(sclera)
    pupil <- style$pupil
    iris <- !is.null(face$eyes$iris) && !identical(flags$iris, FALSE)
    if (iris && pupil$r > 0) {
      items[[length(items) + 1L]] <- list(shape = "circle", r = pupil$r, fill = "iris")
    }
    if (pupil$r > 0) {
      items[[length(items) + 1L]] <- list(shape = "circle", r = pupil$r * if (iris) 0.65 else 1, fill = "feature")
      glints <- if (is.null(pupil$glints)) list(list(at = list(-0.35, -0.4), r = 0.22)) else pupil$glints
      for (glint in glints) {
        if (glint$r > 0) items[[length(items) + 1L]] <- list(shape = "circle", r = pupil$r * glint$r, fill = "shine")
      }
    }
    # A positive held lid is legal while the ellipse style is selected.
    items[[length(items) + 1L]] <- list(
      shape = "rect",
      x = -1.2 * style$rx,
      y = -1.2 * style$ry,
      w = 2.4 * style$rx,
      h = 2.4 * style$ry,
      fill = "eyelid"
    )
    if (!is.null(style$lid_edge) && style$lid_edge$width > 0) {
      items[[length(items) + 1L]] <- list(
        shape = "polyline",
        points = list(list(-1.2 * style$rx, 0), list(1.2 * style$rx, 0)),
        stroke = style$lid_edge$colour,
        width = style$lid_edge$width
      )
    }
    clip <- TRUE
  } else if (op == "eye_dots") {
    for (centre in style$centres) {
      items[[length(items) + 1L]] <- list(
        shape = "circle",
        x = centre[[1L]],
        y = centre[[2L]],
        r = style$r,
        fill = if (is.null(style$fill)) "feature" else style$fill
      )
    }
  } else if (op == "eye_path") {
    items <- list(list(
      shape = "path",
      d = style$d,
      fill = if (!"fill" %in% names(style)) "feature" else style$fill,
      stroke = style$stroke,
      width = if (is.null(style$width)) 2 else style$width
    ))
  } else if (op == "eye_arc") {
    items <- list(list(
      shape = "arc",
      r = style$r,
      start = style$start,
      end = style$end,
      y = if (is.null(style$y)) 0 else style$y,
      stroke = if (!"stroke" %in% names(style)) "feature" else style$stroke,
      width = if (is.null(style$width)) 5 else style$width,
      fill = style$fill,
      closed = !is.null(style$fill)
    ))
  }
  if (!is.null(style$lashes) && !identical(face$eyes$lashes, FALSE) && !identical(flags$lashes, FALSE)) {
    radii <- if (is.null(style$lashes$radii)) {
      c(if (op == "eye_arc") style$r else style$rx, if (op == "eye_arc") style$r else style$ry)
    } else {
      unlist(style$lashes$radii)
    }
    at <- if (is.null(style$lashes$at)) c(0, 0) else unlist(style$lashes$at)
    lash_length <- if (is.null(style$lashes$length)) 7 else style$lashes$length
    for (angle in style$lashes$angles) {
      start <- at + radii * c(cos(angle), sin(angle))
      end <- start + lash_length * c(cos(angle), sin(angle))
      items[[length(items) + 1L]] <- list(
        shape = "polyline",
        points = list(as.list(start), as.list(end)),
        stroke = "feature",
        width = if (is.null(style$lashes$width)) 3 else style$lashes$width
      )
    }
  }
  glow_items <- if (op == "eye_ellipse") {
    c(
      list(items[[1L]]),
      Filter(function(item) identical(item$shape, "polyline") && identical(item$stroke, "feature"), items)
    )
  } else {
    items
  }
  list(items = items, clip = clip, glow_items = glow_items)
}

#' Resolve parts suppressed permanently by this detail band
#' @noRd
character_work_visible <- function(x, graph, band) {
  checkmate::assert_list(x)
  checkmate::assert_list(graph)
  checkmate::assert_choice(band, c("full", "small", "micro"))
  visible <- stats::setNames(rep(FALSE, length(graph$parts)), names(graph$parts))
  hidden <- unlist(x$lod[[band]]$hide)
  for (id in graph$order) {
    part <- graph$parts[[id]]
    parent <- graph$parents[[id]]
    accessory <- attr(part, "accessory")
    allowed <- is.null(part$lod) || band %in% unlist(part$lod)
    if (!is.null(accessory)) {
      allowed <- allowed &&
        (is.null(x$accessories[[accessory]]$lod) || band %in% unlist(x$accessories[[accessory]]$lod))
    }
    visible[[id]] <- allowed && !id %in% hidden && (parent == "root" || visible[[parent]])
  }
  visible
}

#' Count a safe per-band upper bound over structural choices
#' @noRd
character_format_work <- function(x, graph, behaviour, band = "full") {
  checkmate::assert_list(x)
  checkmate::assert_list(graph)
  checkmate::assert_list(behaviour)
  checkmate::assert_choice(band, c("full", "small", "micro"))
  outline <- character_work_outline(x, band)
  shapes <- if (is.null(x$shapes)) character_object() else x$shapes
  visible <- character_work_visible(x, graph, band)
  hidden <- unlist(x$lod[[band]]$hide)
  needed <- character()
  require_part <- function(id) {
    result <- character()
    while (id != "root") {
      result <- c(result, id)
      id <- graph$parents[[id]]
    }
    result
  }
  variants <- function(id) {
    part <- graph$parts[[id]]
    all <- c(list(default = if (is.null(part$items)) list() else part$items), part$variants)
    selected <- x$lod[[band]]$variants[[id]]
    if (is.null(selected)) all else all[selected]
  }
  clip_cost <- function(reference, source_id = "", source_variant = "") {
    pair <- strsplit(reference, ".", fixed = TRUE)[[1L]]
    choices <- variants(pair[[1L]])
    if (pair[[1L]] == source_id) {
      choices <- choices[source_variant]
    }
    costs <- list()
    for (items in choices) {
      found <- Filter(function(item) identical(item$id, pair[[2L]]), items)
      if (length(found) != 1L) {
        character_format_abort(
          "missing_reference",
          "$.clip",
          reference,
          "Keep the clip target in every reachable active variant."
        )
      }
      cost <- character_work_zero()
      cost[["clip_applications"]] <- 1
      cost[["path_numbers"]] <- character_geometry(found[[1L]], shapes)$numbers
      costs[[length(costs) + 1L]] <- cost
    }
    character_work_max(costs)
  }
  part_costs <- list()
  for (id in names(graph$parts)) {
    if (!visible[[id]]) {
      next
    }
    part <- graph$parts[[id]]
    choices <- list()
    for (variant in names(variants(id))) {
      items <- variants(id)[[variant]]
      costs <- list()
      for (index in seq_along(items)) {
        item <- items[[index]]
        if ((!is.null(item$lod) && !band %in% unlist(item$lod)) || paste0(id, ".", item$id) %in% hidden) {
          next
        }
        alternatives <- list(item)
        for (mood in x$moods) {
          for (selection in list(mood, mood$reduced)) {
            change <- selection$items[[paste0(id, ".", item$id)]]
            if (!is.null(change)) alternatives[[length(alternatives) + 1L]] <- character_format_merge(item, change)
          }
        }
        cost <- character_work_max(lapply(alternatives, character_work_item, shapes = shapes, outline = outline))
        emitting <- !is.null(part$glow) &&
          identical(item$id, part$glow$item) &&
          (if (is.null(x$lod[[band]]$glow)) band != "micro" else x$lod[[band]]$glow) &&
          (is.null(part$glow$alpha) || part$glow$alpha > 0)
        if (emitting && !cost[["painted_items"]]) {
          cost[["painted_items"]] <- 1
          cost[["path_numbers"]] <- character_geometry(item, shapes)$numbers
        }
        if (cost[["painted_items"]]) {
          needed <- union(needed, require_part(id))
          if (!is.null(item$clip)) {
            cost <- character_work_sum(list(cost, clip_cost(item$clip, id, variant)))
            needed <- union(needed, require_part(strsplit(item$clip, ".", fixed = TRUE)[[1L]][[1L]]))
          }
          if (!is.null(part$glow) && identical(item$id, part$glow$item)) {
            cost <- character_work_sum(list(
              cost,
              character_work_glow(list(character_shape(item, shapes)), part$glow, id, x, graph, behaviour, band)
            ))
          }
        }
        costs[[length(costs) + 1L]] <- cost
      }
      choices[[length(choices) + 1L]] <- character_work_sum(costs)
    }
    part_costs[[id]] <- character_work_max(choices)
  }
  # Main anatomy always exists; one accessory per slot is a mutually exclusive choice.
  main_ids <- names(graph$parts)[vapply(graph$parts, function(part) is.null(attr(part, "accessory")), logical(1))]
  result <- character_work_sum(part_costs[intersect(main_ids, names(part_costs))])
  slots <- unique(vapply(x$accessories, `[[`, character(1), "slot"))
  for (slot in slots) {
    alternatives <- list()
    for (accessory in names(x$accessories)) {
      if (x$accessories[[accessory]]$slot == slot) {
        ids <- names(graph$parts)[vapply(
          graph$parts,
          function(part) identical(attr(part, "accessory"), accessory),
          logical(1)
        )]
        cost <- character_work_sum(part_costs[intersect(ids, names(part_costs))])
        cost[["active_parts"]] <- length(intersect(ids, needed))
        alternatives[[length(alternatives) + 1L]] <- cost
      }
    }
    result <- character_work_sum(list(result, character_work_max(alternatives)))
  }
  face <- x$face
  if (!is.null(face) && visible[[face$part]]) {
    needed <- union(needed, require_part(face$part))
    flags <- if (is.null(x$lod[[band]]$face)) character_object() else x$lod[[band]]$face
    scale <- if (is.null(face$scale)) 1 else face$scale
    if (!is.null(flags$scale)) {
      scale <- flags$scale
    }
    kit <- graph$kit
    brows <- list()
    for (style in kit$brow_styles) {
      item <- list(
        shape = "path",
        d = style$d,
        stroke = if (is.null(style$stroke)) "feature" else style$stroke,
        width = if (is.null(style$width)) 3.5 else style$width
      )
      cost <- if (identical(flags$brows, FALSE)) character_work_zero() else character_work_item(item, shapes, outline)
      if (cost[["painted_items"]]) {
        cost <- character_work_sum(list(
          cost,
          character_work_glow(list(item), kit$glow, face$part, x, graph, behaviour, band, scale)
        ))
      }
      brows[[length(brows) + 1L]] <- cost
    }
    brow <- character_work_max(brows)
    eyes <- list()
    for (style in kit$eye_styles) {
      expanded <- character_work_eye(style, face, flags)
      cost <- character_work_sum(lapply(expanded$items, character_work_item, shapes = shapes, outline = outline))
      if (expanded$clip) {
        cost[["clip_applications"]] <- cost[["clip_applications"]] + 1
        cost[["path_numbers"]] <- cost[["path_numbers"]] + 7
      }
      if (cost[["painted_items"]]) {
        cost <- character_work_sum(list(
          cost,
          character_work_glow(expanded$glow_items, kit$glow, face$part, x, graph, behaviour, band, scale)
        ))
      }
      if (!isTRUE(style$hide_brows)) {
        cost <- character_work_sum(list(cost, brow))
      }
      eyes[[length(eyes) + 1L]] <- cost
    }
    eye <- character_work_max(eyes)
    mouths <- list()
    for (style in kit$mouth_styles) {
      cost <- character_work_sum(lapply(style$items, character_work_item, shapes = shapes, outline = outline))
      box <- if (is.null(style$box)) c(20, 12) else unlist(style$box)
      # For emission bounds apply normalised mouth box to coordinates, leaving widths in face units.
      emitted <- lapply(style$items, function(item) {
        checkmate::assert_list(item)
        if (item$shape == "path") {
          commands <- character_path(item$d)
          item$d <- paste(
            vapply(
              commands,
              function(command) {
                paste(c(command$op, command$values * rep(box, length.out = length(command$values))), collapse = " ")
              },
              character(1)
            ),
            collapse = " "
          )
        } else if (item$shape == "ellipse") {
          item$x <- (if (is.null(item$x)) 0 else item$x) * box[[1L]]
          item$y <- (if (is.null(item$y)) 0 else item$y) * box[[2L]]
          item$rx <- item$rx * box[[1L]]
          item$ry <- item$ry * box[[2L]]
        } else {
          item$points <- lapply(item$points, function(point) as.list(unlist(point) * box))
        }
        item
      })
      if (cost[["painted_items"]]) {
        cost <- character_work_sum(list(
          cost,
          character_work_glow(emitted, kit$glow, face$part, x, graph, behaviour, band, scale)
        ))
      }
      mouths[[length(mouths) + 1L]] <- cost
    }
    result <- character_work_sum(list(result, eye, eye, character_work_max(mouths)))
    if (!is.null(face$blush)) {
      result <- character_work_sum(c(
        list(result),
        rep(
          list(character_work_item(
            list(shape = "ellipse", rx = face$blush$rx, ry = face$blush$ry, fill = "blush"),
            shapes,
            outline
          )),
          2L
        )
      ))
    }
    if (!is.null(face$clip)) {
      result <- character_work_sum(list(result, clip_cost(face$clip)))
      needed <- union(needed, require_part(strsplit(face$clip, ".", fixed = TRUE)[[1L]][[1L]]))
    }
  }
  effect_cost <- function(effect, anchor) {
    checkmate::assert_list(effect)
    checkmate::assert_string(anchor)
    owner <- x$anchors[[anchor]]$part
    if (!visible[[owner]]) {
      return(character_work_zero())
    }
    choices <- list(effect$items, effect$reduced_items)
    costs <- lapply(choices, function(items) {
      checkmate::assert_list(items, null.ok = TRUE)
      character_work_sum(lapply(items, function(item) {
        checkmate::assert_list(item)
        cost <- character_work_item(item, shapes, outline)
        if (!is.null(item$clip) && cost[["painted_items"]]) {
          cost <- character_work_sum(list(cost, clip_cost(item$clip)))
        }
        cost
      }))
    })
    character_work_max(costs)
  }
  for (id in names(x$effects)) {
    owner <- x$anchors[[x$effects[[id]]$anchor]]$part
    if (visible[[owner]]) {
      needed <- union(needed, require_part(owner))
    }
    result <- character_work_sum(list(result, effect_cost(graph$kit$effects[[id]], x$effects[[id]]$anchor)))
  }
  triggered <- list()
  for (id in unique(unlist(behaviour$playable))) {
    costs <- list()
    for (trigger in x$gestures[[id]]$effects) {
      costs[[length(costs) + 1L]] <- effect_cost(graph$kit$effects[[trigger$effect]], trigger$anchor)
      owner <- x$anchors[[trigger$anchor]]$part
      if (visible[[owner]]) needed <- union(needed, require_part(owner))
    }
    triggered[[length(triggered) + 1L]] <- character_work_sum(costs)
  }
  result <- character_work_sum(list(result, character_work_max(triggered)))
  if (!is.null(x$ground$shadow)) {
    result <- character_work_sum(list(
      result,
      character_work_item(
        list(
          shape = "ellipse",
          rx = x$ground$shadow$rx,
          ry = x$ground$shadow$ry,
          alpha = if (is.null(x$ground$shadow$alpha)) 1 else x$ground$shadow$alpha,
          fill = "shadow"
        ),
        shapes,
        outline
      )
    ))
  }
  result[["active_parts"]] <- result[["active_parts"]] + length(intersect(main_ids, needed))
  area <- result[["inflated_glow_area_ratio"]]
  if (area > 0) {
    result[["inflated_glow_area_ratio"]] <- ceiling((area + abs(area) * .Machine$double.eps) * 1e12) / 1e12
  }
  limits <- character_format_policy()$bands[[band]]
  for (metric in names(result)) {
    if (result[[metric]] > limits[[metric]]) {
      character_format_abort(
        "budget",
        paste0("$.budgets.", band, ".", metric),
        result[[metric]],
        "Reduce expanded drawing work in this band."
      )
    }
  }
  result
}
