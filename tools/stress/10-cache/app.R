# A mascot inside a renderUI() cached with bindCache(): the first session builds it,
# every later session gets the cached HTML.
ui <- shiny::fluidPage(
  shiny::actionButton("change", "Update the mascot"),
  shiny::uiOutput("cached_ui")
)
server <- function(input, output, session) {
  output$cached_ui <- shiny::renderUI({
    mascot::mascot("cached", placement = "inline", motion = FALSE, status = "Cached")
  }) |>
    shiny::bindCache("same-key")
  shiny::observeEvent(input$change, {
    mascot::update_mascot("cached", mood = "happy", status = paste("Updated", input$change))
  })
}
shiny::shinyApp(ui, server)
