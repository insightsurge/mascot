review_ui <- function(id) {
  ns <- shiny::NS(id)
  htmltools::tagList(
    shiny::actionButton(ns("complete"), "Complete review"),
    mascot::mascot(
      ns("helper"),
      status = "Review needed",
      placement = "inline",
      click = mascot::mascot_popup_menu(c(about = "About this review"))
    ),
    shiny::textOutput(ns("choice"))
  )
}

review_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$complete, {
      mascot::update_mascot(session$ns("helper"), mood = "happy", status = golem::get_golem_options("complete"))
    })
    output$choice <- shiny::renderText(input$helper_menu)
  })
}

# An outer module owns the inner review module.
section_ui <- function(id) review_ui(shiny::NS(id)("review"))
section_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    review_server("review")
  })
}
