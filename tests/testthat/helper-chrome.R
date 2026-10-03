# One headless Chrome for the whole test run, shared by the tests that draw with the engine.
#
# Chrome keeps its temporary files in TMPDIR and leaves com.google.Chrome.* folders behind, which R CMD check reports
# as a NOTE ("detritus in the temp directory"). Pointing TMPDIR inside R's session temporary directory keeps them out
# of the system temp directory: R deletes tempdir() when the session ends. Slow CI runners can need more than
# chromote's default 10 seconds to start Chrome, hence the longer timeout.
test_browser_env <- new.env(parent = emptyenv())

test_browser <- function() {
  if (is.null(test_browser_env$browser)) {
    tmp <- file.path(tempdir(), "chrome-tmp")
    dir.create(tmp, showWarnings = FALSE)
    test_browser_env$browser <- withr::with_options(
      list(chromote.timeout = 60),
      withr::with_envvar(c(TMPDIR = tmp), chromote::Chromote$new())
    )
    withr::defer(test_browser_env$browser$close(), envir = testthat::teardown_env())
  }
  test_browser_env$browser
}
