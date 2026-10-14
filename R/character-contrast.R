#' Parse bounded authored colours into normalised RGBA channels
#' @noRd
character_colour <- function(colour, path = "$.colours") {
  checkmate::assert_string(colour)
  checkmate::assert_string(path)
  if (grepl("^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$", colour)) {
    hex <- substring(colour, 2L)
    if (nchar(hex) == 3L) {
      hex <- paste0(rep(strsplit(hex, "", fixed = TRUE)[[1L]], each = 2L), collapse = "")
    }
    return(c(vapply(c(1L, 3L, 5L), function(at) strtoi(substr(hex, at, at + 1L), 16L), numeric(1)) / 255, 1))
  }
  component <- "[[:space:]]*[0-9.]+[[:space:]]*"
  pattern <- paste0("^rgba\\(", paste(rep(component, 4L), collapse = ","), "\\)$")
  if (!grepl(pattern, colour)) {
    character_format_abort("invalid_colour", path, colour, "Use a hex or rgba colour.")
  }

  values <- suppressWarnings(as.numeric(strsplit(substring(colour, 6L, nchar(colour) - 1L), ",", fixed = TRUE)[[1L]]))
  if (
    length(values) != 4L || any(!is.finite(values)) || any(values < 0) || any(values[1:3] > 255) || values[[4L]] > 1
  ) {
    character_format_abort("invalid_colour", path, colour, "Keep RGB in [0,255] and alpha in [0,1].")
  }
  c(values[1:3] / 255, values[[4L]])
}

#' Apply the existing bounded HSL follow adjustment
#' @noRd
character_colour_follow <- function(colour, rule) {
  checkmate::assert_numeric(colour, len = 4L, lower = 0, upper = 1, any.missing = FALSE)
  checkmate::assert_list(rule)
  rgb <- colour[1:3]
  high <- max(rgb)
  low <- min(rgb)
  delta <- high - low
  light <- (high + low) / 2
  saturation <- if (delta == 0) 0 else delta / (1 - abs(2 * light - 1))
  hue <- if (delta == 0) {
    0
  } else if (high == rgb[[1L]]) {
    ((rgb[[2L]] - rgb[[3L]]) / delta + 6) %% 6
  } else if (high == rgb[[2L]]) {
    (rgb[[3L]] - rgb[[1L]]) / delta + 2
  } else {
    (rgb[[1L]] - rgb[[2L]]) / delta + 4
  }
  light <- min(1, max(0, light + if (is.null(rule$amount)) 0 else rule$amount))
  saturation <- if (delta == 0) 0 else min(1, max(0, saturation + if (is.null(rule$saturation)) 0 else rule$saturation))
  chroma <- (1 - abs(2 * light - 1)) * saturation
  secondary <- chroma * (1 - abs(hue %% 2 - 1))
  segments <- list(
    c(chroma, secondary, 0),
    c(secondary, chroma, 0),
    c(0, chroma, secondary),
    c(0, secondary, chroma),
    c(secondary, 0, chroma),
    c(chroma, 0, secondary)
  )
  # Match JavaScript Math.round for nonnegative RGB channels.
  c(floor((segments[[floor(hue) + 1L]] + light - chroma / 2) * 255 + 0.5) / 255, colour[[4L]])
}

#' Resolve authored native/preset/follow/recolour precedence for one still
#' @noRd
character_format_colours <- function(x, mode = "light", preset = "original", recolour = character_object()) {
  checkmate::assert_list(x)
  checkmate::assert_choice(mode, c("light", "dark"))
  checkmate::assert_string(preset)
  checkmate::assert_list(recolour)
  baseline <- x$colours
  if (mode == "dark") {
    for (id in names(x$modes$dark$colours)) {
      baseline[id] <- list(x$modes$dark$colours[[id]])
    }
  }
  colours <- lapply(names(baseline), function(id) character_colour(baseline[[id]], paste0("$.colours.", id)))
  names(colours) <- names(baseline)
  supplied <- character_object()
  if (preset != "original") {
    palette <- x$palettes[[preset]]
    if (is.null(palette)) {
      character_format_abort("missing_reference", "$.palettes", preset, "Select a declared palette.")
    }
    selected <- if (mode == "dark" && !is.null(palette$dark)) palette$dark else palette$light
    supplied <- lapply(names(selected), function(id) {
      character_colour(selected[[id]], paste0("$.palettes.", preset, ".", mode, ".", id))
    })
    names(supplied) <- names(selected)
  }
  explicit <- names(supplied)
  order <- character()
  pending <- names(x$follows)
  while (length(pending)) {
    ready <- pending[vapply(
      pending,
      function(id) {
        all(unlist(x$follows[[id]]$from) %in% c(setdiff(names(colours), names(x$follows)), order))
      },
      logical(1)
    )]
    if (!length(ready)) {
      character_format_abort(
        "invalid_colour",
        paste0("$.follows.", pending[[1L]]),
        NULL,
        "Remove the colour-follow cycle."
      )
    }
    order <- c(order, ready)
    pending <- setdiff(pending, ready)
  }
  filled <- supplied
  for (id in order) {
    if (!is.null(filled[[id]])) {
      next
    }
    for (leader in x$follows[[id]]$from) {
      result <- filled[[leader]]
      if (!is.null(result)) {
        if (!is.null(x$follows[[id]]$shade)) {
          result <- character_colour_follow(result, x$follows[[id]])
        }
        filled[id] <- list(result)
        break
      }
    }
  }
  for (id in names(filled)) {
    colours[id] <- list(filled[[id]])
  }
  native <- colours
  for (id in names(recolour)) {
    cursor <- id
    seen <- character()
    while (!cursor %in% explicit && !is.null(recolour[[cursor]])) {
      if (cursor %in% seen) {
        character_format_abort("invalid_colour", paste0("$.recolour.", id), NULL, "Remove the recolour cycle.")
      }
      seen <- c(seen, cursor)
      cursor <- recolour[[cursor]]
    }
    colours[id] <- list(native[[cursor]])
  }
  colours
}

#' Luminance of three normalised linear-bounded RGB channels
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_luminance <- function(rgb) {
  sum(ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4) * c(0.2126, 0.7152, 0.0722))
}

#' Conservative contrast across both modes, every preset and mood recolour
#' @noRd
character_format_contrast <- function(x) {
  checkmate::assert_list(x)
  if (!is.null(x$face) && isTRUE(x$id %in% character_data_reserved())) {
    feature <- x$face$colours[["feature"]]
    feature <- if (is.null(feature)) "feature" else feature
    if (!any(vapply(x$contrast, function(pair) identical(pair$fg, feature), logical(1)))) {
      character_format_abort(
        "invalid_colour",
        "$.contrast",
        feature,
        "Declare a contrast pair for the face feature role of a built-in character."
      )
    }
  }
  rows <- list()
  for (mode in c("light", "dark")) {
    for (preset in c("original", names(x$palettes))) {
      for (mood_id in names(x$moods)) {
        mood <- x$moods[[mood_id]]
        selections <- c(list(mood$recolour), list(mood$reduced$recolour))
        for (selection in selections) {
          colours <- character_format_colours(
            x,
            mode,
            preset,
            if (is.null(selection)) character_object() else selection
          )
          for (index in seq_along(x$contrast)) {
            pair <- x$contrast[[index]]
            path <- paste0("$.contrast[", index - 1L, "]")
            foreground <- colours[[pair$fg]]
            if (is.null(foreground)) {
              character_format_abort("invalid_colour", paste0(path, ".fg"), pair$fg, "Name a declared foreground role.")
            }
            page <- character_colour(if (mode == "light") "#ffffff" else "#212529")[1:3]
            backgrounds <- if (pair$bg == "page") {
              list(character_colour("#ffffff"), character_colour("#212529"))
            } else if (pair$bg == "page_light") {
              list(character_colour("#ffffff"))
            } else if (pair$bg == "page_dark") {
              list(character_colour("#212529"))
            } else {
              list(colours[[pair$bg]])
            }
            for (background in backgrounds) {
              if (is.null(background)) {
                character_format_abort(
                  "invalid_colour",
                  paste0(path, ".bg"),
                  pair$bg,
                  "Name a declared background role or page baseline."
                )
              }
              rgb <- background[1:3] * background[[4L]] + page * (1 - background[[4L]])
              lower <- upper <- rgb
              if (!is.null(pair$bg_paint)) {
                paint <- x$paints[[pair$bg_paint]]
                if (is.null(paint)) {
                  character_format_abort(
                    "missing_reference",
                    paste0(path, ".bg_paint"),
                    pair$bg_paint,
                    "Name a declared background paint."
                  )
                }
                stops <- vapply(
                  paint$stops,
                  function(stop) {
                    rgba <- colours[[stop[[2L]]]]
                    alpha <- rgba[[4L]] * if (length(stop) == 3L) stop[[3L]] else 1
                    rgba[1:3] * alpha + rgb * (1 - alpha)
                  },
                  numeric(3)
                )
                lower <- apply(stops, 1L, min)
                upper <- apply(stops, 1L, max)
              }
              bg <- c(character_luminance(lower), character_luminance(upper))
              fg <- c(
                character_luminance(foreground[1:3] * foreground[[4L]] + lower * (1 - foreground[[4L]])),
                character_luminance(foreground[1:3] * foreground[[4L]] + upper * (1 - foreground[[4L]]))
              )
              ratio <- if (fg[[1L]] <= bg[[2L]] && bg[[1L]] <= fg[[2L]]) {
                1
              } else if (fg[[1L]] > bg[[2L]]) {
                (fg[[1L]] + 0.05) / (bg[[2L]] + 0.05)
              } else {
                (bg[[1L]] + 0.05) / (fg[[2L]] + 0.05)
              }
              minimum <- if (is.null(pair$min)) 3 else pair$min
              if (ratio + 1e-12 < minimum) {
                character_format_abort(
                  "invalid_colour",
                  path,
                  ratio,
                  "Increase the declared pair's worst-case contrast to its minimum."
                )
              }
              rows[[length(rows) + 1L]] <- list(
                mode = mode,
                preset = preset,
                mood = mood_id,
                pair = index - 1L,
                ratio_lower_bound = ratio
              )
            }
          }
        }
      }
    }
  }
  rows
}
