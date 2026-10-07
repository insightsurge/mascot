# The drawing engine in inst/www/ has no R file of its own: these tests draw with it in headless Chrome.

skip_without_chrome <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
}

# Opens a blank page with the engine's files loaded and returns a function that evaluates JavaScript there.
local_engine_page <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  scripts <- file.path(www, c("mascot.js", "mascot-draw.js", "mascot-motion.js"))
  tessa <- system.file("characters", "tessa.json", package = "mascot")
  blob <- testthat::test_path("fixtures", "characters", "blob.json")
  page <- file.path(dir, "page.html")
  writeLines(
    c(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>engine</title></head><body>",
      "<script type=\"application/json\" data-mascot-character=\"tessa\">",
      readLines(tessa, encoding = "UTF-8"),
      "</script>",
      "<script type=\"application/json\" data-mascot-character=\"blob\">",
      readLines(blob, encoding = "UTF-8"),
      "</script>",
      sprintf("<script src=\"file://%s\"></script>", normalizePath(scripts, winslash = "/")),
      "</body></html>"
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) session$Runtime$evaluate(js, returnByValue = TRUE)$result$value
}

# Draws a character from the page on a new canvas and returns the picture as a PNG data URL.
draw_js <- function(pose, frame = 0, character = "tessa") {
  sprintf(
    paste(
      "(() => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "window.mascot.draw(c.getContext('2d'), window.mascot.readCharacter('%s'), { x: 150, baseY: 280, pose: %s, frame: %d });",
      "return c.toDataURL(); })()"
    ),
    character,
    pose,
    frame
  )
}

# Runs `code` in the page and returns the message of the error it throws (or "no error").
error_js <- function(code) {
  sprintf(
    "(() => { const ch = window.mascot.readCharacter('tessa'); try { %s; } catch (e) { return e.message; } return 'no error'; })()",
    code
  )
}

# Host integration page: real packaged assets and real markup, with motion reduced before navigation.
local_host_page <- function(
  env = parent.frame(),
  bubble = NULL,
  reduced = TRUE,
  scheme = "light",
  size = 160,
  placement = "inline",
  viewport = NULL,
  density = 1,
  theme = NULL,
  record_colours = FALSE,
  motion = TRUE,
  popup_menu = NULL,
  shiny_menu = FALSE
) {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  scripts <- file.path(www, c("mascot.js", "mascot-draw.js", "mascot-motion.js", "mascot-host.js"))
  page <- file.path(dir, "host.html")
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>host</title>',
      sprintf('<link rel="stylesheet" href="file://%s">', normalizePath(file.path(www, "mascot.css"))),
      '</head><body>',
      as.character(mascot(
        id = "a",
        bubble = bubble,
        size = size,
        placement = placement,
        theme = theme,
        motion = motion,
        popup_menu = popup_menu
      )),
      '<script type="application/json" data-mascot-character="blob">',
      readLines(testthat::test_path("fixtures", "characters", "blob.json"), encoding = "UTF-8"),
      '</script>',
      sprintf('<script src="file://%s"></script>', normalizePath(scripts[1:3])),
      if (record_colours) {
        paste0(
          '<script>window.themeDraws=[];const originalDraw=mascot.draw;',
          'mascot.draw=function(ctx,ch,options){themeDraws.push({character:ch.id,',
          'colours:{...ch.colours,...options.colours},overrides:{...options.colours}});',
          'return originalDraw(ctx,ch,options);};</script>'
        )
      },
      if (shiny_menu) {
        '<script>window.menuEvents=[];window.Shiny={setInputValue:(...args)=>menuEvents.push(args)};</script>'
      },
      sprintf('<script src="file://%s"></script>', normalizePath(scripts[4])),
      '</body></html>'
    ),
    page
  )
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  session$Emulation$setEmulatedMedia(
    features = list(
      list(name = "prefers-reduced-motion", value = if (reduced) "reduce" else "no-preference"),
      list(name = "prefers-color-scheme", value = scheme)
    )
  )
  if (!is.null(viewport)) {
    session$Emulation$setDeviceMetricsOverride(
      width = viewport[[1]],
      height = viewport[[2]],
      deviceScaleFactor = density,
      mobile = FALSE
    )
  }
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page)), wait_ = FALSE)
  session$wait_for(loaded)
  evaluate <- function(js) {
    result <- session$Runtime$evaluate(js, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description)
    }
    result$result$value
  }
  attr(evaluate, "session") <- session
  evaluate
}

# Start shinytest2 with its temporary browser files inside R's temporary directory.
local_shiny_browser <- function(env = parent.frame()) {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("shinytest2")
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
  tmp <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(c(TMPDIR = tmp), .local_envir = env)
}

# Read layout after both style resolution and ResizeObserver delivery.
host_layout <- function(js, code) {
  js(paste0(
    "(async () => { await new Promise(resolve => requestAnimationFrame(() => ",
    "requestAnimationFrame(resolve))); ",
    code,
    " })()"
  ))
}

# Real host and canvas, with a deterministic frame queue around one remount.
host_motion_js <- function(code) {
  paste0(
    "(() => {const el=document.getElementById('a');mascot.host.unmount(el);
",
    "const mount=mascot.mount,draw=mascot.draw,raf=window.requestAnimationFrame,cancel=window.cancelAnimationFrame;
",
    "const queued=new Map(),calls=[],players=[];let id=0;
",
    "window.requestAnimationFrame=fn=>{queued.set(++id,fn);return id;};window.cancelAnimationFrame=n=>queued.delete(n);
",
    "mascot.draw=(ctx,ch,options)=>{calls.push({character:ch.id,...options});return draw(ctx,ch,options);};
",
    "mascot.mount=(...args)=>{const p=mount(...args);players.push(p);return p;};
",
    "const send=patch=>mascot.host.receive({id:'a',patch}),state=()=>mascot.host.state(el);
",
    "const fire=t=>{const batch=[...queued.values()];queued.clear();batch.forEach(fn=>fn(t));};
",
    "try{mascot.host.mount(el);const controller=players[0];",
    code,
    "}finally{mascot.host.unmount(el);mascot.mount=mount;mascot.draw=draw;window.requestAnimationFrame=raf;window.cancelAnimationFrame=cancel;}})()"
  )
}
