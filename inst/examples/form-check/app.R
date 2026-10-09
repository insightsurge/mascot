library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

ui <- shiny::tagList(bslib::layout_columns(
  bslib::card(
    shiny::tags$h2("Review a sample"),
    shiny::textInput("sample", "Sample label", ""),
    shiny::numericInput("quantity", "Quantity (1 to 100)", value = 0, min = 0, max = 100),
    shiny::textOutput("checks"),
    shiny::tags$p("The form text explains the problem; the mood reinforces it.")
  ),
  bslib::card(
    shiny::tags$h2("Form status"),
    mascot(id = "helper", mood = "worried", status = "2 fields need attention")
  )
))

server <- function(input, output, session) {
  problems <- shiny::reactive({
    c(
      if (!nzchar(trimws(input$sample))) "Enter a sample label.",
      if (is.null(input$quantity) || is.na(input$quantity) || input$quantity < 1 || input$quantity > 100) {
        "Enter a quantity from 1 to 100."
      }
    )
  })
  output$checks <- shiny::renderText({
    if (length(problems())) paste(problems(), collapse = " ") else "Both fields pass."
  })
  shiny::observe({
    count <- length(problems())
    updateMascot(
      "helper",
      mood = if (count) "worried" else "happy",
      status = if (count) {
        paste(count, if (count == 1) "field needs attention" else "fields need attention")
      } else {
        "Both fields pass"
      }
    )
  })
}

shiny::shinyApp(bslib::page_fluid(ui), server)
