# Examples need a running Shiny app, so they remain interactive.
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
#' @param character A character id such as `"tessa"`, or a [mascot_character()]
#'   helper. `NULL` (the default) leaves the character unchanged.
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
#'   - Inline placement ignores `minimise` and `drag`. If you set either one
#'     yourself, a message says so; the defaults give no message. The update is
#'     still sent.
#'   - With dragging enabled, the minimised restore button can also be dragged.
#'     A click restores it; a drag leaves it minimised in its new position.
#' @param theme A theme in the forms accepted by [mascot()]. `NULL` (the
#'   default) leaves the theme unchanged; `"original"` or `mascot_theme()` restores the
#'   character's own colours. A palette id string chooses a named palette. After
#'   a character swap, the theme is applied again to the new character's parts.
#'   The palette carries over if the new character has one of that name.
#'   If it has not, you get a warning with class `mascot_palette_dropped`, and
#'   colours you set explicitly stay for the roles both characters share.
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
#'   skipped; the mood, bubble and status in the same update still apply. In Shiny
#'   development mode, the browser asks Shiny to show a warning that says why.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param session A Shiny session, defaulting to the current reactive domain.
#'   Must be named when supplied. `NULL` outside a server or module is an error.
#' @details
#' In [mascot()] and its helpers, `NULL` (where accepted) means none or the
#' default. In `update_mascot()`, `NULL` leaves a setting unchanged. To reset a
#' setting, send an empty helper:
#'
#' | Setting | Reset sent to `update_mascot()` |
#' |---|---|
#' | Character | `character = mascot_character()` (back to `"tessa"`) |
#' | Mood | `mood = mascot_mood()` (back to `"idle"`) |
#' | Size | `size = mascot_size()` (160, `small_screen = "auto"`) |
#' | Custom status | `status = mascot_status()` follows the mood |
#' | Bubble | `bubble = mascot_bubble()` removes it |
#' | Theme | `theme = mascot_theme()` restores character colours |
#' | Click | `click = mascot_action()` (or `mascot_popup_menu()`) removes it |
#' | Placement | `placement = mascot_placement()` (bottom-right); `mascot_placement("inline")` for inline |
#' | Motion | `motion = mascot_motion_settings()` allows movement unless the visitor prefers reduced motion |
#'
#' Each non-`NULL` argument replaces that whole setting, not part of it. For
#' example, `update_mascot("h", size = 200)` also resets a custom `small_screen`
#' to `"auto"`.
#'
#' [mascot()] and the helpers raise an error on an invalid value.
#' [update_mascot()] warns instead, with class `mascot_update_ignored`, and
#' leaves the mascot unchanged. That also covers a helper that raises a
#' `mascot_error` while an argument is evaluated inside the call, such as
#' `size = mascot_size(input$px)`; the whole update is then ignored. An invalid
#' `id`, unknown arguments in `...` or a missing session still raise errors. See
#' [mascot-package] for all condition classes.
#'
#' An unknown palette id is an error in [mascot()] but only a warning in
#' `update_mascot()`. [mascot()] runs while the UI is built, where an error shows
#' at once. `update_mascot()` runs in a live session, where an error would stop
#' the app for the visitor, so it warns and the mascot keeps running unchanged.
#' The message names any other characters that have a palette of that name. (A
#' palette carried over from before a character swap is dropped instead, with a
#' warning of class `mascot_palette_dropped`; see the `theme` argument.)
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
#' accepted, including in nested modules; the namespace is not added twice.
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
#' **Queued updates.** Updates sent before a mascot appears are kept for the
#' session, also when the first mascot is created by [shiny::renderUI()] or
#' [shiny::insertUI()]. Each call is checked as a whole before its latest values
#' are accepted. Until the character is known, a buffer of limited size holds
#' whole calls, and they are checked against the first character that appears.
#' A call that fails the check adds nothing, not even its bubble or status. A
#' mascot that replaces one with the same id gets the latest accepted state, and
#' only the latest pending gesture plays, once. A bubble the visitor dismissed
#' stays dismissed in the replacement; sending a bubble again starts a new one,
#' even with the same text.
#'
#' **Several calls in one flush.** A flush is one round of Shiny reacting to
#' inputs. Shiny sends the mascot one message when it ends, built from every
#' call made in it, setting by setting: a call changes only the settings it
#' names, and when two calls name the same setting the later call wins. If a
#' reaction to a click sets `mood = "happy"` and a state observer sets
#' `mood = "worried"` in the same flush, the observer that runs last decides the
#' face and the other mood is never shown. `status` and `bubble` work the same
#' way, and only the latest `gesture` plays. Give each setting one owner, so no
#' call can overwrite another's:
#'
#' ```r
#' # The event reaction owns the bubble and gesture, the observer owns the mood.
#' observeEvent(input$save, {
#'   update_mascot("helper", bubble = "Saved", gesture = "nod")
#' })
#' observe({
#'   update_mascot("helper", mood = if (valid()) "idle" else "worried")
#' })
#' ```
#'
#' **After a custom status.** A custom status stays until you replace it or
#' hand it back with `status = mascot_status()`. A call that sets only `mood`
#' changes the face and leaves the status text as it was, so "Fitting the
#' model" can sit beside a happy face. To let the status follow the mood again,
#' send `update_mascot("helper", mood = "happy", status = mascot_status())`.
#'
#' **What a re-created mascot takes from its UI call.** A mascot that
#' [shiny::renderUI()] draws again, or that is removed and added back, receives
#' the latest accepted state (see "Queued updates"). For each setting an earlier
#' accepted call to `update_mascot()` has set, the value in the [mascot()] call
#' is ignored; the settings the server never set come from the [mascot()] call.
#' A `mood`, `status` or `size` in the UI call therefore only matters until the
#' server first sets that setting, and after that the UI call can use the
#' defaults. A call that changes `character` also sets the mood (adapted to the
#' new character), so after it the UI call's `mood` is ignored too.
#'
#' **A mascot in a modal.** The mascot is off the page while the modal is
#' closed. Updates sent then are kept, as under "Queued updates", and applied
#' when the modal opens: the last value of each setting, a bubble sent in the
#' meantime, and a gesture, which plays once as the mascot appears. So it can
#' open with the mood, status or an unfinished bubble from the last visit, or
#' with whatever was sent while the modal was closed. To open it clean, reset
#' those settings as the modal opens (a reset is an update, so it also replaces
#' the UI call's values for them) and send no gesture while it is closed. A
#' reset cannot cancel a gesture already sent. Sending updates only while the
#' modal is open avoids what was sent while it was closed, but not the state
#' left from the last visit.
#'
#' ```r
#' observeEvent(input$help, {
#'   update_mascot(
#'     "helper",
#'     mood = mascot_mood(),
#'     status = mascot_status(),
#'     bubble = mascot_bubble()
#'   )
#'   showModal(modalDialog(mascot("helper"), title = "Help"))
#' })
#' ```
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
  # Force each promise within the helper-error boundary before accepting any field.
  call <- environment()
  arguments <- c("character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click", "gesture")
  evaluated <- lapply(stats::setNames(arguments, arguments), function(arg) {
    tryCatch(
      list(value = get(arg, envir = call, inherits = FALSE)),
      mascot_error = function(error) list(problem = conditionMessage(error))
    )
  })
  values <- lapply(evaluated, function(result) result$value)
  helper_problems <- unlist(lapply(evaluated, function(result) result$problem), use.names = FALSE)
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
  warning_id <- substring(mascot_binding_id(session, id), nchar(session$ns("")) + 1L)
  if (length(helper_problems)) {
    # One bullet per failed helper, as for the ordinary problems below.
    cli::cli_warn(
      c(
        "{.fn update_mascot} left mascot {.val {warning_id}} unchanged.",
        structure(
          paste0("{helper_problems[[", seq_along(helper_problems), "]]}"),
          names = rep("x", length(helper_problems))
        )
      ),
      class = c("mascot_update_ignored", "mascot_warning")
    )
    if (dev_mode()) {
      send_update(
        session,
        id,
        list(problem = paste0("mascot: ", warning_id, ": ", paste(helper_problems, collapse = "; ")))
      )
    }
    return(invisible(NULL))
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
        value = as_theme_arg(
          theme,
          environment(),
          if (is.null(character)) {
            owner <- session$userData$mascot_protocol
            record <- if (!is.null(owner)) owner$states[[mascot_binding_id(session, id)]]
            context <- record$context
            if (is.null(context)) {
              NULL
            } else if (context$wire$id %in% builtin_characters()$id) {
              context$wire$id
            } else {
              context$data
            }
          } else if (!is.null(arg_problem(character, "character"))) {
            NULL
          } else {
            converted <- as_character_arg(character, environment())
            if (is.null(converted$data)) converted$id else converted$data
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
        "{.fn update_mascot} left mascot {.val {warning_id}} unchanged.",
        structure(paste0("{problems[[", seq_along(problems), "]]}"), names = rep("x", length(problems)))
      ),
      class = c("mascot_update_ignored", "mascot_warning")
    )
    if (dev_mode()) {
      send_update(session, id, list(problem = paste0("mascot: ", warning_id, ": ", paste(problems, collapse = "; "))))
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
send_update <- function(session, id, patch) {
  checkmate::assert_multi_class(session, c("ShinySession", "session_proxy", "MockShinySession"))
  checkmate::assert_string(id, min.chars = 1, pattern = "^\\S+$")
  checkmate::assert_list(patch, names = "unique")
  key <- mascot_binding_id(session, id)
  warning_id <- substring(key, nchar(session$ns("")) + 1L)
  # Development overlays are diagnostics, not accepted desired state/actions.
  if (identical(names(patch), "problem")) {
    mascot_problem(session, key, patch$problem)
    return(invisible(NULL))
  }
  record <- mascot_id_state(session, key, namespaced = TRUE)
  problem_before <- mascot_session(session)$problems[[key]]
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
          record <- mascot_state_settle(record, session)
        }
        accepted <- mascot_state_accept(record, patch)
        if (startup) {
          accepted$owned <- union(accepted$owned, "mood")
        }
        accepted
      }
    },
    error = function(error) {
      mascot_update_warning(warning_id, conditionMessage(error))
      if (dev_mode()) {
        send_update(session, id, list(problem = paste0("mascot: ", warning_id, ": ", conditionMessage(error))))
      }
      NULL
    }
  )
  if (is.null(next_record)) {
    return(invisible(NULL))
  }
  owner <- mascot_session(session)
  # A settle that failed during this call keeps its overlay; otherwise success clears it.
  if (identical(owner$problems[[key]], problem_before)) {
    owner$problems[[key]] <- NULL
  }
  owner$states[[key]] <- next_record
  mascot_state_schedule(session, key)
  invisible(NULL)
}

#' Whether client-side problem messages should be shown
#' @noRd
dev_mode <- function() {
  shiny::in_devmode()
}
