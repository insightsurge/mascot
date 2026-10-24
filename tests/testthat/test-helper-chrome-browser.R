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

describe("local_engine_page()", {
  it("raises a JavaScript exception instead of returning NULL", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_error(js("missing_function()"), "ReferenceError")
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
})

describe("chrome_close()", {
  it("closes a browser that has already stopped without an error", {
    skip_without_chrome()
    local_chrome_restarts()
    browser <- test_browser()
    browser$close()
    expect_no_error(chrome_close(browser))
  })
})

describe("wait_studio_js()", {
  # A page whose live frame appears after `delay` milliseconds (null before), holding a helper element.
  frame_app <- function(delay) {
    shiny::shinyApp(
      shiny::fluidPage(
        shiny::tags$script(shiny::HTML(sprintf(
          "setTimeout(() => { const f = document.createElement('iframe'); f.id = 'live_frame'; f.srcdoc = '<div id=helper data-mood=happy></div>'; document.body.append(f); }, %d);",
          delay
        )))
      ),
      function(input, output, session) NULL
    )
  }

  it("polls again while the frame is missing and returns once the frame holds the element", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    app <- app_driver(frame_app(1500))
    expect_true(app$get_js("document.getElementById('live_frame') === null"))
    wait_studio_js(app, "live.dataset.mood === 'happy' && frame.document === live.ownerDocument")
    expect_true(app$get_js("document.getElementById('live_frame') !== null"))
  })

  it("fails on the time limit, not on a script error, when the frame never appears", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    app <- app_driver(frame_app(600000))
    error <- expect_error(wait_studio_js(app, "live.dataset.mood === 'happy'", timeout = 1500))
    expect_no_match(conditionMessage(error), "Cannot read properties", fixed = TRUE)
  })
})

describe("chrome_device_args", {
  it("gives every app a desktop with a mouse and no wish for reduced motion, which a page can still change", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    app <- app_driver(hello_app())
    device <- "['(hover: hover)', '(pointer: fine)', '(prefers-reduced-motion: reduce)'].map((q) => matchMedia(q).matches)"
    expect_identical(unlist(app$get_js(device)), c(TRUE, TRUE, FALSE))
    app$get_chromote_session()$Emulation$setEmulatedMedia(
      features = list(list(name = "prefers-reduced-motion", value = "reduce"))
    )
    expect_identical(unlist(app$get_js(device)), c(TRUE, TRUE, TRUE))
  })
})

describe("click_now()", {
  it("clicks the element the selector names, and fails when nothing matches", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    app <- app_driver(shiny::shinyApp(
      shiny::fluidPage(shiny::tags$button(id = "go", type = "button", onclick = "window.clicked = true", "Go")),
      function(input, output, session) NULL
    ))
    click_now(app, "#go")
    expect_true(app$get_js("window.clicked === true"))
    expect_error(click_now(app, "#missing"), "No element matches")
  })
})
