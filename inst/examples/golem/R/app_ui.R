app_ui <- function(request) {
  shiny::fluidPage(
    shiny::h1(golem::get_golem_options("title")),
    shiny::p("Function-built UI and nested modules, using golem runtime options."),
    section_ui("first"),
    section_ui("second")
  )
}
