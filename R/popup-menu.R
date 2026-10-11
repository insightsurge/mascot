#' Choose a mascot's click menu
#'
#' Add a click menu to the mascot in a Shiny app. Clicking or tapping the mascot
#' opens the menu, and clicking outside or pressing Escape closes it. While the
#' menu is open, the mascot looks up towards it. You provide the menu choices and
#' handle the selected item in your Shiny server.
#' @param items A named character vector of plain-text labels. Names are unique,
#'   non-empty item IDs without whitespace (for example `c(about = "About", help = "Help")`).
#'   Defaults to `NULL`, which removes the menu; an empty vector is not accepted.
#'   Labels are always escaped.
#' @param direction Direction to open the menu from the mascot: `"auto"` (the default),
#'   `"top"`, `"bottom"`, `"left"` or `"right"`. `"auto"` picks the side with room
#'   (preferring above, then below, then the side towards the page centre). A
#'   chosen side is a preference: see "Where the menu opens" below.
#' @returns A `mascot_popup_menu` object with `items` and `direction` elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
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
#' **Keyboard navigation.** Enter or Space toggles the focused menu control, opening
#' or closing the menu. Use the arrow keys, Home and End to move between items,
#' and press Escape to close the menu and return focus to the mascot. Without
#' menu items, the mascot remains an image with its status text.
#'
#' **Reading the selection in Shiny.** Choosing an item sets `input$<id>_menu` to
#' the item ID (for example, `input$helper_menu` for `mascot(id = "helper")`).
#' Choosing the same item twice triggers the input twice. In a module, use
#' `ns("helper")` in the UI and read `input$helper_menu` inside that module's server:
#' ```r
#' helper_ui <- function(id) {
#'   ns <- shiny::NS(id)
#'   mascot(id = ns("helper"), popup_menu = mascot_popup_menu(
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
#' Action controls hide while the menu is open, and speech bubble timers pause.
#' The restore button only restores a minimised mascot; it does not open the menu.
#' On static pages the mascot stays an image. Run the Shiny example below to try
#' the menu.
#' @export
#' @examples
#' mascot_popup_menu(c(about = "About this app", help = "Help"))
#' mascot_popup_menu(c(about = "About this app"), direction = "top")
#' mascot_popup_menu()
#' mascot(id = "helper", popup_menu = c(about = "About this app"))
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(mascot(id = "helper", popup_menu = mascot_popup_menu(
#'     c(about = "About this app")))),
#'   function(input, output, session) {
#'     shiny::observeEvent(input$helper_menu, {
#'       shiny::showModal(shiny::modalDialog(paste("Selected", input$helper_menu)))
#'     })
#'   }
#' )
mascot_popup_menu <- function(items = NULL, direction = "auto") {
  checkmate::assert_character(items, min.chars = 1, any.missing = FALSE, min.len = 1, null.ok = TRUE)
  if (!isTRUE(checkmate::check_string(direction))) {
    checkmate::assert_choice(direction, popup_menu_directions())
  }
  if (!direction %in% popup_menu_directions()) {
    abort_choice(direction, popup_menu_directions(), "direction", "direction", environment())
  }
  value <- structure(list(items = items, direction = direction), class = "mascot_popup_menu")
  problem <- popup_menu_problem(value)
  if (!is.null(problem)) {
    cli::cli_abort("{problem}")
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
        length(x) != 2L ||
        !setequal(names(x), c("items", "direction"))
    ) {
      return("`popup_menu` must have items and direction fields; use mascot_popup_menu().")
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

#' Accept named items or a menu helper
#' @noRd
as_popup_menu_arg <- function(x, call) {
  checkmate::assert_environment(call)
  check_arg(x, "popup_menu", call)
  value <- if (inherits(x, "mascot_popup_menu")) x else mascot_popup_menu(x)
  list(
    items = if (is.null(value$items)) NULL else as.list(value$items),
    direction = value$direction
  )
}

#' Initial menu configuration, escaped for an inert JSON script
#' @noRd
popup_menu_tag <- function(menu) {
  checkmate::assert_list(menu, names = "unique")
  if (is.null(menu$items)) {
    return(NULL)
  }
  json <- jsonlite::toJSON(menu, auto_unbox = TRUE, null = "null")
  htmltools::tags$script(
    type = "application/json",
    `data-mascot-popup-menu` = "",
    htmltools::HTML(gsub("</", "<\\/", json, fixed = TRUE))
  )
}

#' @export
#' @noRd
format.mascot_popup_menu <- function(x, ...) {
  checkmate::assert_class(x, "mascot_popup_menu")
  helper_format(x)
}

#' @export
#' @noRd
print.mascot_popup_menu <- function(x, ...) {
  checkmate::assert_class(x, "mascot_popup_menu")
  cli::cat_line(format(x))
  invisible(x)
}
