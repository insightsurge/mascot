ui <- shiny::fluidPage(
  shiny::actionButton("replace", "Re-render"),
  shiny::actionButton("remove", "Remove"),
  shiny::actionButton("insert", "Insert"),
  shiny::actionButton("duplicate", "Duplicate"),
  shiny::actionButton("change", "Update"),
  shiny::uiOutput("slot"),
  shiny::div(id = "extra"),
  mascot::mascot("other", placement = "inline", motion = FALSE, status = "Untouched")
)
server <- function(input, output, session) {
  output$slot <- shiny::renderUI({
    input$replace
    mascot::mascot("same", placement = "inline", motion = FALSE, status = "Baseline")
  })
  shiny::observeEvent(input$remove, shiny::removeUI("[id='same']", multiple = TRUE, immediate = TRUE))
  shiny::observeEvent(input$insert, {
    shiny::insertUI("#extra", ui = mascot::mascot("same", placement = "inline", motion = FALSE))
  })
  shiny::observeEvent(input$duplicate, {
    shiny::insertUI("#extra", ui = mascot::mascot("same", placement = "inline", motion = FALSE))
  })
  shiny::observeEvent(input$change, {
    mascot::update_mascot("same", mood = "happy", status = paste("Update", input$change))
  })
}
shiny::shinyApp(ui, server)
