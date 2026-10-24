describe("the test file layout", {
  plant <- function(dir, file, lines) writeLines(lines, file.path(dir, file))

  it("keeps every browser and snapshot test in a -browser.R or -snap.R file, and only those tests", {
    expect_identical(layout_problems(test_path()), character())
  })

  it("finds a Chrome helper outside a -browser.R file, also through a helper of the file's own", {
    # Given a helper file that starts Chrome, and plain and snapshot files that reach it
    dir <- withr::local_tempdir()
    plant(
      dir,
      "helper-page.R",
      c(
        "open_page <- function() skip_without_chrome()",
        "skip_without_chrome <- function() {",
        "  testthat::skip_on_cran()",
        "}"
      )
    )
    plant(dir, "test-thing.R", c("drive <- function() open_page()", "describe('a', { it('b', { drive() }) })"))
    plant(dir, "test-thing-snap.R", "describe('a', { it('c', { open_page(); expect_snapshot(1) }) })")
    # When the layout is checked
    problems <- layout_problems(dir)
    # Then both files are named, with the call that starts Chrome
    expect_length(problems, 2L)
    expect_match(problems[[1]], "test-thing-snap.R starts Chrome", fixed = TRUE)
    expect_match(problems[[2]], "test-thing.R starts Chrome or skips on CRAN (`open_page` and `drive`)", fixed = TRUE)
  })

  it("finds a direct shinytest2 or chromote call, and a snapshot, outside the files for them", {
    dir <- withr::local_tempdir()
    plant(dir, "test-app.R", "it('a', { app <- shinytest2::AppDriver$new(); expect_snapshot(app) })")
    problems <- layout_problems(dir)
    expect_length(problems, 2L)
    expect_match(problems[[1]], "shinytest2::", fixed = TRUE)
    expect_match(problems[[2]], "test-app.R has snapshot tests (`expect_snapshot`)", fixed = TRUE)
  })

  it("finds a test that runs on CRAN inside a -browser.R or -snap.R file", {
    dir <- withr::local_tempdir()
    plant(
      dir,
      "test-app-browser.R",
      c(
        "describe('app', {",
        "  it('opens', { chromote::ChromoteSession$new() })",
        "  for (n in 1:2) it(paste('adds', n), { expect_equal(n + 0, n) })",
        "})"
      )
    )
    plant(dir, "test-app-snap.R", "it('prints', { expect_true(TRUE) })")
    problems <- layout_problems(dir)
    expect_identical(
      problems,
      c(
        "test-app-browser.R: \"paste(\\\"adds\\\", n)\" runs on CRAN too, so it belongs in the plain test file.",
        "test-app-snap.R: \"prints\" runs on CRAN too, so it belongs in the plain test file."
      )
    )
  })

  it("rejects a folder that does not exist", {
    expect_error(layout_problems(file.path(withr::local_tempdir(), "missing")), "Directory")
    expect_error(layout_browser_names(list(1)), "names")
  })
})
