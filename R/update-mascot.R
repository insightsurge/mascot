#' Update a mascot in a Shiny app
#'
#' Update any combination of character, mood, status, bubble, size, placement,
#' theme, motion, click and gesture from your Shiny server. Arguments left as
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
#'   in [mascot()]. `NULL` (the default) leaves placement unchanged.
#'
#'   - Size and placement changes keep the running mascot, its mood and its
#'     character.
#'   - A new placement replaces any position the visitor dragged the mascot to.
#'   - Floating placement shows a minimise control by default, and dragging is
#'     off.
#'   - Inline placement ignores `minimise` and `drag`. Values you supply
#'     explicitly give an informational message; defaults stay silent. The
#'     update is still sent.
#'   - With dragging enabled, the minimised restore button can also be dragged.
#'     A click restores it; a drag leaves it minimised in its new position.
#' @param theme A theme in the forms accepted by [mascot()]. `NULL` (the
#'   default) leaves the theme unchanged; `mascot_theme()` restores the
#'   character's own colours. After a character swap, the theme is applied
#'   again to the new character's parts.
#' @param motion A logical flag or [mascot_motion_settings()] object, as in [mascot()].
#'   `NULL` (the default) leaves motion unchanged. Changes apply to the live mascot
#'   without restarting it; the visitor's reduced-motion preference still applies.
#' @param click A label, a [mascot_action()] object or a [mascot_popup_menu()]
#'   object, as in [mascot()]. `NULL` (the default) leaves the click unchanged; an
#'   empty helper, `mascot_action()` or `mascot_popup_menu()`, removes it, so the
#'   mascot is a picture again. A new click replaces the old one completely and
#'   closes an open menu. Clicks and menu choices arrive as `input$<id>_click` and
#'   `input$<id>_menu` in the module that owns the mascot; the click count
#'   continues across changes.
#' @param gesture A gesture name or [mascot_gesture()] object. `NULL` (the
#'   default) sends no gesture. Use `"nod"` to acknowledge an action or `"wave"`
#'   to greet. Must be named. See [mascot_gestures()] for descriptions.
#'   With `gestures = FALSE` in [mascot_motion_settings()], the gesture is
#'   skipped; the mood, bubble and status in the same update still apply. Shiny
#'   development mode reports it through the browser's client-message warning.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @details
#' `NULL` means none or the default in [mascot()] and helpers where accepted,
#' and unchanged in [update_mascot()]. An empty helper (`mascot_bubble()`,
#' `mascot_status()`, `mascot_theme()`, `mascot_action()` or
#' `mascot_popup_menu()`) resets that setting.
#'
#' Building UI with [mascot()] or helpers errors on invalid values;
#' [update_mascot()] warns and leaves the mascot unchanged. See
#' [mascot-package] for condition classes.
#'
#' **Status text and bubbles.** Use the always visible status line for a short
#' description of the current state.
#' Use a bubble for a message about something that happened; it may time out.
#' Use `mascot_bubble(..., duration = Inf)` for a message the user must act on,
#' such as an invalid form, because a timed message can vanish before it is read.
#' Bubbles survive mood changes and swaps; a queued bubble's timer starts when it
#' appears. See [mascot_bubble()]
#' for timing and closing behaviour.
#'
#' **Shiny modules.** In a module, use `mascot(ns("helper"))` in the UI and
#' `update_mascot("helper")` in its server. A `session$ns("helper")` id is also
#' accepted, including in nested modules. The session namespace is added once.
#' An invalid `id` type, missing session or extra argument is an error. Calling
#' with all update arguments `NULL` does nothing.
#'
#' **Gestures.** A character or mood change applies before the gesture. During a
#' character swap the gesture is skipped, because the wave within the swap
#' replaces it. Reduced motion skips movement. The latest gesture sent before the
#' mascot appears plays once on appearance, after its queued character and mood
#' are applied.
#'
#' **React to your app's state.** Call `update_mascot()` from an observer. Shiny
#' sends updates when the observer finishes, so for a mood to show while a long
#' computation runs, run it as a [shiny::ExtendedTask] and follow its status:
#'
#' ```r
#' task <- ExtendedTask$new(function(x) promises::future_promise(fit_model(x)))
#' observeEvent(input$run, {
#'   update_mascot("helper", mood = "thinking", status = "Fitting the model")
#'   task$invoke(data())
#' })
#' observe({
#'   switch(task$status(),
#'     success = update_mascot("helper", mood = "happy", status = "Model ready"),
#'     error = update_mascot("helper", mood = "worried", status = "The model failed")
#'   )
#' })
#' ```
#'
#' For form validation, observe whether the inputs are valid (yourself, or with a
#' validation package such as `shinyvalidate`) and set the mood from it:
#'
#' ```r
#' observe({
#'   valid <- grepl("@", input$email, fixed = TRUE)
#'   update_mascot(
#'     "helper",
#'     mood = if (valid) "happy" else "worried",
#'     status = if (valid) "Ready to submit" else "Check the email address"
#'   )
#' })
#' ```
#'
#' **Queued updates.** Updates sent before a mascot appears are kept per session,
#' including when the first mascot is created by [shiny::renderUI()] or
#' [shiny::insertUI()]. Once the character is known, R validates each whole call
#' before accepting its latest values. Before that, a bounded buffer keeps whole
#' calls for validation against the first known character. An invalid call never
#' contributes its bubble, status or other fields. A replacement with the same id
#' receives the latest accepted state; only the latest pending gesture can play,
#' once. Dismissed bubbles stay dismissed through replacement; an explicit bubble
#' update starts a new bubble, including when its text is unchanged.
#' @returns Called for its side effect; returns `NULL` invisibly.
#' @family mascots in Shiny
#' @seealso [mascot()], [mascot_motion_settings()] for a Shiny example that switches
#'   idle movement and plays a nod.
#' @export
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   ui = shiny::fluidPage(
#'     mascot("helper"),
#'     shiny::actionButton("work", "Think"),
#'     shiny::actionButton("done", "Finish")
#'   ),
#'   server = function(input, output, session) {
#'     shiny::observeEvent(input$work, {
#'       update_mascot("helper", mood = "thinking", status = "Working")
#'     })
#'     shiny::observeEvent(input$done, {
#'       update_mascot("helper", mood = "happy", status = mascot_status(),
#'         bubble = "Finished", gesture = "nod")
#'     })
#'   }
#' )
update_mascot <- function(
  id,
  ...,
  character = NULL,
  mood = NULL,
  status = NULL,
  bubble = NULL,
  size = NULL,
  placement = NULL,
  theme = NULL,
  motion = NULL,
  click = NULL,
  gesture = NULL,
  session = shiny::getDefaultReactiveDomain()
) {
  with_mascot_asserts({
    checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
    checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"), null.ok = TRUE)
  })
  if (...length() > 0L) {
    abort_dots(
      names(substitute(list(...)))[-1L],
      ...length(),
      c("character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click", "gesture", "session"),
      environment()
    )
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
    click = click,
    gesture = gesture
  )
  misplaced <- vapply(
    values[c("character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click")],
    inherits,
    logical(1),
    what = c("ShinySession", "session_proxy", "MockShinySession")
  )
  if (any(misplaced)) {
    cli::cli_abort(
      "{.arg session} must be named; a Shiny session was supplied to {.arg {names(misplaced)[misplaced]}}.",
      class = "mascot_error"
    )
  }
  if (is.null(session)) {
    cli::cli_abort(
      "{.fn update_mascot} must be called inside a Shiny server function or module.",
      class = "mascot_error"
    )
  }
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
        value = mascot_update_theme(
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
    cli::cli_warn(
      c(
        "{.fn update_mascot} left mascot {.val {id}} unchanged.",
        structure(paste0("{problems[[", seq_along(problems), "]]}"), names = rep("x", length(problems)))
      ),
      class = c("mascot_update_ignored", "mascot_warning")
    )
    if (dev_mode()) {
      send_update(session, id, list(problem = paste0("mascot: ", paste(problems, collapse = "; "))))
    }
    return(invisible(NULL))
  }
  patch <- list()
  if (!is.null(character)) {
    ch <- as_character_arg(character, environment())
    patch$character <- list(id = ch$id, name = ch$name, json = if (is.null(ch$json)) character_json(ch$id) else ch$json)
  }
  if (!is.null(mood)) {
    patch$mood <- if (inherits(mood, "mascot_mood")) mood$name else mood
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
  if (!is.null(click)) {
    patch$click <- as_click_arg(click, environment())
  }
  if (!is.null(gesture)) {
    patch$gesture <- if (inherits(gesture, "mascot_gesture")) gesture$name else gesture
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
  key <- mascot_binding_id(session, id)
  # Development overlays are diagnostics, not accepted desired state/actions.
  if (identical(names(patch), "problem")) {
    mascot_problem(session, key, patch$problem)
    return(invisible(NULL))
  }
  record <- mascot_id_state(session, key, namespaced = TRUE)
  next_record <- tryCatch(
    {
      mascot_wire_check(patch)
      if (is.null(record$context) && is.null(patch$character)) {
        mascot_state_buffer(record, patch)
      } else {
        startup <- is.null(record$context)
        if (startup) {
          # Validate the explicit anchor including all coupled fields BEFORE it
          # can settle any earlier call or choose a startup context.
          prepared <- mascot_state_prepare(record, patch)
          record$context <- prepared$context
          record$desired <- mascot_state_defaults(prepared$context$wire)
          record <- mascot_state_settle(record)
        }
        accepted <- mascot_state_accept(record, patch)
        if (startup) {
          accepted$owned <- union(accepted$owned, "mood")
        }
        accepted
      }
    },
    error = function(error) {
      mascot_update_warning(key, conditionMessage(error))
      if (dev_mode()) {
        send_update(session, id, list(problem = paste0("mascot: ", conditionMessage(error))))
      }
      NULL
    }
  )
  if (is.null(next_record)) {
    return(invisible(NULL))
  }
  owner <- mascot_session(session)
  owner$problems[[key]] <- NULL
  owner$states[[key]] <- next_record
  mascot_state_schedule(session, key)
  invisible(NULL)
}

#' Merge the latest arguments using the browser queue's replacement rules
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
