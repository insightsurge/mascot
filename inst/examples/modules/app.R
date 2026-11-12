library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

review_ui <- function(id, title) {
  ns <- NS(id)
  card(
    h2(title),
    checkboxInput(ns("ready"), "Review complete", FALSE),
    mascot(ns("helper"), mood = "worried", status = "Review still needed", placement = "inline")
  )
}

review_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ready <- reactive(isTRUE(input$ready))
    # Use the local id here: Shiny adds the namespace once.
    watch_mascot(
      "helper",
      ready,
      list(
        "TRUE" = list(mood = "happy", status = "Review complete"),
        "FALSE" = list(mood = "worried", status = "Review still needed")
      )
    )
    ready # The child returns data; it does not reach into its parent's mascot.
  })
}

ui <- page_fluid(
  title = "Work in modules",
  input_dark_mode(id = "dark_mode", mode = "light"),
  h1("Work in modules"),
  p("Each module owns its helper; the parent combines what the modules return."),
  layout_columns(review_ui("first", "First review"), review_ui("second", "Second review")),
  p("The corner helper becomes happy only when both modules finish."),
  mascot(
    id = "parent",
    mood = "worried",
    status = "Waiting for both reviews",
    placement = mascot_placement("bottom-right", minimise = TRUE)
  )
)

server <- function(input, output, session) {
  first <- review_server("first")
  second <- review_server("second")
  both_complete <- reactive(first() && second())
  watch_mascot(
    "parent",
    both_complete,
    list(
      "TRUE" = list(mood = "happy", status = "Both reviews complete"),
      "FALSE" = list(mood = "worried", status = "Waiting for both reviews")
    )
  )
}

shinyApp(ui, server)
