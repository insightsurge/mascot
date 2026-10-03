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
  scripts <- file.path(www, c("mascot.js", "mascot-draw.js"))
  page <- file.path(dir, "page.html")
  writeLines(
    c(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>engine</title></head><body>",
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
  function(js) session$Runtime$evaluate(js)$result$value
}

# JavaScript that draws Tessa on a new canvas and returns the picture as a PNG data URL.
draw_js <- function(pose, frame = 0) {
  sprintf(
    paste(
      "(() => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "window.mascot.draw(c.getContext('2d'), 'tessa', 150, 280, %s, %d); return c.toDataURL(); })()"
    ),
    pose,
    frame
  )
}

describe("the drawing engine (inst/www)", {
  it("loads once and offers mascot.draw()", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_identical(js("typeof window.mascot.draw"), "function")
    expect_identical(js("Object.keys(window.mascot.drawing.characters).join(',')"), "tessa")
  })

  it("draws the same pixels for the same pose and frame", {
    skip_without_chrome()
    js <- local_engine_page()
    pose <- "{ eyes: 'happy', mouth: 'grin', arms: 'up', sparkle: true }"
    first <- js(draw_js(pose, frame = 7))
    expect_true(startsWith(first, "data:image/png"))
    expect_identical(js(draw_js(pose, frame = 7)), first)
  })

  it("draws different pixels for a different pose or frame", {
    skip_without_chrome()
    js <- local_engine_page()
    pose <- "{ sparkle: true }"
    expect_false(identical(js(draw_js(pose)), js(draw_js("{ eyes: 'happy' }"))))
    expect_false(identical(js(draw_js(pose, frame = 0)), js(draw_js(pose, frame = 7))))
  })

  it("refuses an unknown character by name", {
    skip_without_chrome()
    js <- local_engine_page()
    message <- js(paste(
      "(() => { try { window.mascot.draw(document.createElement('canvas').getContext('2d'), 'nobody', 0, 0); }",
      "catch (e) { return e.message; } })()"
    ))
    expect_match(message, "unknown character 'nobody'", fixed = TRUE)
  })
})
