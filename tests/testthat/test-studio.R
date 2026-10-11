describe("mascot_studio()", {
  it("validates each argument and requires later arguments to be named", {
    for (bad in list(NULL, NA_character_, 42, "unknown", "preview", c("studio", "examples"))) {
      expect_error(mascot_studio(view = bad, run = FALSE), "Assertion on 'view' failed")
    }
    expect_error(mascot_studio("studio", "mascot_theme", run = FALSE), "Assertion on 'list")
    for (bad in list(NA_character_, "", 42, c("mascot", "updateMascot"), "unknown")) {
      expect_error(mascot_studio(fn = bad, run = FALSE), "Assertion on 'fn' failed")
    }
    for (bad in list(NULL, NA_character_, "", 42, "unknown", c("a", "b"))) {
      expect_error(mascot_studio(character = bad, run = FALSE), "Assertion on 'character' failed")
    }
    for (bad in list(NULL, NA, 42, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_studio(run = bad), "Assertion on 'run' failed")
    }
    expect_error(mascot_studio(), "needs an interactive R session")
  })
  it("returns independent apps with the requested first view and function", {
    skip_if_not_installed("bslib")
    before <- options()
    studio <- mascot_studio(fn = "mascot_theme", run = FALSE)
    expect_s3_class(studio, "shiny.appobj")
    page <- function(app, query = "") {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    }
    expect_match(page(studio), 'data-initial-function="mascot_theme"', fixed = TRUE)
    # mascot_preview() is an entry of the studio, not a view of its own.
    expect_match(page(studio), 'data-value="mascot_preview"', fixed = TRUE)
    expect_match(page(studio), 'id="preview_build"', fixed = TRUE)
    expect_match(page(studio), 'id="preview_card"', fixed = TRUE)
    expect_match(page(studio), 'data-full-screen="false"', fixed = TRUE)
    expect_match(page(studio), 'id="studio_example_call"', fixed = TRUE)
    expect_match(page(studio), 'data-copy="studio_example_call"', fixed = TRUE)
    expect_false(grepl('id="studio_view"', page(studio), fixed = TRUE))
    expect_false(grepl('id="studio_fn"', page(studio), fixed = TRUE))
    expect_false(grepl('id="studio_run"', page(studio), fixed = TRUE))
    expect_false(grepl("view=preview", page(studio), fixed = TRUE))
    examples <- mascot_studio("examples", run = FALSE)
    expect_match(page(examples), 'id="example_name"', fixed = TRUE)
    expect_match(page(examples), 'href="?view=studio"', fixed = TRUE)
    expect_false(grepl('id="helper"', page(examples), fixed = TRUE))
    expect_match(page(examples, "view=studio"), 'id="helper"', fixed = TRUE)
    expect_false(grepl('id="example_name"', page(examples, "view=studio"), fixed = TRUE))
    expect_identical(options(), before)
  })
  it("passes its app to Shiny when launched interactively", {
    local_mocked_bindings(example_interactive = function() TRUE)
    local_mocked_bindings(runApp = function(appDir) inherits(appDir, "shiny.appobj"), .package = "shiny")
    expect_true(mascot_studio())
  })
  it("opens the chosen view and function in Chrome", {
    skip_on_cran()
    skip_if_not_installed("shinytest2")
    skip_if_not_installed("chromote")
    skip_if_not_installed("bslib")
    skip_if(is.null(chromote::find_chrome()), "Chrome is unavailable")
    withr::local_envvar(TMPDIR = withr::local_tempdir())
    app <- shinytest2::AppDriver$new(
      function() {
        library(mascot)
        mascot_studio(fn = "mascot_theme", run = FALSE)
      },
      width = 1440,
      height = 900
    )
    withr::defer(app$stop())
    app$wait_for_js(
      "document.querySelector('.pg-index-link[data-value=mascot_theme]').getAttribute('aria-current') === 'true'"
    )
    expect_false(app$get_js("document.querySelector('[data-function=mascot_theme]').hidden"))
    expect_identical(app$get_value(input = "character"), formals(mascot)$character)
    # Starting on mascot_preview() shows its page on the canvas in place of the live mascot.
    preview <- shinytest2::AppDriver$new(
      function() {
        library(mascot)
        mascot_studio(fn = "mascot_preview", run = FALSE)
      },
      width = 1440,
      height = 900
    )
    withr::defer(preview$stop())
    preview$wait_for_js("!!document.querySelector('iframe.pg-preview')", timeout = 15000)
    expect_true(preview$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_false(preview$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    expect_true(preview$get_js("document.querySelector('#preview_card .bslib-full-screen-enter') !== null"))
    examples <- shinytest2::AppDriver$new(function() {
      library(mascot)
      mascot_studio("examples", run = FALSE)
    })
    withr::defer(examples$stop())
    examples$wait_for_js("!!document.getElementById('example_name')")
    examples$click(selector = 'a[href="?view=studio"]')
    examples$wait_for_js("!!document.getElementById('helper') && !!document.getElementById('studio_inspector')")
    expect_identical(examples$get_js("new URLSearchParams(location.search).get('view')"), "studio")
    expect_identical(examples$get_js("document.querySelectorAll('#example_name').length"), 0L)
  })
})
