# Select actual matches, rather than allTags(), which returns the query's roots.
preview_nodes <- function(page, selector) {
  unname(htmltools::tagQuery(page)$find(selector)$selectedTags())
}

preview_theme <- function(tag) {
  script <- Filter(function(x) !is.null(x$attribs[["data-mascot-theme"]]), preview_nodes(tag, "script"))[[1]]
  jsonlite::fromJSON(as.character(script$children[[1]]), simplifyVector = FALSE)
}

describe("mascot_preview()", {
  it("returns a static browsable page with every mood and four sizes in both modes", {
    page <- mascot_preview()
    expect_s3_class(page, "shiny.tag.list")
    expect_true(htmltools::is.browsable(page))
    expect_length(preview_nodes(page, "canvas"), 40)
    expect_length(preview_nodes(page, "tbody"), 2)
    expect_length(preview_nodes(page, "tbody tr"), 10)
    expect_length(preview_nodes(page, "thead th"), 10)
    expect_length(preview_nodes(page, "tbody th"), 10)
    expect_length(preview_nodes(page, "h1"), 1)
    expect_match(as.character(page), "happy, 48 px, dark", fixed = TRUE)
    tags <- preview_nodes(page, ".mascot")
    expect_identical(vapply(tags, function(x) x$attribs[["data-size"]], numeric(1)), rep(c(160, 48, 32, 24), 10))
    expect_identical(
      vapply(tags, function(x) x$attribs[["data-mood"]], character(1)),
      rep(rep(mascot_moods()$name, each = 4), 2)
    )
    expect_true(all(vapply(tags, function(x) x$attribs[["data-reduced"]] == "true", logical(1))))
    expect_true(all(vapply(tags, function(x) x$attribs[["data-floating"]] == "false", logical(1))))
    expect_identical(vapply(tags, function(x) preview_theme(x)$mode, character(1)), rep(c("light", "dark"), each = 20))
    contrast <- attr(page, "contrast")
    expect_named(contrast, c("role", "colour", "background", "ratio", "mode"))
    expect_equal(nrow(contrast), 0)
    expect_type(contrast$ratio, "double")
    expect_match(as.character(page), "No supplied colours fall below 3:1", fixed = TRUE)
    expect_setequal(
      vapply(htmltools::findDependencies(page), function(x) x$name, character(1)),
      c("mascot", "mascot-preview")
    )
  })
  it("accepts every helper and preserves status, bubbles and the requested size settings", {
    page <- mascot_preview(
      character = mascot_character(),
      mood = mascot_mood("happy"),
      status = mascot_status("Ready <now>"),
      bubble = mascot_bubble("Check this", duration = Inf),
      size = mascot_size("20%", small_screen = 96),
      placement = mascot_placement("bottom-right", minimise = TRUE),
      theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "dark"),
      motion = mascot_motion(swap = FALSE),
      popup_menu = mascot_popup_menu(c(about = "About"))
    )
    expect_length(preview_nodes(page, "canvas"), 8)
    expect_match(as.character(page), "Floating placement is shown inline", fixed = TRUE)
    expect_match(as.character(page), "Click menus need Shiny", fixed = TRUE)
    expect_match(as.character(page), "Ready &lt;now&gt;", fixed = TRUE)
    expect_match(as.character(page), "happy, 20% of cell width, light", fixed = TRUE)
    tags <- preview_nodes(page, ".mascot")
    expect_identical(tags[[1]]$attribs[["data-size"]], "20%")
    expect_identical(tags[[1]]$attribs[["data-small-screen"]], 96)
    expect_null(tags[[2]]$attribs[["data-small-screen"]])
    expect_true(all(vapply(tags, function(x) is.null(x$attribs[["data-simplify-when-small"]]), logical(1))))
    expect_true(all(vapply(tags, function(x) x$attribs[["data-reduced"]] == "auto", logical(1))))
    expect_true(all(vapply(tags, function(x) x$attribs[["data-swap"]] == "false", logical(1))))
    expect_length(preview_nodes(page, ".mascot-preview-no-bubble"), 0)
    expect_length(Filter(function(x) !is.null(x$attribs[["data-mascot-popup-menu"]]), preview_nodes(page, "script")), 8)
    expect_identical(preview_theme(tags[[1]])$light$body, "#1F6FEB")
    expect_identical(preview_theme(tags[[5]])$dark$body, "#9EC5FE")
    expect_identical(preview_theme(tags[[1]])$mode, "light")
  })
  it("warns once, keeps colours and lists independent contrast findings in R and on the page", {
    warnings <- character()
    page <- withCallingHandlers(
      mascot_preview(theme = mascot_theme(light = list(body = "white"), dark = list(rim = "#212529"))),
      warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
    expect_length(warnings, 1)
    expect_match(warnings, "colours are kept", fixed = TRUE)
    contrast <- attr(page, "contrast")
    expect_identical(contrast$role, c("body", "rim"))
    expect_identical(contrast$colour, c("#FFFFFF", "#212529"))
    expect_identical(contrast$background, c("#FFFFFF", "#212529"))
    expect_identical(contrast$mode, c("light", "dark"))
    expect_equal(contrast$ratio, c(1, 1))
    expect_length(preview_nodes(page, ".mascot-preview-contrast li"), 2)
    expect_match(as.character(page), "body: #FFFFFF against #FFFFFF, 1.00:1 (light).", fixed = TRUE)
    expect_identical(preview_theme(preview_nodes(page, ".mascot")[[1]])$light$body, "#FFFFFF")
    expect_snapshot({
      page <- mascot_preview(mood = "idle", theme = list(body = "white"))
    })
  })
  it("uses bslib's separate light and dark surfaces without requiring an app", {
    skip_if_not_installed("bslib")
    expect_warning(
      page <- mascot_preview(
        mood = "happy",
        theme = bslib::bs_theme(
          bg = "#fefefe",
          fg = "#222222",
          primary = "#1f6feb",
          secondary = "#966600"
        )
      ),
      class = "mascot_contrast"
    )
    expect_match(as.character(page), "--mascot-preview-light-bg:#FEFEFE", fixed = TRUE)
    theme <- bslib::bs_theme(bg = "#fefefe", fg = "#222222", primary = "#1f6feb", secondary = "#966600")
    dark <- theme_colour(bslib::bs_get_variables(theme, "body-bg-dark")[[1]], "bg")
    expect_match(as.character(page), paste0("--mascot-preview-dark-bg:", dark), fixed = TRUE)
    wire <- preview_theme(preview_nodes(page, ".mascot")[[1]])
    expect_identical(wire$brand, list(primary = "#1F6FEB", secondary = "#966600"))
    # bslib derives a dark background from a near-white bg; both brand colours are too dark for it.
    expect_identical(attr(page, "contrast")$mode, c("dark", "dark"))
    expect_identical(attr(page, "contrast")$background, rep(dark, 2))
    low <- suppressWarnings(mascot_preview(
      mood = "idle",
      theme = bslib::bs_theme(
        bg = "#FFFFFF",
        fg = "#212529",
        primary = "white",
        secondary = "white"
      )
    ))
    expect_equal(nrow(attr(low, "contrast")), 2)
    expect_true(all(attr(low, "contrast")$ratio == 1))
  })
  it("explains browser-only CSS checks and does not report a shadowed map as the drawn colour", {
    page <- mascot_preview(theme = mascot_theme(light = list(body = "white"), css = list(body = "--team-blue")))
    expect_equal(nrow(attr(page, "contrast")), 0)
    expect_match(as.character(page), "Experimental CSS colours are checked in the browser console", fixed = TRUE)
    expect_identical(preview_theme(preview_nodes(page, ".mascot")[[1]])$css, list(body = "--team-blue"))
  })
  it("preserves unrelated warnings while aggregating only colour-contrast warnings", {
    local_mocked_bindings(as_theme_arg = function(x, ...) {
      if (!is.null(x)) {
        warning("Upstream theme warning: contrast below 3:1")
      }
      NULL
    })
    expect_warning(
      mascot_preview(mood = "idle", theme = mascot_theme()),
      "Upstream theme warning: contrast below 3:1",
      fixed = TRUE
    )
  })
  it("generates unique ids when two previews share a page and never launches or saves it", {
    local_mocked_bindings(
      runApp = function(...) stop("must not launch Shiny"),
      .package = "shiny"
    )
    local_mocked_bindings(
      save_html = function(...) stop("must not save a page"),
      .package = "htmltools"
    )
    first <- mascot_preview(mood = "idle", size = 48, motion = TRUE)
    second <- mascot_preview(mood = "happy")
    ids <- vapply(preview_nodes(htmltools::tagList(first, second), ".mascot"), function(x) x$attribs$id, character(1))
    expect_identical(anyDuplicated(ids), 0L)
    expect_length(ids, 16)
    expect_identical(preview_nodes(first, ".mascot")[[1]]$attribs[["data-reduced"]], "auto")
  })
  it("shares build-time errors for every shortcut and malformed helper", {
    cases <- list(
      list(character = NULL),
      list(character = "typo"),
      list(mood = "typo"),
      list(mood = 1),
      list(status = 1),
      list(bubble = 1),
      list(size = 23),
      list(size = NULL),
      list(size = Inf),
      list(placement = "middle"),
      list(placement = list(drag = TRUE)),
      list(theme = list(eye_whit = "red")),
      list(theme = list(light = "red")),
      list(motion = NULL),
      list(motion = "yes"),
      list(popup_menu = structure(list(items = c(about = "About"), extra = 1), class = "mascot_popup_menu")),
      list(size = structure(list(size = 96), class = "mascot_size")),
      list(theme = structure(list(mode = "night"), class = "mascot_theme")),
      list(motion = structure(list(animate = TRUE), class = "mascot_motion"))
    )
    for (args in cases) {
      expect_error(do.call(mascot_preview, args), names(args)[[1]], fixed = TRUE)
    }
    expect_error(mascot_preview(popup_menu = c("About")), "items", fixed = TRUE)
    expect_error(mascot_preview(theme = list(body = "not-a-colour")), "Colour for role", fixed = TRUE)
    expect_snapshot(error = TRUE, mascot_preview(character = "typo"))
    expect_snapshot(error = TRUE, mascot_preview(mood = "typo"))
    expect_snapshot(error = TRUE, mascot_preview(theme = list(eye_whit = "red")))
  })
  it("checks the internal table and report inputs before rendering", {
    backgrounds <- c(light = "#FFFFFF", dark = "#212529")
    expect_error(preview_contrast(1, backgrounds), "theme", fixed = TRUE)
    expect_error(preview_contrast(NULL, 1), "backgrounds", fixed = TRUE)
    expect_error(preview_contrast(NULL, c(a = "white", b = "black")), "backgrounds", fixed = TRUE)
    expect_error(preview_contrast_labels(1), "contrast", fixed = TRUE)
    args <- list(
      character = mascot_character(),
      moods = "idle",
      status = mascot_status(),
      bubble = mascot_bubble(),
      sizes = list(mascot_size()),
      labels = "160 px",
      theme = NULL,
      motion = FALSE,
      popup_menu = NULL,
      mode = "light",
      prefix = "comparison"
    )
    bad <- list(
      character = 1,
      moods = NULL,
      status = 1,
      bubble = 1,
      sizes = 1,
      labels = 1,
      theme = 1,
      mode = "night",
      prefix = 1
    )
    for (arg in names(bad)) {
      invalid <- args
      invalid[arg] <- bad[arg]
      expect_error(do.call(preview_panel, invalid), arg, fixed = TRUE)
    }
  })
})

# Save only in a test-owned temporary directory; constructing a preview itself writes nothing.
local_preview_page <- function(page, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file <- file.path(dir, "preview.html")
  htmltools::save_html(page, file, libdir = file.path(dir, "lib"))
  session <- chromote::ChromoteSession$new(parent = test_browser())
  withr::defer(session$close(), envir = env)
  session$Emulation$setDeviceMetricsOverride(width = 1500, height = 1000, deviceScaleFactor = 1, mobile = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(file)))
  evaluate <- function(code) {
    result <- session$Runtime$evaluate(code, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(result$exceptionDetails)) {
      stop(result$exceptionDetails$exception$description)
    }
    result$result$value
  }
  evaluate(paste0(
    "new Promise((resolve,reject)=>{const start=performance.now();const check=()=>{",
    "if(document.readyState==='complete' && document.querySelector('.mascot')?.dataset.shownMood)",
    "requestAnimationFrame(()=>requestAnimationFrame(resolve));",
    "else if(performance.now()-start>15000)reject(new Error('preview did not mount'));",
    "else requestAnimationFrame(check)};check()})"
  ))
  attr(evaluate, "session") <- session
  evaluate
}

describe("mascot_preview() in Chrome", {
  it("P1 draws every labelled mood and size with genuinely light/dark surfaces and steady faces", {
    skip_without_chrome()
    js <- local_preview_page(mascot_preview())
    expect_identical(js("document.querySelectorAll('.mascot canvas').length"), 40L)
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot')).map(el=>el.dataset.shownMood)"), use.names = FALSE),
      rep(rep(mascot_moods()$name, each = 4), 2)
    )
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(160L, 48L, 32L, 24L), 10)
    )
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot-status')).map(el=>el.textContent)"), use.names = FALSE),
      rep(rep(c("Idle", "Thinking", "Happy", "Worried", "Celebrating"), each = 4), 2)
    )
    expect_identical(
      unlist(
        js(
          "Array.from(document.querySelectorAll('.mascot-preview-mode')).map(el=>getComputedStyle(el).backgroundColor)"
        ),
        use.names = FALSE
      ),
      c("rgb(255, 255, 255)", "rgb(33, 37, 41)")
    )
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>mascot.host.state(el).motion.reduced===true)"
    ))
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>el.dataset.floating==='false' && el.querySelector('canvas').getBoundingClientRect().width>=24)"
    ))
    expect_identical(js("typeof window.Shiny"), "undefined")
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot-bubble-region')).every(el=>getComputedStyle(el).height==='0px' && getComputedStyle(el).visibility==='hidden')"
    ))
  })
  it("P2 draws both supplied palettes despite source mode, keeps warnings and static placement/menu semantics", {
    skip_without_chrome()
    page <- suppressWarnings(mascot_preview(
      mood = "happy",
      size = 96,
      placement = "bottom-right",
      status = "Review complete",
      theme = mascot_theme(
        light = list(body = "white", sleeve = "#B53D78"),
        dark = list(body = "#F2A6CF"),
        mode = "light"
      ),
      popup_menu = mascot_popup_menu(c(about = "About"))
    ))
    js <- local_preview_page(page)
    expect_identical(
      unlist(
        js("Array.from(document.querySelectorAll('.mascot')).map(el=>mascot.host.state(el).colours.body)"),
        use.names = FALSE
      ),
      rep(c("#FFFFFF", "#F2A6CF"), each = 4)
    )
    expect_identical(js("document.querySelectorAll('.mascot-menu-button').length"), 0L)
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot')).every(el=>!mascot.host.state(el).placement.floating)"
    ))
    expect_true(js(
      "Array.from(document.querySelectorAll('.mascot-status')).every(el=>el.textContent==='Review complete')"
    ))
    expect_identical(
      js("document.querySelector('.mascot-preview-contrast li').textContent"),
      "body: #FFFFFF against #FFFFFF, 1.00:1 (light)."
    )
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(96L, 48L, 32L, 24L), 2)
    )
  })
  it("P3 keeps percentage and narrow-screen sizes in the requested column only", {
    skip_without_chrome()
    js <- local_preview_page(mascot_preview(
      mood = "idle",
      size = mascot_size("20%", small_screen = 96)
    ))
    widths <- unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE)
    expect_identical(widths[c(2:4, 6:8)], rep(c(48L, 32L, 24L), 2))
    expect_true(all(widths[c(1, 5)] >= 24))
    session <- attr(js, "session")
    session$Emulation$setDeviceMetricsOverride(width = 400, height = 900, deviceScaleFactor = 1, mobile = FALSE)
    js("new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))")
    expect_identical(
      unlist(js("Array.from(document.querySelectorAll('.mascot canvas')).map(el=>el.width)"), use.names = FALSE),
      rep(c(96L, 48L, 32L, 24L), 2)
    )
    expect_true(js("Array.from(document.querySelectorAll('.mascot')).every(el=>!('detail' in mascot.host.state(el)))"))
  })
})

describe("bslib preview dark surface in Chrome", {
  it("P213 paints the dark panel with body-bg-dark", {
    skip_without_chrome()
    skip_if_not_installed("bslib")
    theme <- bslib::bs_theme(version = 5, bg = "#fefefe", fg = "#222222")
    background <- bslib::bs_get_variables(theme, "body-bg-dark")[[1]]
    rgb <- grDevices::col2rgb(background)
    expected <- paste0("rgb(", paste(rgb[, 1], collapse = ", "), ")")
    expect_warning(page <- mascot_preview(mood = "idle", theme = theme), class = "mascot_contrast")
    js <- local_preview_page(page)
    expect_identical(
      js("getComputedStyle(document.querySelector('.mascot-preview-mode[data-bs-theme=dark]')).backgroundColor"),
      expected
    )
  })
})
