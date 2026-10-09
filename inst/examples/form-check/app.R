# A plain observe() connects two form checks to the mascot. No validation package.
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
    shiny::tags$h2("Review a sample"),
    shiny::textInput("sample", "Sample label", ""),
    shiny::numericInput("quantity", "Quantity (1 to 100)", value = 0, min = 0, max = 100),
    shiny::textOutput("checks"),
    shiny::tags$p(class = "example-note", "The form text explains the problem; the mood reinforces it.")
  ),
  shiny::tags$section(
    class = "example-panel example-stage",
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

example_app("Check a form", "Keep the form's feedback and the mascot's status in step.", ui, server)
