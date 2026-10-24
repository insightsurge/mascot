# The optional packages a view of the studio app needs to build its page: bslib for every view, and knitr for the
# studio and examples views (the studio's page checks for its guide pages). The theme view does not need knitr.
skip_without_studio_packages <- function(view = "studio") {
  checkmate::assert_choice(view, c("studio", "examples", "theme"))
  testthat::skip_if_not_installed("bslib")
  if (view != "theme") {
    testthat::skip_if_not_installed("knitr")
  }
  invisible(TRUE)
}

# Records what a copy button puts on the clipboard in `window.copied` (null until something is copied), so a test reads
# it without the browser's clipboard permission. A copy button hands the browser its text as a promise, or as text where
# the browser has no such clipboard call.
stub_studio_clipboard <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$run_js(paste(
    "window.copied = null;",
    "navigator.clipboard.writeText = async (text) => { window.copied = text; };",
    "navigator.clipboard.write = async (items) => { window.copied = await (await items[0].getType('text/plain')).text(); };"
  ))
}

# Waits until the Help or Guide panel shows the page of `fn`: the studio marks a panel busy until its card names `fn`.
# With `character`, the Guide's card must also be drawn for that character.
wait_studio_panel <- function(app, panel, fn, character = NULL) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_choice(panel, c("help", "guide"))
  checkmate::assert_string(fn)
  checkmate::assert_string(character, null.ok = TRUE)
  app$wait_for_js(sprintf(
    paste(
      "(() => { const p = document.getElementById('inspector_%s');",
      "const card = p.querySelector('[data-guide-function]');",
      "return !p.hidden && !p.hasAttribute('aria-busy') && card?.dataset.guideFunction === '%s' &&",
      "(%s === null || card.dataset.guideCharacter === %s); })()"
    ),
    panel,
    fn,
    if (is.null(character)) "null" else sprintf("'%s'", character),
    if (is.null(character)) "null" else sprintf("'%s'", character)
  ))
}

# Waits until the preview page is shown: its frame is drawn, the page inside has loaded (the page marks the frame
# data-loaded) and the studio no longer says "Building".
wait_studio_preview <- function(app) {
  checkmate::assert_r6(app, "AppDriver")
  app$wait_for_js(
    "!!document.querySelector('iframe.pg-preview[data-loaded]') && !document.querySelector('.pg-building')"
  )
}
