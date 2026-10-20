# Rebuild "The Bridge at Five": story.html, story.mp4 and poster.png, from this checkout of mascot.
#
# Run from any folder (the paths below are found from this script's own location):
#
#   RENV_CONFIG_AUTOLOADER_ENABLED=FALSE \
#   R_LIBS=~/Library/Caches/org.R-project.R/R/renv/library/mascot-88913ebe/macos/R-4.6/aarch64-apple-darwin23 \
#   Rscript vignettes/articles/story/build-story.R [all | html | video | verify | stills <times...>]
#
#   html    writes story.html: the engine (inst/www), the four characters and src/ inlined into one offline page.
#   video   records story.mp4 (H.264, 30 fps) and poster.png in headless Chrome (chromote), frame by frame.
#   verify  opens story.mp4 in a <video> element and saves frames at several times (to STORY_OUT or tempdir()).
#   stills  saves stills of the live stage at the given times (seconds), e.g. `stills 7.4 21.7 42`.
#   all     html, then video, then verify (the default).
#
# Needs: pkgload, htmltools, chromote, jsonlite and a Chrome that chromote can find. Nothing is installed.

args <- commandArgs(trailingOnly = TRUE)
step <- if (length(args)) args[[1]] else "all"
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
here <- normalizePath(dirname(sub("^--file=", "", file_arg[[1]])))
repo <- normalizePath(file.path(here, "..", "..", ".."))
src <- file.path(here, "src")
out_dir <- Sys.getenv("STORY_OUT", tempdir())

read_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# Replace one {{KEY}} in the template, literally (no regular expressions in the inserted code).
fill <- function(template, key, value) {
  at <- regexpr(key, template, fixed = TRUE)
  stopifnot(at > 0)
  paste0(substr(template, 1, at - 1), value, substr(template, at + nchar(key), nchar(template)))
}

# A script's text may not contain "</script" inside an inline <script> element.
inline_js <- function(text) gsub("</script", "<\\/script", text, fixed = TRUE)

build_html <- function() {
  pkgload::load_all(repo, quiet = TRUE)
  cast <- lapply(c("tessa", "sela", "knurl", "neer"), function(id) {
    mascot::mascot(paste0("cast-", id), character = id, size = 400, placement = "inline")
  })
  cast_html <- vapply(cast, function(tag) as.character(htmltools::renderTags(tag)$html), character(1))
  dependency <- htmltools::findDependencies(cast[[1]])[[1]]
  www <- file.path(repo, "inst", "www")
  engine_js <- vapply(
    dependency$script,
    function(name) paste0("/* mascot engine: inst/www/", name, " */\n", read_text(file.path(www, name))),
    character(1)
  )
  page <- read_text(file.path(src, "template.html"))
  page <- fill(page, "{{ENGINE_CSS}}", read_text(file.path(www, dependency$stylesheet)))
  page <- fill(page, "{{STAGE_CSS}}", read_text(file.path(src, "stage.css")))
  page <- fill(page, "{{CAST}}", paste(cast_html, collapse = "\n"))
  page <- fill(page, "{{ENGINE_JS}}", inline_js(paste(engine_js, collapse = "\n\n")))
  page <- fill(page, "{{STAGE_JS}}", inline_js(read_text(file.path(src, "stage.js"))))
  target <- file.path(here, "story.html")
  writeLines(enc2utf8(page), target, useBytes = TRUE)
  message("story.html: ", format(file.size(target), big.mark = ","), " bytes")
  invisible(target)
}

start_page <- function(width = 1320, height = 900) {
  session <- chromote::ChromoteSession$new(width = width, height = height)
  session$Page$enable()
  session$Page$addScriptToEvaluateOnNewDocument(source = read_text(file.path(src, "vclock.js")))
  session$Page$navigate(paste0("file://", file.path(here, "story.html")))
  evaluate <- function(js, timeout = 60) {
    result <- session$Runtime$evaluate(js, awaitPromise = TRUE, returnByValue = TRUE, timeout_ = timeout)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description %||% result$exceptionDetails$text, call. = FALSE)
    }
    result$result$value
  }
  waited <- 0
  while (!isTRUE(tryCatch(evaluate("Boolean(window.story && window.story.isReady())"), error = function(e) FALSE))) {
    Sys.sleep(0.25)
    waited <- waited + 1
    if (waited > 120) stop("The story page did not get ready in 30 seconds.", call. = FALSE)
  }
  evaluate(read_text(file.path(src, "record.js")))
  list(session = session, evaluate = evaluate)
}

# Fetch a long string from the page in pieces (one CDP message per piece).
fetch_string <- function(evaluate, expression) {
  total <- evaluate(paste0(expression, ".length"))
  piece <- 2e6
  parts <- character(0)
  for (from in seq(0, total - 1, by = piece)) {
    parts <- c(parts, evaluate(sprintf("%s.slice(%d, %d)", expression, as.integer(from), as.integer(from + piece))))
  }
  paste(parts, collapse = "")
}

save_png <- function(data_url, path) {
  writeBin(jsonlite::base64_dec(sub("^data:image/png;base64,", "", data_url)), path)
  path
}

record_video <- function(poster_time = 41.3) {
  page <- start_page()
  on.exit(page$session$close(), add = TRUE)
  options <- sprintf(
    "{width: 1280, height: 720, fps: 30, bitrate: %s, codec: '%s', hardware: '%s', keyEvery: %s, posters: [%s]}",
    Sys.getenv("STORY_BITRATE", "560000"),
    Sys.getenv("STORY_CODEC", "avc1.640028"),
    Sys.getenv("STORY_HARDWARE", "no-preference"),
    Sys.getenv("STORY_KEY_EVERY", "5"),
    poster_time
  )
  info <- page$evaluate(sprintf("recordStory(%s)", options), timeout = 1200)
  message(
    "recorded ",
    info$frames,
    " frames, ",
    info$samples,
    " samples, ",
    info$keyframes,
    " key frames, ",
    "decode order = presentation order: ",
    info$ordered,
    ", ",
    info$codec,
    " (",
    info$hardware,
    ")",
    ", avcC profile/level ",
    info$profile
  )
  mp4 <- file.path(here, "story.mp4")
  writeBin(jsonlite::base64_dec(fetch_string(page$evaluate, "window.__mp4b64")), mp4)
  message("story.mp4: ", format(file.size(mp4), big.mark = ","), " bytes")
  posters <- page$evaluate("window.__posters")
  save_png(posters[[1]], file.path(here, "poster.png"))
  message("poster.png: ", format(file.size(file.path(here, "poster.png")), big.mark = ","), " bytes")
  invisible(mp4)
}

save_stills <- function(times, tall = FALSE) {
  page <- start_page()
  on.exit(page$session$close(), add = TRUE)
  size <- if (tall) "width: 800, height: 1000, tall: true" else "width: 1280, height: 720"
  js <- sprintf("recordStory({%s, encode: false, posters: [%s]})", size, paste(times, collapse = ","))
  page$evaluate(js, timeout = 600)
  stills <- page$evaluate("window.__posters")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  for (name in names(stills)) {
    path <- file.path(out_dir, sprintf("still-%s%05.2f.png", if (tall) "tall-" else "", as.numeric(name) / 30))
    save_png(stills[[name]], path)
    message(path)
  }
}

# Load story.mp4 in a <video> element, check what the browser reports and screenshot frames at several times.
verify_video <- function(times = c(0.5, 2, 8, 19.7, 30, 36, 43.4, 48.5)) {
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  check <- file.path(out_dir, "verify-video.html")
  writeLines(
    c(
      "<!doctype html><meta charset='utf-8'><style>body{margin:0;background:#000}video{display:block}</style>",
      sprintf(
        "<video id='v' src='%s' muted playsinline preload='auto' width='1280' height='720'></video>",
        paste0("file://", file.path(here, "story.mp4"))
      )
    ),
    check
  )
  session <- chromote::ChromoteSession$new(width = 1280, height = 720)
  on.exit(session$close(), add = TRUE)
  session$Page$navigate(paste0("file://", check))
  evaluate <- function(js) {
    session$Runtime$evaluate(js, awaitPromise = TRUE, returnByValue = TRUE, timeout_ = 60)$result$value
  }
  Sys.sleep(1.5)
  facts <- evaluate(paste(
    "new Promise(r => { const v = document.getElementById('v');",
    "const done = () => r({duration: v.duration, width: v.videoWidth, height: v.videoHeight,",
    "readyState: v.readyState, error: v.error && v.error.message});",
    "if (v.readyState >= 2) done();",
    "else { v.addEventListener('loadeddata', done); v.addEventListener('error', done); }})"
  ))
  message(
    "video: duration ",
    facts$duration,
    " s, ",
    facts$width,
    " x ",
    facts$height,
    ", readyState ",
    facts$readyState,
    if (!is.null(facts$error)) paste0(", error ", facts$error)
  )
  # Play two seconds and read each presented frame's media time: steps of 1/30 s mean a steady 30 fps file.
  steps <- evaluate(paste(
    "new Promise(r => { const v = document.getElementById('v'); const seen = [];",
    "const tick = (now, meta) => { seen.push(meta.mediaTime);",
    "if (seen.length < 40) v.requestVideoFrameCallback(tick);",
    "else { v.pause(); const d = seen.slice(1).map((x, i) => x - seen[i]);",
    "r({min: Math.min(...d), median: d.sort((a, b) => a - b)[d.length >> 1], max: Math.max(...d)}); } };",
    "v.currentTime = 20;",
    "v.addEventListener('seeked', () => { v.requestVideoFrameCallback(tick); v.play(); }, {once: true}); })"
  ))
  message(sprintf(
    paste(
      "presented frame steps (s): min %.4f, median %.4f, max %.4f",
      "(1/30 = 0.0333; a skipped frame while playing shows as 0.0667)"
    ),
    steps$min,
    steps$median,
    steps$max
  ))
  for (time in times) {
    evaluate(sprintf(
      paste(
        "new Promise(r => { const v = document.getElementById('v');",
        "v.addEventListener('seeked', () => r(true), {once: true}); v.currentTime = %s; })"
      ),
      time
    ))
    Sys.sleep(0.3)
    shot <- session$Page$captureScreenshot(format = "png")
    path <- file.path(out_dir, sprintf("video-%05.2f.png", time))
    writeBin(jsonlite::base64_dec(shot$data), path)
    message(path)
  }
  invisible(facts)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

if (step %in% c("all", "html")) {
  build_html()
}
if (step %in% c("all", "video")) {
  record_video()
}
if (step %in% c("all", "verify")) {
  verify_video()
}
if (step == "stills") {
  save_stills(as.numeric(args[-1]))
}
if (step == "stills-tall") {
  save_stills(as.numeric(args[-1]), tall = TRUE)
}
