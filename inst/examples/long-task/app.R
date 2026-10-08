# A short blocking delay demonstrates task states without extra dependencies.
# For real background work, supply ExtendedTask with an asynchronous function.
# Standalone app: attach the package as a user would.
library(mascot) # nolint: undesirable_function_linter.
# Share presentation while keeping the scenario code here.
# nolint start: undesirable_function_linter.
source(
  system.file("examples", "shared", "shell.R", package = "mascot"),
  local = TRUE
)
# nolint end

ui <- shiny::tagList(shiny::tags$div(
  class = "example-grid",
  shiny::tags$section(
    class = "example-panel",
    shiny::tags$h2("Run a sample review"),
    shiny::checkboxInput("fail", "Demonstrate an error", FALSE),
    shiny::actionButton("start", "Start review"),
    shiny::textOutput("result"),
    shiny::tags$p(
      class = "example-note",
      paste(
        "This short delay blocks the R process, including other sessions.",
        "It teaches state changes, not background computing."
      )
    )
  ),
  shiny::tags$section(
    class = "example-panel example-stage",
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
  # Older Shiny versions use the same explicit state changes after a flush.
  has_task <- "ExtendedTask" %in% getNamespaceExports("shiny")
  if (has_task) {
    task <- shiny::ExtendedTask$new(function(failed) {
      Sys.sleep(1.2)
      if (failed) {
        stop("The demonstration review failed.")
      }
      "Review complete"
    })
    shiny::observe({
      state <- task$status()
      if (state == "success") {
        finish(FALSE)
      }
      if (state == "error") finish(TRUE)
    })
  }
  shiny::observeEvent(input$start, {
    if (has_task && task$status() == "running") {
      return()
    }
    failed <- isTRUE(input$fail)
    result("Reviewing the sample...")
    updateMascot("helper", mood = "thinking", status = "Reviewing the sample", bubble = mascot_bubble())
    # Send the thinking state before starting the blocking demonstration step.
    session$onFlushed(
      function() {
        if (has_task) {
          task$invoke(failed)
        } else {
          # Base-R fallback; intentionally blocks and uses no timer package.
          Sys.sleep(1.2)
          finish(failed)
        }
      },
      once = TRUE
    )
  })
}

example_app("Show task progress", "Tell readers when work starts, finishes or needs attention.", ui, server)
