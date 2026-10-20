ui <- shiny::fluidPage(
  shiny::actionButton("slow", "Slow update"),
  shiny::actionButton("burst", "200 updates"),
  shiny::numericInput("rapid", "Rapid value", 0),
  shiny::textOutput("handled"),
  mascot::mascot("helper", placement = "inline", motion = FALSE, status = "Ready")
)
server <- function(input, output, session) {
  session$allowReconnect(TRUE)
  handled <- shiny::reactiveVal(0)
  output$handled <- shiny::renderText(handled())
  shiny::observeEvent(input$slow, {
    Sys.sleep(2.5)
    handled(input$slow)
    mascot::update_mascot("helper", mood = "happy", status = paste("Slow", input$slow))
  })
  shiny::observeEvent(input$burst, {
    for (i in seq_len(200)) {
      mascot::update_mascot("helper", mood = if (i %% 2) "worried" else "happy", status = paste("Burst", i))
    }
  })
  shiny::observeEvent(
    input$rapid,
    {
      mascot::update_mascot("helper", mood = "thinking", status = paste("Rapid", input$rapid))
    },
    ignoreInit = TRUE
  )
}
shiny::shinyApp(ui, server)
