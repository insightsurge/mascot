# Select actual matches, rather than allTags(), which returns the query's roots.
preview_nodes <- function(page, selector) {
  unname(htmltools::tagQuery(page)$find(selector)$selectedTags())
}

preview_theme <- function(tag) {
  script <- Filter(function(x) !is.null(x$attribs[["data-mascot-theme"]]), preview_nodes(tag, "script"))[[1]]
  jsonlite::fromJSON(as.character(script$children[[1]]), simplifyVector = FALSE)
}
