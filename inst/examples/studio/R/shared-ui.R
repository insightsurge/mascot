# Buttons that every view of the studio app shares. Their look is Bootstrap's; inputs.js answers data-copy.

# A small outline button with an accessible name; pressed (TRUE or FALSE) makes it a toggle (aria-pressed).
studio_button <- function(id, label, aria_label = label, pressed = NULL) {
  checkmate::assert_string(id)
  checkmate::assert_string(label)
  checkmate::assert_string(aria_label)
  checkmate::assert_flag(pressed, null.ok = TRUE)
  shiny::tags$button(
    id = id,
    type = "button",
    class = "btn btn-sm btn-outline-primary",
    `aria-label` = aria_label,
    `aria-pressed` = if (!is.null(pressed)) tolower(as.character(pressed)),
    label
  )
}

# Copies the text of the element whose id is target (inputs.js), once the server has answered the click (copy_gate()),
# and says so on the button for a moment.
copy_button <- function(target, label = "Copy") {
  checkmate::assert_string(target, min.chars = 1)
  checkmate::assert_string(label, min.chars = 1)
  shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-primary pg-copy", `data-copy` = target, label)
}

# Updates a linked control with the revision of the choice it answers. The page ignores an older reply and does
# not report a server update as another choice. choices supplies a select's options when its character changes.
update_choice <- function(session, id, value, group, revision, choices = NULL) {
  checkmate::assert_environment(session)
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(value, min.chars = 1)
  checkmate::assert_string(group, min.chars = 1)
  checkmate::assert_count(revision)
  checkmate::assert_character(choices, any.missing = FALSE, null.ok = TRUE)
  message <- list(value = value, group = group, revision = revision)
  if (!is.null(choices)) {
    labels <- if (is.null(names(choices))) choices else names(choices)
    message$options <- as.character(htmltools::tagList(lapply(seq_along(choices), function(i) {
      shiny::tags$option(value = choices[[i]], labels[[i]])
    })))
  }
  session$sendInputMessage(id, message)
  invisible(NULL)
}

# Stamps a text output with what it was drawn for. The page compares the stamp with what it asked for, and says the
# output is busy until they match (studio.js, syncPanelStamps()). Call it in the output's render function. The stamp is
# sent after the flush that sends the text, so it never reaches the page before the text it stands for.
stamp_output <- function(session, id, stamp) {
  checkmate::assert_environment(session)
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(stamp)
  session$onFlushed(
    function() session$sendCustomMessage("studio:stamp", list(id = id, stamp = stamp)),
    once = TRUE
  )
  invisible(NULL)
}

# Answers the tickets of the copy buttons (inputs.js). A copy button sends input$copy_ticket when it is clicked and
# copies only when the server answers that ticket: by then everything the page sent before the click has been applied
# and drawn, so the button copies the code that belongs to what is on the screen, not the code of an earlier state.
# `pending` returns TRUE while the server holds a change it has not applied yet (a debounced input): the answer waits
# for it. Call this once in a view's server function, after the reactives `pending` reads.
copy_gate <- function(input, session, pending = function() FALSE) {
  checkmate::assert_environment(session)
  checkmate::assert_function(pending)
  waiting <- shiny::reactiveVal(integer())
  shiny::observeEvent(input$copy_ticket, {
    ticket <- suppressWarnings(as.integer(input$copy_ticket))
    shiny::req(length(ticket) == 1L, !is.na(ticket))
    waiting(c(shiny::isolate(waiting()), ticket))
  })
  shiny::observe({
    tickets <- waiting()
    if (length(tickets) && !isTRUE(pending())) {
      waiting(integer())
      session$onFlushed(
        function() {
          for (ticket in tickets) {
            session$sendCustomMessage("studio:copy", list(ticket = ticket))
          }
        },
        once = TRUE
      )
    }
  })
  invisible(NULL)
}
