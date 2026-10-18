describe("mascot_examples()", {
  it("lists the studio and six scenario apps in order with readable metadata", {
    examples <- mascot_examples()
    expect_s3_class(examples, "data.frame")
    expect_named(examples, c("name", "title", "description"))
    expect_identical(examples$name, c("studio", "form-check", "long-task", "modules", "branding", "golem", "rhino"))
    expect_true(all(vapply(examples, is.character, logical(1))))
    expect_true(all(nzchar(unlist(examples))))
    expect_identical(anyDuplicated(examples$name), 0L)
    expect_match(examples$description[examples$name == "branding"], "Requires bslib")
  })
  it("copies single-file scenarios and the studio and rhino folders, and builds it without a server", {
    # mascot is already attached by the test run; attaching it here would detach it on exit.
    withr::local_package("shiny")
    if (requireNamespace("bslib", quietly = TRUE)) {
      withr::local_package("bslib")
    }
    for (name in setdiff(mascot_examples()$name, "golem")) {
      file <- mascot_example(name, run = FALSE)
      expect_true(file.exists(file), info = name)
      # The studio and framework examples need their whole folder.
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
      } else if (name == "rhino") {
        expect_setequal(sources, c("app.R", "app/view/main.R", "app/view/review.R"))
      } else {
        expect_identical(sources, "app.R", info = name)
      }
      copy <- withr::local_tempdir()
      expect_true(file.copy(dirname(file), copy, recursive = TRUE))
      dir <- file.path(copy, name)
      for (script in list.files(dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)) {
        expect_type(parse(script), "expression")
      }
      if (name != "rhino" && !requireNamespace("bslib", quietly = TRUE)) {
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
    call <- code$format_call("mascot", list(id = "helper", click = menu$helper, theme = theme$helper))
    expect_match(call, "`finish-review` = ", fixed = TRUE)
    expect_identical(eval(parse(text = call)[[1]][["click"]]), mascot_popup_menu(items))
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
      code$code_motion(idle = "false", swap = "false"),
      code$code_size("20%", 72),
      code$code_placement("top-left", minimise = TRUE, drag = "snap"),
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
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), envir = code)
    for (mode in c("snap", "free")) {
      pair <- code$code_placement("bottom-right", minimise = TRUE, drag = mode)
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
    expect_identical(code$code_placement("inline", minimise = FALSE, drag = "snap"), inline)
    hidden <- code$code_placement("top-left", minimise = FALSE)
    expect_identical(eval(hidden$helper), mascot_placement("top-left", minimise = FALSE))
    expect_identical(eval(hidden$short), list(position = "top-left", minimise = FALSE))
    call <- code$format_call("mascot", list(id = "helper", placement = inline$short))
    expect_match(call, 'placement = "inline"', fixed = TRUE)
    expect_type(parse(text = call), "expression")
  })
  it("preserves every menu direction in shortcut and helper code, including an empty menu", {
    code <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), envir = code)
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
    # A menu has no shortcut since click replaced popup_menu; its label is kept only when written.
    labelled <- code$code_menu(c(about = "About"), "auto", "Help and settings")
    expect_identical(labelled$short, labelled$helper)
    expect_identical(eval(labelled$helper), mascot_popup_menu(c(about = "About"), label = "Help and settings"))
    expect_null(eval(code$code_menu(c(about = "About"), "auto", "  ")$helper)$label)
    tooltip_off <- code$code_menu(c(about = "About"), "auto", "Help and settings", tooltip = FALSE)
    expect_identical(
      eval(tooltip_off$helper),
      mascot_popup_menu(c(about = "About"), label = "Help and settings", tooltip = FALSE)
    )
    expect_match(code$format_expr(tooltip_off$helper), "tooltip = FALSE", fixed = TRUE)
    tooltip_no_label <- code$code_menu(c(about = "About"), "auto", "", tooltip = FALSE)
    expect_false(grepl("tooltip", code$format_expr(tooltip_no_label$helper), fixed = TRUE))
  })
  it("writes an action as its label, or as mascot_action() when it hides the tooltip or is disabled", {
    code <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), envir = code)
    plain <- code$code_action("Open help", TRUE, FALSE)
    expect_identical(plain$short, "Open help")
    expect_identical(eval(plain$helper), mascot_action("Open help"))
    for (flags in list(c(FALSE, FALSE), c(TRUE, TRUE), c(FALSE, TRUE))) {
      pair <- code$code_action("Open help", flags[[1]], flags[[2]])
      expected <- mascot_action("Open help", tooltip = flags[[1]], disabled = flags[[2]])
      expect_identical(pair$short, pair$helper)
      expect_identical(eval(parse(text = code$format_expr(pair$helper))[[1]]), expected)
    }
    # A blank label is no action: the empty helper, which removes the click.
    expect_identical(code$code_action("  ")$helper, quote(mascot_action()))
    expect_null(code$click_handler_code(quote(mascot_action())))
    handler <- code$click_handler_code(plain$helper)
    expect_match(handler, "observeEvent(input$helper_click", fixed = TRUE)
    expect_type(parse(text = handler), "expression")
    expect_match(code$click_handler_code(code$code_menu(c(about = "About"))$helper), "input$helper_menu", fixed = TRUE)
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
      "mascot_motion_settings",
      "mascot_placement",
      "mascot_theme",
      "mascot_action",
      "mascot_popup_menu",
      "update_mascot"
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
    help <- new.env()
    sys.source(file.path(dir, "R", "help.R"), envir = help)
    ui <- new.env()
    sys.source(file.path(dir, "R", "ui.R"), envir = ui)
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
    expect_match(pages[[1]], 'id="preview_card"', fixed = TRUE)
    expect_false(grepl('id="preview_menu_items"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="preview_placement"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="helper"', pages[[2]], fixed = TRUE))
    expect_false(grepl("Use the studio's", pages[[2]], fixed = TRUE))
    expect_false(grepl("Open in a new tab", pages[[2]], fixed = TRUE))
    # mascot_studio() has no inputs and only a Copy button in its controls.
    expect_match(pages[[1]], 'id="studio_example_call"', fixed = TRUE)
    expect_match(pages[[1]], 'data-copy="studio_example_call"', fixed = TRUE)
    expect_false(grepl('id="studio_view"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="studio_fn"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="studio_run"', pages[[1]], fixed = TRUE))
    for (fn in getNamespaceExports("mascot")) {
      if (fn == "mascot_studio") {
        # mascot_studio() is the launcher of this studio: checked for read-only argument rows instead of controls.
        for (arg in names(formals(getExportedValue("mascot", fn)))) {
          expect_true(
            grepl(sprintf('class="pg-arg"[^>]*data-argument="%s"', arg), pages[[1]]) ||
              grepl(sprintf('data-argument="%s"[^>]*class="pg-arg"', arg), pages[[1]]),
            info = paste(fn, arg)
          )
          expect_true(
            grepl(sprintf('class="pg-arg-name">%s</code>', arg), pages[[1]], fixed = TRUE),
            info = paste(fn, arg)
          )
          expect_true(
            grepl(ui$argument_default(fn, arg), pages[[1]], fixed = TRUE),
            info = paste(fn, arg)
          )
          h <- help$help_arg(fn, arg)
          if (!is.null(h)) {
            expect_true(
              grepl(help$html_text(h), help$html_text(pages[[1]]), fixed = TRUE),
              info = paste(fn, arg)
            )
          }
        }
        next
      }
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
      expect_error(mascot_example(bad, run = FALSE), "Assertion on 'name' failed")
    }
    for (bad in list(NULL, NA, 1, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_example("studio", run = bad), "Assertion on 'run' failed")
    }
    expect_snapshot(error = TRUE, mascot_example("typo", run = FALSE))
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
    expect_identical(captured, dirname(mascot_example("modules", run = FALSE)))
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
  app_driver(app_function, width = width, height = 900)
}

wait_example_mood <- function(app, id, mood) {
  checkmate::assert_r6(app, "AppDriver")
  checkmate::assert_string(id)
  checkmate::assert_string(mood)
  app$wait_for_js(sprintf("document.getElementById('%s')?.dataset.shownMood === '%s'", id, mood))
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
    # E1: the code itself is visible in the open tray at 1440 x 900 without scrolling.
    app$wait_for_js("document.getElementById('studio_dock').getAnimations().length === 0")
    expect_true(app$get_js(
      "(() => {
      const tray = document.getElementById('code_tray_body');
      const code = document.getElementById('code_ui').getBoundingClientRect();
      const visible = tray.getBoundingClientRect();
      return tray.scrollTop === 0 && code.top >= visible.top &&
        code.top + 20 < Math.min(visible.bottom, window.innerHeight);
    })()"
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
      "![...document.querySelectorAll('#studio_inspector .accordion-item')].some(item => /^(mascot|update_mascot)/.test(item.dataset.value || ''))"
    ))
    expect_identical(
      app$get_js("document.querySelectorAll('#studio_inspector [data-event=select_function]').length"),
      19L
    )
    select_function("mascot")
    app$click(selector = '[data-function=mascot] a[data-event=select_function][data-value=mascot_status]')
    app$wait_for_js(
      "Shiny.shinyapp.$inputValues.select_function === 'mascot_status' &&
      !document.querySelector('#studio_inspector [data-function=mascot_status]').hidden"
    )
    select_function("mascot_mood")
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
      "(() => {
        const code = document.getElementById('code_function').getBoundingClientRect();
        const copy = document.querySelector('[data-copy=code_function]').getBoundingClientRect();
        return copy.top >= code.top && copy.right <= code.right;
      })()"
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
      if (fn == "mascot_studio") {
        expect_identical(
          app$get_js(
            "document.querySelectorAll('#studio_inspector [data-function=mascot_studio] input, #studio_inspector [data-function=mascot_studio] select, #studio_inspector [data-function=mascot_studio] textarea').length"
          ),
          0L
        )
        expect_identical(
          app$get_js(
            "document.querySelectorAll('#studio_inspector [data-function=mascot_studio] .pg-function-controls button:not([data-copy])').length"
          ),
          0L
        )
        expect_identical(
          app$get_js(
            "document.querySelectorAll('#studio_inspector [data-function=mascot_studio] button[data-copy]').length"
          ),
          1L
        )
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
    app$wait_for_js("document.getElementById('studio_panels_card').getBoundingClientRect().height > 300")
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
    # The native Mood drop-down is the studio's only mood input.
    expect_identical(app$get_js("document.querySelectorAll('select#mood').length"), 1L)
    app$set_inputs(mood = "happy")
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
    select_function("mascot_motion_settings")
    app$set_inputs(idle = "false")
    app$wait_for_js(paste0(state, ".motion.idle === false"))
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
    app$set_inputs(drag = "none", position = "inline")
    app$wait_for_js("document.getElementById('drag').disabled && document.getElementById('minimise').disabled")
    select_function("mascot_theme")
    app$set_inputs(theme_source = "mascot")
    app$run_js(
      "const p = document.getElementById('light_body'); p.value = '#1f6feb'; p.dispatchEvent(new Event('input'))"
    )
    app$wait_for_js(paste0(state, ".colours.body?.toLowerCase() === '#1f6feb'"))
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('mascot_theme(light = list(body')")
    # A followed highlight and an explicit highlight both use the engine's key: snake_case since Tessa moved to the
    # format-v1 engine (M1); the studio maps either spelling to the public role name.
    highlight_swatch_matches <- paste0(
      "(() => {
      const swatch = document.querySelector('.pg-resolved[data-mode=light][data-role=body_highlight]');
      const expected = document.createElement('span'); expected.style.background = ",
      state,
      ".colours.body_highlight;
      return !!swatch && swatch.style.background === expected.style.background && !swatch.classList.contains('is-idle');
    })()"
    )
    app$wait_for_js(highlight_swatch_matches)
    expect_true(app$get_js(highlight_swatch_matches))
    app$run_js(
      "(() => { const p = document.getElementById('light_body_highlight'); p.value = '#abcdef';
      p.dispatchEvent(new Event('input')); })()"
    )
    app$wait_for_js(paste0(state, ".colours.body_highlight?.toLowerCase() === '#abcdef'"))
    app$wait_for_js(highlight_swatch_matches)
    expect_true(app$get_js(highlight_swatch_matches))
    select_function("mascot_popup_menu")
    # The controls start with the mascot's own menu, so changing only the direction keeps every item (#256).
    app$set_inputs(menu_direction = "top")
    app$wait_for_js(paste0(state, ".click.direction === 'top'"))
    expect_identical(
      app$get_js(paste0("Object.keys(", state, ".click.items).join()")),
      "finish,reset,about"
    )
    app$set_inputs(menu_on = TRUE, menu_items = "finish = Finish review", menu_direction = "right")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('direction = \"right\"')")
    app$wait_for_js(paste0(state, ".click.direction === 'right'"))
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper .mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=finish]")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble')?.textContent.includes('Finish review')")
    expect_false(grepl("You chose", app$get_value(output = "code_ui"), fixed = TRUE))
    # A mistake is an error in the log, and the mascot keeps its settings.
    select_function("update_mascot")
    app$set_inputs(mistake = "Misspell an argument")
    app$click("mistake_run")
    app$wait_for_js("document.getElementById('log').textContent.includes('Unexpected arguments')")
    # The second step of the slow task runs later and names the session.
    app$click("task_run")
    wait_example_mood(app, "helper", "thinking")
    expect_true(app$get_js("document.getElementById('task_run').disabled"))
    app$wait_for_js(paste0(state, ".status.text === 'All 120 rows checked'"))
    app$wait_for_js("document.getElementById('code_last').textContent.includes('session = session')")
    app$wait_for_js(
      "document.getElementById('mood').value === 'happy' && document.getElementById('status_text').value === 'All 120 rows checked'"
    )
    expect_match(app$get_value(output = "code_app"), "shinyApp(ui, server)", fixed = TRUE)
    # Switching the menu off works even while its text has a problem.
    select_function("mascot_popup_menu")
    app$set_inputs(menu_items = "no equals sign")
    app$set_inputs(menu_on = FALSE)
    app$wait_for_js(paste0(state, ".click.type === 'none'"))
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
    app$wait_for_js("!!document.querySelector('iframe.pg-preview')")
    expect_true(app$get_js("document.querySelector('[data-canvas=mascot]').hidden"))
    expect_false(app$get_js("document.querySelector('[data-canvas=preview]').hidden"))
    expect_true(app$get_js(
      "!!document.getElementById('preview_mood') &&
      !document.querySelector('#studio_inspector [data-function=mascot_preview]').hidden"
    ))
    expect_true(app$get_js("document.querySelector('#preview_card .bslib-full-screen-enter') !== null"))
    app$click(selector = "#preview_card .bslib-full-screen-enter")
    app$wait_for_js("document.getElementById('preview_card').getAttribute('data-full-screen') === 'true'")
    expect_true(app$get_js("document.getElementById('preview_card').getBoundingClientRect().height > 400"))
    app$click(selector = ".bslib-full-screen-exit")
    app$wait_for_js("document.getElementById('preview_card').getAttribute('data-full-screen') === 'false'")
    app$click(selector = "#preview_card .bslib-full-screen-enter")
    app$wait_for_js("document.getElementById('preview_card').getAttribute('data-full-screen') === 'true'")
    app$run_js(
      "document.getElementById('preview_card').dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}))"
    )
    app$wait_for_js("document.getElementById('preview_card').getAttribute('data-full-screen') === 'false'")
    expect_identical(app$get_js("document.querySelector('#code_tabs .nav-link.active').textContent.trim()"), "Preview")
    app$wait_for_js("document.getElementById('code_preview').textContent.includes('mascot_preview(')")
    # The colour pickers are drawn by the server for the selected character; change them once Shiny has bound them.
    app$wait_for_js(
      "Shiny.shinyapp.$inputValues.preview_body !== undefined &&
      Shiny.shinyapp.$inputValues.preview_rim !== undefined"
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
      "document.querySelector('input[name=preview_width][value=phone]').click();"
    )
    # No button is pressed: the page rebuilds by itself once the controls settle, and the code matches it.
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('body = \"#1f6feb\"')"
    )
    app$wait_for_js("document.querySelector('iframe.pg-preview').classList.contains('is-phone')")
    expect_false(grepl("click =", app$get_js("document.getElementById('code_preview').textContent"), fixed = TRUE))
    # A visible "Building" badge shows between a change and the rebuilt page.
    app$run_js(
      "window.sawBuilding = false;
      new MutationObserver(() => {
        if (document.querySelector('.pg-building')) window.sawBuilding = true;
      }).observe(document.body, {childList: true, subtree: true});
      Shiny.setInputValue('preview_status', 'Auto build status');"
    )
    app$wait_for_js(
      "document.getElementById('code_preview').textContent.includes('status = \"Auto build status\"')"
    )
    app$wait_for_js("document.querySelectorAll('.pg-building').length === 0")
    expect_true(app$get_js("window.sawBuilding"))
    expect_match(
      app$get_js("document.getElementById('code_preview').textContent"),
      'status = "Auto build status"',
      fixed = TRUE
    )
    # Another function brings the live mascot back, in the state it was left in.
    app$click(selector = '.pg-index-link[data-value="mascot_mood"]')
    app$wait_for_js("document.querySelector('[data-canvas=preview]').hidden")
    # The server hides the Preview tab after the client switches the stage.
    app$wait_for_js("document.querySelector('#code_tabs a[data-value=preview]').getClientRects().length === 0")
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
    app$wait_for_js("!!document.querySelector('#example_code')")
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
    app$click(selector = "#helper .mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=reset]")
    wait_example_mood(app, "helper", "idle")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.body"), "#B53D78")
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper .mascot-menu:not([hidden]):not(.mascot-motion-copy) [data-item-id=about]")
    app$wait_for_js("!!document.querySelector('.modal.show, .modal.in')")
    expect_match(app$get_js("document.querySelector('.modal-title').textContent"), "About this example")
  })
})

describe("studio round 4 regression guards", {
  it("labels the active placement with the character and keeps inspector hints independent of selection", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
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
    text <- hint("mascot_character", "id")
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
    expect_identical(unname(env$studio_characters())[[1L]], formals(mascot)$character)
    expect_identical(names(env$studio_characters()), c("Tessa", "Sela", "Knurl (experimental)", "Neer (experimental)"))
  })
  it("omits empty colour groups and groups unfamiliar parts", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "panels.R"), env)
    groups <- env$colour_groups(data.frame(role = c("feature", "beak")))
    expect_named(groups, c("Face", "Other parts"))
    expect_identical(groups$`Other parts`, "beak")
  })
  it("keeps only explicit shared colour overrides across character palettes", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "panels.R"), env)
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
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), env)
    items <- c("a`b" = "Action", "if" = "Conditional action", "a\\b" = "Slash")
    code <- env$format_expr(env$code_menu(items)$short)
    expect_identical(eval(parse(text = code))$items, items)
    expect_type(parse(text = env$menu_handler_code(items)), "expression")
  })
})

# Until the browser's mount snapshot makes the studio's helper live, calls are kept, not accepted or sent. This
# snapshot is what the page sends on mount, so the studio's kept calls are accepted and the first state is sent.
# Defined before its first use: describe() blocks run while this file is sourced.
studio_go_live <- function(session) {
  protocol_ready(list(session = session, id = session$ns("helper")))
  session$flushReact()
  invisible(NULL)
}

describe("studio state and built previews", {
  it("keeps programmatic changes and copied code in step without overlapping tasks", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
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
        drag = "none",
        size_unit = "px",
        size_px = 160,
        small_mode = "auto",
        idle = "follow",
        mood_change = "follow",
        gestures = "follow",
        swap = "follow",
        minimising = "follow",
        restoring = "follow",
        messages = "follow",
        others = TRUE,
        menu_on = TRUE,
        menu_items = "finish = Finish review",
        menu_direction = "auto",
        mistake = "Misspell an argument"
      )
      for (code in c(output$code_ui, output$code_server, output$code_app)) {
        expect_false(grepl("Hello! Choose a function|About this studio", code))
      }
      for (fn in c("mascot", "update_mascot")) {
        session$setInputs(select_function = fn)
        expect_false(grepl("Hello! Choose a function|About this studio", output$code_function))
      }
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
      expect_identical(state$placement, placement_code("top-left", minimise = TRUE, drag = "snap"))
      expect_identical(messages$position$value, "top-left")
      task(list(fail = TRUE, ends = Sys.time() - 1))
      session$flushReact()
      expect_match(messages$bubble_text$value, "Three rows")
      task(list(fail = FALSE, ends = Sys.time() - 1))
      session$flushReact()
      expect_null(eval(state$bubble$helper)$text)
      expect_identical(messages$bubble_text$value, "")
      expect_false(messages$bubble_forever$value)
      session$setInputs(send_many = 1)
      expect_identical(messages$bubble_text$value, "All 120 rows passed.")
      expect_true(messages$bubble_forever$value)
      # Browser input acknowledgements are separate from server update messages.
      session$setInputs(
        bubble_text = messages$bubble_text$value,
        bubble_html = messages$bubble_html$value,
        bubble_forever = messages$bubble_forever$value,
        bubble_closable = messages$bubble_closable$value,
        select_function = "mascot_bubble"
      )
      expect_identical(eval(parse(text = output$code_function))$text, eval(state$bubble$helper)$text)
      expect_identical(eval(parse(text = output$code_function))$duration, Inf)
      session$setInputs(menu_items = "missing equals", select_function = "mascot_popup_menu")
      for (code in c(output$code_function, output$menu_code, output$code_ui, output$code_server, output$code_app)) {
        expect_match(code, "^# .*id = Label")
      }
      # Ids the package rejects (duplicates) also give a comment, not a runnable handler.
      session$setInputs(menu_on = TRUE, menu_items = "same = One\nsame = Two")
      session$elapse(700)
      expect_match(output$menu_code, "^# ")
      session$setInputs(menu_items = "finish = Finish review")
      session$elapse(700)
      # An HTML bubble keeps its HTML switch on after it is shown.
      session$setInputs(bubble_text = "<b>Saved</b>", bubble_html = TRUE, bubble_show = 1)
      expect_true(messages$bubble_html$value)
      session$setInputs(contrast_check = 1)
      expect_match(output$contrast$html, "Every colour checked")
      session$setInputs(theme_source = "mascot", theme_mode = "dark")
      expect_match(output$contrast$html, "[Ss]tale")
      session$setInputs(theme_source = "own", theme_mode = "auto")
      session$elapse(400)
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
      session$setInputs(mood = "happy")
      # Re-selecting the available character exercises the same atomic update as a future character swap.
      # Mood must be present even when it matches state: the engine resets mood on a changed character id.
      session$setInputs(mood = messages$mood$value)
      custom_messages <- list()
      session$sendCustomMessage <- function(type, message) {
        custom_messages[[length(custom_messages) + 1L]] <<- list(type = type, message = message)
      }
      # The mascot goes live (its mount arrives) so the update below is sent, not kept; the mount's own state is
      # set aside before the character change is counted.
      studio_go_live(session)
      custom_messages <- list()
      session$setInputs(character = formals(mascot)$character)
      envelopes <- Filter(function(x) identical(x$type, "mascot:update"), custom_messages)
      expect_length(envelopes, 1)
      expect_identical(envelopes[[1]]$message$state$character$id, formals(mascot)$character)
      expect_identical(envelopes[[1]]$message$state$mood, "happy")
      expect_identical(state$mood$short, "happy")
      expect_identical(messages$mood$value, "happy")
      expect_match(output$code_ui, 'mood = "happy"', fixed = TRUE)
      session$setInputs(select_function = "mascot_example")
      example_call <- output$code_function
      expect_match(example_call, 'run = FALSE', fixed = TRUE)
      example_path <- eval(parse(text = example_call), envir = env)
      expect_true(file.exists(example_path))
      session$setInputs(select_function = "mascot_studio")
      expect_identical(output$code_function, 'mascot_studio(fn = "mascot_theme")')
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
          expect_false(grepl("What each kind of value does in update_mascot()", html, fixed = TRUE))
        } else if (fn == "update_mascot") {
          expect_match(html, "What each kind of value does in update_mascot()", fixed = TRUE)
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
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
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
        drag = "none",
        size_unit = "px",
        size_px = 160,
        small_mode = "auto",
        idle = "follow",
        mood_change = "follow",
        gestures = "follow",
        swap = "follow",
        minimising = "follow",
        restoring = "follow",
        messages = "follow",
        others = TRUE,
        menu_on = FALSE,
        menu_items = "",
        menu_direction = "auto",
        mistake = "Misspell an argument",
        preview_theme_source = "own",
        preview_mood = "idle",
        preview_status = "",
        preview_bubble = "",
        preview_size = 120,
        preview_motion = FALSE,
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
      # A size below the supported minimum is reported without replacing the last good page.
      session$setInputs(preview_size = 10)
      session$elapse(500)
      expect_match(output$code_preview, "^# ")
      expect_identical(last_preview_attempt()$outcome, "error")
      session$setInputs(preview_size = 120)
      session$elapse(500)
      expect_match(output$preview_frame$html, "iframe")
      expect_identical(last_preview_attempt()$outcome, "ok")
      expect_identical(last_preview_attempt()$args, last_built_call())
      session$setInputs(preview_size = 10)
      session$elapse(500)
      session$setInputs(select_function = "mascot_mood", preview_size = 120)
      session$elapse(500)
      expect_identical(last_preview_attempt()$outcome, "error")
      session$setInputs(select_function = "mascot_preview")
      session$elapse(500)
      expect_match(output$preview_frame$html, "iframe")
      expect_identical(last_preview_attempt()$outcome, "ok")
      files <- list.files(preview_dir, pattern = "^preview-.*[.]html$")
      expect_length(files, 2)
      expect_true(all(file.exists(file.path(
        preview_dir,
        sprintf(
          "preview-%s-%d.html",
          session$token,
          c(preview_count() - 1, preview_count())
        )
      ))))
    })
  })
})


describe("studio round 8 help and copied apps", {
  it("keeps a missing help page local while strict lookup still fails", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
    env <- environment(app$serverFuncSource())
    missing <- get("help_rd", env)("mascot_bubble")
    cache <- get("help_cache", env)
    cache$db <- Filter(function(rd) !identical(rd, missing), get("help_db", env)())
    cache$mascot_bubble <- NULL
    if (exists("help_example_cache", env)) {
      example_cache <- get("help_example_cache", env)
      example_cache$mascot_bubble <- NULL
    }
    expect_error(get("help_rd", env)("mascot_bubble"), "no help page")
    page <- as.character(get("studio_page", env)(formals(mascot)$character, "mascot_bubble"))
    expect_match(page, "Help unavailable for mascot_bubble()", fixed = TRUE)
    expect_match(page, get("help_page", env)("mascot_mood")$title, fixed = TRUE)
    expect_match(
      as.character(get("selected_guide", env)("mascot_bubble")),
      "Help unavailable for mascot_bubble()",
      fixed = TRUE
    )
  })
  it("parses help examples only once per function", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "help.R"), env)
    original <- env$help_rd
    calls <- 0L
    env$help_rd <- function(fn) {
      calls <<- calls + 1L
      original(fn)
    }
    first <- env$help_examples("mascot_bubble")
    expect_gt(length(first), 0)
    expect_identical(env$help_examples("mascot_bubble"), first)
    expect_identical(calls, 1L)
  })
  it("starts copied apps with the user's settings and preserves multiline bubble strings", {
    env <- new.env()
    dir <- dirname(mascot_example("studio", run = FALSE))
    sys.source(file.path(dir, "R", "code.R"), env)
    sys.source(file.path(dir, "R", "data.R"), env)
    bubble_calls <- function(expr) {
      if (!is.call(expr)) {
        return(list())
      }
      if (identical(expr[[1]], as.name("mascot")) && !is.null(expr$bubble)) {
        return(list(expr))
      }
      Reduce(c, lapply(as.list(expr)[-1], bubble_calls), init = list())
    }
    cases <- c(env$bubble_examples, list(list(text = 'Both )" and )-" occur\n  with spaces.', html = FALSE)))
    for (example in cases) {
      pair <- env$code_bubble(example$text, example$html, Inf, FALSE)
      for (style in c("short", "helper")) {
        ui <- env$format_call("mascot", list(id = "helper", mood = "worried", bubble = pair[[style]]))
        code <- env$whole_app_code(ui, NULL, c("shiny", "mascot"))
        parsed <- parse(text = code)
        call <- parsed[[3]][[3]][[2]]
        expect_identical(call[[1]], as.name("mascot"))
        expect_identical(call$mood, "worried")
        # Find the user's call independently of its UI/server placement, so this also catches A8 alone.
        calls <- Reduce(c, lapply(as.list(parsed), bubble_calls), init = list())
        expect_length(calls, 1)
        bubble <- eval(calls[[1]]$bubble, envir = list(HTML = htmltools::HTML, mascot_bubble = mascot_bubble))
        expect_identical(as.character(bubble$text), example$text)
        expect_identical(bubble$duration, Inf)
        expect_match(code, 'actionButton("celebrate", "Celebrate")', fixed = TRUE)
        expect_match(code, 'update_mascot("helper", mood = "celebrating", bubble = "Review complete.")', fixed = TRUE)
        expect_false(grepl("Apply my settings", code, fixed = TRUE))
      }
    }
  })
  it("shows the single-character hint only when one character file is shipped", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "data.R"), env)
    directory <- withr::local_tempdir()
    file.create(file.path(directory, "tessa.json"))
    expect_identical(env$studio_character_hint(directory), "Tessa is the only built-in character so far.")
    file.create(file.path(directory, c("one.json", "two.json")))
    expect_null(env$studio_character_hint(directory))
    expect_null(env$studio_character_hint())
  })
  it("removes unused initialisation and presentation helpers", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    app <- parse(file.path(dir, "app.R"))
    assigned <- vapply(
      as.list(app),
      function(expr) {
        if (is.call(expr) && identical(expr[[1]], as.name("<-")) && is.symbol(expr[[2]])) {
          as.character(expr[[2]])
        } else {
          ""
        }
      },
      character(1)
    )
    expect_false(any(c("moods", "start_mascot") %in% assigned))
    env <- new.env()
    sys.source(file.path(dir, "R", "ui.R"), env)
    expect_false(exists("chips", envir = env, inherits = FALSE))
  })
  it("provides helper links and concrete instructions beside controls", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
    env <- environment(app$serverFuncSource())
    page <- as.character(get("studio_page", env)(formals(mascot)$character, "mascot"))
    for (fn in c("mascot", "update_mascot")) {
      for (arg in setdiff(names(get("the_guide", env)(fn)$args), c("id", "...", "session"))) {
        links <- as.character(htmltools::tagList(get("wiring_links", env)(fn)))
        helper <- if (arg == "motion") "mascot_motion_settings" else paste0("mascot_", arg)
        expect_match(links, paste0('data-value="', helper, '"'), fixed = TRUE)
        expect_match(links, paste0(helper, "()"), fixed = TRUE)
        expect_match(links, 'data-event="select_function"', fixed = TRUE)
      }
    }
    for (text in c("cover the Controls panel", "Follow others", "Demonstration:", "One-off gestures")) {
      expect_match(page, text, fixed = TRUE)
    }
    expect_false(grepl("inspector", get("html_text", env)(page), ignore.case = TRUE))
    expect_match(page, "Click or tap the mascot to open its menu", fixed = TRUE)
    expect_false(grepl("is the only built-in character so far", get("html_text", env)(page), fixed = TRUE))
    expect_match(as.character(get("guide_help", env)("mascot")), 'vignette("mascot", package = "mascot")', fixed = TRUE)
    expect_match(
      as.character(get("function_visual", env)("mascot_mood")),
      "Try moods with the Mood drop-down in the top bar",
      fixed = TRUE
    )
  })
})

# The studio app's own environment (its server, data and code builders) and its page, built without a browser.
studio_parts <- function() {
  testthat::skip_if_not_installed("bslib")
  app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
  page <- app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = ""))$content
  list(env = environment(app$serverFuncSource()), page = as.character(page))
}

describe("studio character bar", {
  it("holds all four drop-downs and Play in the main area at 375 pixels", {
    local_shiny_browser()
    app <- example_driver("studio", width = 375)
    withr::defer(app$stop())
    app$wait_for_js(
      "document.querySelector('#studio_centre #studio_character_bar #character') &&
      document.querySelector('#studio_centre #studio_character_bar #mood')"
    )
    expect_true(app$get_js(
      "document.querySelector('#studio_centre #studio_character_bar').contains(document.getElementById('character')) &&
      document.querySelector('#studio_centre #studio_character_bar').contains(document.getElementById('mood'))"
    ))
    for (id in c("character", "palette", "mood", "gesture")) {
      expect_true(app$get_js(sprintf("document.querySelector('#studio_character_bar select#%s') !== null", id)))
    }
    expect_true(app$get_js("document.querySelector('#studio_character_bar #gesture_play') !== null"))
    expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"))
    app$set_inputs(character = "knurl")
    app$wait_for_js("document.getElementById('character').value === 'knurl'")
    app$wait_for_js("Object.hasOwn(document.querySelector('#palette').selectize?.options || {}, 'orbit')")
    app$set_inputs(palette = "orbit")
    app$wait_for_js("document.getElementById('code_ui').textContent.includes('theme = \"orbit\"')")
    app$set_inputs(character = "neer")
    app$wait_for_js(
      "document.querySelector('#palette').value === 'original' && Object.hasOwn(document.querySelector('#palette').selectize?.options || {}, 'lagoon')"
    )
    expect_false(app$get_js("Object.hasOwn(document.querySelector('#palette').selectize?.options || {}, 'orbit')"))
    expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"))
  })
})

describe("studio narrow layout (#341)", {
  it("shows the canvas and the mascot at phone and tablet widths without horizontal scrolling", {
    local_shiny_browser()
    check_width <- function(width) {
      checkmate::assert_number(width, lower = 1)
      app <- example_driver("studio", width = width)
      on.exit(app$stop())
      wait_example_mood(app, "helper", "idle")
      # The bug collapsed the canvas to zero height while its width stayed normal.
      sizes <- app$get_js(
        "(() => {
          const centre = document.querySelector('.pg-centre').getBoundingClientRect();
          const mascot = document.querySelector('#helper .mascot-canvas').getBoundingClientRect();
          return {centre: centre.height, mascot: mascot.height};
        })()"
      )
      expect_gt(sizes$centre, 200, label = paste("canvas height at", width, "px"))
      expect_gt(sizes$mascot, 0, label = paste("mascot height at", width, "px"))
      expect_true(app$get_js("document.documentElement.scrollWidth <= window.innerWidth"), info = paste("width", width))
    }
    for (width in c(375, 560, 768)) {
      check_width(width)
    }
  })
})

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
  for (tag in tags('(?s)<select id="[^"]+".*?</select>')) {
    options <- regmatches(tag, gregexpr('<option value="[^"]*"( selected)?', tag))[[1]]
    chosen <- grep("selected", options, fixed = TRUE, value = TRUE)
    values[[attribute(tag, "id")]] <- unescape(attribute(c(chosen, options)[[1]], "value"))
  }
  values
}

describe("studio safeguards (#248)", {
  it("changes each control's argument in the update sent and in the generated code", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    # Each row: the inputs to set (in order; a click is a count), the field of the update it changes, the code it
    # adds, and the milliseconds a debounced control waits. `code = NA` marks a one-off event (gestures): it is
    # sent and appears in the Last tab, never in the UI code.
    # `sent` checks this control's own value in the update, beyond any companion input the row also sets.
    row <- function(inputs, field, code, sent, wait = 0, ui = TRUE) {
      checkmate::assert_list(inputs, min.len = 1)
      checkmate::assert_function(sent)
      list(inputs = inputs, field = field, code = code, sent = sent, wait = wait, ui = ui)
    }
    show <- function(...) list(list(...), list(bubble_show = 1))
    rows <- list(
      palette = row(list(list(palette = "coral")), "theme", 'theme = "coral"', wait = 300, sent = function(p) {
        identical(p$theme$palette, "coral")
      }),
      mood = row(list(list(mood = "happy")), "mood", 'mood = "happy"', sent = function(p) identical(p$mood, "happy")),
      status_text = row(
        list(list(status_text = "Saving")),
        "status",
        'status = "Saving"',
        wait = 700,
        sent = function(p) identical(p$status$text, "Saving")
      ),
      bubble_text = row(show(bubble_text = "Hi there"), "bubble", 'bubble = "Hi there"', sent = function(p) {
        identical(p$bubble$text, "Hi there")
      }),
      bubble_html = row(
        show(bubble_text = "<b>Hi</b>", bubble_html = TRUE),
        "bubble",
        'HTML("<b>Hi</b>")',
        sent = function(p) isTRUE(p$bubble$html)
      ),
      bubble_duration = row(
        show(bubble_text = "Hi", bubble_duration = 9),
        "bubble",
        "duration = 9",
        sent = function(p) identical(p$bubble$duration, 9)
      ),
      bubble_forever = row(
        show(bubble_text = "Hi", bubble_forever = TRUE),
        "bubble",
        "duration = Inf",
        sent = function(p) is.null(p$bubble$duration)
      ),
      bubble_closable = row(
        show(bubble_text = "Hi", bubble_closable = FALSE),
        "bubble",
        "closable = FALSE",
        sent = function(p) isFALSE(p$bubble$closable)
      ),
      idle = row(list(list(idle = "false")), "motion", "idle = FALSE", sent = function(p) {
        isFALSE(p$motion$idle)
      }),
      swap = row(list(list(swap = "false")), "motion", "swap = FALSE", sent = function(p) isFALSE(p$motion$swap)),
      mood_change = row(list(list(mood_change = "false")), "motion", "mood_change = FALSE", sent = function(p) {
        isFALSE(p$motion$mood_change)
      }),
      gestures = row(list(list(gestures = "false")), "motion", "gestures = FALSE", sent = function(p) {
        isFALSE(p$motion$gestures)
      }),
      minimising = row(list(list(minimising = "false")), "motion", "minimising = FALSE", sent = function(p) {
        isFALSE(p$motion$minimising)
      }),
      restoring = row(list(list(restoring = "false")), "motion", "restoring = FALSE", sent = function(p) {
        isFALSE(p$motion$restoring)
      }),
      messages = row(list(list(messages = "menu")), "motion", 'messages = "menu"', sent = function(p) {
        identical(p$motion$messages, list("menu"))
      }),
      others = row(list(list(others = FALSE)), "motion", "others = FALSE", sent = function(p) {
        isFALSE(p$motion$idle) && isFALSE(p$motion$others)
      }),
      gesture_play = row(
        list(list(gesture = "wave"), list(gesture_play = 1)),
        "gesture",
        'gesture = "wave"',
        ui = FALSE,
        sent = function(p) {
          identical(p$gesture, "wave")
        }
      ),
      size_px = row(list(list(size_px = 120)), "size", "size = 120", sent = function(p) identical(p$size$size, 120)),
      size_unit = row(list(list(size_unit = "pct", size_pct = 40)), "size", 'size = "40%"', sent = function(p) {
        identical(p$size$size, "40%")
      }),
      size_pct = row(list(list(size_unit = "pct"), list(size_pct = 50)), "size", 'size = "50%"', sent = function(p) {
        identical(p$size$size, "50%")
      }),
      small_mode = row(list(list(small_mode = "same")), "size", "small_screen = NULL", sent = function(p) {
        is.null(p$size$small_screen)
      }),
      small_px = row(list(list(small_mode = "number", small_px = 48)), "size", "small_screen = 48", sent = function(p) {
        identical(p$size$small_screen, 48)
      }),
      position = row(list(list(position = "top-left")), "placement", 'placement = "top-left"', sent = function(p) {
        identical(p$placement$position, "top-left")
      }),
      minimise = row(
        list(list(position = "top-left", minimise = FALSE)),
        "placement",
        "minimise = FALSE",
        sent = function(p) isFALSE(p$placement$minimise)
      ),
      drag = row(list(list(position = "top-left", drag = "snap")), "placement", 'drag = "snap"', sent = function(p) {
        identical(p$placement$drag, "snap")
      }),
      theme_source = row(
        list(list(theme_source = "bslib")),
        "theme",
        "bslib::bs_theme(",
        wait = 400,
        sent = function(p) length(p$theme$brand) == 2
      ),
      theme_mode = row(
        list(list(theme_source = "mascot", light_body = "#1f6feb", theme_mode = "dark")),
        "theme",
        'mode = "dark"',
        wait = 400,
        sent = function(p) identical(p$theme$mode, "dark")
      ),
      light_body = row(
        list(list(theme_source = "mascot", light_body = "#1f6feb")),
        "theme",
        'light = list(body = "#1f6feb")',
        wait = 400,
        sent = function(p) identical(tolower(p$theme$light$body), "#1f6feb")
      ),
      dark_body = row(
        list(list(theme_source = "mascot", dark_body = "#9ec5fe")),
        "theme",
        'dark = list(body = "#9ec5fe")',
        wait = 400,
        sent = function(p) identical(tolower(p$theme$dark$body), "#9ec5fe")
      ),
      css_roles = row(
        list(list(theme_source = "mascot", css_roles = "body")),
        "theme",
        'css = list(body = "--studio-accent")',
        wait = 400,
        sent = function(p) identical(p$theme$css$body, "--studio-accent")
      ),
      menu_on = row(
        list(list(menu_on = TRUE, menu_items = "about = About")),
        "click",
        'click = mascot_popup_menu(c(about = "About"))',
        wait = 700,
        sent = function(p) identical(p$click$items$about, "About")
      ),
      menu_items = row(
        list(list(menu_on = TRUE, menu_items = "help = Help")),
        "click",
        'c(help = "Help")',
        wait = 700,
        sent = function(p) identical(p$click$items$help, "Help")
      ),
      menu_direction = row(
        list(list(menu_on = TRUE, menu_items = "about = About", menu_direction = "top")),
        "click",
        'direction = "top"',
        wait = 700,
        sent = function(p) identical(p$click$direction, "top")
      ),
      menu_label = row(
        list(list(menu_on = TRUE, menu_items = "about = About", menu_label = "Help menu")),
        "click",
        'label = "Help menu"',
        wait = 700,
        sent = function(p) identical(p$click$label, "Help menu")
      ),
      menu_tooltip = row(
        list(list(menu_on = TRUE, menu_items = "about = About", menu_label = "Help menu", menu_tooltip = FALSE)),
        "click",
        "tooltip = FALSE",
        wait = 700,
        sent = function(p) isFALSE(p$click$tooltip)
      ),
      action_on = row(
        list(list(action_on = TRUE)),
        "click",
        'click = "Open help"',
        wait = 700,
        sent = function(p) identical(p$click$type, "action")
      ),
      action_label = row(
        list(list(action_on = TRUE, action_label = "Get help")),
        "click",
        'click = "Get help"',
        wait = 700,
        sent = function(p) identical(p$click$label, "Get help")
      ),
      action_tooltip = row(
        list(list(action_on = TRUE, action_tooltip = FALSE)),
        "click",
        "tooltip = FALSE",
        wait = 700,
        sent = function(p) isFALSE(p$click$tooltip)
      ),
      action_disabled = row(
        list(list(action_on = TRUE, action_disabled = TRUE)),
        "click",
        "disabled = TRUE",
        wait = 700,
        sent = function(p) isTRUE(p$click$disabled)
      )
    )
    # mascot_preview() controls change the call that builds the preview, not an update.
    preview_rows <- list(
      preview_mood = list(list(preview_mood = "happy"), 'mood = "happy"'),
      preview_status = list(list(preview_status = "Ready"), 'status = "Ready"'),
      preview_bubble = list(list(preview_bubble = "Hi"), 'bubble = "Hi"'),
      preview_size = list(list(preview_size = 96), "size = 96"),
      preview_theme_source = list(
        list(preview_theme_source = "custom", preview_body = "#1f6feb"),
        'theme = list(body = "#1f6feb")'
      ),
      preview_motion = list(list(preview_motion = TRUE), "motion = TRUE")
    )
    # Controls without a row, and why. Anything else in the control map needs a row above.
    exempt <- c(
      character = "selector choices are checked against every shipped character",
      gesture = "selects the gesture; the gesture_play row checks sending it",
      bubble_example = "fills the bubble controls; tested with Show bubble (#249)",
      mistake = "demonstrates invalid calls, which change nothing",
      mistake_run = "demonstrates invalid calls, which change nothing",
      task_run = "demonstrates the session argument with a timed task",
      preview_width = "the width the preview page is shown at, not an argument",
      example_name = "the Examples view, not the mascot",
      list_family = "filters the listings view (mascot_characters(family =)), not the mascot",
      example_run = "the Examples view, not the mascot"
    )
    controls <- unlist(get("playground_controls", parts$env))
    format_call <- get("format_call", parts$env)
    mapped <- unique(gsub('^id="|"$', "", grep("^id=", controls, value = TRUE)))
    events <- unique(gsub(
      '^data-event="|"$',
      "",
      grep("^data-event=", controls, value = TRUE)
    ))
    expect_setequal(setdiff(c(mapped, events), c(names(rows), names(preview_rows), names(exempt))), character())
    for (name in names(rows)) {
      case <- rows[[name]]
      shiny::testServer(get("studio_server", parts$env), {
        envelopes <- list()
        session$sendCustomMessage <- function(type, message) {
          if (identical(type, "mascot:update")) envelopes[[length(envelopes) + 1L]] <<- message
        }
        do.call(session$setInputs, start)
        studio_go_live(session)
        updates <- function() session$userData$mascot_updates[[session$ns("helper")]]
        before <- updates()
        for (inputs in case$inputs) {
          do.call(session$setInputs, inputs)
        }
        if (case$wait) {
          session$elapse(case$wait)
        }
        session$flushReact()
        after <- updates()
        # The update accepted: a new revision, and this argument set by a call with a new value. A gesture is
        # a one-off: its accepted value is the pending gesture, not a stored argument.
        expect_false(is.null(after), info = name)
        expect_gt(after$revision, before$revision)
        if (identical(case$field, "gesture")) {
          expect_false(identical(after$pending, before$pending), info = name)
        } else {
          expect_true(case$field %in% after$owned, info = name)
          expect_false(identical(after$desired[[case$field]], before$desired[[case$field]]), info = name)
        }
        # The update sent: the newest envelope is that revision and carries this argument, with a gesture as
        # the envelope's own gesture field.
        envelope <- envelopes[[length(envelopes)]]
        expect_identical(envelope$revision, after$revision, info = name)
        expect_true(case$sent(c(envelope$state, list(gesture = envelope$gesture$name))), info = name)
        # The call the studio ran (its Last tab) and the generated UI code.
        expect_match(last_call(), case$code, fixed = TRUE, info = name)
        if (case$ui) {
          expect_match(output$code_ui, case$code, fixed = TRUE, info = name)
        } else {
          expect_false(grepl(case$code, output$code_ui, fixed = TRUE), info = name)
        }
      })
    }
    for (name in names(preview_rows)) {
      case <- preview_rows[[name]]
      shiny::testServer(get("studio_server", parts$env), {
        do.call(session$setInputs, start)
        unchanged <- format_call("mascot_preview", preview_args())
        expect_false(grepl(case[[2]], unchanged, fixed = TRUE), info = name)
        do.call(session$setInputs, case[[1]])
        expect_match(format_call("mascot_preview", preview_args()), case[[2]], fixed = TRUE, info = name)
      })
    }
  })
  it("starts every control at the package's default, apart from the studio's listed choices", {
    parts <- studio_parts()
    # The studio's R/ files load into a parent of the app's environment, hence the inherited lookup.
    env <- mget(
      c(
        "defaults",
        "start",
        "code_pair",
        "format_expr",
        "code_bubble",
        "code_motion",
        "code_size",
        "code_placement",
        "code_menu",
        "code_action",
        "code_theme"
      ),
      envir = parts$env,
      inherits = TRUE
    )
    start <- studio_start_values(parts$page)
    # The studio's deliberate departures from the package defaults, and why.
    overrides <- c(
      placement = "the live mascot sits inline in the studio canvas, not in a window corner",
      bubble = "the live mascot greets the visitor with a welcome bubble",
      click = "the live mascot starts with a demonstration menu"
    )
    # The live mascot starts from the defaults plus the overrides, and nothing else.
    initial <- lapply(env$defaults, env$code_pair)
    changed <- Filter(function(field) !identical(env$start[[field]], initial[[field]]), names(env$defaults))
    expect_setequal(changed, names(overrides))
    # Copied code starts from the defaults except the placement, which the canvas needs.
    expect_identical(env$defaults$placement, formals(mascot)$placement)
    # Every default the studio leaves out of code draws the same mascot as leaving the argument out.
    expect_setequal(names(env$defaults), setdiff(names(formals(mascot)), c("id", "...")))
    # mascot_theme() writes the neutral theme (mode "auto", no colours) where NULL writes none; the engine reads
    # both as the same automatic theme, so that one block is checked and then set aside.
    neutral <- '<script type="application/json" data-mascot-theme="">{"light":null,"dark":null,"mode":"auto","css":null,"brand":null}</script>'
    # The recorded baseline and the mount token derived from it are protocol metadata. For the theme they differ
    # only because mascot_theme() records mode "auto" where the default records null, which the engine reads alike.
    protocol_metadata <- function(lines) {
      lines <- lines[!grepl('data-mascot-baseline=""', lines, fixed = TRUE)]
      sub(' data-mount-token="[^"]*"', "", lines)
    }
    for (field in names(env$defaults)) {
      args <- stats::setNames(list(eval(env$defaults[[field]])), field)
      html <- as.character(do.call(mascot, c(list(id = "x"), args)))
      reference <- as.character(mascot(id = "x"))
      if (field == "theme") {
        expect_match(html, neutral, fixed = TRUE)
        lines <- strsplit(html, "\n", fixed = TRUE)[[1]]
        html <- paste(lines[trimws(lines) != neutral], collapse = "\n")
        html <- paste(protocol_metadata(strsplit(html, "\n", fixed = TRUE)[[1]]), collapse = "\n")
        reference <- paste(protocol_metadata(strsplit(reference, "\n", fixed = TRUE)[[1]]), collapse = "\n")
      }
      expect_identical(html, reference, info = field)
    }
    # The code builders leave out an argument only when it has the helper's default value.
    defaults_of <- function(fn) formals(getExportedValue("mascot", fn))
    bubble <- defaults_of("mascot_bubble")
    expect_identical(
      env$format_expr(env$code_bubble("Hi", FALSE, bubble$duration, bubble$closable)$helper),
      'mascot_bubble("Hi")'
    )
    expect_identical(eval(env$code_bubble("Hi", FALSE, bubble$duration, bubble$closable)$helper), mascot_bubble("Hi"))
    motion <- defaults_of("mascot_motion_settings")
    expect_identical(env$code_motion()$helper, quote(mascot_motion_settings()))
    size <- defaults_of("mascot_size")
    expect_identical(eval(env$code_size(formals(mascot)$size, size$small_screen)$short), formals(mascot)$size)
    expect_identical(formals(env$code_placement), defaults_of("mascot_placement"))
    expect_identical(
      env$code_menu(c(a = "A"), defaults_of("mascot_popup_menu")$direction)$short,
      quote(mascot_popup_menu(c(a = "A")))
    )
    action <- defaults_of("mascot_action")
    expect_identical(env$code_action("Open help", action$tooltip, action$disabled)$short, "Open help")
    expect_false(grepl(
      "mode",
      deparse1(
        env$code_theme("mascot", c(body = "#1f6feb"), NULL, defaults_of("mascot_theme")$mode, NULL, "", "")$helper
      )
    ))
    # Each control starts at the value its argument has by default (the overrides above aside).
    start_menu <- eval(env$start$click$helper)$items
    expected <- list(
      status_text = "", # status = NULL follows the mood
      bubble_duration = bubble$duration,
      bubble_forever = is.infinite(bubble$duration),
      bubble_closable = bubble$closable,
      bubble_html = FALSE, # plain text unless wrapped in HTML()
      idle = "follow",
      mood_change = "follow",
      gestures = "follow",
      swap = "follow",
      minimising = "follow",
      restoring = "follow",
      messages = "follow",
      others = motion$others,
      size_unit = "px",
      size_px = formals(mascot)$size,
      small_mode = size$small_screen,
      minimise = defaults_of("mascot_placement")$minimise,
      drag = as.character(defaults_of("mascot_placement")$drag),
      theme_source = "own", # theme = NULL keeps the character's own colours
      theme_mode = defaults_of("mascot_theme")$mode,
      # The menu controls follow the demonstration menu the live mascot starts with (the override above, #256).
      menu_on = TRUE,
      menu_items = paste(names(start_menu), "=", start_menu, collapse = "\n"),
      menu_direction = defaults_of("mascot_popup_menu")$direction,
      menu_label = "", # label = NULL names the menu after the character
      menu_tooltip = TRUE,
      action_on = FALSE, # one click at a time: the menu above
      action_tooltip = action$tooltip,
      action_disabled = action$disabled,
      mood = formals(mascot)$mood,
      character = formals(mascot)$character,
      preview_mood = "", # mood = NULL shows every mood
      preview_status = "",
      preview_bubble = "",
      preview_size = formals(mascot_preview)$size,
      preview_theme_source = "own",
      preview_motion = formals(mascot_preview)$motion
    )
    for (id in names(expected)) {
      expect_identical(start[[id]], expected[[id]], info = id)
    }
    # The listed override, as a control: the position starts inline.
    expect_identical(start$position, "inline")
    expect_false(identical(start$position, formals(mascot)$placement))
  })
})

describe("studio phone sidebars (#265)", {
  it("uses the opaque page background for overlay sidebars only at phone widths", {
    css <- paste(
      readLines(file.path(dirname(mascot_example("studio", run = FALSE)), "www", "studio.css")),
      collapse = "\n"
    )
    expect_match(
      css,
      paste0(
        "@media \\(max-width: 575[.]98px\\) \\{\\s*",
        "(?:/\\*.*?\\*/\\s*)?",
        "[.]bslib-sidebar-layout > aside[.]sidebar[.]bslib-sidebar-input \\{\\s*",
        "background-color: var\\(--bs-body-bg\\);\\s*\\}"
      ),
      perl = TRUE
    )
  })
})

describe("studio bubble controls (#249)", {
  it("shows the chosen example even when Show arrives before the browser fills the inputs", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    examples <- get("bubble_examples", parts$env)
    shiny::testServer(get("studio_server", parts$env), {
      envelopes <- list()
      session$sendCustomMessage <- function(type, message) {
        if (identical(type, "mascot:update")) envelopes[[length(envelopes) + 1L]] <<- message
      }
      do.call(session$setInputs, start)
      studio_go_live(session)
      # Given an example chosen and Show clicked at once: the server has not yet heard the filled inputs.
      session$setInputs(bubble_example = "Checklist", bubble_show = 1)
      # Then the bubble sent is the example's, not the text still in the input.
      expect_identical(input$bubble_text, start$bubble_text)
      sent <- envelopes[[length(envelopes)]]$state$bubble
      expect_identical(sent$text, examples$Checklist$text)
      expect_true(sent$html)
      expect_match(last_call(), "Before you submit", fixed = TRUE)
      # When the visitor then types, Show sends what they typed.
      session$setInputs(bubble_text = "Typed by hand", bubble_html = FALSE)
      session$setInputs(bubble_show = 2)
      sent <- envelopes[[length(envelopes)]]$state$bubble
      expect_identical(sent$text, "Typed by hand")
      expect_false(sent$html)
    })
  })
  it("puts Show bubble right under the message box, before the duration and close settings", {
    page <- studio_parts()$page
    at <- function(id) regexpr(sprintf('id="%s"', id), page, fixed = TRUE)[[1]]
    expect_gt(at("bubble_show"), at("bubble_text"))
    expect_lt(at("bubble_show"), at("bubble_html"))
    expect_lt(at("bubble_show"), at("bubble_duration"))
    expect_lt(at("bubble_clear"), at("bubble_duration"))
    expect_match(
      page,
      "The HTML switch, duration and close button below apply the next time you click Show bubble.",
      fixed = TRUE
    )
  })
})

describe("studio engine behaviours", {
  it("explains beside the menu direction that the mascot looks towards its menu and bubble (#241)", {
    page <- studio_parts()$page
    note <- regexpr("the mascot looks towards the side the menu opened on", page, fixed = TRUE)[[1]]
    expect_gt(note, regexpr('id="menu_direction"', page, fixed = TRUE)[[1]])
    expect_match(page, "It also looks towards a bubble.", fixed = TRUE)
  })
  it("shows input$helper_click live, answers an action with a wave and only logs menu toggles (#257)", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    expect_match(parts$page, 'id="click_last"', fixed = TRUE)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      expect_match(output$click_last, "Nothing yet", fixed = TRUE)
      updates <- function() session$userData$mascot_updates[[session$ns("helper")]]
      # With the menu, a toggle is logged and gets no wave.
      session$setInputs(helper_click = 1)
      expect_identical(output$click_last, "1 click")
      expect_identical(log()[[1]]$code, "input$helper_click  # 1")
      expect_match(log()[[1]]$message, "opened or closed the menu", fixed = TRUE)
      # Turning the action on sends it, and the switches take turns.
      session$setInputs(action_on = TRUE)
      session$elapse(700)
      expect_identical(updates()$desired$click$type, "action")
      expect_identical(updates()$desired$click$label, "Open help")
      expect_match(output$code_app, "observeEvent(input$helper_click", fixed = TRUE)
      session$setInputs(helper_click = 2)
      expect_identical(output$click_last, "2 clicks")
      expect_match(last_call(), 'gesture = "wave"', fixed = TRUE)
      # The log is newest first: the click event, then the studio's wave in answer.
      expect_identical(log()[[2]]$code, "input$helper_click  # 2")
      expect_identical(log()[[1]]$code, 'update_mascot("helper", gesture = "wave")')
      # A blank label is a problem in the code, never sent; switching off sends the empty helper.
      session$setInputs(action_label = " ")
      session$elapse(700)
      expect_match(output$code_ui, "^# Write a label")
      expect_identical(updates()$desired$click$label, "Open help")
      session$setInputs(action_on = FALSE, menu_on = FALSE)
      session$elapse(700)
      expect_identical(updates()$desired$click, list(type = "none"))
      expect_match(last_call(), "click = mascot_action()", fixed = TRUE)
    })
  })
})

describe("mascot_example() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_example)), c("name", "...", "run"))
    expect_error(mascot_example("studio", run = FALSE, typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_example("studio", run = FALSE, 1), "Name the optional arguments", class = "mascot_error")
  })
})


describe("studio API review", {
  it("generates an id-first UI call and shows the delayed UI example from the help", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
    env <- environment(app$serverFuncSource())
    # The studio sources its R/ files into a parent of the server environment, so look them up with get().
    code <- get("format_call", envir = env)("mascot", get("ui_args", envir = env)(get("start", envir = env), "short"))
    expect_match(code, '^mascot\\(\\s*"helper"', perl = TRUE)
    expect_false(grepl("id =", code, fixed = TRUE))
    guide <- as.character(get("guide_help", envir = env)("mascot"))
    expect_match(guide, "Showing the mascot later", fixed = TRUE)
    expect_match(guide, "renderUI", fixed = TRUE)
  })
  it("warns in the studio outside development mode, honours overrides and restores the option", {
    skip_if_not_installed("bslib")
    local_mocked_bindings(in_devmode = function() FALSE, .package = "shiny")
    withr::local_options(mascot.contrast_warnings = NULL)
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
    env <- environment(app$serverFuncSource())
    shiny::testServer(env$studio_server, {
      expr <- quote(mascot("contrast", theme = mascot_theme(light = list(body = "white"))))
      expect_true(run_logged(expr, "contrast check"))
      expect_identical(log()[[1]]$outcome, "warning")
      expect_match(log()[[1]]$message, "below 3:1")
      expect_null(getOption("mascot.contrast_warnings"))
      withr::local_options(mascot.contrast_warnings = FALSE)
      expect_true(run_logged(expr, "contrast off"))
      expect_identical(log()[[1]]$outcome, "ok")
      expect_identical(getOption("mascot.contrast_warnings"), FALSE)
      withr::local_options(mascot.contrast_warnings = TRUE)
      expect_true(run_logged(expr, "contrast on"))
      expect_identical(log()[[1]]$outcome, "warning")
      expect_identical(getOption("mascot.contrast_warnings"), TRUE)
    })
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_example(name = 1, run = FALSE), "name", class = "mascot_error")
    expect_error(mascot_example("studio", run = 1), "run", class = "mascot_error")
  })
})

describe("studio motion settings builders", {
  it("writes only named overrides and lets others determine untouched controls", {
    env <- new.env(parent = baseenv())
    sys.source(system.file("examples", "studio", "R", "code.R", package = "mascot"), env)
    expect_identical(env$code_motion()$helper, quote(mascot_motion_settings()))
    expect_identical(env$code_motion(idle = "false")$helper, quote(mascot_motion_settings(idle = FALSE)))
    expect_identical(
      eval(env$code_motion(messages = "menu", others = FALSE)$helper),
      mascot_motion_settings(messages = "menu", others = FALSE)
    )
    expect_identical(
      eval(env$code_motion(idle = "true", others = FALSE)$helper),
      mascot_motion_settings(idle = TRUE, others = FALSE)
    )
    expect_identical(eval(env$code_motion(messages = character())$helper), mascot_motion_settings(messages = FALSE))
    expect_identical(
      eval(env$code_motion(messages = c("bubble", "tooltip"))$helper),
      mascot_motion_settings(messages = c("bubble", "tooltip"))
    )
    expect_error(env$code_motion(messages = c("follow", "menu")), "Choose Follow others")
  })
})


describe("framework examples", {
  it("copies the golem folder and retains its runtime options", {
    skip_if_not_installed("golem")
    file <- mascot_example("golem", run = FALSE)
    expect_setequal(
      list.files(dirname(file), recursive = TRUE),
      c("app.R", "R/app_ui.R", "R/app_server.R", "R/mod-review.R")
    )
    copy <- withr::local_tempdir()
    expect_true(file.copy(dirname(file), copy, recursive = TRUE))
    dir <- file.path(copy, "golem")
    withr::local_dir(dir)
    for (script in list.files(dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE)) {
      expect_type(parse(script), "expression")
    }
    app <- source("app.R", local = new.env())$value
    expect_s3_class(app, "shiny.appobj")
    expect_identical(app$appOptions$golem_options, list(title = "Reviews in golem", complete = "Review complete"))
  })
  it("runs golem runtime helpers with two independent nested modules", {
    skip_if_not_installed("golem")
    local_shiny_browser()
    app <- example_driver("golem")
    withr::defer(app$stop())
    app$wait_for_js("document.querySelector('h1').textContent === 'Reviews in golem'")
    app$wait_for_js("!!mascot.host.state(document.getElementById('first-review-helper'))")
    app$click("first-review-complete")
    app$wait_for_js(
      "mascot.host.state(document.getElementById('first-review-helper')).status.text === 'Review complete'"
    )
    expect_identical(app$get_js("mascot.host.state(document.getElementById('first-review-helper')).mood"), "happy")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('second-review-helper')).mood"), "idle")
    app$click(selector = "#first-review-helper .mascot-menu-toggle")
    app$click(selector = "#first-review-helper [role=menuitem]")
    app$wait_for_js("document.getElementById('first-review-choice').textContent === 'about'")
    expect_identical(app$get_value(output = "first-review-choice"), "about")
    expect_identical(app$get_js("document.getElementById('second-review-choice').textContent"), "")
    app$click("second-review-complete")
    app$wait_for_js("mascot.host.state(document.getElementById('second-review-helper')).mood === 'happy'")
    expect_equal(app$get_js("document.querySelectorAll('script[src$=\"/mascot-host.js\"]').length"), 1)
  })
  it("runs plain Shiny view modules in the rhino-shaped folder", {
    local_shiny_browser()
    app <- example_driver("rhino")
    withr::defer(app$stop())
    app$wait_for_js("!!mascot.host.state(document.getElementById('second-review-helper'))")
    app$click("second-review-complete")
    app$wait_for_js("mascot.host.state(document.getElementById('second-review-helper')).mood === 'happy'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('first-review-helper')).mood"), "idle")
    app$click(selector = "#second-review-helper .mascot-menu-toggle")
    app$click(selector = "#second-review-helper [role=menuitem]")
    app$wait_for_js("document.getElementById('second-review-choice').textContent === 'about'")
    expect_identical(app$get_value(output = "second-review-choice"), "about")
    expect_identical(app$get_js("document.getElementById('first-review-choice').textContent"), "")
  })
})

describe("studio listings (character data)", {
  it("reads brand slots, characters and families from the public listings", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "data.R"), env)
    recipe <- system.file("format", "characters", "tessa.json", package = "mascot", mustWork = TRUE)
    brand <- jsonlite::fromJSON(recipe)$brand
    expect_identical(env$studio_brand("tessa")[c("primary", "secondary")], as.list(brand)[c("primary", "secondary")])
    expect_identical(
      env$studio_characters(),
      c(Tessa = "tessa", Sela = "sela", `Knurl (experimental)` = "knurl", `Neer (experimental)` = "neer")
    )
    expect_identical(
      env$studio_families(),
      c(`All characters` = "", Hexonians = "hexonians", Visorfolk = "visorfolk", Elementals = "elementals")
    )
    expect_error(env$studio_brand(1), "Assertion on 'character' failed")
  })
  it("leaves registered characters out of the choices, because mascot() cannot mount them yet", {
    local_empty_registry()
    character_data_register(character_format_check(format_recipe("study_bot")))
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "data.R"), env)
    expect_identical(unname(env$studio_characters()), c("tessa", "sela", "knurl", "neer"))
  })
})

describe("the internal Your character studio panel", {
  it("is off by default and maps all four authoring functions and arguments when enabled", {
    withr::local_envvar(c(NOT_CRAN = "false"))
    env <- new.env(parent = globalenv())
    path <- system.file("examples", "studio", package = "mascot", mustWork = TRUE)
    sys.source(file.path(path, "R", "data.R"), envir = env)
    sys.source(file.path(path, "R", "panels.R"), envir = env)
    withr::local_options(mascot.internal.character_panel = FALSE)
    expect_null(env$panel_your_character())
    options(mascot.internal.character_panel = TRUE)
    html <- as.character(env$panel_your_character())
    for (fn in names(env$studio_character_controls)) {
      expect_setequal(
        names(env$studio_character_controls[[fn]]),
        names(formals(get(fn, envir = asNamespace("mascot"))))
      )
      for (control in env$studio_character_controls[[fn]]) {
        if (is.character(control)) {
          for (id in control) {
            expect_match(html, id, fixed = TRUE)
          }
        }
      }
    }
    expect_match(html, "never sent to another service", fixed = TRUE)
  })
})


describe("studio palette controls", {
  it("offers each character's choices and builds shortcuts and override helpers", {
    parts <- studio_parts()
    for (id in builtin_characters()$id) {
      bar <- as.character(get("panel_character_bar", parts$env)(character = id))
      for (input in c("character", "palette", "mood", "gesture")) {
        expect_match(bar, paste0('<select id="', input, '"'), fixed = TRUE)
      }
      for (palette in mascot_palettes(id)$name) {
        expect_match(bar, paste0('value="', palette, '"'), fixed = TRUE)
      }
      expect_match(bar, 'id="gesture_play"', fixed = TRUE)
      expect_false(grepl("try_mood", bar, fixed = TRUE))
    }
    table <- get("roles_table", parts$env)
    expect_match(as.character(table("tessa", "coral")), "#FFE5D9", fixed = TRUE)
    expect_error(table(1), "character")
    expect_error(table("tessa", 1), "palette")
    builder <- get("code_theme", parts$env)
    valid <- list(
      source = "own",
      light = NULL,
      dark = NULL,
      mode = "auto",
      css_roles = NULL,
      primary = NULL,
      secondary = NULL,
      palette = "original"
    )
    for (arg in names(valid)) {
      invalid <- valid
      invalid[arg] <- list(1)
      expect_error(do.call(builder, invalid), arg)
    }
    value <- builder("own", NULL, NULL, "auto", NULL, "", "", palette = "orbit")
    expect_identical(value$short, "orbit")
    expect_identical(value$helper, quote(mascot_theme(palette = "orbit")))
    value <- builder("mascot", c(body = "#123456"), NULL, "dark", NULL, "", "", palette = "orbit")
    expect_identical(eval(value$helper), mascot_theme(palette = "orbit", light = list(body = "#123456"), mode = "dark"))
    expect_identical(
      builder("bslib", NULL, NULL, "auto", NULL, "blue", "orange", palette = "orbit")$short,
      quote(bslib::bs_theme(primary = "blue", secondary = "orange"))
    )
  })
  it("shows colour-role argument controls and keeps the palette in the low-contrast demonstration", {
    parts <- studio_parts()
    controls <- Filter(
      function(tag) {
        identical(tag$attribs[["data-function"]], "mascot_colour_roles")
      },
      get("panel_colours", parts$env)()
    )[[1]]
    for (arg in c("...", "palette")) {
      expect_match(as.character(controls), paste0('data-argument="', arg, '"'), fixed = TRUE)
    }
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(palette = "coral")
      session$elapse(301)
      session$setInputs(mistake = "Low contrast", mistake_run = 1)
      expect_identical(eval(state$theme$short)$palette, "coral")
      expect_match(output$code_ui, 'palette = "coral"', fixed = TRUE)
    })
  })
  it("refreshes choices and sends a gesture only when Play is pressed", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      messages <- choices <- list()
      session$sendInputMessage <- function(id, message) {
        if (!is.null(message$options)) {
          choices[[id]] <<- message$options
        }
        messages[[id]] <<- message
      }
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(palette = "coral")
      session$elapse(301)
      expect_match(output$code_ui, 'theme = "coral"', fixed = TRUE)
      session$setInputs(character = "sela")
      expect_match(output$code_ui, 'theme = "coral"', fixed = TRUE)
      expect_match(messages$palette$options, 'value="peach"', fixed = TRUE)
      expect_identical(messages$palette$value, "coral")
      expect_match(choices$mood, 'value="happy"', fixed = TRUE)
      expect_match(choices$gesture, 'value="wave"', fixed = TRUE)
      session$setInputs(character = "knurl")
      expect_identical(messages$palette$value, "original")
      expect_false(grepl('theme = "coral"', output$code_ui, fixed = TRUE))
      previous <- session$userData$mascot_updates[[session$ns("helper")]]$revision
      session$setInputs(gesture = "wave")
      expect_identical(session$userData$mascot_updates[[session$ns("helper")]]$revision, previous)
      session$setInputs(gesture_play = 1)
      expect_identical(session$userData$mascot_updates[[session$ns("helper")]]$pending$name, "wave")
    })
  })
})
