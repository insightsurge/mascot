#' Update a mascot in a Shiny app
#'
#' Update any combination of character, mood, status, bubble, size, placement,
#' theme, motion, menu and gesture from your Shiny server. Arguments left as
#' `NULL` stay unchanged. Invalid values warn and leave the mascot unchanged.
#' In Shiny development mode they also show a worried mascot with the problem as
#' its status; the next valid update clears it. Updates sent before a mascot
#' appears are kept until it appears.
#'
#' @inheritParams mascot
#' @param character A character name or [mascot_character()] object. `NULL`
#'   (the default) leaves the character unchanged.
#' @param mood A mood name or [mascot_mood()] object. `NULL` (the default)
#'   leaves the mood unchanged.
#' @param status A non-empty string or [mascot_status()] object. `NULL`
#'   (the default) leaves the status unchanged; `mascot_status()` hands the
#'   status back to the mood. Text is always escaped.
#' @param bubble A non-empty string, an `htmltools` tag or tag list, or a
#'   [mascot_bubble()] object. `NULL` (the default) leaves the bubble unchanged;
#'   `mascot_bubble()` clears it. Plain text is escaped; [htmltools::HTML()] or
#'   tags supply HTML. Tags with dependencies or head content are not supported.
#' @param size A pixel number, percentage string or [mascot_size()] object, as
#'   in [mascot()]. `NULL` (the default) leaves the size unchanged.
#' @param placement A shortcut, named list or [mascot_placement()] object, as
#'   in [mascot()]. `NULL` (the default) leaves placement unchanged. Size and
#'   placement changes keep the running mascot, its mood and character. A new
#'   placement replaces any position the visitor dragged the mascot to.
#'   Floating placement shows a minimise control by default; dragging is off.
#'   Inline placement ignores `minimise` and `drag`: explicitly supplied values
#'   give an informational message, defaults stay silent, and the update is sent.
#'   With dragging enabled, the minimised restore button can also be dragged;
#'   a click restores it, and a drag leaves it minimised in its new position.
#' @param theme A theme in the forms accepted by [mascot()]. `NULL` (the
#'   default) leaves the theme unchanged; `mascot_theme()` restores the
#'   character's own colours. Themes are resolved again after a character swap.
#' @param motion A logical flag or [mascot_motion()] object, as in [mascot()].
#'   `NULL` (the default) leaves motion unchanged. Changes apply to the live mascot
#'   without restarting it; the visitor's reduced-motion preference still applies.
#' @param popup_menu A named character vector or [mascot_popup_menu()] object.
#'   `NULL` (the default) leaves the menu unchanged; `mascot_popup_menu()` removes
#'   it. Choices arrive as `input$<id>_menu` in the module that owns the mascot.
#' @param gesture A gesture name or [mascot_gesture()] object. `NULL` (the
#'   default) sends no gesture. Use `"nod"` to acknowledge an action or `"wave"`
#'   to greet. Must be named. See [mascot_gestures()] for descriptions.
#' @param ... Must be empty. Extra arguments are errors.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @details
#' **Status text and bubbles.** Use the always visible status line for a short
#' description of the current state.
#' Use a bubble for a message about something that happened; it may time out.
#' Use `mascot_bubble(..., duration = Inf)` for a message the user must act on,
#' such as an invalid form, because a timed message can vanish before it is read.
#' Bubbles survive mood changes and swaps; a queued bubble's timer starts when it
#' appears. An infinite duration is sent as JSON `null`. See [mascot_bubble()]
#' for timing and closing behaviour.
#'
#' **Shiny modules.** In a module, use `mascot(id = ns("helper"))` in the UI and
#' `updateMascot("helper")` in its server. The session namespace is added once.
#' An invalid `id` type, missing session or extra argument is an error. Calling
#' with all update fields `NULL` does nothing.
#'
#' **Gestures.** A character or mood change applies before the gesture. During a
#' character swap the engine drops the gesture, because the wave within the swap
#' replaces it. Reduced motion skips movement. The latest gesture sent before the
#' mascot appears plays once on appearance, after its queued character and mood
#' are applied.
#'
#' **Queued updates.** Updates sent before a mascot appears are kept per session,
#' including when the first mascot is created by [shiny::renderUI()] or
#' [shiny::insertUI()]. Only the latest value of each field and the latest early
#' gesture are kept. A replacement with the same id receives the retained state;
#' gestures play once.
#' @returns Called for its side effect; returns `NULL` invisibly.
#' @family mascots in Shiny
#' @seealso [mascot()], [mascot_motion()] for a complete Shiny settings example
#'   with live colours, animation and a colour reset.
#' @export
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   ui = shiny::fluidPage(
#'     mascot(id = "helper"),
#'     shiny::actionButton("work", "Think"),
#'     shiny::actionButton("done", "Finish")
#'   ),
#'   server = function(input, output, session) {
#'     shiny::observeEvent(input$work, {
#'       updateMascot("helper", mood = "thinking", status = "Working")
#'     })
#'     shiny::observeEvent(input$done, {
#'       updateMascot("helper", mood = "happy", status = mascot_status(),
#'         bubble = "Finished", gesture = "nod")
#'     })
#'   }
#' )
updateMascot <- function(
  id,
  character = NULL,
  mood = NULL,
  status = NULL,
  bubble = NULL,
  size = NULL,
  placement = NULL,
  theme = NULL,
  motion = NULL,
  popup_menu = NULL,
  ...,
  gesture = NULL,
  session = shiny::getDefaultReactiveDomain()
) {
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  if (...length() > 0L) {
    extras <- names(substitute(list(...)))[-1L]
    if (is.null(extras)) {
      extras <- rep("unnamed", ...length())
    }
    extras[extras == ""] <- "unnamed"
    cli::cli_abort(c(
      "Unexpected arguments: {.val {extras}}.",
      "i" = paste(
        "Use {.arg id}, {.arg character}, {.arg mood}, {.arg status},",
        "{.arg bubble}, {.arg size}, {.arg placement}, {.arg theme}, {.arg motion},",
        "{.arg popup_menu}, {.arg gesture} and {.arg session};",
        "{.arg gesture} and {.arg session} must be named."
      )
    ))
  }
  values <- list(
    character = character,
    mood = mood,
    status = status,
    bubble = bubble,
    size = size,
    placement = placement,
    theme = theme,
    motion = motion,
    popup_menu = popup_menu,
    gesture = gesture
  )
  misplaced <- vapply(
    values[c("character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "popup_menu")],
    inherits,
    logical(1),
    what = c("ShinySession", "session_proxy", "MockShinySession")
  )
  if (any(misplaced)) {
    cli::cli_abort(
      "{.arg session} must be named; a Shiny session was supplied to {.arg {names(misplaced)[misplaced]}}."
    )
  }
  if (is.null(session)) {
    cli::cli_abort("{.fn updateMascot} must be called inside a Shiny server function or module.")
  }
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  # Normalise once within the warning boundary; keep the result for sending.
  bubble_result <- if (!is.null(bubble)) {
    tryCatch(
      list(value = as_bubble_arg(bubble, environment())),
      error = function(error) list(problem = conditionMessage(error))
    )
  } else {
    list(value = NULL)
  }
  values["bubble"] <- list(bubble_result$value)
  theme_result <- if (!is.null(theme)) {
    tryCatch(
      list(
        value = as_theme_arg(
          theme,
          environment(),
          if (is.null(character) || !is.null(arg_problem(character, "character"))) {
            NULL
          } else {
            as_character_arg(character, environment())$id
          }
        )
      ),
      error = function(error) list(problem = conditionMessage(error))
    )
  } else {
    list(value = NULL)
  }
  # The normalised wire object is not a public helper; do not validate it twice.
  values$theme <- NULL
  # Runtime values deliberately use check_* through arg_problem(): a bad value warns.
  problems <- c(
    bubble_result$problem,
    theme_result$problem,
    unlist(
      lapply(names(values), function(arg) {
        if (!is.null(values[[arg]])) arg_problem(values[[arg]], arg)
      }),
      use.names = FALSE
    )
  )
  if (length(problems)) {
    cli::cli_warn(c(
      "{.fn updateMascot} left mascot {.val {id}} unchanged.",
      structure(paste0("{problems[[", seq_along(problems), "]]}"), names = rep("x", length(problems)))
    ))
    if (dev_mode()) {
      send_update(session, id, list(problem = paste0("mascot: ", paste(problems, collapse = "; "))))
    }
    return(invisible(NULL))
  }
  patch <- list()
  if (!is.null(character)) {
    ch <- as_character_arg(character, environment())
    patch$character <- list(id = ch$id, name = ch$name, json = character_json(ch$id))
  }
  if (!is.null(mood)) {
    patch$mood <- as_mood_arg(mood, environment())$name
  }
  if (!is.null(status)) {
    text <- as_status_arg(status, environment())$text
    patch$status <- if (is.null(text)) list(mode = "mood") else list(mode = "custom", text = text)
  }
  if (!is.null(bubble)) {
    value <- bubble_result$value
    patch$bubble <- if (is.null(value$text)) {
      list(clear = TRUE)
    } else {
      list(
        text = value$text,
        html = value$html,
        closable = value$closable,
        duration = if (is.finite(value$duration)) value$duration else NULL
      )
    }
  }
  if (!is.null(size)) {
    patch$size <- unclass(as_size_arg(size, environment()))
  }
  if (!is.null(placement)) {
    patch$placement <- placement_wire(as_placement_arg(placement, environment()))
  }
  if (!is.null(theme)) {
    patch$theme <- theme_result$value
  }
  if (!is.null(motion)) {
    patch$motion <- as_motion_arg(motion, environment())
  }
  if (!is.null(popup_menu)) {
    patch$popup_menu <- as_popup_menu_arg(popup_menu, environment())
  }
  if (!is.null(gesture)) {
    patch$gesture <- if (inherits(gesture, "mascot_gesture")) gesture$name else mascot_gesture(gesture)$name
  }
  if (length(patch)) {
    send_update(session, id, patch)
  }
  invisible(NULL)
}

#' Send one update, applying the module namespace once
#' @noRd
send_update <- function(session, id, patch, replay = FALSE) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  checkmate::assert_list(patch, names = "unique")
  checkmate::assert_flag(replay)
  key <- session$ns(id)
  if (is.null(session$userData$mascot_updates)) {
    session$userData$mascot_updates <- new.env(parent = emptyenv())
    session$onSessionEnded(function() {
      session$userData$mascot_updates <- NULL
    })
  }
  states <- session$userData$mascot_updates
  if (is.null(states[[key]])) {
    states[[key]] <- list(patch = list(), revision = 0L, gesture_revision = 0L, fields = list())
    # The existing input binding reports each new mount, including the first
    # dependency loaded through dynamic UI. Module input names stay local here.
    shiny::observeEvent(
      session$input[[id]],
      {
        mounted <- session$input[[id]]
        latest <- states[[key]]
        if (
          is.list(mounted) &&
            is.numeric(mounted$revision) &&
            length(mounted$revision) == 1L &&
            !is.na(mounted$revision) &&
            mounted$revision < latest$revision
        ) {
          send_update(session, id, latest$patch, replay = TRUE)
        }
      },
      ignoreInit = FALSE,
      domain = session
    )
  }
  state <- states[[key]]
  if (!replay) {
    state$revision <- state$revision + 1L
    state$patch <- merge_update_patch(state$patch, patch)
    for (field in names(patch)) {
      state$fields[[field]] <- state$revision
    }
    if (is.null(patch$problem)) {
      state$fields$problem <- state$revision
    }
    if (!is.null(patch$character) && is.null(patch$mood)) {
      state$fields$mood <- state$revision
    }
    if (!is.null(patch$gesture)) {
      state$gesture_revision <- state$revision
    }
    states[[key]] <- state
  }
  session$sendCustomMessage(
    "mascot:update",
    list(
      id = key,
      patch = patch,
      revision = state$revision,
      gestureRevision = state$gesture_revision,
      fields = state$fields,
      replay = replay
    )
  )
}

#' Merge the latest fields using the browser queue's replacement rules
#' @noRd
merge_update_patch <- function(previous, patch) {
  checkmate::assert_list(previous, names = "unique")
  checkmate::assert_list(patch, names = "unique")
  if (is.null(patch$problem)) {
    previous$problem <- NULL
  }
  if (!is.null(patch$character)) {
    previous$mood <- NULL
  }
  for (key in names(patch)) {
    previous[key] <- patch[key]
  }
  previous
}

#' Whether client-side problem messages should be shown
#' @noRd
dev_mode <- function() {
  shiny::in_devmode()
}
