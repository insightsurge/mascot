#' Check capability declarations against resolved format constructs
#' @noRd
character_format_capabilities <- function(x, graph, work) {
  checkmate::assert_list(x)
  checkmate::assert_list(graph)
  checkmate::assert_list(work)
  used <- "parts"
  if (!is.null(x$face)) {
    used <- c(used, "face_kit")
  }
  if (length(x$paints)) {
    used <- c(used, "paints")
  }
  if (any(vapply(work, function(cost) cost[["clip_applications"]] > 0, logical(1)))) {
    used <- c(used, "clip")
  }
  if (any(vapply(work, function(cost) cost[["glow_emitters"]] > 0, logical(1)))) {
    used <- c(used, "glow")
  }
  if (
    any(vapply(x$gestures, function(gesture) length(gesture$tracks) > 0, logical(1))) ||
      any(vapply(graph$kit$effects, function(effect) identical(effect$mode, "track"), logical(1)))
  ) {
    used <- c(used, "tracks")
  }
  pending <- list(x)
  while (length(pending)) {
    value <- pending[[length(pending)]]
    pending <- pending[-length(pending)]
    if (!is.list(value)) {
      next
    }
    if ("lod" %in% names(value) && length(value$lod)) {
      used <- c(used, "lod")
    }
    if (isTRUE(value$outline)) {
      used <- c(used, "outline")
    }
    pending <- c(pending, unname(value[vapply(value, is.list, logical(1))]))
  }
  missing <- setdiff(unique(used), unlist(x$requires))
  if (length(missing)) {
    character_format_abort("capability", "$.requires", missing, "Declare every capability used by the resolved recipe.")
  }
  invisible(unique(used))
}

#' Check the required greeting and acknowledgement movements
#' @noRd
character_check_gestures <- function(x, movement = TRUE) {
  checkmate::assert_list(x, names = "unique")
  checkmate::assert_flag(movement)
  for (id in c("wave", "nod")) {
    gesture <- x$gestures[[id]]
    if (is.null(gesture)) {
      character_format_abort(
        "missing_reference",
        paste0("$.gestures.", id),
        NULL,
        paste0("Every character must define the required '", id, "' gesture.")
      )
    }
    if (!movement) {
      next
    }
    moving_targets <- names(gesture$tracks)[vapply(
      gesture$tracks,
      function(track) {
        keys <- if (is.null(names(track))) track else track$keys
        values <- lapply(keys, `[[`, 2L)
        length(values) > 1L && any(!vapply(values[-1L], identical, logical(1), values[[1L]]))
      },
      logical(1)
    )]
    part_ids <- sub("\\..*$", "", moving_targets)
    valid <- if (id == "wave") {
      any(nzchar(part_ids) & part_ids != "root")
    } else {
      length(moving_targets) > 0L
    }
    if (!valid) {
      requirement <- if (id == "wave") {
        "at least one non-root part channel"
      } else {
        "at least one track with changing keyed values"
      }
      character_format_abort(
        "invalid_channel",
        paste0("$.gestures.", id, ".tracks"),
        names(gesture$tracks),
        paste0("The required '", id, "' gesture must move ", requirement, ".")
      )
    }
  }
  invisible(NULL)
}

#' Build internal checked data only after every dependent stage succeeds
#'
#' The manifest is derived internal data, not part of the saved format. Neither
#' a resolved flag nor a caller-supplied class/manifest skips these checks.
#' `builtin = TRUE` is reserved for internal loading of shipped recipes. The
#' default custom path never infers provenance from ids or caller attributes.
#' @noRd
character_format_check <- function(
  x,
  from = "list",
  families = character_object(),
  kits = character_format_kits(),
  builtin = FALSE
) {
  checkmate::assert(checkmate::check_list(x), checkmate::check_character(x, any.missing = FALSE))
  checkmate::assert_choice(from, c("list", "text", "file"))
  checkmate::assert_list(families, names = "unique")
  checkmate::assert_list(kits, names = "unique")
  checkmate::assert_flag(builtin)
  parsed <- character_format_parse(x, from)
  if (!builtin && parsed$id %in% character_data_reserved()) {
    character_format_abort(
      "identity",
      "$.id",
      parsed$id,
      paste0(encodeString(parsed$id, quote = '"'), " is a built-in character; give your character its own id.")
    )
  }
  resolved <- character_format_resolve(parsed, families, kits, parsed = TRUE)
  character_check_gestures(resolved, movement = FALSE)
  graph <- character_format_references(resolved)
  behaviour <- character_format_behaviour(resolved, graph)
  character_check_gestures(resolved)
  work <- stats::setNames(
    lapply(c("full", "small", "micro"), function(band) {
      character_format_work(resolved, graph, behaviour, band)
    }),
    c("full", "small", "micro")
  )
  character_format_capabilities(resolved, graph, work)
  fit <- stats::setNames(
    lapply(names(work), function(band) {
      proof <- character_format_fit(resolved, graph, behaviour, band)
      if (!isTRUE(proof$verified)) {
        character_format_abort(
          "budget",
          paste0("$.frame_fit.", band),
          proof$bounds,
          "Keep every part, movement and effect inside the 300 by 300 frame at this size."
        )
      }
      proof
    }),
    names(work)
  )
  contrast <- character_format_contrast(resolved, builtin = builtin)
  manifest <- list(
    format_version = 1L,
    policy_version = 1L,
    identity = character_format_identity(resolved),
    playable = behaviour$playable,
    work = work,
    fit = fit,
    contrast = contrast
  )
  class(resolved) <- c("mascot_character_data", "list")
  attr(resolved, "mascot_manifest") <- manifest
  resolved
}
