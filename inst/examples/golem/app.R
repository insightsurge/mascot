# Run this whole folder with mascot_example("golem").
if (!requireNamespace("golem", quietly = TRUE)) {
  stop("This example needs golem. Install it before running the app.")
}
for (file in c("mod-review.R", "app_ui.R", "app_server.R")) {
  sys.source(file.path("R", file), envir = environment())
}
golem::with_golem_options(
  app = shiny::shinyApp(ui = app_ui, server = app_server),
  golem_opts = list(title = "Reviews in golem", complete = "Review complete")
)
