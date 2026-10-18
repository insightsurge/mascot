# The engine files, in load order: the legacy drawing and motion files, the format-v1 modules (parts, geometry and faces
# before the player that uses them), the format-v1 player, then the host that mounts either.
engine_scripts <- c(
  "mascot.js",
  "mascot-draw.js",
  "mascot-parts.js",
  "mascot-geometry.js",
  "mascot-faces.js",
  "mascot-motion.js",
  "mascot-player.js",
  "mascot-host.js"
)

describe("mascot()", {
  it("returns the accessible tag structure and a runtime dependency", {
    tag <- mascot(id = "helper")
    expect_s3_class(tag, "shiny.tag")
    expect_identical(tag$name, "div")
    expect_identical(
      tag$attribs[names(tag$attribs) != "data-mount-token"],
      list(
        class = "mascot",
        id = "helper",
        tabindex = "-1",
        `data-character` = "tessa",
        `data-mood` = "idle",
        `data-status` = "mood",
        `data-size` = 160,
        `data-small-screen` = "auto",
        `data-floating` = "true",
        `data-position` = "bottom-right",
        `data-minimise` = "true",
        `data-drag` = "false",
        `data-reduced` = "auto",
        `data-idle` = "true",
        `data-mood-change` = "true",
        `data-gestures` = "true",
        `data-swap` = "true",
        `data-minimising` = "true",
        `data-restoring` = "true",
        `data-messages` = "bubble,tooltip,menu",
        `data-others` = "true"
      )
    )
    html <- sub('(?s)(<script[^>]*>).*?(</script>)', '\\1[character JSON]\\2', as.character(tag), perl = TRUE)
    html <- sub('(?s)(<script[^>]*data-mascot-baseline[^>]*>).*?(</script>)', '\\1[UI baseline]\\2', html, perl = TRUE)
    html <- sub('data-mount-token="[^"]+"', 'data-mount-token="[UI specification token]"', html)
    expect_snapshot(cat(html))
    dep <- htmltools::findDependencies(tag)[[1]]
    expect_identical(dep$name, "mascot")
    expect_identical(dep$version, as.character(utils::packageVersion("mascot")))
    expect_identical(dep$script, engine_scripts)
    # Every listed file ships with the package, so a page works offline.
    expect_true(all(file.exists(file.path(system.file("www", package = "mascot"), dep$script))))
    expect_identical(dep$stylesheet, "mascot.css")
    expect_identical(dep$package, "mascot")
    expect_false(dep$all_files)
  })
  it("uses equivalent shortcuts and helpers and escapes custom text", {
    expect_identical(
      as.character(mascot(id = "a", mood = "happy", status = "Saved")),
      as.character(mascot(
        "a",
        character = mascot_character(),
        mood = mascot_mood("happy"),
        status = mascot_status("Saved")
      ))
    )
    expect_identical(as.character(mascot(id = "a")), as.character(mascot(id = "a", status = mascot_status())))
    html <- as.character(mascot(id = "a", status = htmltools::HTML("<b>Saved</b>")))
    expect_match(html, 'data-status="custom"', fixed = TRUE)
    expect_match(html, "&lt;b&gt;Saved&lt;/b&gt;", fixed = TRUE)
    expect_match(
      as.character(mascot(id = "a", mood = "thinking")),
      '>Working out how the parts fit.</div>',
      fixed = TRUE
    )
  })
  it("bounds UI payloads before retaining a template", {
    expect_error(mascot("bounded", status = strrep("x", 262145)), "capacity", class = "mascot_error")
    expect_error(mascot("bounded", bubble = strrep("x", 262145)), "capacity", class = "mascot_error")
  })
  it("attributes choice errors to mascot and rejects every invalid argument", {
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "hapy"))
    expect_snapshot(error = TRUE, mascot(id = "a", mood = "ha!py"))
    expect_snapshot(error = TRUE, mascot("a", character = "missing"))
    expect_error(mascot(), "missing", class = "mascot_error")
    for (id in list("", "has space", "a\nb", 1, NA_character_)) {
      expect_error(mascot(id = id), "Assertion on 'id' failed")
    }
    for (x in list(NULL, 1, "", NA_character_, c("a", "b"))) {
      expect_error(mascot("a", character = x), "Assertion on 'character' failed")
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

describe("abort_dots()", {
  it("rejects an invalid value for each argument with its checkmate message", {
    expect_error(abort_dots(1, 1L, "tooltip", environment()), "Assertion on 'extras' failed")
    expect_error(abort_dots("extra", 0L, "tooltip", environment()), "Assertion on 'n' failed")
    expect_error(abort_dots("extra", 1L, character(), environment()), "Assertion on 'valid' failed")
    expect_error(abort_dots("extra", 1L, "tooltip", NULL), "Assertion on 'call' failed")
  })
})


describe("mascot() bubbles", {
  it("renders escaped text or explicit HTML with an accessible close button", {
    plain <- as.character(mascot(id = "a", bubble = "<b>Ready</b>"))
    expect_match(plain, "&lt;b&gt;Ready&lt;/b&gt;", fixed = TRUE)
    expect_identical(plain, as.character(mascot(id = "a", bubble = mascot_bubble("<b>Ready</b>"))))
    html <- as.character(mascot(id = "a", bubble = mascot_bubble(htmltools::HTML("<b>Ready</b>"), duration = Inf)))
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
    for (topic in c("mascot", "update_mascot", "mascot_bubble")) {
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
    tag <- mascot(
      id = "a",
      size = mascot_size("20%", small_screen = 48),
      placement = mascot_placement("top-left", minimise = TRUE)
    )
    expect_identical(tag$attribs$`data-size`, "20%")
    expect_identical(tag$attribs$`data-small-screen`, 48)
    expect_null(tag$attribs$`data-simplify-when-small`)
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
    expect_snapshot(error = TRUE, mascot(id = "a", placement = "fixed"))
    expect_identical(mascot("helper")$attribs$id, "helper")
    expect_snapshot(error = TRUE, mascot())
    expect_snapshot(error = TRUE, mascot("a", character = "typo"))
    expect_identical(mascot("{oops}")$attribs$id, "{oops}")
  })
  it("silently disables inline defaults and informs about explicit list controls", {
    for (placement in list("inline", mascot_placement("inline"), list(position = "inline"))) {
      expect_silent(tag <- mascot(id = "a", placement = placement))
      expect_identical(tag$attribs$`data-minimise`, "false")
      expect_identical(tag$attribs$`data-drag`, "false")
    }
    for (controls in list(
      list(minimise = TRUE),
      list(minimise = FALSE),
      list(drag = "snap"),
      list(drag = "free"),
      list(drag = "none")
    )) {
      expect_message(
        tag <- mascot(id = "a", placement = c(list(position = "inline"), controls)),
        paste0(names(controls), ".*no effect.*inline"),
        class = "mascot_placement_ignored"
      )
      expect_identical(tag$attribs$`data-minimise`, "false")
      expect_identical(tag$attribs$`data-drag`, "false")
    }
    expect_snapshot(invisible(mascot(id = "a", placement = list(position = "inline", minimise = TRUE))))
    expect_snapshot(invisible(mascot(id = "a", placement = list(position = "inline", drag = "snap"))))
    expect_snapshot(invisible(mascot(id = "a", placement = mascot_placement("inline", minimise = TRUE))))
    expect_snapshot(invisible(mascot(id = "a", placement = mascot_placement("inline", drag = "free"))))
    expect_identical(mascot(id = "a", placement = list(minimise = FALSE))$attribs$`data-minimise`, "false")
  })
})

describe("mascot() themes", {
  it("embeds both palettes with auto by default and preserves explicit modes", {
    theme <- mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"))
    tag <- mascot(id = "themed", theme = theme)
    scripts <- Filter(
      function(x) {
        inherits(x, "shiny.tag") && identical(x$name, "script") && !"data-mascot-baseline" %in% names(x$attribs)
      },
      tag$children
    )
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
    expect_identical(mascot(id = "a", motion = mascot_motion_settings(swap = FALSE))$attribs$`data-swap`, "false")
    expect_identical(
      as.character(mascot(id = "a", motion = TRUE)),
      as.character(mascot(id = "a", motion = mascot_motion_settings()))
    )
    off <- mascot(id = "a", motion = FALSE)$attribs
    still <- mascot(id = "a", motion = mascot_motion_settings(others = FALSE))$attribs
    expect_identical(
      off[!names(off) %in% c("data-reduced", "data-mount-token")],
      still[!names(still) %in% c("data-reduced", "data-mount-token")]
    )
    expect_error(mascot(id = "a", motion = "auto"), 'motion.*got "auto"')
    expect_error(mascot(id = "a", motion = NULL), 'motion.*got NULL')
    expect_identical(tail(names(formals(mascot)), 3), c("theme", "motion", "click"))
  })
})

describe("mascot() click", {
  it("is a picture without a click: an image that is no keyboard stop", {
    html <- as.character(mascot(id = "a"))
    expect_false(grepl("data-mascot-click", html, fixed = TRUE))
    expect_match(
      html,
      '<canvas class="mascot-canvas" role="img" aria-label="Tessa, Resting, ready for the next piece."></canvas>',
      fixed = TRUE
    )
    expect_identical(html, as.character(mascot(id = "a", click = NULL)))
  })
  it("embeds an action or a menu as inert configuration", {
    html <- as.character(mascot(id = "module-helper", click = "Open help"))
    expect_match(html, 'data-mascot-click=""', fixed = TRUE)
    expect_match(html, '{"type":"action","label":"Open help","tooltip":true,"disabled":false}', fixed = TRUE)
    html <- as.character(mascot(id = "module-helper", click = mascot_popup_menu(c(about = "About"))))
    expect_match(html, '"type":"menu","items":{"about":"About"}', fixed = TRUE)
    expect_false(grepl("data-mascot-click", as.character(mascot(id = "a", click = mascot_action())), fixed = TRUE))
    expect_error(mascot(id = "a", click = c(about = "Help")), "named vector.*mascot_popup_menu")
  })
})

describe("mascot() clicks in a Shiny browser (#257)", {
  it("counts every activation in a module, menus included, and sends nothing without a click", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(
          mascot(id = ns("picture"), placement = "inline"),
          mascot(id = ns("helper"), placement = "inline", click = "Open help"),
          shiny::textOutput(ns("clicks")),
          mascot(id = ns("menu"), placement = "inline", click = mascot_popup_menu(c(about = "About"))),
          shiny::textOutput(ns("menu_clicks"))
        )
      }
      shiny::shinyApp(shiny::fluidPage(ui("module")), function(input, output, session) {
        shiny::moduleServer("module", function(input, output, session) {
          output$clicks <- shiny::renderText(if (is.null(input$helper_click)) 0 else input$helper_click)
          output$menu_clicks <- shiny::renderText(if (is.null(input$menu_click)) 0 else input$menu_click)
        })
      })
    })
    withr::defer(app$stop())
    app$wait_for_js("!!document.querySelector('#module-menu .mascot-menu-toggle')")
    # Given an action: each click and each Enter on it reaches its module's server.
    app$click(selector = "#module-helper .mascot-button")
    app$wait_for_js("document.getElementById('module-clicks').textContent === '1'")
    app$click(selector = "#module-helper .mascot-button")
    app$wait_for_js("document.getElementById('module-clicks').textContent === '2'")
    app$run_js(
      "const button=document.querySelector('#module-helper .mascot-button');button.focus();
      button.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));"
    )
    app$wait_for_js("document.getElementById('module-clicks').textContent === '3'")
    # With a menu, opening and closing it both count.
    app$click(selector = "#module-menu .mascot-menu-toggle")
    app$wait_for_js("mascot.host.state(document.getElementById('module-menu')).menuOpen")
    app$wait_for_js("document.getElementById('module-menu_clicks').textContent === '1'")
    app$click(selector = "#module-menu .mascot-menu-toggle")
    app$wait_for_js("!mascot.host.state(document.getElementById('module-menu')).menuOpen")
    app$wait_for_js("document.getElementById('module-menu_clicks').textContent === '2'")
    # A picture sends nothing.
    app$click(selector = "#module-picture canvas")
    app$wait_for_idle()
    expect_null(app$get_value(input = "module-picture_click"))
  })
})

describe("mascot() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(
      names(formals(mascot)),
      c("id", "...", "character", "mood", "status", "bubble", "size", "placement", "theme", "motion", "click")
    )
    expect_error(mascot("helper", typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot("helper", 1), "Name the optional arguments", class = "mascot_error")
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot(id = 1), "id", class = "mascot_error")
  })
})


describe("with_mascot_asserts()", {
  it("keeps the original assertion message once and adds mascot_error", {
    value <- 1
    original <- tryCatch(checkmate::assert_string(value), error = identity)
    wrapped <- tryCatch(
      with_mascot_asserts({
        checkmate::assert_string(value)
      }),
      error = identity
    )

    expect_s3_class(wrapped, "mascot_error")
    expect_s3_class(wrapped, "error")
    expect_identical(
      trimws(cli::ansi_strip(strsplit(conditionMessage(wrapped), "\n", fixed = TRUE)[[1]])),
      trimws(strsplit(conditionMessage(original), "\n", fixed = TRUE)[[1]])
    )
    expect_null(wrapped$parent)
    expect_snapshot(conditionMessage(wrapped))
  })
  it("also keeps every line of a union assertion message", {
    value <- 1
    original <- tryCatch(
      checkmate::assert(
        checkmate::check_flag(value),
        checkmate::check_string(value),
        .var.name = "value"
      ),
      error = identity
    )
    wrapped <- tryCatch(
      with_mascot_asserts({
        checkmate::assert(checkmate::check_flag(value), checkmate::check_string(value), .var.name = "value")
      }),
      error = identity
    )
    expect_s3_class(wrapped, "mascot_error")
    expect_s3_class(wrapped, "error")
    expect_identical(
      trimws(cli::ansi_strip(strsplit(conditionMessage(wrapped), "\n", fixed = TRUE)[[1]])),
      trimws(strsplit(conditionMessage(original), "\n", fixed = TRUE)[[1]])
    )
  })
  it("attributes assertion errors to the public caller", {
    error <- tryCatch(mascot(id = 1), error = identity)
    expect_identical(conditionCall(error)[[1L]], quote(mascot))
  })
  it("leaves non-assertion errors and errors from argument evaluation untouched", {
    original <- simpleError("An unrelated failure")
    error <- tryCatch(with_mascot_asserts(stop(original)), error = identity)
    expect_identical(error, original)
    error <- tryCatch(
      with_mascot_asserts({
        checkmate::assert_string(stop(original))
      }),
      error = identity
    )
    expect_identical(error, original)
  })
  it("evaluates successful assertions once and validates its call argument", {
    count <- 0L
    result <- with_mascot_asserts({
      count <- count + 1L
      checkmate::assert_string("ready")
    })
    expect_identical(count, 1L)
    expect_identical(result, checkmate::assert_string("ready"))
    expect_error(with_mascot_asserts(NULL, call = NULL), "call")
  })
})

describe("static motion switches", {
  it("serialises every switch and selected message panels", {
    attrs <- mascot("a", motion = mascot_motion_settings(messages = "menu", idle = TRUE, others = FALSE))$attribs
    expect_identical(attrs[["data-reduced"]], "auto")
    expect_identical(attrs[["data-idle"]], "true")
    for (name in c("mood-change", "gestures", "swap", "minimising", "restoring", "others")) {
      expect_identical(attrs[[paste0("data-", name)]], "false", info = name)
    }
    expect_identical(attrs[["data-messages"]], "menu")
    off <- mascot("a", motion = FALSE)$attribs
    expect_identical(off[["data-reduced"]], "true")
    for (name in c("idle", "mood-change", "gestures", "swap", "minimising", "restoring", "others")) {
      expect_identical(off[[paste0("data-", name)]], "false", info = name)
    }
    expect_identical(off[["data-messages"]], "")
  })
})


describe("mascot resources in modules", {
  it("resolves one offline dependency for a function-built UI with nested modules", {
    ui <- function() {
      shiny::fluidPage(
        mascot(shiny::NS("first")(shiny::NS("review")("helper"))),
        mascot(shiny::NS("second")(shiny::NS("review")("helper")))
      )
    }
    dependencies <- htmltools::renderTags(ui())$dependencies
    engine <- Filter(function(dep) dep$name == "mascot", dependencies)
    expect_length(engine, 1)
    expect_identical(engine[[1]]$script, engine_scripts)
    expect_identical(engine[[1]]$stylesheet, "mascot.css")
    expect_identical(engine[[1]]$src$file, system.file("www", package = "mascot"))
    expect_false(grepl("https?://", engine[[1]]$src$file))
  })
})

describe("internal R4a character argument forms", {
  it("accepts checked character palettes through the theme shortcut", {
    checked <- character_format_check(protocol_character()$json, from = "text")
    expect_no_error(mascot("helper", character = checked))
    expect_error(mascot("helper", mood = "processing"), "must be one of", class = "mascot_error")
    expect_error(mascot("helper", theme = "sea"), class = "mascot_error")
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    update_mascot("helper", character = checked, session = session)
    expect_identical(mascot_id_state(session, "helper")$context$data$id, checked$id)
    expect_no_warning(update_mascot("helper", theme = "sea", session = session))
    expect_identical(mascot_id_state(session, "helper")$desired$theme$palette, "sea")
    expect_no_error(mascot("helper", character = checked, theme = "sea"))
  })
})

describe("B2 construction diagnostics", {
  it("explains lowercase ids for custom moods and gestures", {
    bot <- mascot_check_character(format_recipe("study_bot"))
    expect_error(mascot("helper", character = bot, mood = "Reviewing"), "lowercase")
    expect_error(check_arg("Greet", "gesture", environment()), "lowercase")
  })
  it("preserves a specific condition when baseline preparation fails", {
    local_mocked_bindings(mascot_state_prepare = function(...) {
      abort_choice("bad", "good", "mood", "mood", environment())
    })
    expect_error(mascot("helper"), class = "mascot_error_choice")
  })
  it("describes unnamed arguments as arguments", {
    expect_error(mascot("helper", 1), "an unnamed argument", fixed = TRUE)
  })
})
