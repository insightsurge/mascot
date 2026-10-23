#' Parse the closed absolute path grammar without executing drawing code
#' @noRd
character_path <- function(d, path = "$.d") {
  checkmate::assert_string(d)
  checkmate::assert_string(path)
  pattern <- "[A-Za-z]|[+-]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
  tokens <- regmatches(d, gregexpr(pattern, d, perl = TRUE))[[1L]]
  residue <- gsub("[[:space:],]", "", gsub(pattern, "", d, perl = TRUE))
  if (nzchar(residue) || !length(tokens) || tokens[[1L]] != "M") {
    character_format_abort("input_type", path, d, "Use an absolute M/L/Q/C/Z path starting with M.")
  }
  sizes <- c(M = 2L, L = 2L, Q = 4L, C = 6L, Z = 0L)
  result <- list()
  index <- 1L
  while (index <= length(tokens)) {
    op <- tokens[[index]]
    index <- index + 1L
    if (!op %in% names(sizes)) {
      character_format_abort("capability", path, op, "Use only absolute M/L/Q/C/Z commands.")
    }
    count <- sizes[[op]]
    if (!count) {
      result[[length(result) + 1L]] <- list(op = op, values = numeric())
      next
    }
    first <- TRUE
    if (index > length(tokens) || grepl("^[A-Za-z]$", tokens[[index]])) {
      character_format_abort("input_type", path, d, "Complete every path command.")
    }
    while (index <= length(tokens) && !grepl("^[A-Za-z]$", tokens[[index]])) {
      end <- index + count - 1L
      if (end > length(tokens) || any(grepl("^[A-Za-z]$", tokens[index:end]))) {
        character_format_abort("input_type", path, d, "Complete every path command.")
      }
      values <- as.numeric(tokens[index:end])
      if (any(!is.finite(values))) {
        character_format_abort("non_finite", path, NULL, "Use finite path coordinates.")
      }
      character_format_within(values, 4096, path, "path coordinates")
      result[[length(result) + 1L]] <- list(op = if (op == "M" && !first) "L" else op, values = values)
      first <- FALSE
      index <- end + 1L
    }
  }
  result
}

#' Resolve one non-recursive geometry reference
#' @noRd
character_shape <- function(item, shapes = character_object(), path = "$.item") {
  checkmate::assert_list(item, names = "unique")
  checkmate::assert_list(shapes, names = "unique")
  checkmate::assert_string(path)
  if (!identical(item$shape, "ref")) {
    return(item)
  }
  definition <- shapes[[item$use]]
  if (is.null(definition) || identical(definition$shape, "ref")) {
    character_format_abort("missing_reference", paste0(path, ".use"), item$use, "Name a declared non-ref shape.")
  }
  allowed <- c(
    "shape",
    "use",
    "id",
    "fill",
    "stroke",
    "width",
    "alpha",
    "outline",
    "cap",
    "join",
    "lod",
    "x",
    "y",
    "rotate",
    "scale",
    "note",
    "clip"
  )
  bad <- setdiff(names(item), allowed)
  if (length(bad)) {
    character_format_abort("unknown_key", paste0(path, ".", bad[[1L]]), bad[[1L]], "Remove this ref override.")
  }
  result <- definition
  for (key in intersect(
    names(item),
    c("id", "fill", "stroke", "width", "alpha", "outline", "cap", "join", "lod", "clip")
  )) {
    result[key] <- list(item[[key]])
  }
  attr(result, "ref_transform") <- list(x = item$x, y = item$y, rotate = item$rotate, scale = item$scale)
  result
}

#' Independent R primitive operands and conservative local control-point bounds
#' @noRd
character_geometry <- function(item, shapes = character_object(), path = "$.item") {
  checkmate::assert_list(item, names = "unique")
  checkmate::assert_list(shapes, names = "unique")
  checkmate::assert_string(path)
  item <- character_shape(item, shapes, path)
  number <- function(key, default = 0, lower = -4096, upper = 4096) {
    checkmate::assert_string(key)
    checkmate::assert_number(default, finite = TRUE)
    checkmate::assert_number(lower, finite = FALSE)
    checkmate::assert_number(upper, finite = FALSE)
    value <- if (is.null(item[[key]])) default else item[[key]]
    if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
      character_format_abort("input_type", paste0(path, ".", key), NULL, "Supply one finite number.")
    }
    if (value < lower || value > upper) {
      # A strictly positive size has the smallest double as its lower bound: say "above 0".
      rule <- if (lower == .Machine$double.xmin) {
        list(exclusive_min = 0, max = upper)
      } else {
        list(min = lower, max = upper)
      }
      character_format_abort(
        "input_type",
        paste0(path, ".", key),
        value,
        paste0("Use ", character_format_range(rule), ", not ", character_format_shown(value), ".")
      )
    }
    value
  }
  x <- number("x")
  y <- number("y")
  shape <- item$shape
  numbers <- 0L
  box <- c(x, y, x, y)
  if (shape == "path") {
    commands <- character_path(item$d, paste0(path, ".d"))
    values <- unlist(lapply(commands, `[[`, "values"), use.names = FALSE)
    numbers <- length(values)
    box <- c(
      min(values[c(TRUE, FALSE)]),
      min(values[c(FALSE, TRUE)]),
      max(values[c(TRUE, FALSE)]),
      max(values[c(FALSE, TRUE)])
    )
  } else if (shape %in% c("circle", "arc", "polygon", "hexagon")) {
    r <- number("r", lower = .Machine$double.xmin)
    box <- c(x - r, y - r, x + r, y + r)
    if (shape == "arc") {
      number("start", lower = -Inf, upper = Inf)
      number("end", lower = -Inf, upper = Inf)
    }
    numbers <- if (shape %in% c("circle", "arc")) {
      5L
    } else {
      sides <- if (shape == "hexagon") 6L else item$sides
      number("corner", lower = 0)
      sides * if (is.null(item$corner) || item$corner == 0) 2L else 6L
    }
  } else if (shape == "ellipse") {
    rx <- number("rx", lower = .Machine$double.xmin)
    ry <- number("ry", lower = .Machine$double.xmin)
    angle <- number("rotate", lower = -Inf, upper = Inf)
    dx <- sqrt((rx * cos(angle))^2 + (ry * sin(angle))^2)
    dy <- sqrt((rx * sin(angle))^2 + (ry * cos(angle))^2)
    box <- c(x - dx, y - dy, x + dx, y + dy)
    numbers <- 7L
  } else if (shape %in% c("rect", "round_rect")) {
    w <- number("w", lower = .Machine$double.xmin)
    h <- number("h", lower = .Machine$double.xmin)
    box <- c(x, y, x + w, y + h)
    numbers <- if (shape == "rect") 4L else 8L
    radii <- unlist(item$r)
    if (shape == "round_rect" && any(radii < 0 | radii > 4096)) {
      bad <- radii[radii < 0 | radii > 4096][[1L]]
      character_format_abort(
        "input_type",
        paste0(path, ".r"),
        bad,
        paste0("Use corner radii from 0 to 4096, not ", character_format_shown(bad), ".")
      )
    }
  } else if (shape == "polyline") {
    points <- do.call(rbind, lapply(item$points, unlist, use.names = FALSE))
    character_format_within(as.numeric(points), 4096, paste0(path, ".points"), "geometry")
    box <- c(min(points[, 1L]), min(points[, 2L]), max(points[, 1L]), max(points[, 2L]))
    numbers <- length(points)
  } else {
    character_format_abort("capability", paste0(path, ".shape"), shape, "Use a supported shape.")
  }
  if (shape == "polyline" || (shape == "arc" && !isTRUE(item$closed))) {
    if (!is.null(item$fill) || isTRUE(item$outline)) {
      character_format_abort("input_type", path, NULL, "Open arcs and polylines use a detail stroke only.")
    }
  }
  if (!is.null(item$transform)) {
    transform <- unlist(item$transform, use.names = FALSE)
    character_format_within(transform[1:2], 4096, paste0(path, ".transform"), "translations")
    box <- character_geometry_transform(box, transform[1:2], transform[[3L]], c(1, 1))
  }
  ref <- attr(item, "ref_transform")
  if (!is.null(ref)) {
    at <- c(if (is.null(ref$x)) 0 else ref$x, if (is.null(ref$y)) 0 else ref$y)
    scale <- if (is.null(ref$scale)) c(1, 1) else rep(unlist(ref$scale), length.out = 2L)
    character_format_within(at, 4096, path, "ref translations")
    character_format_within(scale, 16, path, "ref scales")
    box <- character_geometry_transform(box, at, if (is.null(ref$rotate)) 0 else ref$rotate, scale)
  }
  list(item = item, numbers = numbers, box = box)
}

#' Transform all corners of a conservative local box
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_geometry_transform <- function(box, at, angle, scale) {
  x <- box[c(1L, 3L, 1L, 3L)] * scale[[1L]]
  y <- box[c(2L, 2L, 4L, 4L)] * scale[[2L]]
  tx <- at[[1L]] + cos(angle) * x - sin(angle) * y
  ty <- at[[2L]] + sin(angle) * x + cos(angle) * y
  c(min(tx), min(ty), max(tx), max(ty))
}
