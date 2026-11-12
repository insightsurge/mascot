describe("mascot_test_state()", {
  it("validates arguments with checkmate and descriptive mascot errors", {
    fake_app <- structure(
      list(
        wait_for_js = function(...) TRUE,
        get_js = function(...) {
          list(
            id = "helper",
            character = "tessa",
            mood = "idle",
            status = "Looking around, ready to help.",
            bubble = NULL,
            minimised = FALSE
          )
        }
      ),
      class = "AppDriver"
    )

    expect_error(mascot_test_state(), class = "mascot_error")
    expect_error(mascot_test_state(fake_app), class = "mascot_error")
    expect_error(mascot_test_state(fake_app, "helper", "extra"), class = "mascot_error_dots")
    expect_error(mascot_test_state(fake_app, ""), class = "mascot_error")
    expect_error(mascot_test_state(fake_app, "has spaces"), class = "mascot_error")
    expect_error(mascot_test_state(fake_app, 123), class = "mascot_error")
    expect_error(mascot_test_state(fake_app, "helper", timeout = -1), class = "mascot_error")
    expect_error(mascot_test_state(fake_app, "helper", timeout = Inf), class = "mascot_error")
    expect_error(mascot_test_state(fake_app, "helper", timeout = "5000"), class = "mascot_error")
    expect_error(mascot_test_state(list(), "helper"), class = "mascot_error")
  })

  it("errors clearly when shinytest2 is not installed", {
    fake_app <- structure(list(), class = "AppDriver")
    testthat::local_mocked_bindings(
      test_state_has_shinytest2 = function() FALSE,
      .package = "mascot"
    )
    expect_error(mascot_test_state(fake_app, "helper"), class = "mascot_error")
  })

  it("normalises bubble durations, waits on settled state, and errors cleanly on timeout or unmount", {
    skip_if_not_installed("shinytest2")

    calls <- list()
    fake_app <- structure(
      list(
        wait_for_js = function(script, timeout) {
          calls$wait <<- list(script = script, timeout = timeout)
          TRUE
        },
        get_js = function(script) {
          calls$get <<- script
          list(
            id = "form-helper",
            character = "tessa",
            mood = "happy",
            status = "Saved",
            bubble = list(text = "Nice", html = FALSE, closable = TRUE, duration = NULL),
            minimised = TRUE
          )
        }
      ),
      class = "AppDriver"
    )

    state <- mascot_test_state(fake_app, "form-helper", timeout = 2500)
    expect_identical(calls$wait$timeout, 2500)
    expect_match(calls$wait$script, "form-helper", fixed = TRUE)
    expect_identical(
      state,
      list(
        id = "form-helper",
        character = "tessa",
        mood = "happy",
        status = "Saved",
        bubble = list(text = "Nice", html = FALSE, closable = TRUE, duration = Inf),
        minimised = TRUE
      )
    )

    # Finite duration is preserved as numeric seconds.
    finite_app <- structure(
      list(
        wait_for_js = function(script, timeout) TRUE,
        get_js = function(script) {
          list(
            id = "helper",
            character = "sela",
            mood = "thinking",
            status = "Checking",
            bubble = list(text = "Wait", html = TRUE, closable = FALSE, duration = 4),
            minimised = FALSE
          )
        }
      ),
      class = "AppDriver"
    )
    expect_identical(mascot_test_state(finite_app, "helper")$bubble$duration, 4)

    timeout_app <- structure(
      list(wait_for_js = function(script, timeout) stop("Timed out waiting"), get_js = function(script) NULL),
      class = "AppDriver"
    )
    expect_error(mascot_test_state(timeout_app, "missing", timeout = 100), class = "mascot_error")

    gone_app <- structure(
      list(wait_for_js = function(script, timeout) TRUE, get_js = function(script) NULL),
      class = "AppDriver"
    )
    expect_error(mascot_test_state(gone_app, "helper"), class = "mascot_error")
  })
})
