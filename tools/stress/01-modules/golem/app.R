for (file in c("mod-review.R", "app_ui.R", "app_server.R")) {
  sys.source(file.path("R", file), envir = environment())
}
golem::with_golem_options(
  shiny::shinyApp(app_ui, app_server),
  golem_opts = list(title = "Module stress")
)
