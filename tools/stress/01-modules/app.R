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
app_ui <- function(request) {
  checkmate::assert_multi_class(request, c("list", "environment"))
  panels <- lapply(seq_len(8), function(i) {
    shiny::tabPanel(paste("Tab", i), value = as.character(i), section_ui(paste0("m", i)))
  })
  do.call(shiny::tabsetPanel, c(list(id = "tabs"), panels))
}
app_server <- function(input, output, session) {
  for (i in seq_len(8)) {
    section_server(paste0("m", i))
  }
}
shiny::shinyApp(app_ui, app_server)
