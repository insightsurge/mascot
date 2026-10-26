describe("the test file layout", {
  plant <- function(dir, file, lines) writeLines(lines, file.path(dir, file))

  it("keeps every browser, snapshot and extended test in a -browser.R, -snap.R or -extended.R file", {
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
        "  chromote::find_chrome()",
        "}"
      )
    )
    plant(dir, "test-thing.R", c("drive <- function() open_page()", "describe('a', { it('b', { drive() }) })"))
    plant(
      dir,
      "test-thing-snap.R",
      "describe('a', { it('c', { open_page(); expect_snapshot(1) }) })"
    )
    # When the layout is checked
    problems <- layout_problems(dir)
    # Then both files are named, with the call that starts Chrome
    expect_length(problems, 2L)
    expect_match(problems[[1]], "test-thing-snap.R starts Chrome", fixed = TRUE)
    expect_match(problems[[2]], "test-thing.R starts Chrome or skips on CRAN (`open_page` and `drive`)", fixed = TRUE)
    expect_match(problems[[2]], "-browser.R or -extended.R file", fixed = TRUE)
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
        "skip_without_chrome()",
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

  it("finds a -browser.R or -extended.R file that does not start with its skip, and needs none in a -snap.R file", {
    # Given files whose first expression is something else, or the skip with an argument, or nothing at all
    dir <- withr::local_tempdir()
    plant(
      dir,
      "test-app-browser.R",
      c("skip_without_chrome(TRUE)", "skip_without_chrome()", "it('a', { chromote::find_chrome() })")
    )
    plant(dir, "test-app-snap.R", c("page <- 1", "it('b', { expect_snapshot(1) })"))
    plant(dir, "test-app-extended.R", "# nothing here yet")
    plant(dir, "test-app.R", "it('c', { expect_true(TRUE) })")
    # When the layout is checked
    problems <- layout_problems(dir)
    # Then each file is named with the skip it must start with, and the snapshot and plain files pass
    expect_identical(
      problems,
      c(
        "test-app-browser.R must start with `skip_without_chrome()`, so CRAN skips the whole file before any of its code runs.",
        "test-app-extended.R must start with `skip_unless_extended()`, so CRAN skips the whole file before any of its code runs."
      )
    )
  })

  it("keeps Chrome and snapshots out of -extended.R files, and the extended skip out of plain files", {
    dir <- withr::local_tempdir()
    plant(dir, "helper-x.R", "skip_unless_extended <- function() testthat::skip_on_cran()")
    plant(
      dir,
      "test-app-extended.R",
      c("skip_unless_extended()", "it('a', { shinytest2::AppDriver$new() })", "it('b', { expect_snapshot(1) })")
    )
    plant(dir, "test-app.R", "it('c', { skip_unless_extended(); expect_true(TRUE) })")
    problems <- layout_problems(dir)
    expect_length(problems, 3L)
    expect_match(problems[[1]], "test-app-extended.R starts Chrome (`shinytest2::`)", fixed = TRUE)
    expect_match(problems[[2]], "test-app-extended.R has snapshot tests (`expect_snapshot`)", fixed = TRUE)
    expect_match(problems[[3]], "test-app.R starts Chrome or skips on CRAN (`skip_unless_extended`", fixed = TRUE)
  })

  it("rejects a folder that does not exist", {
    expect_error(layout_problems(file.path(withr::local_tempdir(), "missing")), "Directory")
    expect_error(layout_names_reaching(list(1), "skip_on_cran"), "names")
    expect_error(layout_names_reaching(list(a = "x"), character()), "length")
  })
})
