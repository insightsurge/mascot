#' Choose a mascot's click menu
#'
#' The app supplies the items and decides what each choice does. Menus appear only
#' in Shiny. Clicking or touching the mascot opens the menu; Escape or a click
#' elsewhere closes it. The mascot looks up while the menu is open.
#' @param items A named character vector of plain-text labels. Names are unique,
#'   non-empty item ids without whitespace. `NULL` (the default) removes the menu;
#'   an empty vector is not accepted. Labels are always escaped.
#' @param key_bindings A logical flag, defaulting to `FALSE`. With `TRUE`, Enter
#'   and Space open the menu while the mascot has focus. There are no page-wide
#'   shortcuts. `NULL` is not accepted.
#' @returns A `mascot_popup_menu` object with `items` and `key_bindings` elements.
#' @family mascot helpers
#' @seealso [mascot()], [updateMascot()]
#' @details
#' Keyboard-only users need `key_bindings = TRUE` to open the menu (`WCAG 2.1.1`).
#' This is recommended for regulated apps. Within an open menu, arrow keys move
#' between choices, Home and End select the ends, and Escape returns focus to
#' the mascot. Without items the mascot remains an image, with its status text.
#'
#' A choice sets `input$helper_menu` for `mascot(id = "helper")` to the item id.
#' Choosing the same item twice fires twice. In a module, use `ns("helper")` in
#' the UI and read `input$helper_menu` inside that module's server:
#' ```r
#' helper_ui <- function(id) {
#'   ns <- shiny::NS(id)
#'   mascot(id = ns("helper"), popup_menu = mascot_popup_menu(
#'     c(about = "About this app"), key_bindings = TRUE))
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
#' The menu prefers above the mascot, or below a top floating corner, over any
#' bubble. It fits the available screen space and can change direction or scroll.
#' Action controls hide while the menu is open. Its bubble countdown pauses. The restore
#' button only restores a minimised mascot; it does not open the menu.
#' On static pages the mascot stays an image. Run the Shiny example below to try
#' the menu.
#' @export
#' @examples
#' mascot_popup_menu(c(about = "About this app", help = "Help"), key_bindings = TRUE)
#' mascot_popup_menu()
#' mascot(id = "helper", popup_menu = c(about = "About this app"))
#' @examplesIf interactive()
#' shiny::shinyApp(
#'   shiny::fluidPage(mascot(id = "helper", popup_menu = mascot_popup_menu(
#'     c(about = "About this app"), key_bindings = TRUE))),
#'   function(input, output, session) {
#'     shiny::observeEvent(input$helper_menu, {
#'       shiny::showModal(shiny::modalDialog(paste("Selected", input$helper_menu)))
#'     })
#'   }
#' )
mascot_popup_menu <- function(items = NULL, key_bindings = FALSE) {
  checkmate::assert_character(items, min.chars = 1, any.missing = FALSE, min.len = 1, null.ok = TRUE)
  checkmate::assert_flag(key_bindings)
  value <- structure(list(items = items, key_bindings = key_bindings), class = "mascot_popup_menu")
  problem <- popup_menu_problem(value)
  if (!is.null(problem)) {
    cli::cli_abort("{problem}")
  }
  value
}

#' Validate a menu shortcut or helper without throwing
#' @noRd
popup_menu_problem <- function(x) {
  # Union inputs use check_* so invalid runtime values warn rather than throw.
  if (inherits(x, "mascot_popup_menu")) {
    if (
      !isTRUE(checkmate::check_list(x, names = "unique")) ||
        length(x) != 2L ||
        !setequal(names(x), c("items", "key_bindings"))
    ) {
      return("`popup_menu` must have items and key_bindings fields; use mascot_popup_menu().")
    }
    if (!isTRUE(checkmate::check_flag(x$key_bindings))) {
      return("`key_bindings` must be TRUE or FALSE; use mascot_popup_menu().")
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
  list(items = if (is.null(value$items)) NULL else as.list(value$items), key_bindings = value$key_bindings)
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
