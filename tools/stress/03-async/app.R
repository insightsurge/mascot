ui <- shiny::fluidPage(
  shiny::actionButton("start", "Start task"),
  shiny::actionButton("finish", "Complete task"),
  shiny::actionButton("replace", "Re-render"),
  shiny::actionButton("first", "First observer"),
  shiny::actionButton("second", "Second observer"),
  shiny::actionButton("third", "Final observer"),
  shiny::textOutput("task_status"),
  shiny::uiOutput("slot")
)
server <- function(input, output, session) {
  completion <- new.env(parent = emptyenv())
  task <- shiny::ExtendedTask$new(function() {
    promises::promise(function(resolve, reject) {
      # The runner releases completion after exercising the in-flight observers.
      completion$resolve <- resolve
    })
  })
  shiny::observeEvent(input$finish, {
    if (!is.null(completion$resolve)) {
      resolve <- completion$resolve
      completion$resolve <- NULL
      later::later(function() resolve("Complete"), delay = 0.2)
    }
  })
  output$slot <- shiny::renderUI({
    input$replace
    mascot::mascot("helper", placement = "inline", motion = FALSE)
  })
  output$task_status <- shiny::renderText(task$status())
  shiny::observeEvent(input$start, {
    mascot::update_mascot("helper", mood = "thinking", status = "Running")
    task$invoke()
  })
  shiny::observe({
    if (task$status() == "success") mascot::update_mascot("helper", mood = "happy", status = "Complete")
  })
  shiny::observeEvent(input$first, mascot::update_mascot("helper", mood = "worried", status = "First"))
  shiny::observeEvent(input$second, mascot::update_mascot("helper", mood = "thinking", status = "Second"))
  shiny::observeEvent(input$third, mascot::update_mascot("helper", mood = "happy", status = "Final"))
}
shiny::shinyApp(ui, server)
