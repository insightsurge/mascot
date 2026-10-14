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

#' Build internal checked data only after every dependent stage succeeds
#'
#' The manifest is derived internal data, not part of the saved format. Neither
#' a resolved flag nor a caller-supplied class/manifest skips these checks.
#' @noRd
character_format_check <- function(x, from = "list", families = character_object(), kits = character_format_kits()) {
  checkmate::assert(checkmate::check_list(x), checkmate::check_character(x, any.missing = FALSE))
  checkmate::assert_choice(from, c("list", "text", "file"))
  checkmate::assert_list(families, names = "unique")
  checkmate::assert_list(kits, names = "unique")
  parsed <- character_format_parse(x, from)
  resolved <- character_format_resolve(parsed, families, kits)
  graph <- character_format_references(resolved)
  behaviour <- character_format_behaviour(resolved, graph)
  work <- stats::setNames(
    lapply(c("full", "small", "micro"), function(band) {
      checkmate::assert_string(band)
      character_format_work(resolved, graph, behaviour, band)
    }),
    c("full", "small", "micro")
  )
  character_format_capabilities(resolved, graph, work)
  contrast <- character_format_contrast(resolved)
  fit <- stats::setNames(
    lapply(names(work), function(band) {
      checkmate::assert_string(band)
      proof <- character_format_fit(resolved, graph, behaviour, band)
      if (!isTRUE(proof$verified)) {
        character_format_abort(
          "budget",
          paste0("$.frame_fit.", band),
          proof$bounds,
          "Provide a provable authored fit or a separately reviewed bounded fixture check."
        )
      }
      proof
    }),
    names(work)
  )
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
