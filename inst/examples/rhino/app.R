# This mirrors rhino's app/view structure without importing rhino or box.
main <- new.env(parent = environment())
sys.source(file.path("app", "view", "main.R"), envir = main)
shiny::shinyApp(
  ui = function(request) {
    shiny::fluidPage(
      shiny::h1("A rhino-shaped app"),
      shiny::p("Plain Shiny: separate view modules, each with a nested review."),
      main$ui("first"),
      main$ui("second")
    )
  },
  server = function(input, output, session) {
    main$server("first")
    main$server("second")
  }
)
