# Numeric tests use the packaged modules in a real browser, without the host.
local_character_engine <- function(env = parent.frame()) {
  checkmate::assert_environment(env)
  skip_without_chrome()
  dir <- withr::local_tempdir(.local_envir = env)
  scripts <- file.path(
    system.file("www", package = "mascot", mustWork = TRUE),
    c("mascot-parts.js", "mascot-geometry.js")
  )
  page <- file.path(dir, "parts.html")
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>parts</title></head><body>',
      sprintf('<script src="file://%s"></script>', normalizePath(scripts, winslash = "/")),
      '</body></html>'
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) {
    checkmate::assert_string(js)
    result <- session$Runtime$evaluate(js, returnByValue = TRUE)
    if (!is.null(result$exceptionDetails)) {
      cli::cli_abort("Browser numeric test failed: {result$exceptionDetails$text}")
    }
    result$result$value
  }
}
