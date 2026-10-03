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
  tessa <- system.file("characters", "tessa.json", package = "mascot")
  page <- file.path(dir, "page.html")
  writeLines(
    c(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>engine</title></head><body>",
      "<script type=\"application/json\" data-mascot-character=\"tessa\">",
      readLines(tessa, encoding = "UTF-8"),
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
  function(js) session$Runtime$evaluate(js)$result$value
}

# JavaScript that draws Tessa on a new canvas and returns the picture as a PNG data URL.
draw_js <- function(pose, frame = 0) {
  sprintf(
    paste(
      "(() => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "window.mascot.draw(c.getContext('2d'), window.mascot.readCharacter('tessa'), 150, 280, %s, %d);",
      "return c.toDataURL(); })()"
    ),
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

describe("the drawing engine (inst/www)", {
  it("loads once and offers mascot.draw() and mascot.readCharacter()", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_identical(js("typeof window.mascot.draw"), "function")
    expect_identical(js("window.mascot.readCharacter('tessa').id"), "tessa")
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

  it("draws each of Tessa's five moods differently", {
    skip_without_chrome()
    js <- local_engine_page()
    moods <- c("idle", "thinking", "happy", "worried", "celebrating")
    expect_identical(
      js("Object.keys(window.mascot.readCharacter('tessa').moods).join(',')"),
      paste(moods, collapse = ",")
    )
    pictures <- vapply(moods, function(m) js(draw_js(sprintf("{ mood: '%s' }", m))), character(1))
    expect_length(unique(pictures), 5)
  })

  it("draws a mood the same as the pose it stands for", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_identical(
      js(draw_js("{ mood: 'worried' }")),
      js(draw_js("{ eyes: 'worried', mouth: 'flat', brows: 'worried', sweat: 0.35, arms: 'idle' }"))
    )
  })

  it("names what is missing when a character, mood, accessory or page element is wrong", {
    skip_without_chrome()
    js <- local_engine_page()
    ctx <- "document.createElement('canvas').getContext('2d')"
    expect_match(js(error_js(sprintf("window.mascot.draw(%s, 'tessa', 0, 0)", ctx))), "needs a character description")
    expect_match(js(error_js(sprintf("window.mascot.draw(%s, ch, 0, 0, { mood: 'sleepy' })", ctx))), "no mood 'sleepy'")
    expect_match(
      js(error_js(sprintf("window.mascot.draw(%s, ch, 0, 0, { accessory: 'hat' })", ctx))),
      "no accessory 'hat'"
    )
    expect_match(js(error_js("window.mascot.readCharacter('nobody')")), "no description of the character 'nobody'")
  })

  it("draws SVG-style paths and refuses commands it does not support", {
    skip_without_chrome()
    js <- local_engine_page()
    ctx <- "document.createElement('canvas').getContext('2d')"
    expect_identical(js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 L10 0 10 10 Z')", ctx))), "no error")
    expect_match(
      js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 a5 5 0 0 1 10 0')", ctx))),
      "unsupported path command 'a'"
    )
    expect_match(js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 L10')", ctx))), "'L' needs 2 numbers")
  })
})
