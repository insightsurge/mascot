# The module owns its local helper; the parent owns the floating helper.
# Standalone app: attach the package as a user would.
library(mascot) # nolint: undesirable_function_linter.
# Share presentation while keeping the scenario code here.
# nolint start: undesirable_function_linter.
source(
  system.file("examples", "shared", "shell.R", package = "mascot"),
  local = TRUE
)
# nolint end

review_ui <- function(id, title) {
  ns <- shiny::NS(id)
  shiny::tags$section(
    class = "example-panel",
    shiny::tags$h2(title),
    shiny::checkboxInput(ns("ready"), "Review complete", FALSE),
    mascot(id = ns("helper"), mood = "worried", status = "Review still needed")
  )
}

review_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    ready <- shiny::reactive(isTRUE(input$ready))
    shiny::observe({
      # Use the local id here: Shiny adds the namespace once.
      updateMascot(
        "helper",
        mood = if (ready()) "happy" else "worried",
        status = if (ready()) "Review complete" else "Review still needed"
      )
    })
    ready # The child returns data; it does not reach into its parent's mascot.
  })
}

ui <- shiny::tagList(
  shiny::tags$div(class = "example-grid", review_ui("first", "First review"), review_ui("second", "Second review")),
  shiny::tags$p(class = "example-note", "The corner helper becomes happy only when both modules finish."),
  mascot(
    id = "parent",
    mood = "worried",
    status = "Waiting for both reviews",
    placement = mascot_placement(floating = TRUE, minimise = TRUE)
  )
)

server <- function(input, output, session) {
  first <- review_server("first")
  second <- review_server("second")
  shiny::observe({
    complete <- first() && second()
    updateMascot(
      "parent",
      mood = if (complete) "happy" else "worried",
      status = if (complete) "Both reviews complete" else "Waiting for both reviews"
    )
  })
}

example_app("Work in modules", "Keep each helper with its owner and return news to the parent.", ui, server)
