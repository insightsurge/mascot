# The drawing engine in inst/www/ has no R file of its own: these tests draw with it in headless Chrome.

skip_without_chrome <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
}

# Opens a blank page with the engine's files loaded and returns a function that evaluates JavaScript there.
local_engine_page <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  scripts <- file.path(www, c("mascot.js", "mascot-draw.js", "mascot-motion.js"))
  tessa <- system.file("characters", "tessa.json", package = "mascot")
  blob <- testthat::test_path("fixtures", "characters", "blob.json")
  page <- file.path(dir, "page.html")
  writeLines(
    c(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>engine</title></head><body>",
      "<script type=\"application/json\" data-mascot-character=\"tessa\">",
      readLines(tessa, encoding = "UTF-8"),
      "</script>",
      "<script type=\"application/json\" data-mascot-character=\"blob\">",
      readLines(blob, encoding = "UTF-8"),
      "</script>",
      sprintf("<script src=\"file://%s\"></script>", normalizePath(scripts, winslash = "/")),
      "</body></html>"
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) session$Runtime$evaluate(js, returnByValue = TRUE)$result$value
}

# Draws a character from the page on a new canvas and returns the picture as a PNG data URL.
draw_js <- function(pose, frame = 0, character = "tessa") {
  sprintf(
    paste(
      "(() => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "window.mascot.draw(c.getContext('2d'), window.mascot.readCharacter('%s'), { x: 150, baseY: 280, pose: %s, frame: %d });",
      "return c.toDataURL(); })()"
    ),
    character,
    pose,
    frame
  )
}

# Runs `code` in the page and returns the message of the error it throws (or "no error").
error_js <- function(code) {
  sprintf(
    "(() => { const ch = window.mascot.readCharacter('tessa'); try { %s; } catch (e) { return e.message; } return 'no error'; })()",
    code
  )
}

# Host integration page: real packaged assets and real markup, with motion reduced before navigation.
local_host_page <- function(env = parent.frame(), bubble = NULL, reduced = TRUE, scheme = "light") {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  scripts <- file.path(www, c("mascot.js", "mascot-draw.js", "mascot-motion.js", "mascot-host.js"))
  page <- file.path(dir, "host.html")
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>host</title>',
      sprintf('<link rel="stylesheet" href="file://%s">', normalizePath(file.path(www, "mascot.css"))),
      '</head><body>',
      as.character(mascot(id = "a", bubble = bubble)),
      '<script type="application/json" data-mascot-character="blob">',
      readLines(testthat::test_path("fixtures", "characters", "blob.json"), encoding = "UTF-8"),
      '</script>',
      sprintf('<script src="file://%s"></script>', normalizePath(scripts)),
      '</body></html>'
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  session$Emulation$setEmulatedMedia(
    features = list(
      list(name = "prefers-reduced-motion", value = if (reduced) "reduce" else "no-preference"),
      list(name = "prefers-color-scheme", value = scheme)
    )
  )
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page)), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) {
    result <- session$Runtime$evaluate(js, returnByValue = TRUE)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description)
    }
    result$result$value
  }
}

# Start shinytest2 with its temporary browser files inside R's temporary directory.
local_shiny_browser <- function(env = parent.frame()) {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("shinytest2")
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
  tmp <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(c(TMPDIR = tmp), .local_envir = env)
}
