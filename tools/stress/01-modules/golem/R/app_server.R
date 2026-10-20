app_server <- function(input, output, session) {
  for (i in seq_len(8)) {
    # Sourced module functions live in the app environment, outside this file.
    section_server(paste0("m", i)) # nolint: object_usage_linter.
  }
}
