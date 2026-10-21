# The shared Chromes are checked and replaced when one dies (tests/testthat/helper-chrome.R, #446). These tests close a
# Chrome on purpose; the restarts they cause are not counted against the run's own allowance.

# Count restarts from `used` while the calling test runs. When it ends, a Chrome the test left dead is replaced (with
# nothing counted) and the run's own count comes back.
local_chrome_restarts <- function(used = 0L, env = parent.frame()) {
  real <- test_browser_env$restarts
  test_browser_env$restarts <- used
  withr::defer(
    {
      test_browser_env$restarts <- 0L
      if (!is.null(test_browser_env$browser)) {
        test_browser()
      }
      if (!is.null(test_browser_env$default)) {
        chrome_ensure_default()
      }
      test_browser_env$restarts <- real
    },
    envir = env
  )
}

# A trivial Shiny app for the tests that open an app in the default Chrome.
hello_app <- function() {
  shiny::shinyApp(shiny::fluidPage(shiny::p("hello")), function(input, output, session) NULL)
}

describe("test_browser()", {
  it("returns the same running browser each time", {
    skip_without_chrome()
    local_chrome_restarts()
    expect_identical(test_browser(), test_browser())
    expect_identical(test_browser_env$restarts, 0L)
  })

  it("starts a new, working browser when the shared one has been closed", {
    skip_without_chrome()
    local_chrome_restarts()
    old <- test_browser()
    old$close()
    expect_false(old$is_alive())
    new <- test_browser()
    expect_false(identical(new, old))
    expect_true(new$is_alive())
    expect_identical(test_browser_env$restarts, 1L)
    js <- local_engine_page()
    expect_equal(js("1 + 1"), 2)
  })

  it("skips with the reason once the run's restarts are used up", {
    skip_without_chrome()
    local_chrome_restarts(chrome_restart_limit)
    old <- test_browser()
    old$close()
    skipped <- tryCatch(test_browser(), skip = function(condition) condition)
    expect_s3_class(skipped, "skip")
    expect_match(conditionMessage(skipped), "shared Chrome stopped (its process has ended)", fixed = TRUE)
    expect_match(conditionMessage(skipped), "after 2 restarts", fixed = TRUE)
    expect_identical(test_browser_env$restarts, chrome_restart_limit)
    expect_identical(test_browser_env$browser, old)
  })
})

describe("app_driver()", {
  it("opens the app in a new default Chrome when the old one has been closed", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    local_chrome_restarts()
    first <- app_driver(hello_app())
    old <- chromote::default_chromote_object()
    first$stop()
    old$close()
    expect_false(old$is_alive())
    second <- app_driver(hello_app())
    new <- chromote::default_chromote_object()
    expect_false(identical(new, old))
    expect_true(new$is_alive())
    expect_identical(test_browser_env$restarts, 1L)
    expect_equal(second$get_js("1 + 1"), 2)
  })

  it("skips with the reason once the run's restarts are used up", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    local_chrome_restarts()
    app_driver(hello_app())$stop()
    chromote::default_chromote_object()$close()
    test_browser_env$restarts <- chrome_restart_limit
    skipped <- tryCatch(app_driver(hello_app()), skip = function(condition) condition)
    expect_s3_class(skipped, "skip")
    expect_match(conditionMessage(skipped), "default Chrome stopped", fixed = TRUE)
  })

  it("checks its arguments", {
    expect_error(app_driver(env = "x"), "env")
  })
})

describe("local_chrome_session()", {
  it("opens a page in the shared browser and closes it when the calling test ends", {
    skip_without_chrome()
    local_chrome_restarts()
    session <- NULL
    (function() {
      session <<- local_chrome_session()
      expect_identical(session$parent, test_browser())
      expect_true(session$is_active())
    })()
    expect_false(session$is_active())
  })

  it("closes the page when the calling test fails first", {
    skip_without_chrome()
    local_chrome_restarts()
    session <- NULL
    expect_error(
      (function() {
        session <<- local_chrome_session()
        stop("the test failed")
      })(),
      "the test failed"
    )
    expect_false(session$is_active())
  })

  it("does not hide the original error when Chrome died meanwhile", {
    skip_without_chrome()
    local_chrome_restarts()
    expect_error(
      (function() {
        local_chrome_session()
        test_browser()$close()
        stop("the original error")
      })(),
      "the original error"
    )
  })

  it("checks its arguments", {
    expect_error(local_chrome_session(env = "x"), "env")
  })
})

describe("chrome_close()", {
  it("closes a browser that has already stopped without an error", {
    skip_without_chrome()
    local_chrome_restarts()
    browser <- test_browser()
    browser$close()
    expect_no_error(chrome_close(browser))
  })

  it("checks its argument", {
    expect_error(chrome_close("x"), "browser")
  })
})
