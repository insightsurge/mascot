# Updates that arrive from outside a reactive event: a later() callback and a promise chain.
ui <- shiny::fluidPage(
  shiny::actionButton("schedule", "Update from later()"),
  shiny::actionButton("promise", "Update from a promise"),
  mascot::mascot("helper", placement = "inline", status = "Waiting")
)
server <- function(input, output, session) {
  shiny::observeEvent(input$schedule, {
    n <- input$schedule
    # No reactive context when this runs, so the session is passed explicitly.
    later::later(
      function() {
        mascot::update_mascot("helper", mood = "happy", status = paste("From later", n), session = session)
      },
      delay = 0.5
    )
  })
  shiny::observeEvent(input$promise, {
    n <- input$promise
    waited <- promises::promise(function(resolve, reject) later::later(function() resolve(n), delay = 0.5))
    promises::then(waited, function(value) {
      mascot::update_mascot("helper", mood = "thinking", status = paste("From promise", value))
    })
  })
}
shiny::shinyApp(ui, server)
