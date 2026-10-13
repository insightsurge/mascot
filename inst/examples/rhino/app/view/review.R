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
      mascot::update_mascot("helper", mood = "happy", status = "Review complete")
    })
    output$choice <- shiny::renderText(input$helper_menu)
  })
}
