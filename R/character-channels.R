#' Typed channel rules and resting values for an assembled character
#' @noRd
character_format_channels <- function(x, graph) {
  checkmate::assert_list(x, names = "unique")
  checkmate::assert_list(graph, names = "unique")
  rules <- list()
  add <- function(name, type = "number", base = 0, lower = -Inf, upper = Inf, choices = NULL) {
    checkmate::assert_string(name)
    checkmate::assert_choice(type, c("number", "boolean", "choice", "eyes", "blush"))
    checkmate::assert(checkmate::check_atomic(base), checkmate::check_list(base))
    checkmate::assert_number(lower, finite = FALSE)
    checkmate::assert_number(upper, finite = FALSE)
    checkmate::assert_character(choices, null.ok = TRUE)
    list(type = type, base = base, lower = lower, upper = upper, choices = choices)
  }
  rules[["root.lift"]] <- add("root.lift", lower = -4096, upper = 4096)
  rules[["root.rotate"]] <- add("root.rotate")
  for (axis in c("scale_x", "scale_y")) {
    rules[[paste0("root.", axis)]] <- add(axis, base = 1, lower = -16, upper = 16)
  }
  rules[["root.flip"]] <- add("root.flip", type = "choice", base = 1, choices = c("-1", "1"))
  for (id in names(graph$parts)) {
    part <- graph$parts[[id]]
    scale <- if (is.null(part$scale)) c(1, 1) else rep(unlist(part$scale), length.out = 2L)
    for (axis in c("x", "y")) {
      rules[[paste0(id, ".", axis)]] <- add(axis, lower = -4096, upper = 4096)
    }
    rules[[paste0(id, ".rotate")]] <- add("rotate", base = if (is.null(part$rotate)) 0 else part$rotate)
    for (index in 1:2) {
      rules[[paste0(id, ".scale_", c("x", "y")[[index]])]] <- add(
        "scale",
        base = scale[[index]],
        lower = -16,
        upper = 16
      )
    }
    rules[[paste0(id, ".opacity")]] <- add(
      "opacity",
      base = if (is.null(part$opacity)) 1 else part$opacity,
      lower = 0,
      upper = 1
    )
    rules[[paste0(id, ".visible")]] <- add("visible", "boolean", if (is.null(part$visible)) TRUE else part$visible)
    rules[[paste0(id, ".variant")]] <- add("variant", "choice", "default", choices = c("default", names(part$variants)))
  }
  if (!is.null(x$face)) {
    for (axis in c("look_x", "look_y")) {
      rules[[paste0("face.", axis)]] <- add(axis, lower = -1, upper = 1)
    }
    for (axis in c("blink", "lid", "open")) {
      rules[[paste0("face.", axis)]] <- add(axis, base = if (axis == "open") 1 else 0, lower = 0, upper = 1)
    }
    for (group in c("eyes", "mouth", "brows")) {
      field <- c(eyes = "eye_styles", mouth = "mouth_styles", brows = "brow_styles")[[group]]
      rules[[paste0("face.", group)]] <- add(
        group,
        if (group == "eyes") "eyes" else "choice",
        graph$kit$defaults[[group]],
        choices = names(graph$kit[[field]])
      )
    }
    rules[["face.blush"]] <- add(
      "blush",
      "blush",
      if (is.null(graph$kit$defaults$blush)) 0 else graph$kit$defaults$blush
    )
  }
  for (id in names(x$effects)) {
    progress <- graph$kit$effects[[id]]$mode == "progress"
    rules[[paste0("effects.", id)]] <- add(
      id,
      if (progress) "number" else "boolean",
      if (progress) 0 else FALSE,
      lower = 0,
      upper = 1
    )
  }
  rules
}

#' Check one channel value against its typed membership/range rule
#' @noRd
# Per-node helper: callers assert inputs (house exception, r-code.md).
character_channel_value <- function(value, rule, path) {
  valid <- switch(
    rule$type,
    number = is.numeric(value) && length(value) == 1L && is.finite(value) && value >= rule$lower && value <= rule$upper,
    boolean = is.logical(value) && length(value) == 1L && !is.na(value),
    choice = length(value) == 1L &&
      ((is.character(rule$base) && is.character(value)) || (is.numeric(rule$base) && is.numeric(value))) &&
      as.character(value) %in% rule$choices,
    eyes = (is.character(value) || is.list(value)) &&
      length(value) %in% c(1L, 2L) &&
      all(vapply(as.list(value), is.character, logical(1))) &&
      all(unlist(value) %in% rule$choices),
    blush = identical(value, "strong") ||
      (is.numeric(value) && length(value) == 1L && is.finite(value) && value >= 0 && value <= 1),
    FALSE
  )
  if (!isTRUE(valid)) {
    character_format_abort("invalid_channel", path, value, "Use the channel's declared type, range and membership.")
  }
  invisible(NULL)
}

#' Check moods, poses, fallback paths and gesture endpoints
#' @noRd
character_format_behaviour <- function(x, graph) {
  checkmate::assert_list(x, names = "unique")
  checkmate::assert_list(graph, names = "unique")
  rules <- character_format_channels(x, graph)
  resting <- lapply(rules, `[[`, "base")
  apply_channels <- function(base, channels, path) {
    checkmate::assert_list(base)
    checkmate::assert_list(channels, null.ok = TRUE)
    checkmate::assert_string(path)
    for (target in names(channels)) {
      if (!target %in% names(rules)) {
        character_format_abort(
          "missing_reference",
          paste0(path, ".", target),
          target,
          "Name a declared channel target."
        )
      }
      character_channel_value(channels[[target]], rules[[target]], paste0(path, ".", target))
      base[target] <- list(channels[[target]])
    }
    base
  }
  for (id in names(x$poses)) {
    apply_channels(resting, x$poses[[id]], paste0("$.poses.", id))
  }
  for (id in names(graph$parts)) {
    switch <- graph$parts[[id]]$switch
    if (!is.null(switch) && (!switch$channel %in% names(rules) || rules[[switch$channel]]$type != "number")) {
      character_format_abort(
        "invalid_channel",
        paste0(graph$paths[[id]], ".switch.channel"),
        switch$channel,
        "Use a declared numeric threshold channel."
      )
    }
  }
  core <- c("idle", "thinking", "happy", "worried", "celebrating")
  mood_bases <- list()
  for (id in names(x$moods)) {
    mood <- x$moods[[id]]
    path <- paste0("$.moods.", id)
    for (field in c("description", "status")) {
      if (is.null(mood[[field]]) || !nzchar(mood[[field]])) {
        character_format_abort(
          "input_type",
          paste0(path, ".", field),
          NULL,
          "Supply nonempty mood metadata after defaults."
        )
      }
    }
    if (id %in% core && !is.null(mood$fallback)) {
      character_format_abort("input_type", paste0(path, ".fallback"), NULL, "Core moods have no fallback.")
    }
    cursor <- id
    seen <- character()
    while (!cursor %in% core) {
      if (cursor %in% seen) {
        character_format_abort(
          "missing_reference",
          paste0(path, ".fallback"),
          NULL,
          "Remove the cyclic mood fallback chain."
        )
      }
      seen <- c(seen, cursor)
      next_id <- x$moods[[cursor]]$fallback
      if (is.null(next_id) || !next_id %in% names(x$moods)) {
        character_format_abort(
          "missing_reference",
          paste0("$.moods.", cursor, ".fallback"),
          next_id,
          "End the fallback chain at a declared core mood."
        )
      }
      cursor <- next_id
    }
    base <- resting
    if (!is.null(mood$pose)) {
      if (!mood$pose %in% names(x$poses)) {
        character_format_abort("missing_reference", paste0(path, ".pose"), mood$pose, "Name a declared pose.")
      }
      base <- apply_channels(base, x$poses[[mood$pose]], paste0("$.poses.", mood$pose))
    }
    for (selection in c(list(mood), list(mood$reduced))) {
      if (is.null(selection)) {
        next
      }
      selected <- apply_channels(base, selection$channels, paste0(path, ".channels"))
      for (prefix in c("face", "effects")) {
        controls <- selection[[prefix]]
        if (length(controls)) {
          selected <- apply_channels(selected, stats::setNames(controls, paste0(prefix, ".", names(controls))), path)
        }
      }
      if (identical(selection, mood)) {
        mood_bases[[id]] <- selected
        base <- selected
      }
      for (role in names(selection$recolour)) {
        if (!role %in% names(x$colours) || !selection$recolour[[role]] %in% names(x$colours)) {
          character_format_abort(
            "invalid_colour",
            paste0(path, ".recolour.", role),
            NULL,
            "Redirect between declared colour roles."
          )
        }
        cursor <- role
        seen <- character()
        while (cursor %in% names(selection$recolour)) {
          if (cursor %in% seen) {
            character_format_abort(
              "invalid_colour",
              paste0(path, ".recolour.", role),
              NULL,
              "Remove the recolour cycle."
            )
          }
          seen <- c(seen, cursor)
          cursor <- selection$recolour[[cursor]]
        }
      }
      for (target in names(selection$items)) {
        pair <- strsplit(target, ".", fixed = TRUE)[[1L]]
        part <- graph$parts[[pair[[1L]]]]
        candidates <- c(list(part$items), part$variants)
        if (
          is.null(part) ||
            !any(vapply(
              candidates,
              function(items) any(vapply(items, function(item) identical(item$id, pair[[2L]]), logical(1))),
              logical(1)
            ))
        ) {
          character_format_abort("missing_reference", paste0(path, ".items.", target), target, "Name a declared item.")
        }
        for (field in c("fill", "stroke")) {
          fill <- selection$items[[target]][[field]]
          if (is.character(fill) && !fill %in% names(x$colours)) {
            character_format_abort(
              "invalid_colour",
              paste0(path, ".items.", target, ".", field),
              fill,
              "Name a declared colour role."
            )
          }
          if (is.list(fill) && !fill$paint %in% names(x$paints)) {
            character_format_abort(
              "missing_reference",
              paste0(path, ".items.", target, ".", field),
              NULL,
              "Name a declared paint."
            )
          }
        }
      }
    }
  }
  playable <- list()
  for (id in names(x$gestures)) {
    cursor <- id
    seen <- character()
    selected <- NULL
    repeat {
      if (cursor %in% seen) {
        character_format_abort(
          "missing_reference",
          paste0("$.gestures.", cursor, ".fallback"),
          NULL,
          "Remove the cyclic gesture fallback chain."
        )
      }
      seen <- c(seen, cursor)
      gesture <- x$gestures[[cursor]]
      if (is.null(gesture)) {
        character_format_abort(
          "missing_reference",
          paste0("$.gestures.", id, ".fallback"),
          cursor,
          "Name a declared fallback gesture."
        )
      }
      available <- all(unlist(gesture$needs) %in% names(graph$parts))
      if (available && is.null(selected)) {
        selected <- cursor
      }
      if (is.null(gesture$fallback)) {
        break
      }
      cursor <- gesture$fallback
    }
    if (is.null(selected)) {
      character_format_abort(
        "missing_reference",
        paste0("$.gestures.", id, ".fallback"),
        NULL,
        "Provide a playable fallback for the absent required parts."
      )
    }
    playable[[id]] <- selected
  }
  tracks <- list()
  for (id in names(x$gestures)) {
    gesture <- x$gestures[[id]]
    path <- paste0("$.gestures.", id)
    if (is.null(gesture$description)) {
      character_format_abort("input_type", paste0(path, ".description"), NULL, "Describe the gesture after defaults.")
    }
    tracks[[id]] <- list()
    for (target in names(gesture$tracks)) {
      track <- gesture$tracks[[target]]
      keys <- if (is.null(names(track))) track else track$keys
      rule <- rules[[target]]
      if (is.null(rule)) {
        pair <- strsplit(target, ".", fixed = TRUE)[[1L]]
        if (
          !pair[[1L]] %in% unlist(gesture$needs) ||
            playable[[id]] == id ||
            !pair[[2L]] %in% c("x", "y", "rotate", "scale_x", "scale_y", "opacity", "visible", "variant")
        ) {
          character_format_abort(
            "invalid_channel",
            paste0(path, ".tracks.", target),
            target,
            "Name a real channel or an explicitly absent needed part with a playable fallback."
          )
        }
        rule <- if (pair[[2L]] == "visible") {
          list(type = "boolean", base = TRUE)
        } else if (pair[[2L]] == "variant") {
          list(type = "choice", choices = unique(unlist(lapply(keys, function(key) key[[2L]]))), base = "default")
        } else {
          rules[[paste0("root.", if (pair[[2L]] %in% c("x", "y")) "lift" else pair[[2L]])]]
        }
        if (is.null(rule)) rule <- list(type = "number", base = 1, lower = 0, upper = 1)
      }
      numeric <- rule$type == "number"
      mode <- if (!is.null(track$mode)) {
        track$mode
      } else if (numeric) {
        "add"
      } else {
        "set"
      }
      track_path <- paste0(path, ".tracks.", target)
      times <- vapply(keys, function(key) key[[1L]], numeric(1))
      if (times[[1L]] != 0 || utils::tail(times, 1L) != 1 || any(diff(times) <= 0)) {
        character_format_abort("invalid_channel", track_path, NULL, "Keys must increase strictly from 0 to 1.")
      }
      if (!numeric && mode != "set") {
        character_format_abort("invalid_channel", track_path, mode, "Discrete channels use set tracks.")
      }
      for (index in seq_along(keys)) {
        value <- keys[[index]][[2L]]
        if (is.null(value)) {
          if (mode == "add") {
            character_format_abort(
              "invalid_channel",
              track_path,
              NULL,
              "Add tracks use numeric offsets, with zero endpoints."
            )
          }
        } else if (mode == "add") {
          if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
            character_format_abort("invalid_channel", track_path, value, "Use finite numeric offsets.")
          }
          for (base in mood_bases) {
            if (!is.null(base[[target]])) character_channel_value(base[[target]] + value, rule, track_path)
          }
          if (is.null(rules[[target]])) character_channel_value(rule$base + value, rule, track_path)
        } else {
          character_channel_value(value, rule, track_path)
        }
      }
      first <- keys[[1L]][[2L]]
      last <- keys[[length(keys)]][[2L]]
      if (mode == "add" && (!identical(as.numeric(first), 0) || !identical(as.numeric(last), 0))) {
        character_format_abort("invalid_channel", track_path, NULL, "Add tracks start and end with zero offsets.")
      }
      if (!numeric && (!is.null(first) || !is.null(last))) {
        character_format_abort("invalid_channel", track_path, NULL, "Discrete tracks start and end with null.")
      }
      if (
        numeric &&
          mode == "set" &&
          !is.null(last) &&
          any(vapply(mood_bases, function(base) !identical(as.numeric(base[[target]]), as.numeric(last)), logical(1)))
      ) {
        character_format_abort(
          "invalid_channel",
          track_path,
          last,
          "End at null or the identical base value in every usable mood."
        )
      }
      tracks[[id]][[target]] <- list(mode = mode, keys = keys)
    }
    for (index in seq_along(gesture$effects)) {
      trigger <- gesture$effects[[index]]
      if (!trigger$effect %in% names(graph$kit$effects) || !trigger$anchor %in% names(x$anchors)) {
        character_format_abort(
          "missing_reference",
          paste0(path, ".effects[", index - 1L, "]"),
          NULL,
          "Name a declared kit effect and anchor."
        )
      }
    }
  }
  idle <- character_format_merge(
    list(
      frames = 150,
      blink_every = 120,
      blink_jitter = 30,
      blink_frames = 6,
      breathe = 0.012,
      breathe_period = 90,
      breathe_part = "root",
      extra = NULL
    ),
    if (is.null(x$motion$idle)) character_object() else x$motion$idle
  )
  if (idle$blink_jitter + idle$blink_frames / 2 >= idle$blink_every) {
    character_format_abort(
      "input_type",
      "$.motion.idle.blink_every",
      NULL,
      "Keep the blink window shorter than the blink interval."
    )
  }
  if (!idle$breathe_part %in% c("root", names(graph$parts))) {
    character_format_abort(
      "missing_reference",
      "$.motion.idle.breathe_part",
      idle$breathe_part,
      "Name root or a declared part."
    )
  }
  if (!is.null(idle$extra) && !idle$extra %in% names(playable)) {
    character_format_abort("missing_reference", "$.motion.idle.extra", idle$extra, "Name a playable gesture.")
  }
  change <- character_format_merge(
    list(style = "wiggle", frames = 18, angle = 0.06, height = 8, swap_at = 0.5),
    if (is.null(x$motion$change)) character_object() else x$motion$change
  )
  if (change$style == "gesture" && (is.null(change$gesture) || !change$gesture %in% names(playable))) {
    character_format_abort(
      "missing_reference",
      "$.motion.change.gesture",
      change$gesture,
      "Name a playable change gesture."
    )
  }
  list(rules = rules, mood_bases = mood_bases, playable = playable, tracks = tracks, idle = idle, change = change)
}
