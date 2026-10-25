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
    expect_match(as.character(page), "happy, 96 px, dark", fixed = TRUE)
    tags <- preview_nodes(page, ".mascot")
    expect_identical(vapply(tags, function(x) x$attribs[["data-size"]], numeric(1)), rep(c(160, 160, 96, 24), 10))
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
      c("mascot", "mascot-character-tessa", "mascot-preview")
    )
  })
  it("accepts every helper and preserves status, bubbles and the requested size settings", {
    page <- mascot_preview(
      character = mascot_character(),
      mood = mascot_mood("happy"),
      status = mascot_status("Ready <now>"),
      bubble = mascot_bubble("Check this", duration = Inf),
      size = mascot_size("20%", small_screen = 96),
      theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "dark"),
      motion = mascot_motion_settings(swap = FALSE)
    )
    expect_length(preview_nodes(page, "canvas"), 8)
    expect_match(as.character(page), "Ready &lt;now&gt;", fixed = TRUE)
    expect_match(as.character(page), "happy, 20% of cell width, light", fixed = TRUE)
    tags <- preview_nodes(page, ".mascot")
    expect_identical(tags[[1]]$attribs[["data-size"]], "20%")
    expect_identical(tags[[1]]$attribs[["data-small-screen"]], 96)
    expect_identical(tags[[2]]$attribs[["data-small-screen"]], "auto")
    expect_true(all(vapply(tags, function(x) is.null(x$attribs[["data-simplify-when-small"]]), logical(1))))
    expect_true(all(vapply(tags, function(x) x$attribs[["data-reduced"]] == "auto", logical(1))))
    expect_true(all(vapply(tags, function(x) x$attribs[["data-swap"]] == "false", logical(1))))
    expect_length(preview_nodes(page, ".mascot-preview-no-bubble"), 0)
    # Cells stay pictures: a static page cannot send a click.
    expect_length(Filter(function(x) !is.null(x$attribs[["data-mascot-click"]]), preview_nodes(page, "script")), 0)
    expect_identical(preview_theme(tags[[1]])$light$body, "#1F6FEB")
    expect_identical(preview_theme(tags[[5]])$dark$body, "#9EC5FE")
    expect_identical(preview_theme(tags[[1]])$mode, "light")
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
    expect_match(as.character(page), "--_mascot-preview-light-bg:#FEFEFE", fixed = TRUE)
    theme <- bslib::bs_theme(bg = "#fefefe", fg = "#222222", primary = "#1f6feb", secondary = "#966600")
    dark <- theme_colour(bslib::bs_get_variables(theme, "body-bg-dark")[[1]], "bg")
    expect_match(as.character(page), paste0("--_mascot-preview-dark-bg:", dark), fixed = TRUE)
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
      list(click = structure(list(items = c(about = "About"), extra = 1), class = "mascot_popup_menu")),
      list(size = structure(list(size = 96), class = "mascot_size")),
      list(theme = structure(list(mode = "night"), class = "mascot_theme")),
      list(motion = structure(list(animate = TRUE), class = "mascot_motion_settings"))
    )
    for (args in cases) {
      expect_error(do.call(mascot_preview, args), names(args)[[1]], fixed = TRUE)
    }
    expect_error(mascot_preview(click = c(about = "About")), class = "mascot_error_dots")
    expect_error(mascot_preview(click = mascot_action()), class = "mascot_error_dots")
    expect_error(mascot_preview(theme = list(body = "not-a-colour")), "Colour for role", fixed = TRUE)
  })
})

describe("mascot_preview() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(
      names(formals(mascot_preview)),
      c("character", "...", "mood", "status", "bubble", "size", "theme", "motion")
    )
    expect_error(mascot_preview("tessa", typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_preview("tessa", 1), "Name the optional arguments", class = "mascot_error")
  })
})

describe("preview contrast warning policy", {
  it("warns without development mode unless the option disables warnings, keeping findings", {
    local_mocked_bindings(in_devmode = function() FALSE, .package = "shiny")
    withr::local_options(mascot.contrast_warnings = NULL)
    theme <- mascot_theme(light = list(body = "white"))
    expect_warning(on <- mascot_preview(mood = "idle", theme = theme), class = "mascot_contrast")
    withr::local_options(mascot.contrast_warnings = FALSE)
    expect_silent(off <- mascot_preview(mood = "idle", theme = theme))
    expect_identical(attr(on, "contrast"), attr(off, "contrast"))
    withr::local_options(mascot.contrast_warnings = TRUE)
    expect_warning(mascot_preview(mood = "idle", theme = theme), class = "mascot_warning")
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_preview(character = 1), "character", class = "mascot_error")
  })
})

describe("preview contract", {
  it("removes inert arguments and compares 160, 96 and 24 pixels", {
    expect_false(any(c("placement", "click") %in% names(formals(mascot_preview))))
    expect_error(mascot_preview(placement = "inline"), class = "mascot_error_dots")
    expect_error(mascot_preview(click = "Help"), class = "mascot_error_dots")
    tags <- preview_nodes(mascot_preview(mood = "idle", size = 200), ".mascot")
    expect_identical(vapply(tags, function(x) x$attribs[["data-size"]], numeric(1)), rep(c(200, 160, 96, 24), 2))
  })
})

describe("palette previews", {
  it("accepts a string shortcut without contrast warnings and checks added role colours", {
    withr::local_options(mascot.contrast_warnings = TRUE)
    expect_no_warning(page <- mascot_preview(character = "knurl", theme = "orbit"))
    expect_equal(nrow(attr(page, "contrast")), 0)
    expect_match(as.character(page), '"palette":"orbit"', fixed = TRUE)
    expect_warning(
      page <- mascot_preview(
        character = "knurl",
        theme = mascot_theme(palette = "orbit", light = list(body = "white"))
      ),
      class = "mascot_contrast"
    )
    expect_identical(attr(page, "contrast")$role, "body")
    expect_error(mascot_preview(character = "knurl", theme = "oribt"), "oribt.*knurl.*orbit.*Did you mean")
  })
})

describe("mascot_preview() mood errors", {
  it("names the valid moods for a malformed mood", {
    expect_error(mascot_preview(mood = "ha!py"), "Choose.*idle.*celebrating", class = "mascot_error")
  })
})
