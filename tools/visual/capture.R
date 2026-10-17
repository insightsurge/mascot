# Offline, deterministic old-engine captures; called by visual-baselines.py.
# Uses a browser only when explicitly requested, never from the package tests.
capture_visuals <- function(config_path) {
  checkmate::assert_file_exists(config_path)
  for (package in c("chromote", "jsonlite")) {
    if (!requireNamespace(package, quietly = TRUE)) cli::cli_abort("Missing package: {package}.")
  }
  config <- jsonlite::fromJSON(config_path, simplifyVector = FALSE)
  checkmate::assert_directory_exists(config$source)
  checkmate::assert_directory_exists(config$output)
  chrome <- chromote::find_chrome()
  checkmate::assert_file_exists(chrome)
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(path = chrome, args = unlist(config$flags)))
  on.exit(browser$close(), add = TRUE)
  session <- chromote::ChromoteSession$new(parent = browser)
  on.exit(session$close(), add = TRUE, after = FALSE)
  session$Emulation$setTimezoneOverride(timezoneId = "UTC")
  session$Emulation$setLocaleOverride(locale = "en-GB")
  session$Emulation$setEmulatedMedia(
    features = list(
      list(name = "prefers-reduced-motion", value = "reduce")
    )
  )
  page <- file.path(config$source, "capture.html")
  scripts <- file.path(
    config$source,
    c(
      "mascot.js",
      "mascot-parts.js",
      "mascot-geometry.js",
      "mascot-faces.js",
      "mascot-motion.js",
      "mascot-player.js"
    )
  )
  writeLines(
    c(
      '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Tessa capture</title>',
      "<style>html,body{margin:0}canvas{display:block}</style></head><body>",
      '<script type="application/json" data-mascot-character="tessa">',
      readLines(file.path(config$source, "tessa.json"), warn = FALSE),
      "</script>",
      if (file.exists(file.path(config$source, "classic.json"))) {
        unlist(lapply(c("classic", "screen"), function(id) {
          c(
            sprintf('<script type="application/json" data-mascot-kit="%s">', id),
            readLines(file.path(config$source, paste0(id, ".json"))),
            "</script>"
          )
        }))
      },
      sprintf('<script src="file://%s"></script>', normalizePath(scripts, winslash = "/")),
      "</body></html>"
    ),
    page
  )
  event <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(event)
  evaluate <- function(js) {
    checkmate::assert_string(js)
    response <- session$Runtime$evaluate(js, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(response$exceptionDetails)) {
      cli::cli_abort("Capture JS failed: {response$exceptionDetails$exception$description}")
    }
    response$result$value
  }
  version <- session$Browser$getVersion()
  runtime <- list(
    chromote = as.character(utils::packageVersion("chromote")),
    chrome = version$product,
    chrome_js = version$jsVersion,
    user_agent = version$userAgent,
    platform = Sys.info()[["sysname"]],
    machine = Sys.info()[["machine"]],
    chrome_path = normalizePath(chrome, winslash = "/")
  )
  # Verify the browser build before producing any image.
  if (!is.null(config$chrome) && !identical(config$chrome, runtime$chrome)) {
    cli::cli_abort("Chrome build differs from the profile lock.")
  }
  if (!is.null(config$chromote) && !identical(config$chromote, runtime$chromote)) {
    cli::cli_abort("chromote differs from the profile lock.")
  }
  cases <- list()
  for (dpr in c(1L, 2L)) {
    session$Emulation$setDeviceMetricsOverride(width = 1280L, height = 960L, deviceScaleFactor = dpr, mobile = FALSE)
    for (mode in c("light", "dark")) {
      session$Emulation$setEmulatedMedia(
        features = list(
          list(name = "prefers-reduced-motion", value = "reduce"),
          list(name = "prefers-color-scheme", value = mode)
        )
      )
      for (size in c(160L, 96L, 24L)) {
        for (mood in c("idle", "thinking", "happy", "worried", "celebrating")) {
          name <- sprintf("tessa-%s-%s-%d-dpr%d.png", mood, mode, size, dpr)
          # Same native palette in both modes (old-main has no native dark override).
          # The backdrop is explicit and part of the comparison, as in the host defaults.
          result <- evaluate(sprintf(
            paste0(
              "(() => {document.querySelector('canvas')?.remove();const c=document.createElement('canvas');",
              "c.width=%d;c.height=%d;c.style.width='%dpx';c.style.height='%dpx';document.body.append(c);",
              "const g=c.getContext('2d',{colorSpace:'srgb'});g.fillStyle='%s';g.fillRect(0,0,c.width,c.height);",
              "const o=document.createElement('canvas');o.width=c.width;o.height=c.height;",
              "const og=o.getContext('2d',{colorSpace:'srgb'});og.setTransform(%f,0,0,%f,0,0);",
              "const ch=JSON.parse(document.querySelector('script[data-mascot-character=tessa]').textContent);",
              "const p=mascot.mount(o,ch,{x:150,baseY:270,mood:'%s',band:",
              # The page picks the band from the CSS width: micro below 48, small below 128, full from 128.
              sprintf(
                "'%s'",
                if (size < 48L) {
                  "micro"
                } else if (size < 128L) {
                  "small"
                } else {
                  "full"
                }
              ),
              "});g.drawImage(o,0,0);p.destroy();",
              "return {png:c.toDataURL('image/png'),dpr:devicePixelRatio,width:innerWidth,height:innerHeight};})()"
            ),
            size * dpr,
            size * dpr,
            size,
            size,
            if (mode == "dark") "#212529" else "#ffffff",
            size * dpr / 300,
            size * dpr / 300,
            mood
          ))
          if (!identical(result$dpr, dpr) || result$width != 1280L || result$height != 960L) {
            cli::cli_abort("Browser viewport or DPR differs from the capture settings.")
          }
          jsonlite::base64_dec(sub("^data:image/png;base64,", "", result$png)) |>
            writeBin(file.path(config$output, name))
          cases[[name]] <- list(mood = mood, mode = mode, size = size, dpr = dpr, frame = 0L)
        }
      }
    }
  }
  jsonlite::write_json(
    list(runtime = runtime, cases = cases),
    file.path(config$output, "capture.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  invisible(NULL)
}

capture_visuals(commandArgs(trailingOnly = TRUE)[[1L]])
