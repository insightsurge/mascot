# One headless Chrome for the whole test run, shared by the tests that draw with the engine.
#
# Chrome keeps its temporary files in TMPDIR and leaves com.google.Chrome.* folders behind, which R CMD check reports
# as a NOTE ("detritus in the temp directory"). Pointing TMPDIR inside R's session temporary directory keeps them out
# of the system temp directory: R deletes tempdir() when the session ends. Slow CI runners can need more than
# chromote's default 10 seconds to start Chrome, hence the longer timeout.
test_browser_env <- new.env(parent = emptyenv())

# Milliseconds any browser test waits for a signal (a Shiny value, a DOM state, a finished animation) before it fails.
# One generous limit for every wait: a busy machine or a slow CI runner can take seconds to answer, while a passing
# wait returns as soon as its signal arrives, so a long limit costs nothing on a fast machine (#250). Never sleep for a
# fixed time instead: wait for the signal.
browser_timeout <- 30000

# Start a Shiny app in Chrome with the shared timeout for loading and for every wait, click and value it reads.
# The app is stopped when the calling test ends, pass or fail (#432): a test that fails before its own `app$stop()`
# would otherwise leave the app's R process running until the whole suite ends. Stopping twice is harmless.
app_driver <- function(..., env = parent.frame()) {
  app <- shinytest2::AppDriver$new(..., load_timeout = browser_timeout, timeout = browser_timeout)
  withr::defer(app$stop(), envir = env)
  app
}

test_browser <- function() {
  if (is.null(test_browser_env$browser)) {
    tmp <- file.path(tempdir(), "chrome-tmp")
    dir.create(tmp, showWarnings = FALSE)
    test_browser_env$browser <- withr::with_options(
      list(chromote.timeout = 60),
      withr::with_envvar(c(TMPDIR = tmp), chromote::Chromote$new())
    )
    # Sessions opened from this browser inherit the limit, in seconds, for navigation and page commands.
    test_browser_env$browser$default_timeout <- browser_timeout / 1000
    withr::defer(test_browser_env$browser$close(), envir = testthat::teardown_env())
  }
  test_browser_env$browser
}
