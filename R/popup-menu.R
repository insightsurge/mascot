#' Choose a mascot's click menu
#'
#' Make a click on the mascot open a menu in a Shiny app. Pass it as `click` to
#' [mascot()] or [update_mascot()]. Clicking or tapping the mascot opens the
#' menu, and clicking outside or pressing Escape closes it. While the menu is
#' open, the mascot looks towards it, on the side where it actually opened (see
#' "Where the menu opens" below). You provide the menu choices and handle the
#' selected item in your Shiny server. For a single action, use
#' [mascot_action()] instead.
#'
#' **Bubble or menu?** A menu lets the visitor ask the app to do something: attach
#' it with `click =` and read the choice from `input$<id>_menu`. For a message the
#' app sends to the visitor, use [mascot_bubble()] and `update_mascot(id, bubble = ...)`.
#' @param items A named character vector of plain-text labels. Names are unique,
#'   non-empty item IDs without whitespace (for example `c(about = "About", help = "Help")`).
#'   Defaults to `NULL`, an empty helper: in [update_mascot()], it removes the
#'   click, so the mascot is a picture again. An empty vector is not accepted.
#'   Labels are always escaped. With `items = NULL`, explicitly supplying
#'   `direction`, `label` or `tooltip` is an error; use `mascot_popup_menu()`
#'   without options to remove the click.
#' @param ... Must be empty. Forces the arguments after it to be named.
#' @param direction Direction to open the menu from the mascot: `"auto"` (the default),
#'   `"top"`, `"bottom"`, `"left"` or `"right"`. `"auto"` picks the side with room
#'   (preferring above, then below, then the side towards the page centre). A
#'   chosen side is a preference: see "Where the menu opens" below.
#' @param label The name screen readers announce for the mascot's menu button,
#'   such as `"Help and settings"`: one string containing a non-whitespace
#'   character. `NULL` (the default) uses the character's name, such as "Tessa, menu".
#' @param tooltip A flag. `TRUE` (the default) shows the label in a tooltip when
#'   the pointer rests on the mascot or the keyboard focuses it, provided a
#'   `label` is set. `FALSE` hides the tooltip; screen readers still announce
#'   the label.
#' @returns A `mascot_popup_menu` object with `items`, `direction`, `label` and
#'   `tooltip` elements.
#' The returned object's fields are internal; pass the object on rather than reading its fields.
#' @family mascot helpers
#' @seealso [mascot()], [update_mascot()], [mascot_action()], [mascot_bubble()]
#' @details
#' **Where the menu opens.** The menu must fit in the space where it can show. For
#' an inline mascot, that space is bounded by the nearest container that scrolls
#' or clips (such as a `bslib::card()` body or a sidebar), not the whole window.
#' For a floating mascot, it uses the window. When the chosen `direction` has no
#' room there, the menu opens on the opposite side; when neither side has room, it
#' opens wherever `"auto"` finds space. So `direction = "bottom"` on a mascot near
#' the bottom of a card opens above it. Give the mascot room on the chosen side,
#' or use `"auto"`.
#'
#' **Keyboard navigation.** Enter or Space on the focused mascot opens or closes
#' the menu and moves the focus to its first item; holding the key down toggles
#' it once. After opening it with a click, the down and up arrows move from the
#' mascot to the first or last item. Use the arrow keys, Home and End to move
#' between items, and press Escape to close the menu and return focus to the
#' mascot.
#'
#' **Reading the selection in Shiny.** Choosing an item sets `input$<id>_menu` to
#' the item ID (for example, `input$helper_menu` for `mascot("helper")`).
#' Choosing the same item twice triggers the input twice. Opening and closing the
#' menu never set `input$<id>_click`; that input is only for [mascot_action()].
#' In a module, use `ns("helper")` in the UI and read `input$helper_menu`
#' inside that module's server:
#' ```r
#' helper_ui <- function(id) {
#'   ns <- shiny::NS(id)
#'   mascot(ns("helper"), click = mascot_popup_menu(
#'     c(about = "About this app")))
#' }
#' helper_server <- function(id) {
#'   shiny::moduleServer(id, function(input, output, session) {
#'     shiny::observeEvent(input$helper_menu, {
#'       if (input$helper_menu == "about") {
#'         shiny::showModal(shiny::modalDialog("About this app"))
#'       }
#'     })
#'   })
#' }
#' shiny::shinyApp(
#'   shiny::fluidPage(helper_ui("demo")),
#'   function(input, output, session) helper_server("demo")
#' )
#' ```
#'
#' The menu opens from the mascot's on-screen position in the requested direction.
#' It fits the available screen space and can change direction or scroll.
#' Action controls hide while the menu is open. Opening the menu closes any speech
#' bubble that is showing.
#' The restore button only restores a minimised mascot; it does not open the menu.
#' On static pages the mascot stays an image. Run the Shiny example below to try
#' the menu.
#' @export
#' @examples
#' mascot_popup_menu(c(about = "About this app", help = "Help"))
#' mascot_popup_menu(c(about = "About this app"), direction = "top")
#' mascot_popup_menu(c(about = "About this app"), label = "Help and settings")
#' mascot_popup_menu(c(about = "About this app"), label = "Help and settings", tooltip = FALSE)
#' mascot_popup_menu()
#' mascot("helper", click = mascot_popup_menu(c(about = "About this app")))
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(mascot("helper", click = mascot_popup_menu(
#'     c(about = "About this app")))),
#'   function(input, output, session) {
#'     shiny::observeEvent(input$helper_menu, {
#'       shiny::showModal(shiny::modalDialog(paste("Selected", input$helper_menu)))
#'     })
#'   }
#' )
mascot_popup_menu <- function(items = NULL, ..., direction = "auto", label = NULL, tooltip = TRUE) {
  with_mascot_asserts({
    checkmate::assert_character(items, min.chars = 1, any.missing = FALSE, min.len = 1, null.ok = TRUE)
    if (!isTRUE(checkmate::check_string(direction))) {
      checkmate::assert_choice(direction, popup_menu_directions())
    }
    checkmate::assert_string(label, min.chars = 1, pattern = "\\S", null.ok = TRUE)
    checkmate::assert_flag(tooltip)
  })
  if (...length() > 0L) {
    abort_dots(names(substitute(list(...)))[-1L], ...length(), c("direction", "label", "tooltip"), environment())
  }
  if (!direction %in% popup_menu_directions()) {
    abort_choice(direction, popup_menu_directions(), "direction", "direction", environment())
  }
  if (is.null(items) && (!missing(direction) || !missing(label) || !missing(tooltip))) {
    cli::cli_abort(
      c(
        "{.arg items} cannot be NULL when options are supplied.",
        "i" = "Use {.code mascot_popup_menu()} without options to remove it."
      ),
      class = "mascot_error"
    )
  }
  value <- structure(
    list(items = items, direction = direction, label = label, tooltip = tooltip),
    class = "mascot_popup_menu"
  )
  problem <- popup_menu_problem(value)
  if (!is.null(problem)) {
    cli::cli_abort("{problem}", class = "mascot_error")
  }
  value
}

#' Valid popup menu directions
#' @noRd
popup_menu_directions <- function() {
  c("auto", "top", "bottom", "left", "right")
}

#' Validate a menu shortcut or helper without throwing
#' @noRd
popup_menu_problem <- function(x) {
  # Union inputs use check_* so invalid runtime values warn rather than throw.
  if (inherits(x, "mascot_popup_menu")) {
    if (
      !isTRUE(checkmate::check_list(x, names = "unique")) ||
        length(x) != 4L ||
        !setequal(names(x), c("items", "direction", "label", "tooltip")) ||
        !isTRUE(checkmate::check_string(x$label, min.chars = 1, pattern = "\\S", null.ok = TRUE)) ||
        !isTRUE(checkmate::check_flag(x$tooltip))
    ) {
      return("`click` must have items, direction, label and tooltip fields; use mascot_popup_menu().")
    }
    if (!isTRUE(checkmate::check_choice(x$direction, popup_menu_directions()))) {
      return(paste0(
        "`direction` must be one of ",
        paste(encodeString(popup_menu_directions(), quote = '"'), collapse = ", "),
        "; ",
        if (is.character(x$direction)) encodeString(x$direction, quote = '"') else deparse1(x$direction),
        " is not a valid direction."
      ))
    }
    x <- x$items
  }
  if (is.null(x)) {
    return(NULL)
  }
  if (!isTRUE(checkmate::check_character(x, min.chars = 1, any.missing = FALSE, min.len = 1))) {
    return("`items` must be a non-empty named character vector of plain-text labels, or NULL for no menu.")
  }
  ids <- names(x)
  if (is.null(ids) || anyNA(ids) || any(!nzchar(ids)) || anyDuplicated(ids) || any(grepl("\\s", ids))) {
    return("`items` names must be unique, non-empty ids without whitespace; use c(about = 'About this app').")
  }
  NULL
}

#' @export
#' @noRd
format.mascot_popup_menu <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_popup_menu")
  })
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_popup_menu <- function(x, ...) {
  with_mascot_asserts({
    checkmate::assert_class(x, "mascot_popup_menu")
  })
  cli::cat_line(format(x))
  invisible(x)
}
