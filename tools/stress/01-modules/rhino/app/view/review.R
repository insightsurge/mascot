review_ui <- function(id) {
  checkmate::assert_string(id)
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::actionButton(ns("change"), "Change this mascot"),
    mascot::mascot(ns("helper"), placement = "inline", motion = FALSE, status = id)
  )
}
review_server <- function(id) {
  checkmate::assert_string(id)
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$change, {
      mascot::update_mascot(
        "helper",
        mood = if (input$change %% 2) "happy" else "worried",
        status = paste(session$ns("helper"), input$change)
      )
    })
  })
}
section_ui <- function(id) {
  checkmate::assert_string(id)
  review_ui(shiny::NS(id)("review"))
}
section_server <- function(id) {
  checkmate::assert_string(id)
  shiny::moduleServer(id, function(input, output, session) review_server("review"))
}
