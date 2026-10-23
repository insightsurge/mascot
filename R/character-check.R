#' The data the semantic checks read: checked data without its extension keys
#'
#' Extension keys (`x_` keys in fixed-field objects) belong to other tools. The
#' checked data keeps them; the reference, movement, drawing-work, frame-fit and
#' contrast checks read this copy, so they never interpret one.
#' @noRd
character_format_plain <- function(x) {
  checkmate::assert_list(x, names = "unique")
  schema <- character_format_schema()
  character_format_node(
    x,
    schema$definitions$character,
    "$",
    schema$definitions,
    on_object = function(object) object[!startsWith(as.character(names(object)), "x_")]
  )
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
  plain <- character_format_plain(resolved)
  character_check_gestures(plain, movement = FALSE)
  graph <- character_format_references(plain)
  behaviour <- character_format_behaviour(plain, graph)
  character_check_gestures(plain)
  work <- stats::setNames(
    lapply(c("full", "small", "micro"), function(band) {
      character_format_work(plain, graph, behaviour, band)
    }),
    c("full", "small", "micro")
  )
  fit <- stats::setNames(
    lapply(names(work), function(band) {
      proof <- character_format_fit(plain, graph, behaviour, band)
      if (!isTRUE(proof$verified)) {
        character_format_abort(
          "budget",
          paste0("$.frame_fit.", band),
          proof$bounds,
          character_fit_fix(proof)
        )
      }
      proof
    }),
    names(work)
  )
  contrast <- character_format_contrast(plain, builtin = builtin)
  manifest <- list(
    format_version = 1L,
    policy_version = as.integer(character_format_policy()$policy_version),
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

#' The repair instruction for a character that does not fit its frame
#'
#' Names what reaches furthest outside the 300 by 300 frame, by how much and on
#' which side, so the author knows what to move or shrink.
#' @noRd
character_fit_fix <- function(proof) {
  checkmate::assert_list(proof, names = "unique")
  rule <- "Keep every part, movement and effect inside the 300 by 300 frame at this size."
  widest <- proof$widest
  if (is.null(widest)) {
    return(rule)
  }
  # The proof pads its bounds by a rounding margin, so a part that only touches an edge can fail it.
  reach <- if (widest$overflow < 0.01) {
    paste0(" reaches the ", widest$side, " edge.")
  } else {
    paste0(
      " can reach ",
      format(signif(widest$overflow, 3L), scientific = FALSE, trim = TRUE),
      " units past the ",
      widest$side,
      " edge."
    )
  }
  paste0(rule, " The ", proof$band, " band is too big: ", widest$source, reach)
}
