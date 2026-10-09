library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

ui <- shiny::tagList(bslib::layout_columns(
  bslib::card(
    shiny::tags$h2("Run a sample review"),
    shiny::checkboxInput("fail", "Demonstrate an error", FALSE),
    shiny::actionButton("start", "Start review"),
    shiny::textOutput("result"),
    shiny::tags$p(
      paste(
        "This short delay blocks the R process, including other sessions.",
        "It teaches state changes, not background computing."
      )
    )
  ),
  bslib::card(
    shiny::tags$h2("Task status"),
    mascot(id = "helper", status = "Ready to review")
  )
))

server <- function(input, output, session) {
  result <- shiny::reactiveVal("No review has run yet.")
  output$result <- shiny::renderText(result())
  finish <- function(failed) {
    if (failed) {
      result("The review could not finish. Check the source data and try again.")
      updateMascot(
        "helper",
        mood = "worried",
        status = "Review needs attention",
        bubble = mascot_bubble("Check the source data and try again.", duration = Inf)
      )
    } else {
      result("Review complete: all rows checked.")
      updateMascot("helper", mood = "happy", status = "Review complete", bubble = mascot_bubble())
    }
  }
  shiny::observeEvent(input$start, {
    failed <- isTRUE(input$fail)
    result("Reviewing the sample...")
    updateMascot("helper", mood = "thinking", status = "Reviewing the sample", bubble = mascot_bubble())
    # Send the thinking state before starting the blocking demonstration step.
    session$onFlushed(
      function() {
        Sys.sleep(1.2) # Demonstration only: blocks the R process.
        finish(failed)
      },
      once = TRUE
    )
  })
}

shiny::shinyApp(bslib::page_fluid(ui), server)
