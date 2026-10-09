library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

# Stands in for a slow model: a promise that later::later() resolves after two seconds, without blocking R.
# For real work, return a mirai instead, e.g. mirai::mirai(fit_model(data), data = data).
slow_review <- function(fail) {
  promises::promise(function(resolve, reject) {
    later::later(
      function() {
        if (fail) {
          reject(simpleError("3 rows have no sample id."))
        } else {
          resolve("Review complete: all 120 rows checked.")
        }
      },
      delay = 2
    )
  })
}

ui <- page_fluid(
  title = "Show task progress",
  input_dark_mode(id = "dark_mode", mode = "light"),
  h1("Show task progress"),
  p("Tessa thinks while a slow step runs, then shows how it went. The rest of the app stays responsive."),
  layout_columns(
    card(
      h2("Run a sample review"),
      checkboxInput("fail", "Demonstrate an error", FALSE),
      input_task_button("start", "Start review"),
      textOutput("result")
    ),
    card(
      h2("Task status"),
      mascot(id = "helper", status = "Ready to review")
    )
  )
)

server <- function(input, output, session) {
  review <- ExtendedTask$new(slow_review) |> bind_task_button("start")

  observeEvent(input$start, {
    updateMascot("helper", mood = "thinking", status = "Reviewing the sample", bubble = mascot_bubble())
    review$invoke(isTRUE(input$fail))
  })

  # React to the task's result: happy when it succeeds, worried with a lasting message when it fails.
  observe({
    status <- review$status()
    if (status == "success") {
      updateMascot("helper", mood = "happy", status = "Review complete")
    }
    if (status == "error") {
      updateMascot(
        "helper",
        mood = "worried",
        status = "Review needs attention",
        bubble = mascot_bubble("Check the source data and try again.", duration = Inf)
      )
    }
  })

  output$result <- renderText({
    switch(
      review$status(),
      initial = "No review has run yet.",
      running = "Reviewing the sample...",
      success = review$result(),
      error = "The review could not finish. Check the source data and try again."
    )
  })
}

shinyApp(ui, server)
