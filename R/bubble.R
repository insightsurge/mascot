#' Set a mascot's message bubble
#'
#' A bubble survives mood changes and character swaps. Plain text is escaped;
#' use [htmltools::HTML()] only for HTML you trust. A timed bubble pauses while
#' the pointer is over it or focus is inside the mascot, then resumes with the
#' time left. The Escape key closes it while focus is inside the mascot. Closing a bubble
#' is final until the app supplies a new bubble.
#'
#' Use the always visible status line for a short description of the current state.
#' Use a bubble for a message about something that happened; it may time out.
#' Use `duration = Inf` for a message the user must act on, such as an invalid form,
#' because a timed message can vanish before it is read.
#' @param text A non-empty string, optionally marked with [htmltools::HTML()],
#'   or an `htmltools` tag or tag list, rendered as HTML. Tags with dependencies
#'   or head content are not supported and give an error. `NULL` (the default)
#'   clears the bubble.
#' @param duration A number greater than zero, in seconds. Defaults to `5`;
#'   `Inf` or `NULL` keeps the bubble until closed, replaced or cleared.
#' @param closable A logical flag, defaulting to `TRUE`, to show a close button.
#'   `FALSE` hides the button; the Escape key still closes the bubble. `NULL` is not accepted.
#' @returns A `mascot_bubble` object with `text`, `html`, `duration` and
#'   `closable` elements. `text` is a plain string or `NULL`; `html` is a flag.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @export
#' @examples
#' mascot_bubble("3 rows skipped")
#' mascot_bubble("Ready", duration = Inf)
#' mascot_bubble(htmltools::HTML("<strong>Ready</strong>"))
#' mascot_bubble()
mascot_bubble <- function(text = NULL, duration = 5, closable = TRUE) {
  # Text is a union: validate tags as tags, and strings with the usual assertion.
  if (inherits(text, c("shiny.tag", "shiny.tag.list"))) {
    checkmate::assert_multi_class(text, c("shiny.tag", "shiny.tag.list"))
  } else {
    checkmate::assert_string(text, min.chars = 1, null.ok = TRUE)
  }
  checkmate::assert_number(duration, lower = 0, null.ok = TRUE)
  checkmate::assert_flag(closable)
  if (is.null(duration)) {
    duration <- Inf
  }
  if (duration == 0) {
    cli::cli_abort("{.arg duration} must be greater than zero; got {.val {duration}}.")
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
      class = "mascot-bubble",
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
      "{.arg text} carries HTML dependencies, which are not supported in a bubble; use self-contained tags."
    )
  }
  if (nzchar(rendered$head)) {
    cli::cli_abort("{.arg text} contains head content, which is not supported in a bubble; use body HTML only.")
  }
  checkmate::assert_string(rendered$html, min.chars = 1, .var.name = "text")
  htmltools::HTML(rendered$html)
}

#' @export
#' @noRd
format.mascot_bubble <- function(x, ...) {
  checkmate::assert_class(x, "mascot_bubble")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_bubble <- function(x, ...) {
  checkmate::assert_class(x, "mascot_bubble")
  cli::cat_line(format(x))
  invisible(x)
}
