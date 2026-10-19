#' Set a mascot's message bubble
#'
#' A speech bubble stays visible across mood changes and character swaps.
#' Plain text is escaped; use [htmltools::HTML()] only for HTML you trust. A
#' timed countdown pauses while the mascot is hidden or minimised, while the
#' pointer is over the bubble, or while keyboard focus is anywhere inside the
#' mascot, and resumes with the time left. Pressing Escape while
#' focused inside the mascot closes the bubble. Closing a bubble removes it
#' until the app supplies a new one. While the bubble shows, the mascot looks
#' towards it: up when the bubble is above (inline and bottom corners), down
#' when it is below (top corners).
#'
#' Use the always visible status line for a short description of the current state.
#' Use a bubble for a message about something that happened; it may time out.
#' Use `duration = Inf` for a message the user must act on, such as an invalid form,
#' because a timed message can vanish before it is read.
#'
#' **Bubble or menu?** A bubble is a message the app shows; the server supplies or
#' updates it with `update_mascot(id, bubble = ...)`. For an action the visitor
#' chooses, use [mascot_popup_menu()] with `click =` instead.
#' @param text A non-empty string, optionally marked with [htmltools::HTML()],
#'   or an `htmltools` tag or tag list. HTML-marked strings and tags are shown as
#'   HTML. Tags with dependencies or head content are not supported and give an
#'   error. `NULL` (the default) clears the bubble. With `text = NULL`, explicitly
#'   supplying `duration` or `closable` is an error; use `mascot_bubble()` without
#'   options to clear the bubble.
#' @param duration How long the bubble stays visible: a number greater than zero,
#'   in seconds. Defaults to `5`. Use `Inf` to keep the bubble until it
#'   is closed, replaced or cleared.
#' @param closable A logical flag, defaulting to `TRUE`, to show a close button.
#'   `FALSE` hides the button; the Escape key still closes the bubble. `NULL`
#'   is not accepted.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @returns A `mascot_bubble` object with `text`, `html`, `duration`, and
#'   `closable` elements. `text` is a plain string or `NULL`; `html` is a flag.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()], [update_mascot()], [mascot_popup_menu()]
#' @export
#' @examples
#' mascot_bubble("3 rows skipped")
#' mascot_bubble("Ready", duration = Inf)
#' mascot_bubble(htmltools::HTML("<strong>Ready</strong>"))
#' mascot_bubble()
mascot_bubble <- function(text = NULL, ..., duration = 5, closable = TRUE) {
  with_mascot_asserts({
    # Text is a union: validate tags as tags, and strings with the usual assertion.
    if (inherits(text, c("shiny.tag", "shiny.tag.list"))) {
      checkmate::assert_multi_class(text, c("shiny.tag", "shiny.tag.list"))
    } else {
      checkmate::assert_string(text, min.chars = 1, null.ok = TRUE)
    }
    # NULL used to mean "stay"; it gets its own hint instead of checkmate's generic type message.
    if (is.null(duration)) {
      cli::cli_abort(
        "{.arg duration} cannot be NULL; use {.code duration = Inf} to keep the bubble open.",
        class = "mascot_error"
      )
    }
    checkmate::assert_number(duration, lower = 0)
    checkmate::assert_flag(closable)
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("duration", "closable"), environment())
  }
  if (duration == 0) {
    cli::cli_abort("{.arg duration} must be greater than zero; got {.val {duration}}.", class = "mascot_error")
  }
  if (is.null(text) && (!missing(duration) || !missing(closable))) {
    cli::cli_abort(
      c(
        "{.arg text} cannot be NULL when options are supplied.",
        "i" = "Use {.code mascot_bubble()} without options to remove it."
      ),
      class = "mascot_error"
    )
  }
  if (inherits(text, c("shiny.tag", "shiny.tag.list"))) {
    text <- render_bubble_text(text)
  }
  html <- inherits(text, "html")
  if (html) {
    text <- as.character(unclass(text))
  }
  structure(list(text = text, html = html, duration = duration, closable = closable), class = "mascot_bubble")
}

#' Accept plain text or a bubble helper
#' @noRd
as_bubble_arg <- function(x, call) {
  checkmate::assert_environment(call)
  # Retain rendered HTML before validation, so deferred tags run only once.
  if (inherits(x, c("shiny.tag", "shiny.tag.list"))) {
    x <- mascot_bubble(x)
  }
  # Union arguments share non-throwing checks with runtime validation.
  check_arg(x, "bubble", call)
  if (inherits(x, "mascot_bubble")) x else mascot_bubble(x)
}

#' Initial bubble markup, after the status in reading and focus order
#' @noRd
bubble_tag <- function(bubble) {
  checkmate::assert_class(bubble, "mascot_bubble")
  htmltools::tags$div(
    class = "mascot-bubble-region",
    role = "status",
    `aria-live` = "polite",
    `aria-atomic` = "true",
    htmltools::tags$div(
      class = "mascot-panel mascot-bubble",
      hidden = if (is.null(bubble$text)) NA else NULL,
      `data-text` = bubble$text,
      `data-html` = tolower(as.character(bubble$html)),
      `data-closable` = tolower(as.character(bubble$closable)),
      `data-duration` = if (is.finite(bubble$duration)) bubble$duration else NULL,
      htmltools::tags$div(
        class = "mascot-bubble-text",
        if (bubble$html) htmltools::HTML(bubble$text) else bubble$text
      ),
      if (!is.null(bubble$text) && bubble$closable) {
        htmltools::tags$button(
          class = "mascot-bubble-close",
          type = "button",
          `aria-label` = "Close message",
          "\u00d7"
        )
      }
    )
  )
}


#' Render self-contained body HTML; bubble messages cannot install dependencies
#' @noRd
render_bubble_text <- function(text) {
  checkmate::assert_multi_class(text, c("shiny.tag", "shiny.tag.list"))
  rendered <- htmltools::renderTags(text)
  if (length(rendered$dependencies)) {
    cli::cli_abort(
      "{.arg text} carries HTML dependencies, which are not supported in a bubble; use self-contained tags.",
      class = "mascot_error"
    )
  }
  if (nzchar(rendered$head)) {
    cli::cli_abort(
      "{.arg text} contains head content, which is not supported in a bubble; use body HTML only.",
      class = "mascot_error"
    )
  }
  checkmate::assert_string(rendered$html, min.chars = 1, .var.name = "text")
  htmltools::HTML(rendered$html)
}

#' @export
#' @noRd
format.mascot_bubble <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_bubble")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_bubble <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_bubble")
  })
  cli::cat_line(format(x))
  invisible(x)
}
