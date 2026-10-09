# Shared app shell. Scenario files supply ordinary UI and server code.
# It accepts a tag list, so future examples can combine several features.
example_app <- function(title, description, content, server, theme = NULL) {
  checkmate::assert_string(title, min.chars = 1)
  checkmate::assert_string(description, min.chars = 1)
  checkmate::assert_class(content, "shiny.tag.list")
  checkmate::assert_function(server)
  checkmate::assert_list(theme, null.ok = TRUE)
  styles <- htmltools::htmlDependency(
    "mascot-examples",
    as.character(utils::packageVersion("mascot")),
    src = c(file = system.file("examples", "shared", package = "mascot")),
    stylesheet = "styles.css"
  )
  has_bslib <- requireNamespace("bslib", quietly = TRUE)
  page_content <- htmltools::attachDependencies(
    shiny::tags$main(
      class = "example-shell",
      shiny::tags$header(
        class = "example-header",
        shiny::tags$p(class = "example-eyebrow", "mascot / examples"),
        shiny::tags$h1(title),
        shiny::tags$p(class = "example-description", description),
        if (has_bslib) bslib::input_dark_mode(id = "dark_mode", mode = "light")
      ),
      content,
      shiny::tags$footer(
        "Only this example is loaded. Run mascot_examples() to find the others."
      )
    ),
    styles
  )
  page <- if (has_bslib) {
    if (is.null(theme)) {
      theme <- bslib::bs_theme(version = 5)
    }
    bslib::page_fluid(page_content, theme = theme, title = title, lang = "en")
  } else {
    shiny::fluidPage(page_content, title = title, lang = "en")
  }
  shiny::shinyApp(page, server)
}
