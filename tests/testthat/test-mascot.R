describe("mascot()", {
  it("returns the accessible tag structure and a runtime dependency", {
    tag <- mascot(id = "helper")
    expect_s3_class(tag, "shiny.tag")
    expect_identical(tag$name, "div")
    expect_identical(
      tag$attribs,
      list(
        class = "mascot",
        id = "helper",
        tabindex = "-1",
        `data-character` = "tessa",
        `data-mood` = "idle",
        `data-status` = "mood",
        `data-size` = 160,
        `data-simplify-when-small` = "true",
        `data-floating` = "false",
        `data-position` = "bottom-right",
        `data-minimise` = "false",
        `data-drag` = "false",
        `data-reduced` = "auto",
        `data-swap` = "true"
      )
    )
    html <- sub('(?s)(<script[^>]*>).*?(</script>)', '\\1[character JSON]\\2', as.character(tag), perl = TRUE)
    expect_snapshot(cat(html))
    dep <- htmltools::findDependencies(tag)[[1]]
    expect_identical(dep$name, "mascot")
    expect_identical(dep$version, as.character(utils::packageVersion("mascot")))
    expect_identical(dep$script, c("mascot.js", "mascot-draw.js", "mascot-motion.js", "mascot-host.js"))
    expect_identical(dep$stylesheet, "mascot.css")
    expect_identical(dep$package, "mascot")
    expect_false(dep$all_files)
  })
  it("uses equivalent shortcuts and helpers and escapes custom text", {
    expect_identical(
      as.character(mascot(id = "a", mood = "happy", status = "Saved")),
      as.character(mascot(mascot_character(), "a", mascot_mood("happy"), mascot_status("Saved")))
    )
    expect_identical(as.character(mascot(id = "a")), as.character(mascot(id = "a", status = mascot_status())))
    html <- as.character(mascot(id = "a", status = htmltools::HTML("<b>Saved</b>")))
    expect_match(html, 'data-status="custom"', fixed = TRUE)
    expect_match(html, "&lt;b&gt;Saved&lt;/b&gt;", fixed = TRUE)
    expect_match(as.character(mascot(id = "a", mood = "thinking")), '>Thinking</div>', fixed = TRUE)
  })
  it("attributes choice errors to mascot and rejects every invalid argument", {
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "hapy"))
    expect_snapshot(error = TRUE, mascot("missing", "a"))
    expect_error(mascot(), "missing")
    for (id in list("", "has space", "a\nb", 1, NA_character_)) {
      expect_error(mascot(id = id), "Assertion on 'id' failed")
    }
    for (x in list(NULL, 1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot(x, "a"), "character.*non-empty string")
      expect_error(mascot(id = "a", mood = x), "mood.*non-empty string")
    }
    for (x in list(1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot(id = "a", status = x), "mascot_status", fixed = TRUE)
    }
    expect_error(mascot(id = "a", mood = "{oops"), "not a mood", fixed = TRUE)
  })
})

describe("argument converters", {
  it("checks the internal call and argument contracts", {
    expect_error(as_character_arg("tessa", NULL), "'call'")
    expect_error(as_mood_arg("idle", NULL), "'call'")
    expect_error(as_status_arg(NULL, NULL), "'call'")
    expect_error(check_arg("idle", "other", environment()), "'arg'")
    expect_error(check_arg("idle", "mood", NULL), "'call'")
    expect_error(arg_problem("idle", "other"), "'arg'")
  })
})


describe("mascot() bubbles", {
  it("renders escaped text or explicit HTML with an accessible close button", {
    plain <- as.character(mascot(id = "a", bubble = "<b>Ready</b>"))
    expect_match(plain, "&lt;b&gt;Ready&lt;/b&gt;", fixed = TRUE)
    expect_identical(plain, as.character(mascot(id = "a", bubble = mascot_bubble("<b>Ready</b>"))))
    html <- as.character(mascot(id = "a", bubble = mascot_bubble(htmltools::HTML("<b>Ready</b>"), Inf)))
    expect_match(html, '<b>Ready</b>', fixed = TRUE)
    expect_match(html, 'aria-label="Close message"', fixed = TRUE)
    expect_match(html, 'type="button"', fixed = TRUE)
    expect_match(html, 'aria-live="polite"', fixed = TRUE)
    expect_false(grepl('data-duration=', html, fixed = TRUE))
    expect_false(grepl(
      'mascot-bubble-close',
      as.character(mascot(id = "a", bubble = mascot_bubble("Ready", closable = FALSE))),
      fixed = TRUE
    ))
    expect_match(as.character(mascot(id = "a")), 'hidden', fixed = TRUE)
    # Reading order is canvas, status, bubble text, close button; the status is not a tab stop.
    expect_true(regexpr('mascot-canvas', html) < regexpr('mascot-status', html))
    expect_true(regexpr('mascot-status', html) < regexpr('mascot-bubble-text', html))
    expect_true(regexpr('mascot-bubble-text', html) < regexpr('mascot-bubble-close', html))
  })
  it("rejects malformed shortcuts and bubble objects", {
    for (x in list("", 1, NA_character_, c("a", "b"))) {
      expect_error(mascot(id = "a", bubble = x), "bubble.*non-empty string")
    }
    bad <- mascot_bubble("Ready")
    bad$duration <- 0
    expect_error(mascot(id = "a", bubble = bad), "bubble.*valid text")
  })
})

describe("bubble keyboard markup", {
  it("G3 leaves static bubble text out of the tab order", {
    tag <- bubble_tag(mascot_bubble("Ready"))
    text <- tag$children[[1]]$children[[1]]
    expect_identical(text$attribs$class, "mascot-bubble-text")
    expect_null(text$attribs$tabindex)
  })
  it("G4 makes the mascot a programmatic focus target only", {
    expect_identical(mascot(id = "a")$attribs$tabindex, "-1")
  })
})


describe("mascot() tag bubbles", {
  it("R2 renders a deferred tag once at build time and errors on rendering failures", {
    calls <- new.env(parent = emptyenv())
    calls$count <- 0L
    deferred <- htmltools::tagList(htmltools::tagFunction(function() {
      calls$count <- calls$count + 1L
      shiny::tags$strong(paste("Saved", calls$count))
    }))
    html <- as.character(mascot(id = "a", bubble = deferred))
    expect_identical(calls$count, 1L)
    expect_match(html, "<strong>Saved 1</strong>", fixed = TRUE)
    broken <- htmltools::tagList(htmltools::tagFunction(function() stop("Cannot render message")))
    expect_error(mascot(id = "a", bubble = broken), "Cannot render message")
  })
  it("G6 renders tag shortcuts and rejects dependency-bearing tags", {
    expect_match(
      as.character(mascot(id = "a", bubble = shiny::tags$strong("Saved"))),
      "<strong>Saved</strong>",
      fixed = TRUE
    )
    tag <- htmltools::attachDependencies(
      shiny::tags$strong("Saved"),
      htmltools::htmlDependency("bubble-test", "1.0", src = c(file = tempdir()))
    )
    expect_error(mascot(id = "a", bubble = tag), "text.*dependencies.*not supported")
  })
})

describe("message guidance", {
  it("R3 explains state, event messages and actionable message duration in each help page", {
    for (topic in c("mascot", "updateMascot", "mascot_bubble")) {
      path <- system.file("man", paste0(topic, ".Rd"), package = "mascot")
      rd <- if (nzchar(path)) tools::parse_Rd(path) else tools::Rd_db("mascot")[[paste0(topic, ".Rd")]]
      text <- paste(unlist(rd), collapse = "")
      expect_match(text, "always visible", info = topic)
      expect_match(text, "current state", info = topic)
      expect_match(text, "something that happened", info = topic)
      expect_match(text, "duration = Inf", fixed = TRUE, info = topic)
      expect_match(text, "invalid form", info = topic)
    }
  })
})


describe("mascot() size and placement", {
  it("writes data attributes without inline layout styles and normalises shortcuts", {
    tag <- mascot(id = "a", size = mascot_size("20%", 48, FALSE), placement = mascot_placement("top-left", TRUE))
    expect_identical(tag$attribs$`data-size`, "20%")
    expect_identical(tag$attribs$`data-small-screen`, 48)
    expect_identical(tag$attribs$`data-simplify-when-small`, "false")
    expect_identical(tag$attribs$`data-floating`, "true")
    expect_identical(tag$attribs$`data-position`, "top-left")
    expect_identical(tag$attribs$`data-minimise`, "true")
    expect_null(tag$attribs$style)
    expect_identical(
      as.character(mascot(id = "a", size = 96, placement = "bottom-right")),
      as.character(mascot(id = "a", size = mascot_size(96), placement = mascot_placement("bottom-right")))
    )
    expect_error(mascot(id = "a", size = NULL), "size")
    expect_error(mascot(id = "a", size = "24px"), "size.*24px")
    expect_error(mascot(id = "a", placement = list(minimise = TRUE)), "corner")
    expect_snapshot(error = TRUE, mascot(id = "a", placement = "fixed"))
    expect_snapshot(error = TRUE, mascot("helper"))
    expect_snapshot(error = TRUE, mascot())
    expect_snapshot(error = TRUE, mascot("typo", id = "a"))
    expect_error(mascot("{oops}"), "{oops}", fixed = TRUE)
  })
})

describe("mascot() themes", {
  it("embeds both palettes with auto by default and preserves explicit modes", {
    theme <- mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"))
    tag <- mascot(id = "themed", theme = theme)
    scripts <- Filter(function(x) inherits(x, "shiny.tag") && identical(x$name, "script"), tag$children)
    expect_length(scripts, 2)
    wire <- jsonlite::fromJSON(as.character(scripts[[2]]$children[[1]]), simplifyVector = FALSE)
    expect_identical(wire$light, list(body = "#1F6FEB"))
    expect_identical(wire$dark, list(body = "#9EC5FE"))
    expect_identical(wire$mode, "auto")
    expect_false(grepl("data-mascot-theme", as.character(mascot(id = "own")), fixed = TRUE))
    expect_match(
      as.character(mascot(id = "light", theme = mascot_theme(mode = "light"))),
      '"mode":"light"',
      fixed = TRUE
    )
    expect_snapshot(error = TRUE, mascot(id = "bad", theme = list(bdoy = "blue")))
  })
})

describe("mascot() motion", {
  it("serialises motion for static pages and keeps shortcuts equivalent to helpers", {
    expect_identical(mascot(id = "a")$attribs$`data-reduced`, "auto")
    expect_identical(mascot(id = "a", motion = FALSE)$attribs$`data-reduced`, "true")
    expect_identical(mascot(id = "a", motion = mascot_motion(swap = FALSE))$attribs$`data-swap`, "false")
    for (value in c(TRUE, FALSE)) {
      expect_identical(
        as.character(mascot(id = "a", motion = value)),
        as.character(mascot(id = "a", motion = mascot_motion(value)))
      )
    }
    expect_error(mascot(id = "a", motion = "auto"), 'motion.*got "auto"')
    expect_error(mascot(id = "a", motion = NULL), 'motion.*got NULL')
    expect_identical(tail(names(formals(mascot)), 3), c("theme", "motion", "popup_menu"))
  })
})

describe("mascot() popup menu", {
  it("embeds inert menu configuration and keeps no-menu markup unchanged", {
    expect_false(grepl("data-mascot-popup-menu", as.character(mascot(id = "a")), fixed = TRUE))
    html <- as.character(mascot(id = "module-helper", popup_menu = mascot_popup_menu(c(about = "About"))))
    expect_match(html, 'data-mascot-popup-menu=""', fixed = TRUE)
    expect_match(html, '"items":{"about":"About"}', fixed = TRUE)
    expect_error(mascot(id = "a", popup_menu = c("Help")), "items.*names must")
  })
})
