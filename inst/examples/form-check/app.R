library(shiny)
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("This example needs bslib. Install it before running the app.")
}
library(bslib)
library(mascot)

ui <- page_fluid(
  title = "Check a form",
  input_dark_mode(id = "dark_mode", mode = "light"),
  h1("Check a form"),
  p("A worried helper names the fields that need attention and becomes happy when both pass."),
  layout_columns(
    card(
      h2("Review a sample"),
      textInput("sample", "Sample label", ""),
      numericInput("quantity", "Quantity (1 to 100)", value = 0, min = 0, max = 100),
      textOutput("checks"),
      p("The form text explains the problem; the mood reinforces it.")
    ),
    card(
      h2("Form status"),
      mascot(id = "helper", mood = "worried", status = "2 fields need attention", placement = "inline")
    )
  )
)

server <- function(input, output, session) {
  problems <- reactive({
    c(
      if (!nzchar(trimws(input$sample))) "Enter a sample label.",
      if (is.null(input$quantity) || is.na(input$quantity) || input$quantity < 1 || input$quantity > 100) {
        "Enter a quantity from 1 to 100."
      }
    )
  })
  output$checks <- renderText({
    if (length(problems())) paste(problems(), collapse = " ") else "Both fields pass."
  })
  observe({
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

shinyApp(ui, server)
