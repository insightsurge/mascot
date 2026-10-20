app_ui <- function(request) {
  checkmate::assert_multi_class(request, c("list", "environment"))
  panels <- lapply(seq_len(8), function(i) {
    # Sourced module functions live in the app environment, outside this file.
    shiny::tabPanel(paste("Tab", i), value = as.character(i), section_ui(paste0("m", i))) # nolint: object_usage_linter.
  })
  do.call(shiny::tabsetPanel, c(list(id = "tabs"), panels))
}
