# A separate environment stands in for a box module's exported ui and server.
review <- new.env(parent = environment())
sys.source(file.path("app", "view", "review.R"), envir = review)
ui <- function(id) review$review_ui(shiny::NS(id)("review"))
server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    review$review_server("review")
  })
}
