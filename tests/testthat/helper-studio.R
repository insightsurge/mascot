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

# Clicks a slow button (one with data-busy-label) and waits until the result of that click is drawn: the button says it
# is busy from the click until its output carries the number the click sent (inputs.js, busy_done_mark()). Returns that
# number.
click_studio_busy <- function(app, id) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(id, min.chars = 1)
  click <- app$get_js(sprintf(
    "(() => { const b = document.getElementById('%s'); b.click(); return b.dataset.busyClick ?? null; })()",
    id
  ))
  checkmate::assert_string(click, pattern = "^[0-9]+$")
  app$wait_for_js(sprintf(
    paste(
      "(() => { const b = document.getElementById('%s');",
      "return !b.hasAttribute('aria-busy') &&",
      "!!document.querySelector(`#${b.dataset.busyOutput} [data-busy-done=\"%s\"]`); })()"
    ),
    id,
    click
  ))
  invisible(click)
}

# The studio and its guide pages (guide/*.Rmd), loaded the way the tests load pieces of the studio: into an environment
# under the global one, as the app's own files are, so they find shiny and bslib, attached until the calling test ends.
# (A helper file's own environment sits below them on the search path.)
studio_guide_env <- function(frame = parent.frame()) {
  checkmate::assert_environment(frame)
  testthat::skip_if_not_installed("bslib")
  testthat::skip_if_not_installed("knitr")
  withr::local_package("shiny", .local_envir = frame)
  withr::local_package("bslib", .local_envir = frame)
  dir <- dirname(mascot_example("studio", run = FALSE))
  env <- new.env(parent = globalenv())
  for (file in c(
    "guide.R",
    "shared-help.R",
    "data.R",
    "shared-data.R",
    "shared-ui.R",
    "code.R",
    "panels.R",
    "ui.R",
    "guide-md.R"
  )) {
    sys.source(file.path(dir, "R", file), envir = env)
  }
  env
}

# Until the browser's mount snapshot makes the studio's helper live, calls are kept, not accepted or sent. This
# snapshot is what the page sends on mount, so the studio's kept calls are accepted and the first state is sent.
studio_go_live <- function(session) {
  protocol_ready(list(session = session, id = session$ns("helper")))
  session$flushReact()
  invisible(NULL)
}

# The first value unless it is NULL; base R has `%||%` only from 4.4 and the package supports R 4.1.
value_or <- function(value, fallback) if (is.null(value)) fallback else value

# The studio's pages, drawn once per R process when a test first asks for one (a page takes about a second). The
# environments the `*_parts()` functions return are always fresh; a test that needs a fresh page uses app_page().
studio_page_cache <- new.env(parent = emptyenv())

# The page `draw()` returns, drawn the first time `key` is asked for.
studio_page <- function(key, draw) {
  checkmate::assert_string(key)
  checkmate::assert_function(draw)
  if (!exists(key, envir = studio_page_cache, inherits = FALSE)) {
    assign(key, draw(), envir = studio_page_cache)
  }
  get(key, envir = studio_page_cache, inherits = FALSE)
}

# The HTML page `app` serves at `query`, drawn without a browser.
app_page <- function(app, query = "") {
  checkmate::assert_class(app, "shiny.appobj")
  checkmate::assert_string(query)
  as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
}

# The studio app's own environment (its server, data and code builders) and its page, built without a browser.
studio_parts <- function() {
  skip_without_studio_packages("studio")
  app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
  list(env = environment(app$serverFuncSource()), page = studio_page("studio", function() app_page(app)))
}

# The studio app's environment where the theme view's functions live, and the theme view's page.
theme_parts <- function() {
  skip_without_studio_packages("theme")
  app_env <- environment(shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))$serverFuncSource())
  # Shiny loads the files in R/ into an environment of their own, above app.R's.
  list(
    env = environment(get("theme_view_server", app_env)),
    page = studio_page("theme", function() app_page(mascot_studio("theme", run = FALSE)))
  )
}

# The value each control starts with on the page, by input id, as the browser first reports it to the server.
studio_start_values <- function(page) {
  checkmate::assert_string(page)
  attribute <- function(tag, name) {
    checkmate::assert_string(tag)
    checkmate::assert_string(name)
    match <- regmatches(tag, regexec(sprintf(' %s="([^"]*)"', name), tag))[[1]]
    if (length(match)) match[[2]] else NULL
  }
  unescape <- function(text) {
    checkmate::assert_string(text)
    for (entity in names(entities <- c("&lt;" = "<", "&gt;" = ">", "&quot;" = '"', "&#39;" = "'", "&amp;" = "&"))) {
      text <- gsub(entity, entities[[entity]], text, fixed = TRUE)
    }
    text
  }
  tags <- function(pattern) regmatches(page, gregexpr(pattern, page, perl = TRUE))[[1]]
  values <- list()
  for (tag in tags('<input class="js-range-slider"[^>]*>')) {
    values[[attribute(tag, "id")]] <- as.numeric(attribute(tag, "data-from"))
  }
  for (tag in tags('<input id="[^"]+" class="form-check-input" type="checkbox"[^>]*>')) {
    values[[attribute(tag, "id")]] <- grepl(" checked", tag, fixed = TRUE)
  }
  for (tag in tags('<input id="[^"]+" type="text"[^>]*>')) {
    values[[attribute(tag, "id")]] <- attribute(tag, "value")
  }
  for (tag in tags('(?s)<textarea id="[^"]+"[^>]*>.*?</textarea>')) {
    values[[attribute(tag, "id")]] <- unescape(sub("(?s)^<textarea[^>]*>(.*)</textarea>$", "\\1", tag, perl = TRUE))
  }
  for (tag in tags('(?s)<div id="[^"]+" class="[^"]*shiny-input-radiogroup.*?</div>\\s*</div>')) {
    id <- attribute(tag, "id")
    checked <- regmatches(tag, regexec(sprintf('name="%s" value="([^"]*)" checked', id), tag))[[1]]
    values[[id]] <- checked[[2]]
  }
  for (tag in tags('(?s)<select\\b[^>]*\\bid="[^"]+"[^>]*>.*?</select>')) {
    options <- regmatches(tag, gregexpr('<option value="[^"]*"( selected)?', tag))[[1]]
    chosen <- grep("selected", options, fixed = TRUE, value = TRUE)
    values[[attribute(tag, "id")]] <- unescape(attribute(c(chosen, options)[[1]], "value"))
  }
  values
}
