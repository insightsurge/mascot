describe("mascot_examples()", {
  it("lists the studio and four scenario apps in order with readable metadata", {
    examples <- mascot_examples()
    expect_s3_class(examples, "data.frame")
    expect_named(examples, c("name", "title", "description"))
    expect_identical(examples$name, c("studio", "form-check", "long-task", "modules", "branding"))
    expect_true(all(vapply(examples, is.character, logical(1))))
    expect_true(all(nzchar(unlist(examples))))
    expect_identical(anyDuplicated(examples$name), 0L)
    expect_match(examples$description[examples$name == "branding"], "Requires bslib")
  })
  it("copies each scenario's app.R alone, or the studio's folder, and builds it without a server", {
    # mascot is already attached by the test run; attaching it here would detach it on exit.
    withr::local_package("shiny")
    if (requireNamespace("bslib", quietly = TRUE)) {
      withr::local_package("bslib")
    }
    for (name in mascot_examples()$name) {
      file <- mascot_example(name, run = FALSE)
      expect_true(file.exists(file), info = name)
      # The studio is a folder (app.R, R/ and www/); every other example is one file.
      sources <- list.files(dirname(file), recursive = TRUE)
      if (name == "studio") {
        expect_setequal(
          sources,
          c(
            "app.R",
            "R/code.R",
            "R/data.R",
            "R/guide.R",
            "R/help.R",
            "R/panels.R",
            "R/ui.R",
            "www/studio.css",
            "www/studio.js"
          )
        )
      } else {
        expect_identical(sources, "app.R", info = name)
      }
      copy <- withr::local_tempdir()
      expect_true(file.copy(dirname(file), copy, recursive = TRUE))
      dir <- file.path(copy, name)
      for (script in list.files(dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)) {
        expect_type(parse(script), "expression")
      }
      if (!requireNamespace("bslib", quietly = TRUE)) {
        # shinyAppDir() reads app.R on the first request.
        expect_error(shiny::shinyAppDir(dir)$httpHandler(list(PATH_INFO = "/")), "example needs bslib")
      } else {
        app <- shiny::shinyAppDir(dir)
        expect_s3_class(app, "shiny.appobj")
        html <- as.character(app$httpHandler(list(PATH_INFO = "/"))$content)
        # bslib's inline icons name the SVG namespace, which is not a request.
        html <- gsub("http://www.w3.org/2000/svg", "", html, fixed = TRUE)
        # External navbar links are navigation only; assets must remain local.
        for (link in c("https://github.com/insightsurge/mascot", "https://mascot-pkg.web.app/")) {
          html <- gsub(paste0('href="', link, '"'), "", html, fixed = TRUE)
        }
        expect_false(any(grepl("https?://", html)), info = name)
      }
    }
  })
  it("keeps in guide.R only what the help pages do not have", {
    guide <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "guide.R"), envir = guide)
    exports <- getNamespaceExports("mascot")
    expect_setequal(names(guide$playground_guide), exports)
    for (fn in exports) {
      entry <- guide$playground_guide[[fn]]
      # The category, the vignette section and, per argument, where it can be tried: no description, argument
      # text or return value (those are read from the help page).
      expect_setequal(names(entry), c("category", "vignette", "args"))
      expect_setequal(as.character(names(entry$args)), as.character(names(formals(getExportedValue("mascot", fn)))))
      expect_true(entry$category %in% names(guide$playground_categories), info = fn)
      expect_true(nzchar(entry$vignette), info = fn)
      for (arg in names(entry$args)) {
        expect_true(all(names(entry$args[[arg]]) %in% "try"), info = paste(fn, arg))
        expect_true(is.null(entry$args[[arg]]$try) || entry$args[[arg]]$try %in% names(guide$playground_categories))
      }
    }
    # Everything left is a short label, never a sentence of explanation.
    prose <- Filter(function(text) nchar(text) > 40, unlist(lapply(guide$playground_guide, unlist)))
    expect_length(prose, 0)
  })
  it("reads every description, argument and return value from the package's help pages", {
    skip_if_not_installed("htmltools")
    help <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "help.R"), envir = help)
    # Letters and digits only, so markup, quotes and line wrapping do not matter.
    plain <- function(text) tolower(gsub("[^[:alnum:]]", "", text))
    for (fn in getNamespaceExports("mascot")) {
      rd <- help$help_rd(fn)
      page <- help$help_page(fn)
      file <- withr::local_tempfile(fileext = ".txt")
      suppressMessages(tools::Rd2txt(rd, out = file, options = list(underline_titles = FALSE)))
      reference <- plain(paste(readLines(file, warn = FALSE), collapse = " "))
      expect_true(nzchar(page$title), info = fn)
      expect_true(grepl(plain(page$title), reference, fixed = TRUE), info = fn)
      expect_true(grepl(plain(help$html_text(page$description)), reference, fixed = TRUE), info = fn)
      expect_true(grepl(plain(help$html_text(page$value)), reference, fixed = TRUE), info = fn)
      if (!is.null(page$details)) {
        expect_true(grepl(plain(help$html_text(page$details)), reference, fixed = TRUE), info = fn)
      }
      for (arg in names(formals(getExportedValue("mascot", fn)))) {
        text <- help$help_arg(fn, arg)
        expect_false(is.null(text), info = paste(fn, arg))
        expect_true(grepl(plain(help$html_text(text)), reference, fixed = TRUE), info = paste(fn, arg))
      }
    }
  })
  it("renders help text as HTML and finds the help example that supplies an argument", {
    help <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "help.R"), envir = help)
    expect_error(help$help_page(42), "string")
    expect_error(help$help_arg("mascot_bubble", 42), "string")
    expect_error(help$help_rd("not_a_mascot_function"), "no help page")
    expect_error(help$help_arg_example("mascot_bubble", NA_character_), "Assertion on 'arg' failed")
    expect_error(help$first_sentence(42), "string")
    expect_error(help$vignette_anchor(42), "string")
    expect_identical(help$html_text("<p>0&ndash;255 &amp; &#39;x&#39;</p>"), "0\u2013255 & 'x'")
    expect_identical(help$first_sentence("One. Two."), "One.")
    expect_identical(help$first_sentence("No full stop"), "No full stop")
    expect_identical(help$vignette_anchor("Theme and light/dark mode"), "theme-and-lightdark-mode")
    expect_match(help$vignette_url("Motion"), "^https://.*#motion$")
    html <- as.character(help$help_arg("mascot_bubble", "duration"))
    expect_match(html, "<code>Inf</code>", fixed = TRUE)
    expect_false(grepl("<h3", html, fixed = TRUE))
    expect_true(length(help$help_examples("mascot_bubble")) > 0)
    expect_match(help$help_arg_example("mascot_bubble", "duration"), "duration =", fixed = TRUE)
  })
})

describe("the studio's controls", {
  it("prints code that parses, including menu ids that need backticks", {
    code <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), envir = code)
    items <- c(`finish-review` = "Finish the review of every row in this table", about = "About this app")
    menu <- code$code_menu(items)
    theme <- code$code_theme("mascot", c(body = "#1f6feb"), c(body = "#9ec5fe"), "dark", "rim", "", "")
    call <- code$format_call("mascot", list(id = "helper", popup_menu = menu$helper, theme = theme$helper))
    expect_match(call, "`finish-review` = ", fixed = TRUE)
    expect_identical(eval(parse(text = call)[[1]][["popup_menu"]]), mascot_popup_menu(items))
    handler <- code$menu_handler_code(items)
    expect_type(parse(text = handler), "expression")
    app <- code$whole_app_code(call, handler, c("shiny", "mascot"), "#7b4fd6")
    expect_type(parse(text = app), "expression")
    # Every helper has live example code in the guide, including the compound controls.
    pairs <- list(
      code$code_character("tessa"),
      code$code_mood("worried"),
      code$code_status("Checking rows"),
      code$code_bubble("<strong>Saved</strong>", TRUE, Inf, FALSE),
      code$code_gesture("wave"),
      code$code_motion(FALSE, FALSE),
      code$code_size("20%", 72),
      code$code_placement("top-left", TRUE, "snap"),
      code$code_menu(character()),
      theme
    )
    for (pair in pairs) {
      for (style in c("short", "helper")) {
        expect_type(parse(text = code$format_expr(pair[[style]])), "expression")
      }
    }
  })
  it("prints parseable bubble calls without escaped quotes, including raw delimiter collisions", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    code <- new.env()
    sys.source(file.path(dir, "R", "code.R"), envir = code)
    sys.source(file.path(dir, "R", "data.R"), envir = code)
    cases <- c(
      code$bubble_examples,
      list(
        quotes = list(text = '<p class="notice">She said "Saved".</p>', html = TRUE),
        delimiters = list(text = 'Both )" and )-" occur, plus a \nnew line.', html = FALSE),
        short = list(text = 'A "quote"', html = FALSE)
      )
    )
    for (example in cases) {
      pair <- code$code_bubble(example$text, example$html, Inf, TRUE)
      for (style in c("short", "helper")) {
        text <- code$format_call("mascot", list(id = "helper", bubble = pair[[style]]))
        expect_type(parse(text = text), "expression")
        expect_false(grepl('\\"', text, fixed = TRUE))
        # Parsing must preserve the original text, not merely accept the syntax.
        parsed <- parse(text = text)[[1]][["bubble"]]
        bubble <- eval(parsed, envir = list(HTML = htmltools::HTML, mascot_bubble = mascot_bubble))
        expect_identical(as.character(bubble$text), example$text)
      }
    }
    direct <- code$format_call(
      "mascot",
      list(id = "helper", bubble = code$code_bubble(cases$quotes$text, TRUE, 5, TRUE)$short)
    )
    expect_type(parse(text = direct), "expression")
    expect_false(grepl('\\"', direct, fixed = TRUE))
    expect_match(code$format_expr('A "quote"'), 'r"(A "quote")"', fixed = TRUE)
    expect_match(code$format_expr('Both )" and )-"'), 'r"--(', fixed = TRUE)
  })
  it("prints drag in both placement forms and omits the removed size argument", {
    code <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", FALSE)), "R", "code.R"), envir = code)
    for (mode in c("snap", "free")) {
      pair <- code$code_placement("bottom-right", TRUE, mode)
      expect_identical(eval(pair$short), list(position = "bottom-right", drag = mode))
      expect_identical(eval(pair$helper), mascot_placement("bottom-right", drag = mode))
      for (style in c("short", "helper")) {
        expect_match(code$format_expr(pair[[style]]), paste0('drag = "', mode, '"'), fixed = TRUE)
      }
    }
    expect_false(grepl("simplify_when_small", code$format_expr(code$code_size(120, 72)$helper), fixed = TRUE))
  })
  it("uses the package's floating placement default and prints an explicit inline choice", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    code <- new.env()
    sys.source(file.path(dir, "R", "code.R"), envir = code)
    sys.source(file.path(dir, "R", "data.R"), envir = code)
    expect_identical(code$defaults$placement, formals(mascot)[["placement"]])
    expect_identical(formals(code$code_placement), formals(mascot_placement))
    pair <- code$code_placement()
    expect_identical(pair$short, "bottom-right")
    expect_identical(eval(pair$helper), mascot_placement())
    expect_identical(code$format_expr(pair$helper), "mascot_placement()")
    inline <- code$code_placement("inline")
    expect_identical(eval(inline$helper), mascot_placement("inline"))
    # Inline ignores minimise and drag, so the printed code leaves them out instead of prompting a message.
    expect_identical(code$code_placement("inline", FALSE, "snap"), inline)
    hidden <- code$code_placement("top-left", FALSE)
    expect_identical(eval(hidden$helper), mascot_placement("top-left", minimise = FALSE))
    expect_identical(eval(hidden$short), list(position = "top-left", minimise = FALSE))
    call <- code$format_call("mascot", list(id = "helper", placement = inline$short))
    expect_match(call, 'placement = "inline"', fixed = TRUE)
    expect_type(parse(text = call), "expression")
  })
  it("preserves every menu direction in shortcut and helper code, including an empty menu", {
    code <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", FALSE)), "R", "code.R"), envir = code)
    for (items in list(c(about = "About this app"), character())) {
      for (direction in c("auto", "top", "bottom", "left", "right")) {
        pair <- code$code_menu(items, direction)
        expected <- mascot_popup_menu(if (length(items)) items else NULL, direction = direction)
        expect_identical(eval(pair$helper), expected)
        for (style in c("short", "helper")) {
          text <- code$format_expr(pair[[style]])
          expect_type(parse(text = text), "expression")
          if (direction != "auto") {
            expect_identical(eval(parse(text = text)[[1]]), expected)
            expect_match(text, paste0('direction = "', direction, '"'), fixed = TRUE)
          } else {
            expect_false(grepl("direction =", text, fixed = TRUE))
          }
        }
      }
    }
  })
  it("reads every displayed default from the installed function's formals", {
    skip_if_not_installed("bslib")
    withr::local_package("shiny")
    withr::local_package("bslib")
    dir <- dirname(mascot_example("studio", run = FALSE))
    ui <- new.env()
    sys.source(file.path(dir, "R", "guide.R"), envir = ui)
    sys.source(file.path(dir, "R", "help.R"), envir = ui)
    sys.source(file.path(dir, "R", "data.R"), envir = ui)
    sys.source(file.path(dir, "R", "ui.R"), envir = ui)
    expect_error(ui$argument_default(42, "position"), "string")
    expect_error(ui$argument_default("mascot_placement", 42), "string")
    expect_error(ui$argument_default("mascot_placement", "missing_argument"), "position")
    expect_error(ui$arg_popover_body(42, "position"), "string")
    expect_error(ui$arg_popover_body("mascot_placement", 42), "string")
    for (fn in getNamespaceExports("mascot")) {
      arguments <- formals(getExportedValue("mascot", fn))
      for (arg in names(arguments)) {
        value <- deparse1(arguments[[arg]])
        expected <- if (nzchar(value)) {
          value
        } else if (arg == "...") {
          "empty"
        } else {
          "none: required"
        }
        expect_null(ui$playground_guide[[fn]]$args[[arg]]$default, info = paste(fn, arg))
        expect_identical(ui$argument_default(fn, arg), expected, info = paste(fn, arg))
        # Inspect the text of the actual badge, popover paragraph and guide code tag.
        field <- ui$arg_field(fn, arg, htmltools::tags$span("Control"))
        expect_identical(field$children[[1]]$children[[2]]$children[[2]], expected, info = paste(fn, arg))
        popover <- ui$arg_popover_body(fn, arg)
        expect_identical(popover[[2]]$children[[2]]$children[[1]], expected, info = paste(fn, arg))
        # The popover carries the argument's whole help text, read from the help page.
        expect_true(
          grepl(as.character(ui$help_arg(fn, arg)), as.character(popover), fixed = TRUE),
          info = paste(fn, arg)
        )
        block <- ui$arg_block(fn, arg)
        expect_identical(block$children[[2]]$children[[2]]$children[[1]], expected, info = paste(fn, arg))
      }
    }
  })
  it("labels the Guide as a call to its selected function and keeps visuals in separate sections", {
    skip_if_not_installed("bslib")
    withr::local_package("shiny")
    withr::local_package("bslib")
    dir <- dirname(mascot_example("studio", run = FALSE))
    ui <- new.env()
    sys.source(file.path(dir, "R", "guide.R"), envir = ui)
    sys.source(file.path(dir, "R", "help.R"), envir = ui)
    sys.source(file.path(dir, "R", "data.R"), envir = ui)
    sys.source(file.path(dir, "R", "ui.R"), envir = ui)
    sys.source(file.path(dir, "R", "data.R"), envir = ui)
    sys.source(file.path(dir, "R", "code.R"), envir = ui)
    expect_error(ui$selected_guide(42), "string")
    for (fn in c(
      "mascot_mood",
      "mascot_bubble",
      "mascot_motion",
      "mascot_placement",
      "mascot_theme",
      "mascot_popup_menu",
      "updateMascot"
    )) {
      html <- as.character(ui$selected_guide(fn))
      expect_match(html, paste0("Example: how to call ", fn, "()"), fixed = TRUE)
      expect_match(html, 'id="code_function"', fixed = TRUE)
      expect_match(html, "pg-guide-piece", fixed = TRUE)
      # The Guide shows the help page's description, details and value; each argument's text is in Controls.
      expect_true(grepl(as.character(ui$help_page(fn)$description), html, fixed = TRUE), info = fn)
      expect_true(grepl(as.character(ui$help_page(fn)$value), html, fixed = TRUE), info = fn)
      expect_false(grepl("Argument details", html, fixed = TRUE), info = fn)
    }
  })
  it("has a control on the page, or a stated reason, for every exported argument", {
    skip_if_not_installed("bslib")
    # mascot is already attached by the test run; attaching it here would detach it on exit.
    withr::local_package("shiny")
    withr::local_package("bslib")
    dir <- dirname(mascot_example("studio", run = FALSE))
    data <- new.env()
    sys.source(file.path(dir, "R", "data.R"), envir = data)
    app <- shiny::shinyAppDir(dir)
    pages <- lapply(c("", "view=examples"), function(query) {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    })
    for (page in pages) {
      ids <- regmatches(page, gregexpr(' id="[^"]+"', page))[[1]]
      expect_identical(anyDuplicated(ids), 0L)
    }
    html <- paste(unlist(pages), collapse = "\n")
    expect_match(pages[[1]], 'id="code_tray_body"', fixed = TRUE)
    expect_match(pages[[1]], 'id="studio_panels_card"', fixed = TRUE)
    expect_false(grepl('id="learn_card"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="code_dock"', pages[[1]], fixed = TRUE))
    expect_false(grepl("view=preview", html, fixed = TRUE))
    expect_false(grepl('id="code_toggle"', pages[[1]], fixed = TRUE))
    expect_match(pages[[1]], 'href="?view=examples"', fixed = TRUE)
    expect_match(pages[[1]], 'href="https://github.com/insightsurge/mascot"', fixed = TRUE)
    expect_match(pages[[1]], 'href="https://mascot-pkg.web.app/"', fixed = TRUE)
    expect_match(pages[[1]], "Links", fixed = TRUE)
    # mascot_preview() is in the studio page: its canvas part and its controls.
    expect_match(pages[[1]], 'data-canvas="preview"', fixed = TRUE)
    expect_match(pages[[1]], 'id="preview_menu_items"', fixed = TRUE)
    expect_false(grepl('id="helper"', pages[[2]], fixed = TRUE))
    expect_false(grepl("Use the studio's", pages[[2]], fixed = TRUE))
    expect_false(grepl("Open in a new tab", pages[[2]], fixed = TRUE))
    for (fn in getNamespaceExports("mascot")) {
      for (arg in names(formals(getExportedValue("mascot", fn)))) {
        control <- data$playground_controls[[fn]][[arg]]
        expect_false(is.null(control), info = paste(fn, arg))
        if (is.list(control)) {
          expect_true(nzchar(control$fixed), info = paste(fn, arg))
        } else {
          for (fragment in control) {
            expect_true(grepl(fragment, html, fixed = TRUE), info = paste(fn, arg, fragment))
          }
        }
      }
    }
  })
})

describe("mascot_example()", {
  it("returns the installed app.R path without writing or running anything", {
    path <- mascot_example("studio", run = FALSE)
    expect_identical(path, system.file("examples", "studio", "app.R", package = "mascot"))
    expect_identical(basename(path), "app.R")
    expect_true(file.exists(path))
  })
  it("checks every argument and names valid examples for unknown names", {
    for (bad in list(NULL, NA_character_, "", 1, c("studio", "modules"))) {
      expect_error(mascot_example(bad, FALSE), "Assertion on 'name' failed")
    }
    for (bad in list(NULL, NA, 1, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_example("studio", bad), "Assertion on 'run' failed")
    }
    expect_snapshot(error = TRUE, mascot_example("typo", FALSE))
  })
  it("explains how to locate an app in a non-interactive session", {
    expect_false(interactive())
    expect_error(mascot_example("studio"), "needs an interactive R session")
  })
  it("delegates the selected directory to Shiny when running interactively", {
    # Restore both bindings at teardown; no browser or server is started here.
    local_mocked_bindings(example_interactive = function() TRUE)
    captured <- NULL
    local_mocked_bindings(
      runApp = function(appDir) {
        captured <<- appDir
        "app stopped"
      },
      .package = "shiny"
    )
    expect_identical(mascot_example("modules"), "app stopped")
    expect_identical(captured, dirname(mascot_example("modules", FALSE)))
  })
})

# A literal scenario name is embedded so the child R process needs no test globals.
example_driver <- function(name, width = 1100) {
  checkmate::assert_string(name)
  checkmate::assert_number(width, lower = 1)
  testthat::skip_if_not_installed("bslib")
  app_function <- function() NULL
  body(app_function) <- substitute(
    {
      library(mascot)
      shiny::shinyAppDir(system.file("examples", NAME, package = "mascot"))
    },
    list(NAME = name)
  )
  shinytest2::AppDriver$new(app_function, width = width, height = 900, load_timeout = 30000)
}

wait_example_mood <- function(app, id, mood) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(id)
  checkmate::assert_string(mood)
  app$wait_for_js(sprintf("document.getElementById('%s')?.dataset.shownMood === '%s'", id, mood), timeout = 15000)
  expect_identical(app$get_js(sprintf("document.getElementById('%s').dataset.shownMood", id)), mood)
}

describe("bundled example apps", {
  it("E1 studio selects functions and changes Tessa with code and an event log", {
    local_shiny_browser()
    app <- example_driver("studio", width = 1440)
    withr::defer(app$stop())
    state <- "mascot.host.state(document.getElementById('helper'))"
    wait_example_mood(app, "helper", "idle")
    expect_identical(app$get_js("document.querySelectorAll('.mascot').length"), 1L)
    expect_identical(app$get_value(input = "position"), "inline")
    expect_identical(app$get_js("document.getElementById('helper').dataset.floating"), "false")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('placement = \"inline\"')")
    expect_match(app$get_value(output = "code_server"), 'placement = "inline"', fixed = TRUE)
    expect_match(app$get_value(output = "code_app"), 'placement = "inline"', fixed = TRUE)
    select_function <- function(fn) {
      checkmate::assert_string(fn)
      app$click(selector = sprintf('.pg-index-link[data-value="%s"]', fn))
      app$wait_for_js(sprintf(
        "!document.querySelector('#studio_inspector [data-function=\"%s\"]').hidden && document.querySelectorAll('#studio_inspector [data-function]:not([hidden])').length === 1",
        fn
      ))
    }
    code_panel <- "#code_tray_body"
    expect_identical(app$get_js("document.querySelectorAll('#studio_dock .accordion').length"), 0L)
    expect_true(app$get_js(
      "document.getElementById('code_tray_body').contains(document.getElementById('studio_panels_card')) && !document.getElementById('code_tray_header').contains(document.querySelector('.bslib-full-screen-enter')) && document.querySelector('#studio_panels_card .bslib-full-screen-enter') !== null"
    ))
    # The tray's own header bar is the only Code control: there is no toolbar button.
    expect_identical(app$get_js("document.querySelectorAll('#code_toggle').length"), 0L)
    expect_identical(app$get_js("document.getElementById('code_tray_toggle').textContent.trim()"), "Code")
    expect_true(app$get_js(
      "document.getElementById('code_tray_body').contains(document.getElementById('code_style')) && !document.querySelector('.pg-toolbar #code_style')"
    ))
    expect_true(app$get_js(
      "document.querySelector('.pg-code-style').compareDocumentPosition(document.getElementById('code_tabs')) & Node.DOCUMENT_POSITION_FOLLOWING ? true : false"
    ))
    # No accordion wraps a whole function; the colour pickers keep theirs, folded by group.
    expect_true(app$get_js(
      "![...document.querySelectorAll('#studio_inspector .accordion-item')].some(item => /^(mascot|updateMascot)/.test(item.dataset.value || ''))"
    ))
    expect_identical(
      app$get_js("document.querySelectorAll('#studio_inspector [data-event=select_function]').length"),
      0L
    )
    expect_identical(app$get_js("document.querySelectorAll('#status_text').length"), 1L)
    app$run_js("window.studioStatusInput = document.getElementById('status_text')")
    expect_match(
      app$get_js("document.querySelector('.pg-code-purpose').textContent"),
      "Code for Tessa with the current settings.",
      fixed = TRUE
    )
    # A fully readable description does not open a tooltip, even when Bootstrap requests one.
    app$run_js(
      "(() => {
      const button = document.querySelectorAll('.pg-index-link')[0];
      button.querySelector('span').style.width = '1000px';
      const tooltip = bootstrap.Tooltip.getInstance(button) || bootstrap.Tooltip.getInstance(button.closest('bslib-tooltip'));
      tooltip.show();
    })()"
    )
    expect_identical(app$get_js("document.querySelectorAll('.tooltip.show').length"), 0L)
    # Narrow two descriptions to exercise real truncation independently of their wording.
    app$run_js(
      "for (const button of [...document.querySelectorAll('.pg-index-link')].slice(0, 2)) button.querySelector('span').style.width = '3rem'"
    )
    # Focus does not keep an index tooltip open after the pointer leaves.
    index_tooltip_shown <- "(() => {
      const button = document.querySelectorAll('.pg-index-link')[%d];
      const trigger = button.hasAttribute('aria-describedby') ? button : button.closest('bslib-tooltip');
      return document.getElementById(trigger?.getAttribute('aria-describedby'))?.classList.contains('show') === true;
    })()"
    app$run_js("document.querySelectorAll('.pg-index-link')[0].focus()")
    app$run_js(
      "document.querySelectorAll('.pg-index-link')[0].dispatchEvent(new MouseEvent('mouseover', {bubbles: true}))"
    )
    app$wait_for_js(sprintf(index_tooltip_shown, 0))
    app$run_js(
      "document.querySelectorAll('.pg-index-link')[0].dispatchEvent(new MouseEvent('mouseout', {bubbles: true}))"
    )
    app$wait_for_js("document.querySelectorAll('.tooltip.show').length === 0")
    # A new hover also hides the previous tooltip, even before its mouseout arrives.
    app$run_js(
      "document.querySelectorAll('.pg-index-link')[0].dispatchEvent(new MouseEvent('mouseover', {bubbles: true}))"
    )
    app$wait_for_js(sprintf(index_tooltip_shown, 0))
    app$run_js(
      "document.querySelectorAll('.pg-index-link')[1].dispatchEvent(new MouseEvent('mouseover', {bubbles: true}))"
    )
    app$wait_for_js(sprintf(index_tooltip_shown, 1))
    expect_true(app$get_js(
      "document.querySelectorAll('.tooltip.show').length === 1 && document.activeElement === document.querySelectorAll('.pg-index-link')[0]"
    ))
    app$run_js(
      "for (const button of document.querySelectorAll('.pg-index-link')) button.dispatchEvent(new MouseEvent('mouseout', {bubbles: true}))"
    )
    app$wait_for_js("document.querySelectorAll('.tooltip.show').length === 0")
    app$run_js(
      "for (const button of [...document.querySelectorAll('.pg-index-link')].slice(0, 2)) button.querySelector('span').style.removeProperty('width')"
    )
    expect_identical(app$get_js("document.getElementById('code_tray_toggle').getAttribute('aria-expanded')"), "true")
    # The canvas includes the reserved bubble space and status with either panel open.
    canvas_fits <- "(() => {
      const canvas = document.getElementById('studio_canvas').getBoundingClientRect();
      return ['.mascot-canvas', '.mascot-status', '.mascot-bubble-region'].every(selector => {
        const item = document.querySelector('#helper ' + selector).getBoundingClientRect();
        return item.top >= canvas.top && item.bottom <= canvas.bottom;
      });
    })()"
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    app$run_js(
      "window.studioGuideOpener = document.querySelector('[data-function=mascot_mood] [data-event=open_guide]');
      window.studioGuideOpener.focus();"
    )
    app$click(selector = '[data-function="mascot_mood"] [data-event="open_guide"]')
    app$wait_for_js("!!document.querySelector('.pg-guide-modal.show #guide [data-guide-function=mascot_mood]')")
    guide_read_only <- "(() => {
      const modal = document.querySelector('.pg-guide-modal.show');
      return !!modal && modal.querySelectorAll('input, select, textarea, [contenteditable=true], [data-event]').length === 0 &&
        modal.querySelectorAll('button:not(#close_guide):not([data-copy])').length === 0;
    })()"
    expect_true(app$get_js(guide_read_only))
    expect_identical(
      app$get_js("document.querySelector('.pg-guide-example .pg-section-title').textContent"),
      "Example: how to call mascot_mood()"
    )
    expect_true(app$get_js(
      "document.querySelector('.pg-guide-mistakes').textContent.includes('sleepy') && document.querySelector('.pg-guide-mistakes').textContent.includes('Error:')"
    ))
    app$wait_for_js(
      "getComputedStyle(document.querySelector('.pg-guide-columns')).gridTemplateColumns.split(' ').length >= 3"
    )
    expect_true(app$get_js(
      "(() => { const example = document.querySelector('.pg-guide-example').getBoundingClientRect(); const table = document.querySelector('.pg-guide-visual .pg-table').getBoundingClientRect(); const callout = document.querySelector('.pg-guide-visual .pg-callout').getBoundingClientRect(); return table.left > example.left && callout.left > table.left && Math.abs(table.top - example.top) < 80; })()"
    ))
    expect_true(app$get_js(
      "(() => { const code = document.getElementById('code_function').getBoundingClientRect(); const copy = document.querySelector('[data-copy=code_function]').getBoundingClientRect(); return copy.bottom <= code.top; })()"
    ))
    guide_removed <- "!document.querySelector('.pg-guide-modal') && !document.getElementById('shiny-modal-wrapper') && !document.querySelector('.modal-backdrop') && !document.body.classList.contains('modal-open')"
    app$click("close_guide")
    app$wait_for_js(guide_removed)
    expect_true(app$get_js(guide_removed))
    app$wait_for_js("document.activeElement === window.studioGuideOpener")
    expect_true(app$get_js("document.activeElement === window.studioGuideOpener"))
    # Usage popover opens, closes on Escape, and closes before opening Guide.
    usage_btn <- '[data-function="mascot_mood"] > bslib-popover > button'
    app$click(selector = usage_btn)
    app$wait_for_js("!!document.querySelector('.popover.show')")
    expect_true(app$get_js("!!document.querySelector('.popover.show')"))
    # Escape closes the popover
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyDown",
      key = "Escape",
      code = "Escape",
      windowsVirtualKeyCode = 27
    )
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyUp",
      key = "Escape",
      code = "Escape",
      windowsVirtualKeyCode = 27
    )
    app$wait_for_js("!document.querySelector('.popover.show')")
    expect_true(app$get_js("!document.querySelector('.popover.show')"))
    # Reopen popover; opening Guide closes it first so nothing floats above the modal
    app$click(selector = usage_btn)
    app$wait_for_js("!!document.querySelector('.popover.show')")
    app$click(selector = '[data-function="mascot_mood"] [data-event="open_guide"]')
    app$wait_for_js("!!document.querySelector('.pg-guide-modal.show #guide [data-guide-function=mascot_mood]')")
    expect_true(app$get_js("!document.querySelector('.popover.show')"))
    app$click("close_guide")
    app$wait_for_js(guide_removed)

    # Every Guide is read-only, showing only its own visuals.
    for (fn in setdiff(getNamespaceExports("mascot"), "mascot_mood")) {
      select_function(fn)
      app$click(selector = sprintf('[data-function="%s"] [data-event="open_guide"]', fn))
      app$wait_for_js(sprintf("!!document.querySelector('.pg-guide-modal.show #guide [data-guide-function=%s]')", fn))
      if (fn == "mascot_size") {
        app$wait_for_js("!!document.querySelector('.pg-guide-modal #size_ruler .pg-ruler')")
        expect_true(app$get_js("!document.querySelector('.pg-guide-modal #placement_map')"))
      }
      if (fn == "mascot_placement") {
        app$wait_for_js("!!document.querySelector('.pg-guide-modal #placement_map .pg-map')")
        expect_true(app$get_js("!document.querySelector('.pg-guide-modal #size_ruler')"))
      }
      if (fn == "mascot_colour_roles") {
        app$wait_for_js("!!document.querySelector('.pg-guide-modal #roles_table .pg-table')")
        expect_true(app$get_js("!document.querySelector('.pg-guide-modal .pg-flow')"))
      }
      if (fn == "mascot_theme") {
        app$wait_for_js("!!document.querySelector('.pg-guide-modal .pg-flow')")
        expect_true(app$get_js("!document.querySelector('.pg-guide-modal #roles_table')"))
      }
      expect_true(app$get_js(guide_read_only))
      app$click("close_guide")
      app$wait_for_js(guide_removed)
    }
    select_function("mascot_mood")
    # Reopen the same Guide and exercise a real keyboard Escape, including cleanup.
    app$click(selector = '[data-function="mascot_mood"] [data-event="open_guide"]')
    app$wait_for_js("!!document.querySelector('.pg-guide-modal.show #guide [data-guide-function=mascot_mood]')")
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyDown",
      key = "Escape",
      code = "Escape",
      windowsVirtualKeyCode = 27
    )
    app$get_chromote_session()$Input$dispatchKeyEvent(
      type = "keyUp",
      key = "Escape",
      code = "Escape",
      windowsVirtualKeyCode = 27
    )
    app$wait_for_js(guide_removed)
    expect_true(app$get_js(guide_removed))
    app$wait_for_js("document.activeElement === window.studioGuideOpener")
    expect_true(app$get_js("document.activeElement === window.studioGuideOpener"))
    app$click(selector = "#studio_panels_card .bslib-full-screen-enter")
    app$wait_for_js("document.getElementById('studio_panels_card').getAttribute('data-full-screen') === 'true'")
    expect_true(app$get_js("document.getElementById('studio_panels_card').getBoundingClientRect().height > 300"))
    app$run_js(
      "document.getElementById('studio_panels_card').dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}))"
    )
    app$wait_for_js("document.getElementById('studio_panels_card').getAttribute('data-full-screen') === 'false'")
    app$wait_for_js(canvas_fits)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-index-link code')).whiteSpace"), "nowrap")
    # The dock's height transitions after full screen ends: measure it only once the transition has finished.
    app$wait_for_js("document.getElementById('studio_dock').getAnimations().length === 0")
    grip_height <- app$get_js("document.getElementById('studio_dock').getBoundingClientRect().height")
    app$run_js(
      "document.getElementById('dock_grip').dispatchEvent(new KeyboardEvent('keydown', {key: 'ArrowDown', bubbles: true}))"
    )
    app$wait_for_js(sprintf("document.getElementById('studio_dock').getBoundingClientRect().height < %f", grip_height))
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    expect_identical(
      app$get_js(
        "[...document.querySelectorAll('#code_tabs .nav-link')].filter(el => el.getClientRects().length > 0)
        .map(el => el.textContent.trim()).join('|')"
      ),
      "UI|Server|App|Last|Log"
    )
    # There is no Static preview view: mascot_preview() is an entry of the function index.
    expect_identical(app$get_js("document.querySelectorAll('a[href=\"?view=preview\"]').length"), 0L)
    expect_identical(app$get_js("document.querySelectorAll('.pg-index-link[data-value=mascot_preview]').length"), 1L)
    expect_true(app$get_js("document.querySelector('a[href=\"?view=examples\"]').target === '_blank'"))
    app$run_js(
      "[...document.querySelectorAll('.dropdown-toggle')].find(el => el.textContent.includes('Links')).click()"
    )
    expect_true(app$get_js(
      "(() => {
      const links = [...document.querySelectorAll('.dropdown-menu a')].filter(el =>
        ['GitHub', 'Package website'].includes(el.textContent.trim()));
      return links.length === 2 && links.every(el => el.target === '_blank' && el.rel === 'noopener');
    })()"
    ))
    app$run_js(
      "[...document.querySelectorAll('.dropdown-toggle')].find(el => el.textContent.includes('Links')).click()"
    )
    # The mood cards are the inspector's only mood input.
    expect_identical(app$get_js("document.querySelectorAll('#mood input[type=radio]').length"), 0L)
    app$run_js("document.querySelector('[data-event=try_mood][data-value=happy]').click()")
    wait_example_mood(app, "helper", "happy")
    app$wait_for_js("document.getElementById('code_last').textContent.includes('mood = \"happy\"')")
    select_function("mascot_status")
    # The selected function owns the inspector header, controls and Learn example.
    expect_true(app$get_js(
      "!document.querySelector('#studio_inspector [data-function=mascot_status]').hidden && document.getElementById('status_text').getClientRects().length > 0"
    ))
    expect_true(app$get_js("document.querySelector('#studio_inspector [data-function=mascot_mood]').hidden"))
    # Its title and return value are the help page's own words.
    status_help <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "help.R"), envir = status_help)
    status_page <- status_help$help_page("mascot_status")
    expect_true(app$get_js(sprintf(
      "(() => {
      const panel = document.querySelector('#studio_inspector [data-function=mascot_status]');
      const text = panel.textContent.replace(/\\s+/g, ' ');
      return text.includes('Usage') && text.includes('Returns:') &&
        text.includes(%s) && text.includes(%s);
    })()",
      jsonlite::toJSON(status_page$title, auto_unbox = TRUE),
      jsonlite::toJSON(status_help$html_text(status_page$value), auto_unbox = TRUE)
    )))
    app$set_inputs(status_text = "Checking 120 rows")
    app$wait_for_js(paste0(state, ".status.text === 'Checking 120 rows'"))
    select_function("mascot_bubble")
    app$set_inputs(bubble_forever = TRUE)
    app$wait_for_js(
      "document.getElementById('bubble_seconds').getAttribute('aria-disabled') === 'true' && $('#bubble_duration').data('ionRangeSlider').options.disable === true"
    )
    app$set_inputs(bubble_forever = FALSE)
    app$wait_for_js("$('#bubble_duration').data('ionRangeSlider').options.disable === false")
    app$set_inputs(bubble_example = "Small table")
    app$click("bubble_show")
    app$wait_for_js("!!document.querySelector('#helper .mascot-bubble table')")
    app$set_inputs(bubble_text = '<p class="notice">Saved</p>', bubble_html = TRUE)
    app$click("bubble_show")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('r\"(')")
    expect_type(parse(text = app$get_value(output = "code_ui")), "expression")
    expect_false(grepl('\\"', app$get_value(output = "code_ui"), fixed = TRUE))
    select_function("mascot_motion")
    app$set_inputs(animate = FALSE)
    app$wait_for_js(paste0(state, ".motion.reduced === true"))
    select_function("mascot_size")
    app$set_inputs(size_px = 120)
    app$wait_for_js(paste0(state, ".size.size === 120"))
    select_function("mascot_placement")
    app$set_inputs(position = "bottom-right")
    app$wait_for_js("document.getElementById('helper').dataset.position === 'bottom-right'")
    app$wait_for_js("!document.getElementById('code_ui').textContent.includes('placement =')")
    app$set_inputs(position = "top-left")
    app$wait_for_js(paste0(state, ".placement.floating && ", state, ".placement.minimise"))
    app$set_inputs(minimise = FALSE)
    app$wait_for_js(paste0("!", state, ".placement.minimise"))
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('minimise = FALSE')")
    app$set_inputs(minimise = TRUE)
    app$wait_for_js(paste0(state, ".placement.minimise"))
    app$set_inputs(drag = "snap", position = "bottom-right")
    app$wait_for_js(paste0(state, ".placement.drag === 'snap'"))
    app$run_js(
      "(() => {
      const canvas = document.querySelector('#helper canvas'), r = canvas.getBoundingClientRect();
      const x = r.left + r.width / 2, y = r.top + r.height / 2;
      const press = (type, x, y) => canvas.dispatchEvent(new PointerEvent(type, {
        bubbles: true, cancelable: true, pointerId: 1, button: 0, isPrimary: true, clientX: x, clientY: y
      }));
      press('pointerdown', x, y); press('pointermove', 80, 80); press('pointerup', 80, 80);
    })()"
    )
    app$wait_for_js("document.getElementById('position_last').textContent.includes('top-left')")
    expect_identical(app$get_value(input = "helper_position"), "top-left")
    app$wait_for_js("document.querySelector('#position input:checked').value === 'top-left'")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('top-left')")
    app$wait_for_js("document.getElementById('log').textContent.includes('input$helper_position')")
    # Disable dragging for later menu clicks, then return to inline to test disabled controls.
    app$set_inputs(drag = "FALSE", position = "inline")
    app$wait_for_js("document.getElementById('drag').disabled && document.getElementById('minimise').disabled")
    select_function("mascot_theme")
    app$set_inputs(theme_source = "mascot")
    app$run_js(
      "const p = document.getElementById('light_body'); p.value = '#1f6feb'; p.dispatchEvent(new Event('input'))"
    )
    app$wait_for_js(paste0(state, ".colours.body?.toLowerCase() === '#1f6feb'"))
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('mascot_theme(light = list(body')")
    # A followed highlight and an explicit highlight both use the engine's camelCase key.
    highlight_swatch_matches <- paste0(
      "(() => {
      const swatch = document.querySelector('.pg-resolved[data-mode=light][data-role=body_highlight]');
      const expected = document.createElement('span'); expected.style.background = ",
      state,
      ".colours.bodyHighlight;
      return !!swatch && swatch.style.background === expected.style.background && !swatch.classList.contains('is-idle');
    })()"
    )
    app$wait_for_js(highlight_swatch_matches)
    expect_true(app$get_js(highlight_swatch_matches))
    app$run_js(
      "(() => { const p = document.getElementById('light_body_highlight'); p.value = '#abcdef';
      p.dispatchEvent(new Event('input')); })()"
    )
    app$wait_for_js(paste0(state, ".colours.bodyHighlight?.toLowerCase() === '#abcdef'"))
    app$wait_for_js(highlight_swatch_matches)
    expect_true(app$get_js(highlight_swatch_matches))
    select_function("mascot_popup_menu")
    app$set_inputs(menu_direction = "right")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('direction = \"right\"')")
    app$wait_for_js(paste0(state, ".popup_menu.direction === 'right'"))
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper [role=menuitem][data-item-id=finish]")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble')?.textContent.includes('Finish review')")
    expect_false(grepl("You chose", app$get_value(output = "code_ui"), fixed = TRUE))
    # A mistake is an error in the log, and the mascot keeps its settings.
    select_function("updateMascot")
    app$set_inputs(mistake = "Misspell an argument")
    app$click("mistake_run")
    app$wait_for_js("document.getElementById('log').textContent.includes('Unexpected arguments')")
    # The second step of the slow task runs later and names the session.
    app$click("task_run")
    wait_example_mood(app, "helper", "thinking")
    expect_true(app$get_js("document.getElementById('task_run').disabled"))
    app$wait_for_js(paste0(state, ".status.text === 'All 120 rows checked'"), timeout = 15000)
    app$wait_for_js("document.getElementById('code_last').textContent.includes('session = session')")
    app$wait_for_js(
      "document.getElementById('mood').dataset.value === 'happy' && document.getElementById('status_text').value === 'All 120 rows checked'"
    )
    expect_match(app$get_value(output = "code_app"), "shinyApp(ui, server)", fixed = TRUE)
    # Switching the menu off works even while its text has a problem.
    select_function("mascot_popup_menu")
    app$set_inputs(menu_items = "no equals sign")
    app$set_inputs(menu_on = FALSE)
    app$wait_for_js(paste0(state, ".popup_menu.items === null"))
    app$wait_for_js("!document.getElementById('code_app').textContent.includes('observeEvent(input$helper_menu')")
    # Switching functions reuses the same mounted inputs and their values.
    select_function("mascot_status")
    expect_identical(app$get_value(input = "status_text"), "All 120 rows checked")
    expect_true(app$get_js("document.getElementById('status_text') === window.studioStatusInput"))
    expect_true(app$get_js("document.querySelector('[data-function=mascot_bubble]').hidden"))
    expect_identical(
      app$get_js("document.querySelectorAll('#studio_inspector [data-function]:not([hidden])').length"),
      1L
    )
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    expect_identical(app$get_js("getComputedStyle(document.getElementById('code_tray_body')).overflowY"), "auto")
    app$run_js(
      "document.getElementById('dock_grip').dispatchEvent(new KeyboardEvent('keydown', {key: 'End', bubbles: true}))"
    )
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    # The header remains visible when collapsed; both controls reflect the same state and height.
    tray_settled <- "(() => {
      const dock = document.getElementById('studio_dock');
      // During the max-height transition the computed max-height is the in-between value, so wait for it to end.
      return dock.getAnimations().length === 0 &&
        Math.abs(dock.getBoundingClientRect().height - parseFloat(getComputedStyle(dock).maxHeight)) < 1;
    })()"
    app$wait_for_js(tray_settled)
    expanded_canvas_height <- app$get_js("document.getElementById('studio_canvas').clientHeight")
    expanded_tray_height <- app$get_js("document.getElementById('studio_dock').getBoundingClientRect().height")
    app$click(selector = "#code_tray_header")
    app$wait_for_js("document.getElementById('studio_dock').classList.contains('is-closed')")
    app$wait_for_js(tray_settled)
    app$wait_for_js(sprintf("document.getElementById('studio_canvas').clientHeight > %f", expanded_canvas_height))
    expect_identical(app$get_js("document.getElementById('code_tray_toggle').getAttribute('aria-expanded')"), "false")
    expect_identical(
      app$get_js("document.getElementById('code_tray_toggle').getAttribute('aria-controls')"),
      "code_tray_body"
    )
    expect_true(app$get_js(
      "document.getElementById('code_tray_header').getClientRects().length > 0 &&
      document.getElementById('code_tray_body').getClientRects().length === 0 &&
      document.getElementById('code_tray_body').inert && getComputedStyle(document.getElementById('dock_grip')).display === 'none'"
    ))
    collapsed_canvas_height <- app$get_js("document.getElementById('studio_canvas').clientHeight")
    app$click(selector = "#code_tray_toggle")
    app$wait_for_js("!document.getElementById('studio_dock').classList.contains('is-closed')")
    app$wait_for_js(tray_settled)
    app$wait_for_js(sprintf("document.getElementById('studio_canvas').clientHeight < %f", collapsed_canvas_height))
    expect_true(app$get_js(sprintf(
      "Math.abs(document.getElementById('studio_dock').getBoundingClientRect().height - %f) < 2",
      expanded_tray_height
    )))
    expect_identical(app$get_js("document.getElementById('code_tray_toggle').getAttribute('aria-expanded')"), "true")
    expect_true(app$get_js(
      "!document.getElementById('code_tray_body').inert && getComputedStyle(document.getElementById('dock_grip')).display !== 'none'"
    ))
    # The header bar itself collapses and expands the tray, and the chevron button does the same from the keyboard.
    app$click(selector = "#code_tray_header")
    app$wait_for_js("document.getElementById('studio_dock').classList.contains('is-closed')")
    expect_identical(app$get_js("document.getElementById('code_tray_toggle').getAttribute('aria-expanded')"), "false")
    app$click(selector = "#code_tray_header")
    app$wait_for_js("!document.getElementById('studio_dock').classList.contains('is-closed')")
    expect_identical(app$get_js("document.getElementById('code_tray_toggle').getAttribute('aria-expanded')"), "true")
    expect_true(app$get_js("JSON.parse(sessionStorage.getItem('mascot-studio-tray')).open === true"))
    expect_true(app$get_js("JSON.parse(sessionStorage.getItem('mascot-studio-tray')).height > 0"))
    # mascot_preview() is a normal entry of the index: its page replaces the live mascot on the canvas, its
    # arguments are in Controls and its call is in the Code tray. Selecting another function brings the mascot back.
    expect_false(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_true(app$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    app$click(selector = '.pg-index-link[data-value="mascot_preview"]')
    app$wait_for_js("!!document.querySelector('iframe.pg-preview')", timeout = 15000)
    expect_true(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_false(app$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    expect_true(app$get_js(
      "!!document.getElementById('preview_menu_items') &&
      !document.querySelector('#studio_inspector [data-function=mascot_preview]').hidden"
    ))
    expect_identical(app$get_js("document.querySelector('#code_tabs .nav-link.active').textContent.trim()"), "Preview")
    app$wait_for_js("document.getElementById('code_preview').textContent.includes('mascot_preview(')")
    # The colour pickers are drawn by the server for the selected character; change them once Shiny has bound them.
    app$wait_for_js(
      "Shiny.shinyapp.$inputValues.preview_body !== undefined &&
      Shiny.shinyapp.$inputValues.preview_rim !== undefined",
      timeout = 15000
    )
    app$run_js(
      "(() => {
      for (const [id, value] of [['preview_body', '#1f6feb'], ['preview_rim', '#966600']]) {
        const picker = document.getElementById(id); picker.value = value;
        picker.dispatchEvent(new Event('input'));
      }
    })()"
    )
    app$run_js("Shiny.setInputValue('preview_theme_source', 'custom')")
    app$run_js(
      "Shiny.setInputValue('preview_menu_items', 'about = About the preview');
      document.querySelector('input[name=preview_width][value=phone]').click();"
    )
    # No button is pressed: the page rebuilds by itself once the controls settle, and the code matches it.
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('body = \"#1f6feb\"') &&
      document.getElementById('code_preview').textContent.includes('About the preview')",
      timeout = 15000
    )
    app$wait_for_js("document.querySelector('iframe.pg-preview').classList.contains('is-phone')")
    expect_match(
      app$get_js("document.getElementById('code_preview').textContent"),
      'popup_menu = c(about = "About the preview")',
      fixed = TRUE
    )
    # A visible "Building" badge shows between a change and the rebuilt page.
    app$run_js(
      "window.sawBuilding = false;
      new MutationObserver(() => {
        if (document.querySelector('.pg-building')) window.sawBuilding = true;
      }).observe(document.body, {childList: true, subtree: true});
      Shiny.setInputValue('preview_status', 'Auto build status');"
    )
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('status = \"Auto build status\"')",
      timeout = 15000
    )
    app$wait_for_js("document.querySelectorAll('.pg-building').length === 0", timeout = 15000)
    expect_true(app$get_js("window.sawBuilding"))
    expect_match(
      app$get_js("document.getElementById('code_preview').textContent"),
      'status = "Auto build status"',
      fixed = TRUE
    )
    # Another function brings the live mascot back, in the state it was left in.
    app$click(selector = '.pg-index-link[data-value="mascot_mood"]')
    app$wait_for_js("document.querySelector('[data-canvas=preview]').hidden")
    expect_false(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_identical(app$get_js("document.querySelectorAll('#helper').length"), 1L)
    expect_identical(
      app$get_js(
        "[...document.querySelectorAll('#code_tabs .nav-link')].filter(el => el.getClientRects().length > 0)
        .map(el => el.textContent.trim()).join('|')"
      ),
      "UI|Server|App|Last|Log"
    )
    # Each URL starts a new Shiny session and builds only its own view.
    app$run_js("window.location.search = '?view=examples'")
    app$wait_for_js("!!document.querySelector('#example_code')", timeout = 15000)
    expect_identical(app$get_js("document.querySelectorAll('#helper').length"), 0L)
    expect_identical(
      app$get_js("document.querySelectorAll('#examples_guide_card button, #examples_guide_card input').length"),
      0L
    )
    expect_identical(
      app$get_js("document.querySelectorAll('#examples_guide_card table').length"),
      0L
    )
  })
  it("E2 form-check names invalid fields and becomes happy when both pass", {
    local_shiny_browser()
    app <- example_driver("form-check")
    withr::defer(app$stop())
    wait_example_mood(app, "helper", "worried")
    expect_match(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "2 fields")
    app$set_inputs(sample = "Sample A", quantity = 12)
    wait_example_mood(app, "helper", "happy")
    expect_identical(app$get_js("document.getElementById('checks').textContent"), "Both fields pass.")
    app$set_inputs(quantity = 0)
    wait_example_mood(app, "helper", "worried")
    expect_match(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "1 field")
  })
  it("E3 long-task shows thinking then success and retains an error message", {
    local_shiny_browser()
    app <- example_driver("long-task")
    withr::defer(app$stop())
    wait_example_mood(app, "helper", "idle")
    # Record browser-observed transitions even if the server completes before a poll.
    app$run_js(
      "window.seenMoods=[];new MutationObserver(()=>seenMoods.push(document.getElementById('helper').dataset.shownMood)).observe(document.getElementById('helper'),{attributes:true,attributeFilter:['data-shown-mood']})"
    )
    app$click("start")
    # The task runs as a promise, so the app answers while it works.
    wait_example_mood(app, "helper", "thinking")
    expect_match(app$get_js("document.getElementById('result').textContent"), "Reviewing the sample")
    wait_example_mood(app, "helper", "happy")
    expect_match(app$get_js("document.getElementById('result').textContent"), "all 120 rows")
    expect_true(app$get_js("seenMoods.includes('thinking')"))
    app$set_inputs(fail = TRUE)
    app$click("start")
    wait_example_mood(app, "helper", "worried")
    expect_match(app$get_js("document.querySelector('#helper .mascot-bubble').textContent"), "Check the source data")
    expect_true(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining === null"))
    app$set_inputs(fail = FALSE)
    app$click("start")
    wait_example_mood(app, "helper", "happy")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
  })
  it("E4 modules update their own helpers and return completion to the parent", {
    local_shiny_browser()
    app <- example_driver("modules")
    withr::defer(app$stop())
    wait_example_mood(app, "first-helper", "worried")
    wait_example_mood(app, "second-helper", "worried")
    wait_example_mood(app, "parent", "worried")
    app$set_inputs(`first-ready` = TRUE)
    wait_example_mood(app, "first-helper", "happy")
    wait_example_mood(app, "second-helper", "worried")
    wait_example_mood(app, "parent", "worried")
    app$set_inputs(`second-ready` = TRUE)
    wait_example_mood(app, "parent", "happy")
    expect_true(app$get_js("mascot.host.state(document.getElementById('parent')).placement.floating"))
  })
  it("E5 branding switches palettes and modes and handles each menu action", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- example_driver("branding")
    withr::defer(app$stop())
    wait_example_mood(app, "helper", "idle")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.sleeve?.toLowerCase()==='#1f6feb'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.limb"), "#966600")
    app$click("celebrate")
    wait_example_mood(app, "helper", "celebrating")
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("document.documentElement.dataset.bsTheme==='dark'")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#1f6feb'")
    app$set_inputs(palette = "rose")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#f2a6cf'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.rim"), "#C5B0EB")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.sleeve"), "#F2A6CF")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.limb"), "#C5B0EB")
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("document.documentElement.dataset.bsTheme==='light'")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#b53d78'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.accessory"), "#A94A82")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.sleeve"), "#B53D78")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.limb"), "#A94A82")
    app$click("personalise")
    app$wait_for_js("!!mascot.host.state(document.getElementById('helper')).bubble")
    app$click("original")
    app$wait_for_js("Object.values(mascot.host.state(document.getElementById('helper')).colours).every(x=>x===null)")
    app$click("brand")
    app$wait_for_js("!!mascot.host.state(document.getElementById('helper')).colours.body")
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper [role=menuitem][data-item-id=finish]")
    wait_example_mood(app, "helper", "happy")
    expect_match(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "Review complete")
    expect_match(app$get_js("document.querySelector('#helper .mascot-bubble').textContent"), "All checks finished")
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper [role=menuitem][data-item-id=reset]")
    wait_example_mood(app, "helper", "idle")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.body"), "#B53D78")
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper [role=menuitem][data-item-id=about]")
    app$wait_for_js("!!document.querySelector('.modal.show, .modal.in')")
    expect_match(app$get_js("document.querySelector('.modal-title').textContent"), "About this example")
  })
})

describe("studio round 4 regression guards", {
  it("labels the active placement with the character and keeps inspector hints independent of selection", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", FALSE)))
    env <- environment(app$serverFuncSource())
    map <- get("placement_map", envir = env)
    hint <- get("arg_hint", envir = env)
    for (corner in c("top-left", "top-right", "bottom-left", "bottom-right")) {
      html <- as.character(map(corner, FALSE, "Review character"))
      expect_match(html, sprintf('data-value="%s"[^>]*>\\s*Review character\\s*</span>', corner))
      expect_false(grepl("<button", html, fixed = TRUE))
    }
    expect_match(as.character(map("inline", FALSE, "Review character")), "Review character, inline")
    # The one-line hint is the first sentence of the argument's help text, so it cannot depend on the selection.
    text <- hint("mascot_character", "name")
    expect_false(grepl("Selected:", text, fixed = TRUE))
    expect_match(text, "built-in character", fixed = TRUE)
  })
  it("gets character labels and defaults from the package", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    for (file in list.files(dir, recursive = TRUE, full.names = TRUE)) {
      expect_false(any(grepl("tessa", readLines(file, warn = FALSE), ignore.case = TRUE)), info = file)
    }
    env <- new.env()
    sys.source(file.path(dir, "R", "data.R"), env)
    expect_identical(unname(env$studio_characters()), formals(mascot)$character)
    expect_identical(names(env$studio_characters()), mascot_character(formals(mascot)$character)$name)
  })
  it("omits empty colour groups and groups unfamiliar parts", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", FALSE)), "R", "panels.R"), env)
    groups <- env$colour_groups(data.frame(role = c("feature", "beak")))
    expect_named(groups, c("Face", "Other parts"))
    expect_identical(groups$`Other parts`, "beak")
  })
  it("keeps only explicit shared colour overrides across character palettes", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", FALSE)), "R", "panels.R"), env)
    old <- data.frame(role = c("body", "outline", "limb"), colour = c("#abcdef", "#000000", "#123456"))
    new <- data.frame(role = c("body", "outline", "beak"), colour = c("#fedcba", "#111111", "#654321"))
    values <- env$reconcile_colour_values(
      old,
      new,
      list(body = "#ABCDEF", outline = "#444444", limb = "#999999", beak = "#222222")
    )
    expect_named(values, new$role)
    expect_null(values$body)
    expect_identical(values$outline, "#444444")
    expect_null(values$beak)
  })
  it("round-trips menu ids containing reserved words and backticks", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", FALSE)), "R", "code.R"), env)
    items <- c("a`b" = "Action", "if" = "Conditional action", "a\\b" = "Slash")
    code <- env$format_expr(env$code_menu(items)$short)
    expect_identical(eval(parse(text = code)), items)
    expect_type(parse(text = env$menu_handler_code(items)), "expression")
  })
})

describe("studio state and built previews", {
  it("keeps programmatic changes and copied code in step without overlapping tasks", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", FALSE)))
    env <- environment(app$serverFuncSource())
    placement_code <- get("code_placement", envir = env)
    shiny::testServer(env$studio_server, {
      messages <- list()
      session$sendInputMessage <- function(id, message) messages[[id]] <<- message
      session$setInputs(
        character = formals(mascot)$character,
        mood = "idle",
        status_text = "",
        code_style = "short",
        bubble_text = "Hello",
        bubble_html = FALSE,
        bubble_forever = FALSE,
        bubble_duration = 5,
        bubble_closable = TRUE,
        theme_source = "own",
        theme_mode = "auto",
        css_roles = character(),
        css_accent = "#123456",
        position = "inline",
        minimise = TRUE,
        drag = "FALSE",
        size_unit = "px",
        size_px = 160,
        small_on = FALSE,
        animate = TRUE,
        swap = TRUE,
        menu_on = TRUE,
        menu_items = "finish = Finish review",
        menu_direction = "auto",
        mistake = "Misspell an argument",
        studio_view = "studio",
        studio_fn = "",
        studio_run = FALSE
      )
      session$setInputs(task_run = 1)
      expect_identical(state$mood$short, "thinking")
      expect_identical(messages$mood$value, "thinking")
      expect_identical(messages$status_text$value, "Checking 120 rows")
      job <- task()
      session$setInputs(task_fail = TRUE, task_run = 2)
      expect_identical(task(), job)
      # Expire the timer without a wall-clock wait; completion uses the same observer.
      task(list(fail = FALSE, ends = Sys.time() - 1))
      session$flushReact()
      expect_identical(state$mood$short, "happy")
      expect_identical(messages$mood$value, "happy")
      expect_identical(messages$status_text$value, "All 120 rows checked")
      expect_null(task())
      session$setInputs(helper_position = "top-left")
      expect_identical(state$placement, placement_code("top-left", TRUE, "snap"))
      expect_identical(messages$position$value, "top-left")
      bubble <- state$bubble
      session$setInputs(helper_menu = "finish")
      expect_identical(state$bubble, bubble)
      session$setInputs(mistake = "Minimise an inline mascot", mistake_run = 1)
      expect_identical(state$placement, placement_code("inline"))
      expect_identical(messages$position$value, "inline")
      expect_false(grepl("minimise = TRUE", output$code_ui, fixed = TRUE))
      session$setInputs(menu_on = FALSE)
      session$elapse(700)
      expect_false(grepl("observeEvent(input$helper_menu", output$code_app, fixed = TRUE))
      # Re-selecting the available character exercises the same atomic update as a future character swap.
      # Mood must be present even when it matches state: the engine resets mood on a changed character id.
      session$setInputs(mood = messages$mood$value)
      custom_messages <- list()
      session$sendCustomMessage <- function(type, message) {
        custom_messages[[length(custom_messages) + 1L]] <<- list(type = type, message = message)
      }
      session$setInputs(character = formals(mascot)$character)
      patches <- Filter(function(x) identical(x$type, "mascot:update"), custom_messages)
      expect_length(patches, 1)
      expect_identical(patches[[1]]$message$patch$character$id, formals(mascot)$character)
      expect_identical(patches[[1]]$message$patch$mood, "happy")
      expect_identical(state$mood$short, "happy")
      expect_identical(messages$mood$value, "happy")
      expect_match(output$code_ui, 'mood = "happy"', fixed = TRUE)
      session$setInputs(select_function = "mascot_example")
      example_call <- output$code_function
      expect_match(example_call, 'run = FALSE', fixed = TRUE)
      example_path <- eval(parse(text = example_call), envir = env)
      expect_true(file.exists(example_path))
      unchanged <- shiny::reactiveValuesToList(state)
      custom_messages <- list()
      guide <- get("selected_guide", envir = env)
      for (fn in names(get("playground_guide", envir = env))) {
        expect_match(as.character(guide(fn)), "Warnings, errors and common mistakes", fixed = TRUE)
        session$setInputs(select_function = fn)
        html <- output$guide$html
        expect_match(html, "Warnings, errors and common mistakes", fixed = TRUE)
        expect_false(grepl("<(input|select|textarea)\\b|data-event=", html, perl = TRUE), info = fn)
        buttons <- regmatches(html, gregexpr("<button\\b[^>]*>", html, perl = TRUE))[[1]]
        expect_true(all(grepl("data-copy=", buttons, fixed = TRUE)), info = fn)
        # Verify no Guide contains a visual belonging to another function
        if (fn == "mascot_size") {
          expect_match(html, 'id="size_ruler"', fixed = TRUE)
          expect_false(grepl('id="placement_map"', html, fixed = TRUE))
        } else if (fn == "mascot_placement") {
          expect_match(html, 'id="placement_map"', fixed = TRUE)
          expect_false(grepl('id="size_ruler"', html, fixed = TRUE))
        } else if (fn == "mascot_colour_roles") {
          expect_match(html, 'id="roles_table"', fixed = TRUE)
          expect_false(grepl("pg-flow", html, fixed = TRUE))
        } else if (fn == "mascot_theme") {
          expect_match(html, "pg-flow", fixed = TRUE)
          expect_false(grepl('id="roles_table"', html, fixed = TRUE))
        } else if (fn == "mascot_status") {
          expect_match(html, "Status line or speech bubble?", fixed = TRUE)
          expect_false(grepl("pg-timeline", html, fixed = TRUE))
        } else if (fn == "mascot_bubble") {
          expect_match(html, "pg-timeline", fixed = TRUE)
          expect_false(grepl("Status line or speech bubble?", html, fixed = TRUE))
        } else if (fn == "mascot") {
          expect_match(html, "Two calls, one id", fixed = TRUE)
          expect_false(grepl("What each kind of value does in updateMascot()", html, fixed = TRUE))
        } else if (fn == "updateMascot") {
          expect_match(html, "What each kind of value does in updateMascot()", fixed = TRUE)
          expect_false(grepl("Two calls, one id", html, fixed = TRUE))
        }
      }
      expect_false(grepl("<(button|input|select|textarea)\\b|data-event=", output$placement_map$html, perl = TRUE))
      guide_page <- get("guide_content", envir = env)
      for (category in c("preview", "examples")) {
        expect_false(grepl(
          "<(button|input|select|textarea)\\b|data-event=",
          as.character(guide_page(category)),
          perl = TRUE
        ))
      }
      expect_identical(shiny::reactiveValuesToList(state), unchanged)
      expect_length(Filter(function(x) startsWith(x$type, "mascot:"), custom_messages), 0)
      modal_messages <- list()
      session$sendModal <- function(type, message) {
        modal_messages[[length(modal_messages) + 1L]] <<- list(type = type, message = message)
      }
      session$setInputs(open_guide = "mascot_mood")
      expect_identical(modal_messages[[1]]$type, "show")
      expect_match(modal_messages[[1]]$message$html, 'id="close_guide"', fixed = TRUE)
      session$setInputs(close_guide = 1)
      expect_identical(modal_messages[[2]]$type, "remove")
      session$setInputs(close_guide = "escape")
      expect_identical(modal_messages[[3]]$type, "remove")
    })
  })
  it("shows the call that built the preview and rebuilds it after a pause", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", FALSE)))
    env <- environment(app$serverFuncSource())
    shiny::testServer(env$studio_server, {
      session$setInputs(
        character = formals(mascot)$character,
        mood = "idle",
        status_text = "",
        code_style = "short",
        bubble_text = "Hello",
        bubble_html = FALSE,
        bubble_forever = FALSE,
        bubble_duration = 5,
        bubble_closable = TRUE,
        theme_source = "own",
        theme_mode = "auto",
        css_roles = character(),
        css_accent = "#123456",
        position = "inline",
        minimise = FALSE,
        drag = "FALSE",
        size_unit = "px",
        size_px = 160,
        small_on = FALSE,
        animate = TRUE,
        swap = TRUE,
        menu_on = FALSE,
        menu_items = "",
        menu_direction = "auto",
        mistake = "Misspell an argument",
        preview_theme_source = "own",
        preview_mood = "idle",
        preview_status = "",
        preview_bubble = "",
        preview_size = 120,
        preview_placement = "inline",
        preview_motion = FALSE,
        preview_menu_items = "",
        preview_width = "full"
      )
      # Nothing is built until mascot_preview() is selected.
      expect_match(output$code_preview, "Select mascot_preview()", fixed = TRUE)
      session$setInputs(select_function = "mascot_preview")
      session$elapse(500)
      built <- output$code_preview
      expect_match(built, "mascot_preview(", fixed = TRUE)
      expect_false(grepl("theme =", built, fixed = TRUE))
      expect_identical(output$code_function, built)
      expect_false(is_building())
      session$setInputs(preview_mood = "happy")
      # The new arguments are pending (Building...) until the pause ends; then the page and its code follow.
      expect_true(is_building())
      session$elapse(500)
      expect_false(is_building())
      expect_match(output$code_preview, 'mood = "happy"', fixed = TRUE)
      expect_false(identical(output$code_preview, built))
      session$setInputs(preview_status = "Auto rebuild status")
      session$elapse(500)
      expect_match(output$code_preview, 'status = "Auto rebuild status"', fixed = TRUE)
      expect_true(file.exists(file.path(preview_dir, sprintf("preview-%s-%d.html", session$token, preview_count()))))
      # A menu line that is not "id = Label" is reported and nothing is rebuilt from it.
      session$setInputs(preview_menu_items = "no label here")
      session$elapse(500)
      expect_match(output$preview_problem$html, "id = Label", fixed = TRUE)
      expect_match(output$code_preview, 'status = "Auto rebuild status"', fixed = TRUE)
    })
  })
})
