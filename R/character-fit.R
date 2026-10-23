#' Interval addition/multiplication for conservative authored geometry
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_interval <- function(a, b, operation = "add") {
  result <- if (operation == "add") a + b else range(outer(a, b, "*"))
  if (any(!is.finite(result))) {
    character_format_abort("budget", "$.geometry", NULL, "Reduce composed transform magnitudes.")
  }
  result
}

#' Trigonometric interval including interior extrema
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_interval_trig <- function(angle, cosine = FALSE) {
  if (diff(angle) >= 2 * pi || any(abs(angle) > 1e12)) {
    return(c(-1, 1))
  }
  offset <- if (cosine) 0 else pi / 2
  low <- ceiling((angle[[1L]] - offset) / pi)
  high <- floor((angle[[2L]] - offset) / pi)
  values <- if (cosine) cos(angle) else sin(angle)
  if (low <= high) {
    values <- c(values, (-1)^(low:high))
  }
  range(values)
}

#' Interval affine multiplication, using six Canvas-ordered components
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_interval_matrix <- function(a, b) {
  mul <- function(i, j) character_interval(a[[i]], b[[j]], "multiply")
  add <- function(i, j, k, l) character_interval(mul(i, j), mul(k, l))
  result <- list(
    add(1, 1, 3, 2),
    add(2, 1, 4, 2),
    add(1, 3, 3, 4),
    add(2, 3, 4, 4),
    character_interval(add(1, 5, 3, 6), a[[5L]]),
    character_interval(add(2, 5, 4, 6), a[[6L]])
  )
  bound <- function(matrix) {
    known <- attr(matrix, "norm")
    if (!is.null(known)) {
      return(known)
    }
    sqrt(sum(vapply(matrix[1:4], function(axis) max(abs(axis))^2, numeric(1))))
  }
  norm <- bound(a) * bound(b)
  if (!is.finite(norm)) {
    character_format_abort("budget", "$.geometry", NULL, "Reduce composed transform magnitudes.")
  }
  for (index in 1:4) {
    result[[index]] <- c(max(-norm, result[[index]][[1L]]), min(norm, result[[index]][[2L]]))
  }
  attr(result, "norm") <- norm
  result
}

#' Interval local translation, rotation and scale
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_interval_local <- function(x, y, rotate, sx, sy) {
  cosine <- character_interval_trig(rotate, TRUE)
  sine <- character_interval_trig(rotate)
  result <- list(
    character_interval(cosine, sx, "multiply"),
    character_interval(sine, sx, "multiply"),
    -rev(character_interval(sine, sy, "multiply")),
    character_interval(cosine, sy, "multiply"),
    x,
    y
  )
  attr(result, "norm") <- max(abs(c(sx, sy)))
  result
}

#' Transform a conservative box with an interval affine matrix
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_interval_box <- function(box, matrix) {
  x <- character_interval(
    character_interval(matrix[[1L]], box[c(1L, 3L)], "multiply"),
    character_interval(matrix[[3L]], box[c(2L, 4L)], "multiply")
  )
  y <- character_interval(
    character_interval(matrix[[2L]], box[c(1L, 3L)], "multiply"),
    character_interval(matrix[[4L]], box[c(2L, 4L)], "multiply")
  )
  x <- character_interval(x, matrix[[5L]])
  y <- character_interval(y, matrix[[6L]])
  c(x[[1L]], y[[1L]], x[[2L]], y[[2L]])
}

#' Authored channel extrema over poses, moods, reduced stills and playable tracks
#' @noRd
character_format_ranges <- function(x, behaviour) {
  checkmate::assert_list(x)
  checkmate::assert_list(behaviour)
  ranges <- list()
  for (target in names(behaviour$rules)) {
    rule <- behaviour$rules[[target]]
    if (rule$type != "number" && target != "root.flip") {
      next
    }
    bases <- c(rule$base, unlist(lapply(behaviour$mood_bases, `[[`, target)), unlist(lapply(x$poses, `[[`, target)))
    for (mood in x$moods) {
      if (!is.null(mood$reduced$channels[[target]])) bases <- c(bases, mood$reduced$channels[[target]])
    }
    values <- bases
    for (id in unique(unlist(behaviour$playable))) {
      track <- behaviour$tracks[[id]][[target]]
      if (is.null(track)) {
        next
      }
      keys <- unlist(lapply(track$keys, function(key) key[[2L]]))
      values <- c(values, if (track$mode == "add") as.vector(outer(bases, keys, "+")) else keys)
    }
    ranges[[target]] <- range(values)
  }
  for (axis in c("scale_x", "scale_y")) {
    target <- paste0(behaviour$idle$breathe_part, ".", axis)
    ranges[[target]] <- character_interval(
      ranges[[target]],
      c(1 - behaviour$idle$breathe, 1 + behaviour$idle$breathe),
      "multiply"
    )
  }
  if (behaviour$change$style != "gesture") {
    ranges[["root.rotate"]] <- character_interval(
      ranges[["root.rotate"]],
      c(-abs(behaviour$change$angle), abs(behaviour$change$angle))
    )
    ranges[["root.lift"]] <- character_interval(
      ranges[["root.lift"]],
      c(-abs(behaviour$change$height), abs(behaviour$change$height))
    )
  }
  ranges
}

#' Bound authored artwork at default host placement; never certify an uncertain fit
#' @noRd
character_format_fit <- function(x, graph, behaviour, band = "full") {
  checkmate::assert_list(x)
  checkmate::assert_list(graph)
  checkmate::assert_list(behaviour)
  checkmate::assert_choice(band, c("full", "small", "micro"))
  world_coordinates <- any(vapply(
    graph$parts,
    function(part) isTRUE(part$keep_upright) || isTRUE(part$no_flip),
    logical(1)
  ))
  ranges <- character_format_ranges(x, behaviour)
  identity <- list(c(1, 1), c(0, 0), c(0, 0), c(1, 1), c(0, 0), c(0, 0))
  attr(identity, "norm") <- 1
  matrices <- list(root = identity)
  if (world_coordinates) {
    root_scale <- character_interval(ranges[["root.scale_x"]], ranges[["root.flip"]], "multiply")
    translation <- identity
    translation[[5L]] <- c(150, 150)
    translation[[6L]] <- character_interval(c(270, 270), -rev(ranges[["root.lift"]]))
    squash <- character_interval_local(c(0, 0), c(0, 0), c(0, 0), root_scale, ranges[["root.scale_y"]])
    pivot <- identity
    pivot[[6L]] <- rep(-x$ground$centre_height, 2L)
    rotation <- character_interval_local(c(0, 0), c(0, 0), ranges[["root.rotate"]], c(1, 1), c(1, 1))
    back <- identity
    back[[6L]] <- rep(x$ground$centre_height, 2L)
    matrices$root <- Reduce(character_interval_matrix, list(translation, squash, pivot, rotation, back))
  }
  anchor_matrix <- function(id) {
    definition <- x$anchors[[id]]
    choices <- c(
      list(definition),
      lapply(definition$variants, function(override) character_format_merge(definition, override))
    )
    at <- lapply(1:2, function(index) {
      range(vapply(choices, function(anchor) if (is.null(anchor$at)) 0 else anchor$at[[index]], numeric(1)))
    })
    angle <- range(vapply(choices, function(anchor) if (is.null(anchor$rotate)) 0 else anchor$rotate, numeric(1)))
    scale <- range(vapply(choices, function(anchor) if (is.null(anchor$scale)) 1 else anchor$scale, numeric(1)))
    character_interval_matrix(
      matrices[[definition$part]],
      character_interval_local(at[[1L]], at[[2L]], angle, scale, scale)
    )
  }
  for (id in graph$order) {
    part <- graph$parts[[id]]
    parent <- matrices[[if (is.null(part$parent)) "root" else part$parent]]
    accessory <- attr(part, "accessory")
    if (!is.null(accessory) && (is.null(part$parent) || part$parent == "root")) {
      parent <- anchor_matrix(x$accessories[[accessory]]$anchor)
    }
    at <- if (is.null(part$at)) c(0, 0) else unlist(part$at)
    local <- character_interval_local(
      character_interval(c(at[[1L]], at[[1L]]), ranges[[paste0(id, ".x")]]),
      character_interval(c(at[[2L]], at[[2L]]), ranges[[paste0(id, ".y")]]),
      ranges[[paste0(id, ".rotate")]],
      ranges[[paste0(id, ".scale_x")]],
      ranges[[paste0(id, ".scale_y")]]
    )
    matrices[[id]] <- if (isTRUE(part$keep_upright) || isTRUE(part$no_flip)) {
      character_interval_filter(parent, local, isTRUE(part$keep_upright), isTRUE(part$no_flip))
    } else {
      character_interval_matrix(parent, local)
    }
  }
  visible <- character_work_visible(x, graph, band)
  outline <- character_work_outline(x, band)
  shapes <- if (is.null(x$shapes)) character_object() else x$shapes
  boxes <- list()
  variants <- function(id) {
    part <- graph$parts[[id]]
    choices <- c(list(default = if (is.null(part$items)) list() else part$items), part$variants)
    selected <- x$lod[[band]]$variants[[id]]
    if (is.null(selected)) choices else choices[selected]
  }
  union_box <- function(bounds) {
    checkmate::assert_list(bounds, min.len = 1L)
    c(
      min(vapply(bounds, `[[`, numeric(1), 1L)),
      min(vapply(bounds, `[[`, numeric(1), 2L)),
      max(vapply(bounds, `[[`, numeric(1), 3L)),
      max(vapply(bounds, `[[`, numeric(1), 4L))
    )
  }
  clip_box <- function(reference) {
    checkmate::assert_string(reference)
    pair <- strsplit(reference, ".", fixed = TRUE)[[1L]]
    bounds <- list()
    for (items in variants(pair[[1L]])) {
      for (item in items) {
        if (identical(item$id, pair[[2L]])) {
          bounds[[length(bounds) + 1L]] <- character_interval_box(
            character_geometry(item, shapes)$box,
            matrices[[pair[[1L]]]]
          )
        }
      }
    }
    union_box(bounds)
  }
  intersect_box <- function(a, b) {
    checkmate::assert_numeric(a, len = 4L, finite = TRUE, any.missing = FALSE)
    checkmate::assert_numeric(b, len = 4L, finite = TRUE, any.missing = FALSE)
    result <- c(pmax(a[1:2], b[1:2]), pmin(a[3:4], b[3:4]))
    if (any(result[1:2] > result[3:4])) NULL else result
  }
  glow_enabled <- if (is.null(x$lod[[band]]$glow)) band != "micro" else x$lod[[band]]$glow
  for (id in graph$order) {
    if (!visible[[id]]) {
      next
    }
    part <- graph$parts[[id]]
    for (items in variants(id)) {
      for (item in items) {
        if (
          (!is.null(item$lod) && !band %in% unlist(item$lod)) ||
            paste0(id, ".", item$id) %in% unlist(x$lod[[band]]$hide)
        ) {
          next
        }
        target <- paste0(id, ".", item$id)
        for (mood in x$moods) {
          for (selection in list(mood, mood$reduced)) {
            if (!is.null(selection$items[[target]]$stroke)) item$stroke <- selection$items[[target]]$stroke
          }
        }
        local <- character_work_box(item, shapes, outline)
        box <- character_interval_box(local, matrices[[id]])
        blur <- if (glow_enabled && !is.null(part$glow) && identical(part$glow$item, item$id)) part$glow$blur else 0
        if (!is.null(item$clip) && blur == 0) {
          box <- intersect_box(box, clip_box(item$clip))
        }
        if (!is.null(box)) {
          attr(box, "blur") <- blur
          attr(box, "source") <- paste0("part \"", id, "\"")
          boxes[[length(boxes) + 1L]] <- box
        }
      }
    }
  }
  face <- x$face
  if (!is.null(face) && visible[[face$part]]) {
    flags <- if (is.null(x$lod[[band]]$face)) character_object() else x$lod[[band]]$face
    scale <- (if (is.null(face$scale)) 1 else face$scale) * if (is.null(flags$scale)) 1 else flags$scale
    at <- if (is.null(face$at)) c(0, 0) else unlist(face$at)
    matrix <- character_interval_matrix(
      matrices[[face$part]],
      character_interval_local(rep(at[[1L]], 2L), rep(at[[2L]], 2L), c(0, 0), rep(scale, 2L), rep(scale, 2L))
    )
    face_boxes <- list()
    eye_y <- if (is.null(face$eyes$y)) -12 else face$eyes$y
    spacing <- if (is.null(face$eyes$spacing)) 30 else face$eyes$spacing
    for (style in graph$kit$eye_styles) {
      eye <- character_work_eye(style, face, flags)
      for (item in eye$glow_items) {
        box <- character_work_box(item, shapes, outline)
        for (side in c(-1, 1)) {
          face_boxes[[length(face_boxes) + 1L]] <- character_geometry_transform(
            box,
            c(side * spacing, eye_y),
            0,
            c(side, 1)
          )
        }
      }
    }
    if (!identical(flags$brows, FALSE)) {
      for (style in graph$kit$brow_styles) {
        item <- list(
          shape = "path",
          d = style$d,
          stroke = if (is.null(style$stroke)) "feature" else style$stroke,
          width = if (is.null(style$width)) 3.5 else style$width
        )
        if (item$width == 0) {
          next
        }
        box <- character_work_box(item, shapes, outline)
        for (side in c(-1, 1)) {
          face_boxes[[length(face_boxes) + 1L]] <- character_geometry_transform(
            box,
            c(side * spacing, if (is.null(style$y)) -25 else style$y),
            0,
            c(side, 1)
          )
        }
      }
    }
    for (style in graph$kit$mouth_styles) {
      dimensions <- if (is.null(style$box)) c(20, 12) else unlist(style$box)
      for (item in style$items) {
        box <- character_geometry(item, shapes)$box
        box[c(2L, 4L)] <- range(c(0, box[c(2L, 4L)]))
        box <- box * rep(dimensions, 2L)
        width <- if (is.null(item$stroke)) {
          0
        } else if (is.null(item$width)) {
          2.5
        } else {
          item$width
        }
        box <- box + c(-1, -1, 1, 1) * width * if (identical(item$join, "miter")) 5 else 0.5
        box <- box +
          c(0, if (is.null(face$mouth$y)) 24 else face$mouth$y, 0, if (is.null(face$mouth$y)) 24 else face$mouth$y)
        face_boxes[[length(face_boxes) + 1L]] <- box
      }
    }
    if (!is.null(face$blush)) {
      blush <- face$blush
      for (side in c(-1, 1)) {
        face_boxes[[length(face_boxes) + 1L]] <- c(
          side * blush$x - blush$rx,
          blush$y - blush$ry,
          side * blush$x + blush$rx,
          blush$y + blush$ry
        )
      }
    }
    for (local in face_boxes) {
      box <- character_interval_box(local, matrix)
      blur <- if (glow_enabled && !is.null(graph$kit$glow)) graph$kit$glow$blur else 0
      if (!is.null(face$clip) && blur == 0) {
        box <- intersect_box(box, clip_box(face$clip))
      }
      if (!is.null(box)) {
        attr(box, "blur") <- blur
        attr(box, "source") <- "the face"
        boxes[[length(boxes) + 1L]] <- box
      }
    }
  }
  effects <- list()
  for (id in names(x$effects)) {
    effects[[length(effects) + 1L]] <- list(effect = id, anchor = x$effects[[id]]$anchor)
  }
  for (id in unique(unlist(behaviour$playable))) {
    effects <- c(effects, x$gestures[[id]]$effects)
  }
  for (trigger in effects) {
    effect <- graph$kit$effects[[trigger$effect]]
    owner <- x$anchors[[trigger$anchor]]$part
    if (!visible[[owner]]) {
      next
    }
    matrix <- anchor_matrix(trigger$anchor)
    at <- if (is.null(effect$at)) c(0, 0) else unlist(effect$at)
    tracks <- character_effect_ranges(effect)
    sway <- if (effect$mode == "progress") {
      if (is.null(effect$sway)) 2 else abs(effect$sway)
    } else {
      0
    }
    travel <- if (effect$mode == "progress") {
      if (is.null(effect$travel)) 26 else effect$travel
    } else {
      0
    }
    amplitude <- if (effect$mode == "pulse") {
      if (is.null(effect$amplitude)) 0.18 else effect$amplitude
    } else {
      0
    }
    local <- character_interval_local(
      c(at[[1L]] - sway, at[[1L]] + sway),
      range(c(at[[2L]], at[[2L]] + travel)),
      c(0, 0),
      c(1 - amplitude, 1 + amplitude),
      c(1 - amplitude, 1 + amplitude)
    )
    if (effect$mode == "track") {
      local <- character_interval_local(
        character_interval(rep(at[[1L]], 2L), tracks$x),
        character_interval(rep(at[[2L]], 2L), tracks$y),
        c(0, 0),
        tracks$scale_x,
        tracks$scale_y
      )
    }
    matrix <- character_interval_matrix(matrix, local)
    for (item in c(effect$items, effect$reduced_items)) {
      box <- character_interval_box(character_work_box(item, shapes, outline), matrix)
      attr(box, "source") <- paste0("effect \"", trigger$effect, "\"")
      boxes[[length(boxes) + 1L]] <- box
    }
  }
  # Apply the root last so its centre-height translation remains correlated with
  # the local part tree, rather than introducing two independent pivot offsets.
  height <- x$ground$centre_height
  root_rotate <- ranges[["root.rotate"]]
  root_sx <- character_interval(ranges[["root.scale_x"]], ranges[["root.flip"]], "multiply")
  root_sy <- ranges[["root.scale_y"]]
  root_lift <- ranges[["root.lift"]]
  root <- character_interval_local(c(0, 0), c(0, 0), root_rotate, c(1, 1), c(1, 1))
  final <- list()
  sources <- character()
  for (box in boxes) {
    blur <- if (is.null(attr(box, "blur"))) 0 else attr(box, "blur")
    sources <- c(sources, attr(box, "source"))
    if (!world_coordinates) {
      box <- box + c(0, height, 0, height)
      box <- character_interval_box(box, root)
      x_axis <- character_interval(box[c(1L, 3L)], root_sx, "multiply") + 150
      y_axis <- character_interval(box[c(2L, 4L)] - height, root_sy, "multiply")
      y_axis <- character_interval(y_axis, -rev(root_lift)) + 270
      box <- c(x_axis[[1L]], y_axis[[1L]], x_axis[[2L]], y_axis[[2L]])
    }
    final[[length(final) + 1L]] <- box + c(-1, -1, 1, 1) * 3 * blur
  }
  if (!is.null(x$ground$shadow)) {
    if (root_lift[[1L]] <= -200) {
      return(list(verified = FALSE, reason = "shadow_lift_singularity", band = band))
    }
    factor <- 1 / (1 + root_lift[[1L]] / 200)
    rx <- x$ground$shadow$rx * factor * max(1, 0.6 + 0.4 * max(abs(root_sx)))
    ry <- x$ground$shadow$ry * factor
    final[[length(final) + 1L]] <- c(150 - rx, 269 - ry, 150 + rx, 270 + ry)
    sources <- c(sources, "the ground shadow")
  }
  if (!length(final)) {
    return(list(verified = TRUE, bounds = NULL, band = band))
  }
  bounds <- union_box(final)
  pad <- max(1, abs(bounds)) * .Machine$double.eps * 128
  bounds <- bounds + c(-pad, -pad, pad, pad)
  verified <- all(bounds[1:2] >= 0) && all(bounds[3:4] <= 300)
  list(
    verified = verified,
    bounds = bounds,
    band = band,
    reason = "conservative_authored_interval_bound",
    widest = if (!verified) character_fit_widest(final, sources)
  )
}

#' What reaches furthest outside the frame: its name, side and distance
#' @noRd
character_fit_widest <- function(boxes, sources) {
  checkmate::assert_list(boxes, types = "numeric", min.len = 1L)
  checkmate::assert_character(sources, len = length(boxes), any.missing = FALSE)
  sides <- c("left", "top", "right", "bottom")
  overflow <- vapply(boxes, function(box) c(-box[[1L]], -box[[2L]], box[[3L]] - 300, box[[4L]] - 300), numeric(4))
  at <- which(overflow == max(overflow), arr.ind = TRUE)[1L, ]
  list(source = sources[[at[["col"]]]], side = sides[[at[["row"]]]], overflow = max(overflow))
}

#' Bound inherited orientation filtering without dividing by an uncertain determinant
#' @noRd
character_interval_filter <- function(parent, local, upright, no_flip) {
  checkmate::assert_list(parent, len = 6L)
  checkmate::assert_list(local, len = 6L)
  checkmate::assert_flag(upright)
  checkmate::assert_flag(no_flip)
  original <- character_interval_matrix(parent, local)
  norm <- attr(parent, "norm")
  if (is.null(norm)) {
    norm <- sqrt(sum(vapply(parent[1:4], function(axis) max(abs(axis))^2, numeric(1))))
  }
  filtered <- parent
  if (upright) {
    filtered[[1L]] <- if (no_flip) c(0, norm) else c(-norm, norm)
    filtered[[2L]] <- filtered[[3L]] <- c(0, 0)
    filtered[[4L]] <- c(0, norm)
  } else if (no_flip) {
    filtered[[1L]] <- rep(max(abs(parent[[1L]])), 2L) * c(-1, 1)
    filtered[[2L]] <- rep(max(abs(parent[[2L]])), 2L) * c(-1, 1)
  }
  filtered[[5L]] <- original[[5L]]
  filtered[[6L]] <- original[[6L]]
  local[[5L]] <- local[[6L]] <- c(0, 0)
  character_interval_matrix(filtered, local)
}
