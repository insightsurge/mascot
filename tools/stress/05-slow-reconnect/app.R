# Motion stays on (the default) so bursts and swaps arrive while the mascot animates.
ui <- shiny::fluidPage(
  shiny::actionButton("slow", "Slow update"),
  shiny::actionButton("burst", "200 updates"),
  shiny::numericInput("rapid", "Rapid value", 0),
  shiny::textOutput("handled"),
  mascot::mascot("helper", placement = "inline", status = "Ready")
)
server <- function(input, output, session) {
  # "force" lets a local runApp() resume the same session after the socket closes (testing only).
  session$allowReconnect("force")
  handled <- shiny::reactiveVal(0)
  output$handled <- shiny::renderText(handled())
  shiny::observeEvent(input$slow, {
    Sys.sleep(2.5)
    handled(input$slow)
    mascot::update_mascot("helper", mood = "happy", status = paste("Slow", input$slow))
  })
  shiny::observeEvent(input$burst, {
    characters <- c("tessa", "knurl", "sela", "neer")
    for (i in seq_len(200)) {
      if (i %% 50 == 0) {
        # Every 50th call also swaps the character, opens a bubble and nods.
        mascot::update_mascot(
          "helper",
          character = characters[[i / 50]],
          mood = "happy",
          status = paste("Burst", i),
          bubble = mascot::mascot_bubble(paste("Bubble", i), duration = Inf),
          gesture = "nod"
        )
      } else {
        mascot::update_mascot("helper", mood = if (i %% 2) "worried" else "happy", status = paste("Burst", i))
      }
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
