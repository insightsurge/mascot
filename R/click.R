#' Make the mascot a button for one action
#'
#' Turn the mascot into a button for one action of your Shiny app, such as
#' opening a help panel or a chat. Pass it as `click` to [mascot()] or
#' [updateMascot()], and handle the click in your server with
#' `shiny::observeEvent(input$<id>_click, ...)`. For a choice of several actions,
#' use [mascot_popup_menu()] instead.
#'
#' @param label The action's name: one string containing a non-whitespace
#'   character that says what a click does, such as `"Open help"`. Screen readers
#'   announce the mascot as a button with this name, and the tooltip shows it.
#'   `NULL` (the default) makes an empty helper: in [updateMascot()], it removes
#'   the click, so the mascot is a picture again.
#' @param ... Must be empty. Extra arguments are errors.
#' @param tooltip A flag. `TRUE` (the default) shows the label in a tooltip when
#'   the pointer rests on the mascot or the keyboard focuses it. `FALSE` hides the
#'   tooltip; screen readers still announce the label.
#' @param disabled A flag. `TRUE` keeps the mascot a button that does nothing:
#'   clicks are not sent, and screen readers announce the button as unavailable.
#'   Defaults to `FALSE`. Use it while the action makes no sense, such as during
#'   a long task, and send `mascot_action(..., disabled = FALSE)` afterwards.
#' @returns A `mascot_action` object with `label`, `tooltip` and `disabled`
#'   elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()], [mascot_popup_menu()]
#' @details
#' **What a click sends.** Every activation of the button sets
#' `input$<id>_click` to the number of activations since the mascot appeared, so
#' `shiny::observeEvent()` runs each time. An activation is a click or tap, Enter
#' or Space while the mascot has keyboard focus, or a screen reader's activate
#' command. Holding a key down counts once. Dragging a floating mascot, clicking
#' elsewhere, pressing Escape, the minimise and restore buttons and updates from
#' the server never count. In a module, use `ns("helper")` in the UI and read
#' `input$helper_click` in that module's server.
#'
#' **Without a click.** The default, `click = NULL` in [mascot()], keeps the
#' mascot a picture: it is not a keyboard stop and sends no clicks. Use a click
#' only when it does something, so keyboard users never land on a control that
#' does nothing.
#'
#' **The tooltip** shows the label next to the mascot, on the side with room.
#' It stays while the pointer is over the mascot or the tooltip, and Escape hides
#' it without moving the focus. It never shows on touch screens or while a menu
#' or bubble is open. On static pages the mascot stays a picture.
#' @export
#' @examples
#' mascot_action("Open help")
#' mascot_action("Open help", tooltip = FALSE)
#' mascot_action()
#' mascot(id = "helper", click = "Open help")
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(mascot(id = "helper", click = "Open help")),
#'   function(input, output, session) {
#'     shiny::observeEvent(input$helper_click, {
#'       shiny::showModal(shiny::modalDialog("Help for this app"))
#'     })
#'   }
#' )
mascot_action <- function(label = NULL, ..., tooltip = TRUE, disabled = FALSE) {
  checkmate::assert_string(label, min.chars = 1, pattern = "\\S", null.ok = TRUE)
  checkmate::assert_flag(tooltip)
  checkmate::assert_flag(disabled)
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("tooltip", "disabled"), environment())
  }
  structure(list(label = label, tooltip = tooltip, disabled = disabled), class = "mascot_action")
}

#' Validate a click shortcut or helper without throwing
#' @noRd
click_problem <- function(x) {
  # Union inputs use check_* so invalid runtime values warn rather than throw.
  if (is.null(x)) {
    return(NULL)
  }
  if (inherits(x, "mascot_popup_menu")) {
    return(popup_menu_problem(x))
  }
  if (inherits(x, "mascot_action")) {
    if (
      !isTRUE(checkmate::check_list(x, names = "unique")) ||
        length(x) != 3L ||
        !setequal(names(x), c("label", "tooltip", "disabled")) ||
        !isTRUE(checkmate::check_string(x$label, min.chars = 1, pattern = "\\S", null.ok = TRUE)) ||
        !isTRUE(checkmate::check_flag(x$tooltip)) ||
        !isTRUE(checkmate::check_flag(x$disabled))
    ) {
      return("`click` must have label, tooltip and disabled fields; use mascot_action().")
    }
    return(NULL)
  }
  # A named vector was the menu shortcut before `click` replaced `popup_menu`.
  if (is.character(x) && !is.null(names(x))) {
    return(paste0(
      "`click` got a named vector; for a menu, wrap it in mascot_popup_menu(), such as ",
      "click = mascot_popup_menu(c(help = \"Help\"))."
    ))
  }
  if (!isTRUE(checkmate::check_string(x, min.chars = 1, pattern = "\\S"))) {
    return(paste0(
      "`click` must be one non-empty label such as \"Open help\", a mascot_action() or ",
      "mascot_popup_menu() object, or NULL for no click."
    ))
  }
  NULL
}

#' Accept a label or a click helper, returning what the browser receives
#' @noRd
as_click_arg <- function(x, call) {
  checkmate::assert_environment(call)
  check_arg(x, "click", call)
  if (is.null(x)) {
    return(NULL)
  }
  value <- if (is.character(x)) mascot_action(x) else x
  click_wire(value)
}

#' The browser's click configuration; an empty helper means no click
#' @noRd
click_wire <- function(value) {
  checkmate::assert_multi_class(value, c("mascot_action", "mascot_popup_menu"))
  if (inherits(value, "mascot_popup_menu")) {
    if (is.null(value$items)) {
      return(list(type = "none"))
    }
    return(list(
      type = "menu",
      items = as.list(value$items),
      direction = value$direction,
      label = value$label,
      tooltip = value$tooltip
    ))
  }
  if (is.null(value$label)) {
    return(list(type = "none"))
  }
  list(type = "action", label = value$label, tooltip = value$tooltip, disabled = value$disabled)
}

#' Initial click configuration, escaped for a data-only script tag
#' @noRd
click_tag <- function(click) {
  checkmate::assert_list(click, names = "unique", null.ok = TRUE)
  if (is.null(click) || identical(click$type, "none")) {
    return(NULL)
  }
  json <- jsonlite::toJSON(click, auto_unbox = TRUE, null = "null")
  htmltools::tags$script(
    type = "application/json",
    `data-mascot-click` = "",
    htmltools::HTML(gsub("</", "<\\/", json, fixed = TRUE))
  )
}

#' @export
#' @noRd
format.mascot_action <- function(x, ...) {
  checkmate::assert_class(x, "mascot_action")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_action <- function(x, ...) {
  checkmate::assert_class(x, "mascot_action")
  cli::cat_line(format(x))
  invisible(x)
}
