# The studio and its guide pages (guide/*.Rmd), loaded the way the tests below load pieces of the studio.
studio_guide_env <- function(frame = parent.frame()) {
  testthat::skip_if_not_installed("bslib")
  testthat::skip_if_not_installed("knitr")
  withr::local_package("shiny", .local_envir = frame)
  withr::local_package("bslib", .local_envir = frame)
  dir <- dirname(mascot_example("studio", run = FALSE))
  env <- new.env()
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
# Defined before its first use: describe() blocks run while this file is sourced.
studio_go_live <- function(session) {
  protocol_ready(list(session = session, id = session$ns("helper")))
  session$flushReact()
  invisible(NULL)
}

# The first value unless it is NULL; base R has `%||%` only from 4.4 and the package supports R 4.1.
value_or <- function(value, fallback) if (is.null(value)) fallback else value

# The studio app's own environment (its server, data and code builders) and its page, built without a browser.
studio_parts <- function() {
  skip_without_studio_packages("studio")
  app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
  page <- app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = ""))$content
  list(env = environment(app$serverFuncSource()), page = as.character(page))
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

describe("mascot_examples()", {
  it("lists the studio, its theme page and five scenario apps in order with readable metadata", {
    examples <- mascot_examples()
    expect_s3_class(examples, "data.frame")
    expect_named(examples, c("name", "title", "description"))
    expect_identical(examples$name, c("studio", "form-check", "long-task", "modules", "theme", "golem", "rhino"))
    expect_true(all(vapply(examples, is.character, logical(1))))
    expect_true(all(nzchar(unlist(examples))))
    expect_identical(anyDuplicated(examples$name), 0L)
    expect_identical(examples$title[examples$name == "theme"], "Theme a mascot")
    expect_match(examples$description[examples$name == "theme"], "Requires bslib")
    expect_match(examples$description[examples$name == "long-task"], "Requires promises and later", fixed = TRUE)
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
      # The theme page is a view of the studio's app: the same folder.
      if (name == "theme") {
        expect_identical(file, mascot_example("studio", run = FALSE))
        next
      }
      if (name == "studio") {
        studio_dir <- dirname(file)
        expect_true(file.exists(file.path(studio_dir, "app.R")))
        for (folder in c("R", "guide", "www")) {
          expect_gt(length(list.files(file.path(studio_dir, folder))), 0, label = folder)
        }
        # Every R file in the folder is plain R (parsed below with the other examples) and nothing else ships
        # beside the app except the guide pages, their helpers and styles, and the web files.
        expect_true(all(
          grepl("^(app[.]R|R/[^/]+[.]R|guide/[^/]+[.](R|Rmd|css)|www/[^/]+[.](js|css))$", sources)
        ))
        # One guide page for each exported function (the leading underscore marks a page that is only included).
        pages <- sub("[.]Rmd$", "", basename(grep("^guide/.*[.]Rmd$", sources, value = TRUE)))
        expect_setequal(setdiff(pages, "_palette-notes"), getNamespaceExports("mascot"))
        # Every web file is used by the app, so none is left behind.
        code <- unlist(lapply(
          list.files(studio_dir, pattern = "[.]R$", recursive = TRUE, full.names = TRUE),
          readLines
        ))
        for (asset in basename(grep("^(www|guide)/.*[.](js|css)$", sources, value = TRUE))) {
          expect_true(any(grepl(asset, code, fixed = TRUE)), info = asset)
        }
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
      # The studio's page needs knitr too (helper-studio.R); without it only its files are checked above.
      if (name == "studio" && requireNamespace("bslib", quietly = TRUE) && !requireNamespace("knitr", quietly = TRUE)) {
        next
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
        for (link in c("https://github.com/insightsurge/mascot", "https://insightsurge.github.io/mascot/")) {
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
    expect_setequal(names(guide$studio_guide), exports)
    for (fn in exports) {
      entry <- guide$studio_guide[[fn]]
      # The category, the vignette section and, per argument, where it can be tried: no description, argument
      # text or return value (those are read from the help page).
      expect_setequal(names(entry), c("category", "vignette", "args"))
      expect_setequal(as.character(names(entry$args)), as.character(names(formals(getExportedValue("mascot", fn)))))
      expect_true(entry$category %in% names(guide$studio_categories), info = fn)
      expect_true(nzchar(entry$vignette), info = fn)
      for (arg in names(entry$args)) {
        expect_true(all(names(entry$args[[arg]]) %in% "try"), info = paste(fn, arg))
        expect_true(is.null(entry$args[[arg]]$try) || entry$args[[arg]]$try %in% names(guide$studio_categories))
      }
    }
    # Everything left is a short label, never a sentence of explanation.
    prose <- Filter(function(text) nchar(text) > 40, unlist(lapply(guide$studio_guide, unlist)))
    expect_length(prose, 0)
  })
  it("reads every description, argument and return value from the package's help pages", {
    help <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "shared-help.R"), envir = help)
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
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "shared-help.R"), envir = help)
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
    theme <- code$code_theme("mascot", c(body = "#1f6feb"), c(body = "#9ec5fe"), "dark", c(rim = "--brand"), "", "")
    call <- code$format_call("mascot", list(id = "helper", click = menu$helper, theme = theme$helper))
    expect_match(call, "`finish-review` = ", fixed = TRUE)
    expect_identical(eval(parse(text = call)[[1]][["click"]]), mascot_popup_menu(items))
    handler <- code$menu_handler_code(items)
    expect_type(parse(text = handler), "expression")
    app <- code$whole_app_code(call, handler, c("shiny", "mascot"), c(`--brand` = "#7b4fd6"))
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
        expected <- if (length(items)) mascot_popup_menu(items, direction = direction) else mascot_popup_menu()
        expect_identical(eval(pair$helper), expected)
        for (style in c("short", "helper")) {
          text <- code$format_expr(pair[[style]])
          expect_type(parse(text = text), "expression")
          if (length(items) && direction != "auto") {
            expect_identical(eval(parse(text = text)[[1]]), expected)
            expect_match(text, paste0('direction = "', direction, '"'), fixed = TRUE)
          } else {
            expect_false(grepl("direction =", text, fixed = TRUE))
          }
        }
      }
    }
    # A menu has no shortcut; its label is kept only when written.
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
    sys.source(file.path(dir, "R", "shared-help.R"), envir = ui)
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
        expect_null(ui$studio_guide[[fn]]$args[[arg]]$default, info = paste(fn, arg))
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
    # The same files the guide pages need as in the app, so no page falls back to "could not be built".
    ui <- studio_guide_env()
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
      # A page that cannot be built warns and shows a fallback: that must fail here, not pass on structure alone.
      expect_no_warning(html <- as.character(ui$selected_guide(fn)), message = "could not be built")
      expect_false(grepl("could not be built", html, fixed = TRUE), info = fn)
      expect_match(html, paste0('data-guide-function="', fn, '"'), fixed = TRUE)
      # The card names the character it was drawn for, which the page compares with the chosen one
      expect_match(html, 'data-guide-character="tessa"', fixed = TRUE)
      expect_match(
        as.character(ui$selected_guide(fn, "sela")),
        'data-guide-character="sela"',
        fixed = TRUE,
        info = fn
      )
      # Function code has one pinned output outside the Guide; no duplicate id.
      expect_false(grepl('id="code_function"', html, fixed = TRUE))
      expect_match(html, "pg-guide-piece", fixed = TRUE)
      # The Guide shows the help page's description, details and value; each argument's text is in Controls.
      expect_true(grepl(as.character(ui$help_page(fn)$description), html, fixed = TRUE), info = fn)
      expect_true(grepl(as.character(ui$help_page(fn)$value), html, fixed = TRUE), info = fn)
      expect_false(grepl("Argument details", html, fixed = TRUE), info = fn)
    }
  })
  it("has a control on the page, or a stated reason, for every exported argument", {
    skip_without_studio_packages("studio")
    # mascot is already attached by the test run; attaching it here would detach it on exit.
    withr::local_package("shiny")
    withr::local_package("bslib")
    dir <- dirname(mascot_example("studio", run = FALSE))
    data <- new.env()
    sys.source(file.path(dir, "R", "data.R"), envir = data)
    help <- new.env()
    sys.source(file.path(dir, "R", "shared-help.R"), envir = help)
    ui <- new.env()
    sys.source(file.path(dir, "R", "ui.R"), envir = ui)
    app <- shiny::shinyAppDir(dir)
    pages <- lapply(c("", "view=examples"), function(query) {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    })
    for (page in pages) {
      expect_unique_ids(page)
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
    expect_match(pages[[1]], 'href="https://insightsurge.github.io/mascot/"', fixed = TRUE)
    expect_match(pages[[1]], "Package website", fixed = TRUE)
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
        control <- data$studio_controls[[fn]][[arg]]
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
  it("opens the studio's app on its theme page for \"theme\"", {
    skip_without_studio_packages("theme")
    # Given an interactive session where running an app only records it
    local_mocked_bindings(example_interactive = function() TRUE)
    captured <- NULL
    local_mocked_bindings(
      runApp = function(appDir) {
        captured <<- appDir
        "app stopped"
      },
      .package = "shiny"
    )
    # Then run = FALSE gives the studio's app.R, and run = TRUE runs that app on the theme page
    expect_identical(mascot_example("theme", run = FALSE), mascot_example("studio", run = FALSE))
    expect_identical(mascot_example("theme"), "app stopped")
    expect_s3_class(captured, "shiny.appobj")
    page <- captured$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = ""))$content
    expect_match(as.character(page), "<title>Theme a mascot</title>", fixed = TRUE)
  })

  it("checks every argument and names valid examples for unknown names", {
    for (bad in list(NULL, NA_character_, "", 1, c("studio", "modules"))) {
      expect_error(mascot_example(bad, run = FALSE), "Assertion on 'name' failed")
    }
    for (bad in list(NULL, NA, 1, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_example("studio", run = bad), "Assertion on 'run' failed")
    }
  })
})

describe("studio inspector labels, colour groups and menu ids", {
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
    expect_match(text, "known character", fixed = TRUE)
  })
  it("gets character labels and defaults from the package", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    for (file in list.files(dir, recursive = TRUE, full.names = TRUE)) {
      lines <- readLines(file, warn = FALSE)
      # Explicit named demos and the temporary #375 workaround are independent of defaults.
      lines <- lines[!grepl("^studio_(resting_gestures|palette_swap) <-", lines)]
      expect_false(any(grepl("tessa", lines, ignore.case = TRUE)), info = file)
    }
    env <- new.env()
    # The characters come from the studio app's shared data.
    sys.source(file.path(dir, "R", "shared-data.R"), env)
    expect_identical(unname(env$studio_characters())[[1L]], formals(mascot)$character)
    expect_identical(names(env$studio_characters()), c("Tessa", "Sela", "Knurl (experimental)", "Neer (experimental)"))
  })
  it("opens the main colours and folds the other parts under a heading per group", {
    skip_if_not_installed("bslib")
    # studio_parts() is defined further down this file, after this block has run.
    parts <- list(
      env = environment(shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))$serverFuncSource())
    )
    roles <- mascot_colour_roles("sela")
    groups <- get("colour_groups", parts$env)(roles, "sela")
    html <- as.character(get("role_pickers", parts$env)("light", roles, character = "sela"))
    titles <- regmatches(html, gregexpr('<div class="accordion-title">[^<]*</div>', html))[[1]]
    expect_identical(gsub("<[^>]+>", "", titles), c("Main colours", "More parts"))
    expect_match(
      html,
      'data-value="Main colours"[^>]*>\\s*<div class="accordion-header">\\s*<button[^>]*aria-expanded="true"'
    )
    expect_match(
      html,
      'data-value="More parts"[^>]*>\\s*<div class="accordion-header">\\s*<button[^>]*aria-expanded="false"'
    )
    headings <- regmatches(html, gregexpr('<h4 class="pg-role-group-title">[^<]*</h4>', html))[[1]]
    expect_identical(gsub("<[^>]+>", "", headings), names(groups$`More parts`))
    expect_error(get("role_pickers", parts$env)("light", roles, character = 1), "character")
  })
  it("keeps only explicit shared colour overrides across character palettes", {
    env <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "shared-colours.R"), env)
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
        `colours-css_roles` = character(),
        `colours-css_value` = "#123456",
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
        expect_false(grepl("Hello! (Choose a function|Open the function index)|About this studio", code))
      }
      for (fn in c("mascot", "update_mascot")) {
        session$setInputs(select_function = fn)
        expect_false(grepl(
          "Hello! (Choose a function|Open the function index)|About this studio",
          output$code_function
        ))
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
      # Browser input acknowledgements are separate from server update messages. A control the server did not set
      # (it already held the value) keeps the value it sent.
      session$setInputs(
        bubble_text = messages$bubble_text$value,
        bubble_html = value_or(messages$bubble_html$value, input$bubble_html),
        bubble_forever = messages$bubble_forever$value,
        bubble_closable = value_or(messages$bubble_closable$value, input$bubble_closable),
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
      messages$bubble_html <- NULL
      session$setInputs(bubble_text = "<b>Saved</b>", bubble_html = TRUE, bubble_show = 1)
      expect_true(is.null(messages$bubble_html$value) || messages$bubble_html$value)
      expect_true(input$bubble_html)
      session$setInputs(contrast_check = 1)
      # No colour of the studio's own is chosen yet, so nothing is checked in R.
      expect_match(output$contrast$html, "No colour of your own was chosen in R")
      # The result carries the number of the click it answers, which the busy button waits for
      expect_match(output$contrast$html, 'data-busy-done="1"', fixed = TRUE)
      session$setInputs(theme_source = "mascot", theme_mode = "dark")
      expect_match(output$contrast$html, "The settings changed since the last check")
      # The note after a settings change still answers the earlier click
      expect_match(output$contrast$html, 'data-busy-done="1"', fixed = TRUE)
      session$setInputs(contrast_check = 2)
      expect_match(output$contrast$html, 'data-busy-done="2"', fixed = TRUE)
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
      # The mood the page holds is "happy": the server does not send it back, as it already holds it.
      session$setInputs(mood = "happy")
      expect_identical(input$mood, "happy")
      # Re-selecting the available character exercises the same atomic update as a future character swap.
      # Mood must be present even when it matches state: the engine resets mood on a changed character id.
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
      expect_identical(input$mood, "happy")
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
      for (fn in names(get("studio_guide", envir = env))) {
        expect_match(as.character(guide(fn)), "Warnings, errors and common mistakes", fixed = TRUE)
        session$setInputs(select_function = fn)
        html <- output$guide$html
        expect_match(html, "Warnings, errors and common mistakes", fixed = TRUE)
        expect_false(grepl("<(input|select|textarea)\\b", html, perl = TRUE), info = fn)
        buttons <- regmatches(html, gregexpr("<button\\b[^>]*>", html, perl = TRUE))[[1]]
        # Only these named demonstrations may change state; other Guide actions copy code or expand it.
        allowed_events <- switch(
          fn,
          mascot_theme = "palette_swap",
          mascot_palettes = "palette_swap",
          mascot_popup_menu = "menu_long_status",
          character()
        )
        events <- regmatches(html, gregexpr('data-event="[^"]+"', html))[[1]]
        # Links to another function's guide (data-event="select_function") only move the studio there.
        events <- setdiff(events, 'data-event="select_function"')
        expect_setequal(events, paste0('data-event="', allowed_events, '"')[seq_along(allowed_events)])
        demo <- grepl('data-event="', buttons, fixed = TRUE)
        if (length(allowed_events)) {
          expect_identical(sum(demo), 2L, info = fn)
          expect_match(
            html,
            if (fn == "mascot_popup_menu") 'data-value="top-right"' else 'data-value="kept"',
            fixed = TRUE
          )
          expect_match(
            html,
            if (fn == "mascot_popup_menu") 'data-value="bottom-right"' else 'data-value="dropped"',
            fixed = TRUE
          )
        }
        expand <- grepl('data-expand-inspector="true"', buttons, fixed = TRUE)
        expect_identical(sum(expand), 1L, info = fn)
        expect_true(all(grepl('aria-controls="inspector_sidebar"', buttons[expand], fixed = TRUE)), info = fn)
        expect_true(all(grepl("data-copy=", buttons[!expand & !demo], fixed = TRUE)), info = fn)
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
          expect_match(html, 'id="roles_table"', fixed = TRUE)
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
        `colours-css_roles` = character(),
        `colours-css_value` = "#123456",
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
      # Nothing is built until the preview page is shown: the browser sets the host mode when it selects the function.
      expect_match(output$code_preview, "Select mascot_preview()", fixed = TRUE)
      session$setInputs(select_function = "mascot_preview", host_mode = "preview")
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
      session$setInputs(select_function = "mascot_mood", host_mode = "mascot", preview_size = 120)
      session$elapse(500)
      expect_identical(last_preview_attempt()$outcome, "error")
      session$setInputs(select_function = "mascot_preview", host_mode = "preview")
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

describe("the preview page and the host mode", {
  it("stops rebuilding the page once the host mode leaves it, although mascot_preview() stays selected", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      # Given the preview page is shown, as the browser's host mode says when it selects mascot_preview()
      session$setInputs(select_function = "mascot_preview", host_mode = "preview")
      session$elapse(500)
      expect_identical(preview_request(), 1)
      # And the host mode is back on the live mascot, while the function is still mascot_preview()
      session$setInputs(host_mode = "mascot")
      expect_false(preview_selected())
      # When the character changes, nothing builds the hidden page
      session$setInputs(character = "sela")
      session$elapse(500)
      expect_identical(preview_request(), 1)
      expect_false(is_building())
      # And it is built for the character chosen meanwhile when the page is shown again
      session$setInputs(host_mode = "preview")
      session$elapse(500)
      expect_identical(preview_request(), 2)
      expect_match(output$code_preview, 'character = "sela"', fixed = TRUE)
    })
  })
  it("stops saying Building, and answers Copy, when the page is left before a change is built", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      answers <- integer()
      session$sendCustomMessage <- function(type, message) {
        if (identical(type, "studio:copy")) answers <<- c(answers, message$ticket)
      }
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(select_function = "mascot_preview", host_mode = "preview")
      session$elapse(500)
      expect_identical(preview_request(), 1)
      # Given a change to the page, and the page left before its pause ends
      session$setInputs(preview_status = "Second build")
      expect_true(is_building())
      session$setInputs(host_mode = "mascot")
      session$elapse(500)
      # Then nothing is being built, the code is the call that will build the page, and a copy button's ticket is answered
      expect_false(is_building())
      expect_identical(preview_request(), 1)
      expect_match(output$code_preview, 'status = "Second build"', fixed = TRUE)
      session$setInputs(copy_ticket = 1)
      expect_identical(answers, 1L)
      # And the change is built when the page is shown again
      session$setInputs(host_mode = "preview")
      session$elapse(500)
      expect_identical(preview_request(), 2)
      expect_match(output$code_preview, 'status = "Second build"', fixed = TRUE)
      # And a change undone while the page was hidden needs no build, so "Building" is not left on either
      session$setInputs(preview_status = "Third build")
      session$setInputs(host_mode = "mascot")
      session$setInputs(preview_status = "Second build")
      session$setInputs(host_mode = "preview")
      session$elapse(500)
      expect_false(is_building())
      expect_identical(preview_request(), 2)
    })
  })
  it("says Building until the browser reports that the page has loaded in its frame", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(select_function = "mascot_preview", host_mode = "preview")
      session$elapse(500)
      # Given the page is built and its frame is drawn, the page inside has not loaded: the badge stays
      expect_false(is_building())
      expect_match(output$preview_frame$html, built_preview()$file, fixed = TRUE)
      badge_shown <- function() any(grepl("Building", output$preview_status_badge$html, fixed = TRUE))
      expect_true(badge_shown())
      # When the frame reports the page it loaded, the badge goes
      session$setInputs(preview_loaded = paste0(prefix, "/", built_preview()$file))
      expect_false(badge_shown())
      # And a rebuilt page is a new page: the report of the old one does not count, and the badge is back
      session$setInputs(preview_mood = "happy")
      session$elapse(500)
      expect_false(is_building())
      expect_true(badge_shown())
      # Until the new page reports that it has loaded
      session$setInputs(preview_loaded = paste0(prefix, "/", built_preview()$file))
      expect_false(badge_shown())
    })
  })
})

describe("the studio's echo of a change it applied", {
  it("leaves a typed bubble draft alone when an editor-open request arrives afterwards", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      messages <- list()
      session$sendInputMessage <- function(id, message) messages[[id]] <<- message
      do.call(session$setInputs, start)
      studio_go_live(session)
      # The text input has arrived, but the chip's delayed application has not. The live bubble
      # still contains the welcome text when the earlier request to open its editor arrives.
      session$setInputs(
        bubble_text = "abc",
        bubble_html = TRUE,
        bubble_forever = TRUE,
        bubble_duration = 9,
        bubble_closable = FALSE
      )
      before <- live_demo$bubble
      expect_identical(as.character(eval(before$helper)$text), get("welcome", parts$env))
      call <- last_call()
      messages <- list()
      session$setInputs(chip_argument = "bubble")
      for (id in c("bubble_text", "bubble_html", "bubble_forever", "bubble_duration", "bubble_closable")) {
        expect_null(messages[[id]], info = id)
      }
      expect_identical(live_demo$bubble, before)
      expect_identical(last_call(), call)
      expect_identical(bubble_draft$text, "abc")
      expect_true(bubble_draft$html)
      # Show must use the draft too, even before the chip's application arrives.
      session$setInputs(bubble_show = 1)
      shown <- eval(state$bubble$helper)
      expect_identical(as.character(shown$text), "abc")
      expect_true(shown$html)
      expect_identical(shown$duration, Inf)
      expect_false(shown$closable)
    })
  })

  it("sets a control only when the control did not send that value itself", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    status_code <- get("code_status", parts$env)
    shiny::testServer(get("studio_server", parts$env), {
      messages <- list()
      session$sendInputMessage <- function(id, message) messages[[id]] <<- message
      do.call(session$setInputs, start)
      studio_go_live(session)
      messages <- list()
      # Given the status text came from the page, the server applies it and leaves the control alone
      session$setInputs(status_text = "ab")
      session$elapse(700)
      expect_identical(state$status$helper, quote(mascot_status("ab")))
      expect_null(messages$status_text)
      # When a chip sets the status instead, the control follows
      session$setInputs(chip_reset = "status")
      expect_identical(messages$status_text$value, "")
      # And the same value sent to the control twice, before it answers, is sent twice: the control may not hold the first
      messages <- list()
      send(list(status = status_code("one")), force = TRUE)
      expect_identical(messages$status_text$value, "one")
      send(list(status = status_code("")), force = TRUE)
      expect_identical(messages$status_text$value, "")
      expect_error(echo_to_control("", "x", identity), "Assertion on 'id' failed")
      expect_error(echo_to_control("mood", "x", 1), "Assertion on 'update' failed")
    })
  })
})

describe("studio help pages and copied apps", {
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
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "shared-help.R"), env)
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
  it("provides helper links and concrete instructions beside controls", {
    skip_if_not_installed("bslib")
    app <- shiny::shinyAppDir(dirname(mascot_example("studio", run = FALSE)))
    env <- environment(app$serverFuncSource())
    page <- as.character(get("studio_page", env)(formals(mascot)$character, "mascot"))
    for (fn in c("mascot", "update_mascot")) {
      for (arg in setdiff(names(get("the_guide", env)(fn)$args), c("id", "...", "session"))) {
        links <- as.character(htmltools::tagList(get("wiring_links", env)(fn)))
        helper <- switch(arg, motion = "mascot_motion_settings", click = "mascot_action", paste0("mascot_", arg))
        expect_match(links, paste0('data-value="', helper, '"'), fixed = TRUE)
        expect_match(links, paste0(helper, "()"), fixed = TRUE)
        expect_match(links, 'data-event="select_function"', fixed = TRUE)
      }
    }
    for (text in c("stays inside this contained preview", "Follow others", "Demonstration:", "One-off gestures")) {
      expect_match(page, text, fixed = TRUE)
    }
    expect_match(page, "Inspector", fixed = TRUE)
    expect_match(page, "Click or tap the mascot to open its menu", fixed = TRUE)
    expect_match(as.character(get("guide_help", env)("mascot")), 'vignette("mascot", package = "mascot")', fixed = TRUE)
    expect_match(
      as.character(get("function_visual", env)("mascot_mood")),
      "Try moods with the Mood drop-down in the top bar",
      fixed = TRUE
    )
  })
})

describe("studio guide pages", {
  guide_dir <- function() file.path(dirname(mascot_example("studio", run = FALSE)), "guide")
  page_html <- function(page) paste(vapply(page, as.character, character(1)), collapse = "\n")
  # The website knit also holds two boxes that speak of the studio by design: "Try it live" and the section of
  # real warnings and errors. The checks of the page's own content leave them out; they have their own tests.
  without_site_extras <- function(html) {
    html <- sub("(?s)<h3[^>]*>Warnings, errors and common mistakes</h3>.*$", "", html, perl = TRUE)
    gsub("(?s)<div class=\"pg-callout\">\\s*<strong>Try it live\\. </strong>.*?</div>", "", html, perl = TRUE)
  }
  # The studio names the selected character in a heading ("Sela's anchors"); the website, which shows every
  # character in tabs, uses the general title ("Anchors"). NULL where the studio text has no general form.
  site_title <- function(text) {
    if (!startsWith(text, "Sela's")) {
      return(text)
    }
    rest <- trimws(sub("^Sela's", "", text))
    if (nzchar(rest)) paste0(toupper(substring(rest, 1, 1)), substring(rest, 2))
  }
  batch_pages <- c("mascot_bubble", "mascot_action", "mascot_preview", "update_mascot")
  batch_content <- list(
    mascot_bubble = c(
      "How long a bubble stays",
      "duration = 5: hides",
      "Inf: stays",
      "HTML is trusted as it is.",
      "Supply text when setting options.",
      "pg-timeline",
      "pg-callout-warn"
    ),
    mascot_action = c(
      "From a click to your server",
      "Open help",
      "input$helper_click",
      "counts up",
      "observeEvent()",
      "can answer too",
      "A picture or a button.",
      "Supply a label when setting options."
    ),
    mascot_preview = c("Offline comparison", "160, 96 and 24 px columns", "no placement or click arguments"),
    update_mascot = c(
      "What each kind of value does in update_mascot()",
      "Reset table: what each argument resets to",
      "Condition classes",
      "Whole setting.",
      "All or nothing.",
      "mascot_update_ignored",
      "mascot_error_choice",
      "mascot_error_dots",
      "mascot_contrast",
      "mascot_placement_ignored"
    )
  )
  interactive_pages <- c("mascot_size", "mascot_placement", "mascot_colour_roles", "mascot_popup_menu", "mascot")
  interactive_content <- list(
    mascot_size = c("Size", "Small screens.", "576 pixels", "160"),
    mascot_placement = c("Placement", "bottom-right corner", "inline"),
    mascot_colour_roles = c("Sela's parts", "Leaders adopt", "Followers copy", "mascot.contrast_warnings"),
    mascot_popup_menu = c(
      "From a click to your server",
      "Long status",
      "Your server code for these items",
      "Supply menu items when setting options.",
      "Keyboard.",
      "Opening and closing the menu sends no Shiny input."
    ),
    mascot = c("Two calls, one id", "module UI", "module server", "pg-wire-box")
  )
  new_pages <- list(
    mascot_motion_settings = c(
      "What each switch controls",
      "Which setting wins",
      "Three motion recipes",
      "A calm dashboard"
    ),
    mascot_character = c("Choose a character for the job", "Shipped characters", "What comes with the character"),
    mascot_example = c("Copy an example into your project", "Run one"),
    mascot_examples = c("Pick an example by its task", "List the names"),
    mascot_studio = c(
      "Open a useful starting point",
      "Three views, one app",
      "Inspect without launching",
      "What to look at first"
    )
  )
  data_pages <- c(
    "mascot_mood",
    "mascot_moods",
    "mascot_characters",
    "mascot_families",
    "mascot_anchors",
    "mascot_gesture",
    "mascot_gestures",
    "mascot_palettes"
  )
  data_content <- list(
    mascot_mood = c("The 5 moods", "The mood never speaks alone.", "screen readers"),
    mascot_moods = c("Sela's", "moods", "The five shared moods come first", "fallback"),
    mascot_characters = "Characters this session knows",
    mascot_families = "Character families",
    mascot_anchors = "Sela's anchors",
    mascot_gesture = c("Gestures", "pg-cards", "pg-card-mini", "gesture ="),
    mascot_gestures = c("Sela's gestures", "30 frames per second", "plays its fallback"),
    mascot_palettes = c("Sela's palettes", "first row", "Colour precedence", "below 3:1 contrast")
  )
  # The website knit of a page: no studio, so no widgets, but every character, the live box and the real messages.
  knit_for_website <- function(fn) {
    standalone <- new.env(parent = globalenv())
    standalone$guide_dir <- guide_dir()
    sys.source(file.path(guide_dir(), "guide-helpers.R"), standalone)
    options <- knitr::opts_chunk$get()
    withr::defer(knitr::opts_chunk$restore(options))
    knitr::opts_chunk$set(echo = FALSE, error = FALSE)
    markdown <- knitr::knit(
      file.path(guide_dir(), paste0(fn, ".Rmd")),
      output = file.path(withr::local_tempdir(), "page.md"),
      envir = standalone,
      quiet = TRUE
    )
    paste(readLines(markdown, warn = FALSE), collapse = "\n")
  }
  all_pages <- sub("[.]Rmd$", "", list.files(guide_dir(), pattern = "^[^_].*[.]Rmd$"))
  tabbed_pages <- c(
    "mascot_moods",
    "mascot_gestures",
    "mascot_anchors",
    "mascot_palettes",
    "mascot_colour_roles",
    "mascot_theme",
    "mascot_gesture"
  )
  for (fn in batch_pages) {
    it(paste("knits", fn, "with its existing guide content and no live widgets in either context"), {
      env <- studio_guide_env()
      pieces <- env$studio_guide_page(fn, "sela", guide_dir())
      html <- page_html(pieces)
      if (fn %in% c("mascot_bubble", "mascot_action", "update_mascot")) {
        expect_true("mascot-guide" %in% vapply(htmltools::findDependencies(pieces), function(d) d$name, character(1)))
      }
      standalone <- new.env(parent = globalenv())
      standalone$guide_dir <- guide_dir()
      sys.source(file.path(guide_dir(), "guide-helpers.R"), standalone)
      standalone$studio_character <- "sela"
      options <- knitr::opts_chunk$get()
      withr::defer(knitr::opts_chunk$restore(options))
      markdown <- knitr::knit(
        file.path(guide_dir(), paste0(fn, ".Rmd")),
        output = file.path(withr::local_tempdir(), "page.md"),
        envir = standalone,
        quiet = TRUE
      )
      outside <- without_site_extras(page_html(env$studio_guide_pieces(paste(readLines(markdown), collapse = "\n"))))
      for (text in batch_content[[fn]]) {
        expect_match(html, text, fixed = TRUE)
        expect_match(outside, text, fixed = TRUE)
      }
      for (text in c(html, outside)) {
        expect_false(grepl("data-event|shiny-html-output|shiny-text-output|data-mascot", text))
        expect_false(grepl("studio", env$html_text(text), ignore.case = TRUE))
      }
      builder <- switch(
        fn,
        mascot_bubble = "visual_bubble",
        mascot_action = "visual_action",
        mascot_preview = "visual_preview",
        update_mascot = "visual_update_mascot"
      )
      expect_false(exists(builder, envir = env, inherits = FALSE))
      if (fn == "update_mascot") {
        expect_match(env$html_text(html), paste0('back to "', formals(mascot::mascot)$character, '"'), fixed = TRUE)
        # Resetting a character uses the package default, even when another character is selected.
        expect_identical(html, page_html(env$studio_guide_page(fn, "tessa", guide_dir())))
        expect_identical(
          lengths(regmatches(html, gregexpr('<table class="table table-sm pg-table">', html, fixed = TRUE))),
          3L
        )
      }
      selected <- as.character(env$selected_guide(fn, "sela"))
      expect_match(selected, paste0("Help page: ", fn, "()"), fixed = TRUE)
      expect_match(selected, "Warnings, errors and common mistakes", fixed = TRUE)
    })
  }
  for (fn in interactive_pages) {
    it(paste("knits", fn, "with its content and guards its live widgets"), {
      env <- studio_guide_env()
      html <- page_html(env$studio_guide_page(fn, "sela", guide_dir()))
      standalone <- new.env(parent = globalenv())
      standalone$guide_dir <- guide_dir()
      standalone$studio_character <- "sela"
      sys.source(file.path(guide_dir(), "guide-helpers.R"), standalone)
      options <- knitr::opts_chunk$get()
      withr::defer(knitr::opts_chunk$restore(options))
      knitr::opts_chunk$set(error = FALSE)
      markdown <- knitr::knit(
        file.path(guide_dir(), paste0(fn, ".Rmd")),
        output = file.path(withr::local_tempdir(), "page.md"),
        envir = standalone,
        quiet = TRUE
      )
      outside <- without_site_extras(page_html(env$studio_guide_pieces(paste(readLines(markdown), collapse = "\n"))))
      for (text in interactive_content[[fn]]) {
        expect_match(html, text, fixed = TRUE)
        if (!is.null(site_title(text))) expect_match(outside, site_title(text), fixed = TRUE)
      }
      expect_false(grepl("data-event|shiny-html-output|shiny-text-output|data-mascot", outside))
      expect_false(grepl("studio|Controls tab|sentence bar", env$html_text(outside), ignore.case = TRUE))
      ids <- switch(
        fn,
        mascot_size = "size_ruler",
        mascot_placement = "placement_map",
        mascot_colour_roles = "roles_table",
        mascot_popup_menu = c("menu_last", "menu_code"),
        character()
      )
      for (id in ids) {
        expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
        expect_false(grepl(paste0('id="', id, '"'), outside, fixed = TRUE))
      }
      if (fn == "mascot_popup_menu") {
        expect_match(html, 'data-event="menu_long_status"', fixed = TRUE)
        expect_match(outside, "shiny::observeEvent", fixed = TRUE)
      }
      if (fn == "mascot_colour_roles") {
        expect_false(grepl("<table", html, fixed = TRUE))
        expect_match(outside, "pg-swatch", fixed = TRUE)
        expect_match(outside, "mascot_theme page", fixed = TRUE)
      }
      if (fn == "mascot_placement") {
        expect_match(outside, "pg-map", fixed = TRUE)
      }
      builder <- switch(
        fn,
        mascot_size = "visual_size",
        mascot_placement = "visual_placement",
        mascot_colour_roles = "visual_colour_roles",
        mascot_popup_menu = "visual_menu",
        mascot = "visual_mascot"
      )
      expect_false(exists(builder, envir = env, inherits = FALSE))
      selected <- as.character(env$selected_guide(fn, "sela"))
      expect_match(selected, paste0("Help page: ", fn, "()"), fixed = TRUE)
    })
  }
  for (fn in names(new_pages)) {
    it(paste("knits", fn, "with its worked guide and guards its live content"), {
      env <- studio_guide_env()
      html <- page_html(env$studio_guide_page(fn, "sela", guide_dir()))
      standalone <- new.env(parent = globalenv())
      standalone$guide_dir <- guide_dir()
      sys.source(file.path(guide_dir(), "guide-helpers.R"), standalone)
      standalone$studio_character <- "sela"
      options <- knitr::opts_chunk$get()
      withr::defer(knitr::opts_chunk$restore(options))
      markdown <- knitr::knit(
        file.path(guide_dir(), paste0(fn, ".Rmd")),
        output = file.path(withr::local_tempdir(), "page.md"),
        envir = standalone,
        quiet = TRUE
      )
      outside <- without_site_extras(page_html(env$studio_guide_pieces(paste(readLines(markdown), collapse = "\n"))))
      for (heading in new_pages[[fn]]) {
        for (text in c(html, outside)) {
          expect_match(text, paste0(">", heading, "</h3>"), fixed = TRUE)
        }
      }
      expect_false(grepl("data-event|shiny-html-output|shiny-text-output|data-mascot", outside))
      if (fn == "mascot_character") {
        expect_match(html, 'id="characters_table"', fixed = TRUE)
        for (id in mascot_characters()$id) {
          expect_match(outside, paste0("<td>", id, "</td>"), fixed = TRUE)
        }
        expect_match(html, 'character = "sela"', fixed = TRUE)
        other <- page_html(env$studio_guide_page(fn, "neer", guide_dir()))
        expect_match(other, 'character = "neer"', fixed = TRUE)
        expect_false(grepl('character = "sela"', other, fixed = TRUE))
      } else {
        # Only a link to another guide (data-event="select_function") may appear in the studio.
        expect_false(grepl(
          'data-event="(?!select_function")|shiny-html-output|shiny-text-output|data-mascot',
          html,
          perl = TRUE
        ))
      }
      if (fn == "mascot_examples") {
        for (column in mascot_examples()) {
          for (value in column) {
            expect_match(outside, value, fixed = TRUE)
          }
        }
      }
      if (fn %in% c("mascot_example", "mascot_examples")) {
        expect_match(html, "Examples host mode", fixed = TRUE)
        expect_false(grepl("Examples host mode", outside, fixed = TRUE))
      }
      if (fn == "mascot_motion_settings") {
        for (switch in names(formals(mascot_motion_settings))[-1L]) {
          expect_match(outside, paste0("<code>", switch, "</code>"), fixed = TRUE)
        }
        expect_match(outside, "pg-flow-step", fixed = TRUE)
        expect_match(outside, "instant drag transitions", fixed = TRUE)
        expect_match(html, "live motion switches in Controls", fixed = TRUE)
        expect_false(grepl("live motion switches in Controls", outside, fixed = TRUE))
        expect_s3_class(standalone$no_idle, "mascot_motion_settings")
        expect_s3_class(standalone$gestures_only, "mascot_motion_settings")
        expect_s3_class(standalone$still, "shiny.tag")
      }
      if (fn == "mascot_studio") {
        # Here the studio is the subject, so the word belongs in standalone prose.
        for (value in c("bslib", "knitr", "offline", "shiny.appobj", "Preview page")) {
          expect_match(outside, value, fixed = TRUE)
        }
      } else {
        # The required examples listing includes the app named studio. Exclude the
        # package-generated table and code when checking our surrounding prose.
        prose <- gsub("(?s)<table.*?</table>|<pre.*?</pre>|<code.*?</code>", "", outside, perl = TRUE)
        expect_false(grepl("studio", env$html_text(prose), ignore.case = TRUE))
      }
      selected <- as.character(env$selected_guide(fn, "sela"))
      expect_match(selected, paste0("Help page: ", fn, "()"), fixed = TRUE)
      expect_match(selected, "Warnings, errors and common mistakes", fixed = TRUE)
    })
  }
  it("draws static role swatches for each character and retains the live outline link", {
    env <- studio_guide_env()
    helpers <- new.env()
    helpers$guide_dir <- guide_dir()
    sys.source(file.path(guide_dir(), "guide-helpers.R"), helpers)
    for (id in mascot_characters()$id) {
      roles <- mascot_colour_roles(id)
      static <- as.character(helpers$guide_roles_table(id))
      live <- as.character(env$roles_table(id))
      for (value in c(roles$role, roles$colour, roles$brand[!is.na(roles$brand)])) {
        expect_match(static, value, fixed = TRUE)
        expect_match(live, value, fixed = TRUE)
      }
      for (column in names(roles)) {
        expect_match(static, paste0("<th>", column, "</th>"), fixed = TRUE)
      }
      expect_identical(lengths(regmatches(static, gregexpr('class="pg-swatch"', static, fixed = TRUE))), nrow(roles))
      for (value in roles$follows[!is.na(roles$follows)]) {
        expect_match(static, paste("\u2190", value), fixed = TRUE)
      }
      expect_match(live, 'data-value="mascot_theme"', fixed = TRUE)
      expect_false(grepl("data-event", static, fixed = TRUE))
      expect_match(
        page_html(env$studio_guide_page("mascot_colour_roles", id, guide_dir())),
        paste0(mascot_character(id)$name, "'s parts"),
        fixed = TRUE
      )
    }
    expect_error(helpers$guide_roles_table(1), "string")
  })
  for (fn in data_pages) {
    it(paste("knits", fn, "with its data, headings and guarded widgets"), {
      env <- studio_guide_env()
      html <- page_html(env$studio_guide_page(fn, "sela", guide_dir()))
      standalone <- new.env(parent = globalenv())
      standalone$guide_dir <- guide_dir()
      standalone$studio_character <- "sela"
      sys.source(file.path(guide_dir(), "guide-helpers.R"), standalone)
      options <- knitr::opts_chunk$get()
      withr::defer(knitr::opts_chunk$restore(options))
      markdown <- knitr::knit(
        file.path(guide_dir(), paste0(fn, ".Rmd")),
        output = file.path(withr::local_tempdir(), "page.md"),
        envir = standalone,
        quiet = TRUE
      )
      outside <- without_site_extras(page_html(env$studio_guide_pieces(paste(readLines(markdown), collapse = "\n"))))
      for (text in data_content[[fn]]) {
        expect_match(html, text, fixed = TRUE)
        if (!is.null(site_title(text))) expect_match(outside, site_title(text), fixed = TRUE)
      }
      expect_false(grepl("data-event|shiny-html-output|shiny-text-output|data-mascot", outside))
      expect_false(grepl("studio|sentence|top bar|Controls tab", env$html_text(outside), ignore.case = TRUE))
      ids <- switch(
        fn,
        mascot_characters = "characters_table",
        mascot_palettes = c(
          "palette_base_demo",
          "dark_outline_tip",
          "roles_table",
          "palette_swap_demo",
          "palette_swap_result"
        ),
        character()
      )
      for (id in ids) {
        expect_match(html, paste0('id="', id, '"'), fixed = TRUE)
        expect_false(grepl(paste0('id="', id, '"'), outside, fixed = TRUE))
      }
      if (fn == "mascot_palettes") {
        expect_match(html, "data-event", fixed = TRUE)
      }
      if (fn == "mascot_mood") {
        expect_match(html, "Try moods with the Mood drop-down in the top bar.", fixed = TRUE)
        expect_false(grepl("Try moods", outside, fixed = TRUE))
      }
      listing <- switch(
        fn,
        mascot_mood = mascot_moods(),
        mascot_moods = mascot_moods("sela"),
        mascot_characters = mascot_characters(),
        mascot_families = mascot_families(),
        mascot_anchors = mascot_anchors("sela"),
        mascot_gestures = mascot_gestures("sela"),
        mascot_palettes = mascot_palettes("sela"),
        NULL
      )
      if (!is.null(listing)) {
        for (column in names(listing)) {
          for (value in ifelse(is.na(listing[[column]]), "NA", as.character(listing[[column]]))) {
            expect_match(outside, as.character(htmltools::htmlEscape(value)), fixed = TRUE)
            if (fn != "mascot_characters") expect_match(html, as.character(htmltools::htmlEscape(value)), fixed = TRUE)
          }
        }
      }
      builder <- sub("mascot_", "visual_", fn, fixed = TRUE)
      expect_false(exists(builder, envir = env, inherits = FALSE))
      selected <- as.character(env$selected_guide(fn, "sela"))
      expect_match(selected, paste0("Help page: ", fn, "()"), fixed = TRUE)
      expect_match(selected, "Warnings, errors and common mistakes", fixed = TRUE)
    })
  }
  it("follows each selected character in the data pages and preserves anchor empty states", {
    env <- studio_guide_env()
    for (id in mascot_characters()$id) {
      name <- mascot_character(id)$name
      for (fn in c("mascot_moods", "mascot_anchors", "mascot_gestures", "mascot_palettes")) {
        html <- page_html(env$studio_guide_page(fn, id, guide_dir()))
        expect_match(html, paste0(name, "'s"), fixed = TRUE)
        listing <- getExportedValue("mascot", fn)(id)
        if (nrow(listing)) {
          for (value in as.character(listing[[1]])) {
            expect_match(html, paste0("<td>", value, "</td>"), fixed = TRUE)
          }
        } else if (fn == "mascot_anchors") {
          expect_match(html, paste(name, "has no anchors"), fixed = TRUE)
        }
      }
      gestures <- page_html(env$studio_guide_page("mascot_gesture", id, guide_dir()))
      resting <- mascot_gestures(id)$name %in% env$studio_resting_gestures[id]
      for (value in mascot_gestures(id)$description[!resting]) {
        expect_match(gestures, value, fixed = TRUE)
      }
      if (any(resting)) {
        expect_match(gestures, "idle animation.", fixed = TRUE)
        expect_match(gestures, "in the gesture list at the top.", fixed = TRUE)
      }
    }
    for (helper in c("palette_table", "palette_guide_notes", "palette_guide_demo")) {
      expect_false(exists(helper, envir = env, inherits = FALSE))
    }
    expect_null(env$studio_guide_page("_palette-notes", "sela", guide_dir()))
  })
  it("returns NULL for a function without a page, so only its help and mistakes are shown", {
    env <- studio_guide_env()
    expect_null(env$studio_guide_page("not_a_mascot_function", "tessa", guide_dir()))
    expect_null(env$studio_guide_page("../mascot_theme", "tessa", guide_dir()))
    expect_null(env$studio_guide_page("mascot_theme", "tessa", withr::local_tempdir()))
    expect_error(env$studio_guide_page(1, "tessa"), "string")
    expect_error(env$studio_guide_page("mascot_theme", "", guide_dir()), "character")
    expect_error(env$studio_guide_page("mascot_theme", "tessa", 1), "string")
    # Simulate an absent page: the Guide still shows the help page and the live mistakes.
    empty_dir <- withr::local_tempdir()
    env$studio_guide_dir <- function() empty_dir
    missing <- as.character(env$selected_guide("mascot_motion_settings"))
    expect_match(missing, "pg-guide-help", fixed = TRUE)
    expect_match(missing, "Warnings, errors and common mistakes", fixed = TRUE)
  })
  it("knits mascot_status into its table of status line and speech bubble", {
    env <- studio_guide_env()
    page <- env$studio_guide_page("mascot_status", "tessa", guide_dir())
    html <- page_html(page)
    expect_match(html, '<h3 class="pg-section-title">Status line or speech bubble?</h3>', fixed = TRUE)
    expect_match(html, '<table class="table table-sm pg-table">', fixed = TRUE)
    for (text in c("Screen readers", "Announced politely", "status = mascot_status()", "bubble = mascot_bubble()")) {
      expect_match(html, text, fixed = TRUE)
    }
    expect_identical(vapply(page, attr, character(1), "guide_kind"), "heading")
  })
  it("knits mascot_theme into its diagrams, callout and live demos with the ids the studio relies on", {
    env <- studio_guide_env()
    page <- env$studio_guide_page("mascot_theme", "tessa", guide_dir())
    html <- page_html(page)
    for (text in c(
      "Which mode applies",
      "Brand colours from bslib",
      "pg-flow-step",
      "pg-flow-arrow",
      "pg-flow-gap",
      "Colour precedence",
      "theme = &quot;original&quot;",
      "below 3:1 contrast",
      "A bs_theme() always uses mode"
    )) {
      expect_match(html, text, fixed = TRUE)
    }
    for (id in c("palette_swap_demo", "palette_base_demo", "dark_outline_tip", "roles_table")) {
      expect_match(html, sprintf('id="%s"', id), fixed = TRUE)
    }
    # The tip comes from the help page of mascot_theme(), not from the page.
    tip <- env$studio_help_tail(
      env$help_arg("mascot_theme", "dark"),
      "Built-in characters keep one outline colour"
    )
    expect_match(html, tip, fixed = TRUE)
    expect_false(grepl(
      "Built-in characters keep one outline colour",
      paste(readLines(file.path(guide_dir(), "mascot_theme.Rmd")), collapse = " "),
      fixed = TRUE
    ))
    # Headings and the callout start their own pieces; the callout stands alone at the end.
    kinds <- vapply(page, attr, character(1), "guide_kind")
    expect_identical(kinds[[1]], "heading")
    expect_identical(kinds[[length(kinds)]], "callout")
    expect_true(all(kinds[-length(kinds)] == "heading"))
    # The diagram stylesheet travels with the page.
    expect_true("mascot-guide" %in% vapply(htmltools::findDependencies(page), function(d) d$name, character(1)))
    # selected_guide() puts every piece in its own column and keeps the help page and the mistakes.
    guide <- as.character(env$selected_guide("mascot_theme"))
    expect_gte(lengths(regmatches(guide, gregexpr('class="pg-guide-piece', guide, fixed = TRUE))), length(page))
    expect_match(guide, "Help page: mascot_theme()", fixed = TRUE)
    expect_match(guide, "Warnings, errors and common mistakes", fixed = TRUE)
  })
  it("follows the selected character in its tables", {
    env <- studio_guide_env()
    tessa <- page_html(env$studio_guide_page("mascot_theme", "tessa", guide_dir()))
    sela <- page_html(env$studio_guide_page("mascot_theme", "sela", guide_dir()))
    expect_match(tessa, "Tessa's palettes", fixed = TRUE)
    expect_match(sela, "Sela's palettes", fixed = TRUE)
    own <- setdiff(mascot_palettes("sela")$name, mascot_palettes("tessa")$name)
    expect_gt(length(own), 0L)
    expect_match(sela, paste0("<td>", own[[1]], "</td>"), fixed = TRUE)
    expect_false(grepl(paste0("<td>", own[[1]], "</td>"), tessa, fixed = TRUE))
  })
  it("builds a page afresh on every visit, so a live demo never holds another session's mascot", {
    env <- studio_guide_env()
    dir <- withr::local_tempdir()
    file.copy(list.files(guide_dir(), full.names = TRUE), dir)
    expect_false(exists("studio_guide_cache", envir = env))
    page <- file.path(dir, "mascot_status.Rmd")
    expect_match(
      page_html(env$studio_guide_page("mascot_status", "tessa", dir)),
      "Status line or speech bubble?",
      fixed = TRUE
    )
    text <- readLines(page)
    writeLines(sub("Status line or speech bubble?", "A new heading", text, fixed = TRUE), page)
    expect_match(page_html(env$studio_guide_page("mascot_status", "tessa", dir)), "A new heading", fixed = TRUE)
  })
  it("links to another guide inside its paragraph: moving the studio there, or to the site page", {
    env <- studio_guide_env()
    html <- page_html(env$studio_guide_page("mascot_character", "tessa", guide_dir()))
    for (fn in c("mascot_moods", "mascot_gestures", "mascot_anchors", "mascot_palettes")) {
      expect_match(html, paste0('data-event="select_function" data-value="', fn, '"'), fixed = TRUE)
      expect_match(
        html,
        paste0("<li>[A-Za-z]+: <a href=\"#\" data-event=\"select_function\" data-value=\"", fn),
        perl = TRUE
      )
    }
    expect_false(grepl("GUIDEINLINE|GUIDEBLOCK", html))
    helpers <- new.env(parent = globalenv())
    sys.source(file.path(guide_dir(), "guide-helpers.R"), envir = helpers)
    expect_match(as.character(helpers$guide_fn_link("mascot_moods")), 'href="guide-mascot_moods.html"', fixed = TRUE)
    expect_error(helpers$guide_fn_link(1), "string")
  })
  it("has a website article for every guide page, listed on the guide index the navbar links", {
    articles <- test_path("..", "..", "vignettes", "articles")
    config <- test_path("..", "..", "_pkgdown.yml")
    skip_if_not(
      dir.exists(articles) && file.exists(config),
      "The website sources are not part of the installed package."
    )
    pages <- sub("[.]Rmd$", "", list.files(guide_dir(), pattern = "^[^_].*[.]Rmd$"))
    stubs <- sub("^guide-(.*)[.]Rmd$", "\\1", list.files(articles, pattern = "^guide-.*[.]Rmd$"))
    expect_setequal(stubs, pages)
    navbar <- paste(readLines(config, warn = FALSE), collapse = "\n")
    expect_match(navbar, "href: articles/studio-guide.html", fixed = TRUE)
    # The index (vignettes/articles/studio-guide.Rmd) lists each page under its studio group.
    groups <- new.env()
    sys.source(file.path(dirname(guide_dir()), "R", "guide.R"), envir = groups)
    expect_true(file.exists(file.path(articles, "studio-guide.Rmd")))
    category <- vapply(
      pages,
      function(page) {
        entry <- groups$studio_guide[[page]]
        if (is.null(entry)) NA_character_ else entry$category
      },
      character(1)
    )
    grouped <- category %in% names(groups$studio_categories)
    expect_true(all(grouped), info = toString(pages[!grouped]))
    for (page in pages) {
      stub <- paste(readLines(file.path(articles, paste0("guide-", page, ".Rmd")), warn = FALSE), collapse = "\n")
      # The stub includes the page by name and sets up the helpers from the installed package.
      expect_match(stub, paste0('file.path(guide_dir, "', page, '.Rmd")'), fixed = TRUE, info = page)
      expect_match(
        stub,
        'sys.source(file.path(guide_dir, "guide-helpers.R"), envir = knitr::knit_global())',
        fixed = TRUE,
        info = page
      )
    }
  })
  it("shows the website reader a live box, every character and the real messages", {
    names <- mascot_characters()$name
    for (fn in all_pages) {
      site <- knit_for_website(fn)
      expect_match(site, "Try it live", fixed = TRUE, info = fn)
      expect_match(site, sprintf('mascot::mascot_studio(fn = "%s")', fn), fixed = TRUE, info = fn)
      expect_match(site, "Warnings, errors and common mistakes", fixed = TRUE, info = fn)
      # Some calls only work and say nothing; the page then says so.
      expect_match(site, "Error:|Warning:|Message:|No R warning or error|takes no arguments", info = fn)
      expect_false(grepl("shiny-html-output|shiny-text-output|data-event=", site), info = fn)
    }
    # Calls that do go wrong give the reader the real messages.
    for (fn in c("mascot_theme", "update_mascot", "mascot_size", "mascot_placement", "mascot_moods")) {
      expect_match(knit_for_website(fn), "Error:|Warning:", info = fn)
    }
    for (fn in tabbed_pages) {
      site <- knit_for_website(fn)
      expect_match(site, 'class="nav nav-tabs"', fixed = TRUE, info = fn)
      for (name in names) {
        expect_match(site, paste0(">", name, "</button>"), fixed = TRUE, info = paste(fn, name))
      }
    }
  })
  it("shows every character of the listing on the website, with each character's own data", {
    site <- knit_for_website("mascot_moods")
    for (id in mascot_characters()$id) {
      expect_match(site, paste0('id="guide-character-1-', id, '"'), fixed = TRUE)
      for (mood in mascot_moods(id)$name) {
        expect_match(site, paste0("<td>", mood, "</td>"), fixed = TRUE, info = paste(id, mood))
      }
    }
  })
  it("leaves the studio's pages as they were: no tabs, no live box, no second mistakes section", {
    env <- studio_guide_env()
    for (fn in all_pages) {
      html <- page_html(env$studio_guide_page(fn, "tessa", guide_dir()))
      expect_false(grepl("nav-tabs|Try it live|Warnings, errors and common mistakes", html), info = fn)
      selected <- as.character(env$selected_guide(fn, "tessa"))
      expect_identical(
        lengths(regmatches(selected, gregexpr("Warnings, errors and common mistakes", selected, fixed = TRUE))),
        1L,
        info = fn
      )
    }
    expect_match(
      page_html(env$studio_guide_page("mascot_moods", "sela", guide_dir())),
      "Sela's [0-9]+ moods",
      perl = TRUE
    )
  })
  it("gives the studio and the website the same calls and the same messages", {
    env <- studio_guide_env()
    for (fn in c("mascot_theme", "update_mascot", "mascot_size")) {
      cases <- env$guide_mistake_cases(fn, "tessa")
      expect_gt(length(cases), 0L)
      studio <- as.character(env$guide_mistakes(fn, "tessa"))
      website <- as.character(env$guide_mistakes_html(fn, "tessa"))
      for (case in cases) {
        expect_match(studio, htmltools::htmlEscape(case$code), fixed = TRUE, info = fn)
        expect_match(website, htmltools::htmlEscape(case$code), fixed = TRUE, info = fn)
        for (message in case$messages) {
          expect_match(website, htmltools::htmlEscape(message), fixed = TRUE, info = fn)
        }
      }
    }
    # The studio's own names point to the shared code.
    expect_identical(env$mistakes, env$guide_mistake_base)
    expect_identical(env$character_mistakes("sela"), env$guide_character_mistakes("sela"))
    expect_error(env$guide_mistake_cases(1, "tessa"), "string")
    expect_error(env$guide_mistakes_html("mascot", 1), "string")
  })
  it("draws per-character content as the studio always did, and as tabs on the website", {
    helpers <- new.env(parent = globalenv())
    helpers$guide_dir <- guide_dir()
    sys.source(file.path(guide_dir(), "guide-helpers.R"), helpers)
    helpers$studio_character <- "sela"
    render <- function(id) htmltools::tags$p(id)
    helpers$in_studio <- function() TRUE
    expect_identical(as.character(helpers$guide_each_character(render)), "<p>sela</p>")
    helpers$in_studio <- function() FALSE
    first <- as.character(helpers$guide_each_character(render))
    second <- as.character(helpers$guide_each_character(render))
    expect_match(first, 'id="guide-character-1-sela"', fixed = TRUE)
    expect_match(second, 'id="guide-character-2-sela"', fixed = TRUE)
    expect_identical(lengths(regmatches(first, gregexpr('aria-selected="true"', first, fixed = TRUE))), 1L)
    expect_match(first, 'role="tabpanel"', fixed = TRUE)
    expect_error(helpers$guide_each_character("no"), "function")
    expect_error(helpers$guide_each_character(render, id = 1), "string")
    expect_error(helpers$guide_try_live(1), "string")
    expect_error(helpers$guide_heading(1), "string")
    expect_output(helpers$guide_heading("Studio title", "Site title"), "### Site title")
    helpers$in_studio <- function() TRUE
    expect_output(helpers$guide_heading("Studio title", "Site title"), "### Studio title")
  })
  it("marks the bslib mapping as experimental in the words of the help page", {
    env <- studio_guide_env()
    note <- as.character(env$studio_bslib_experimental())
    expect_match(note, "badge text-bg-warning", fixed = TRUE)
    expect_match(note, "Experimental", fixed = TRUE)
    help <- paste(
      as.character(env$help_page("mascot_theme")$description),
      as.character(env$help_page("mascot_theme")$details)
    )
    if (grepl("Which parts of a character", help, fixed = TRUE)) {
      expect_match(note, "may change in a later release", fixed = TRUE)
    }
  })
  it("says so in the guide, and warns, when a page cannot be built", {
    env <- studio_guide_env()
    dir <- withr::local_tempdir()
    file.copy(list.files(guide_dir(), full.names = TRUE), dir)
    writeLines(c("```{r}", "stop('broken page')", "```"), file.path(dir, "mascot_status.Rmd"))
    suppressMessages(expect_warning(
      page <- env$studio_guide_page("mascot_status", "tessa", dir),
      "could not be built"
    ))
    html <- page_html(page)
    expect_match(html, "This guide page could not be built.", fixed = TRUE)
    expect_match(html, "broken page", fixed = TRUE)
    # A guide never shows a page of an older builder: those functions are gone from the studio.
    expect_false(exists("visual_status", envir = env, inherits = FALSE))
    expect_false(exists("visual_needs_knitr", envir = env, inherits = FALSE))
  })
  it("does not repeat the description of the help page", {
    env <- studio_guide_env()
    for (fn in c("mascot_status", "mascot_theme", batch_pages, data_pages, interactive_pages, names(new_pages))) {
      # The experimental note quotes the help page at run time (studio_bslib_experimental()); that is not a copy.
      page <- gsub(
        '(?s)<div class="pg-note">\\s*<span class="badge text-bg-warning">.*?</div>',
        "",
        page_html(env$studio_guide_page(fn, "tessa", guide_dir())),
        perl = TRUE
      )
      text <- env$html_text(page)
      description <- env$html_text(env$help_page(fn)$description)
      sentences <- trimws(strsplit(description, "(?<=[.!?])\\s+", perl = TRUE)[[1]])
      sentences <- sentences[nchar(sentences) >= 30]
      expect_gt(length(sentences), 0L)
      for (sentence in sentences) {
        expect_false(grepl(sentence, text, fixed = TRUE), info = paste(fn, sentence))
      }
    }
  })
  it("starts every page with a setup chunk that sets studio_character", {
    pages <- list.files(guide_dir(), pattern = "^[^_].*[.]Rmd$", full.names = TRUE)
    expect_gte(length(pages), 2L)
    for (page in pages) {
      lines <- readLines(page, warn = FALSE)
      expect_match(lines[[1]], "^```\\{r setup", info = page)
      expect_true(
        any(
          lines ==
            'studio_character <- if (exists("studio_character")) studio_character else formals(mascot::mascot)$character'
        ),
        info = page
      )
    }
  })
  it("loads its helpers without the studio and draws the diagrams with their stylesheet", {
    skip_if_not_installed("knitr")
    helpers <- new.env()
    helpers$guide_dir <- guide_dir()
    sys.source(file.path(guide_dir(), "guide-helpers.R"), envir = helpers)
    expect_false(helpers$in_studio())
    flow <- helpers$guide_flow(
      helpers$guide_step("a"),
      helpers$guide_step("b"),
      helpers$guide_gap(),
      helpers$guide_step("c")
    )
    html <- as.character(flow)
    expect_identical(lengths(regmatches(html, gregexpr("pg-flow-arrow", html, fixed = TRUE))), 1L)
    expect_match(as.character(helpers$guide_callout("x", warn = TRUE)), "pg-callout pg-callout-warn", fixed = TRUE)
    expect_match(as.character(helpers$guide_timeline("shown", "hides")), "<span>hides</span>", fixed = TRUE)
    expect_match(
      as.character(helpers$guide_table(data.frame(a = 1), wrap = "pg-palette-table")),
      "<td>1</td>",
      fixed = TRUE
    )
    for (piece in list(
      flow,
      helpers$guide_callout("x"),
      helpers$guide_timeline("a"),
      helpers$guide_table(data.frame(a = 1))
    )) {
      dependency <- htmltools::findDependencies(piece)[[1]]
      expect_identical(dependency$name, "mascot-guide")
      expect_true(file.exists(file.path(dependency$src$file, dependency$stylesheet)))
    }
    expect_identical(
      helpers$guide_brand_roles("tessa")$primary,
      mascot_colour_roles("tessa")$role[grepl("primary", mascot_colour_roles("tessa")$brand)][[1]]
    )
    expect_error(helpers$guide_callout("x", warn = "yes"), "flag")
    expect_error(helpers$guide_flow(arrow = 1), "string")
    expect_error(helpers$guide_table(1), "data.frame")
    expect_error(helpers$guide_gesture_cards(1), "data.frame")
    expect_error(helpers$guide_gesture_cards(data.frame(name = "wave")), "subset")
    expect_error(helpers$guide_dependency(file.path(tempdir(), "no-such-folder")), "exist")
  })
  it("knits on its own as a child of another document, with the live demos hidden", {
    skip_if_not_installed("knitr")
    skip_if_not_installed("bslib")
    for (page in c("mascot_status", "mascot_theme", batch_pages, data_pages, interactive_pages)) {
      dir <- withr::local_tempdir()
      stub <- file.path(dir, "stub.Rmd")
      writeLines(
        c(
          "```{r setup, include = FALSE}",
          sprintf("guide_dir <- '%s'", guide_dir()),
          "source(file.path(guide_dir, 'guide-helpers.R'))",
          "```",
          "",
          sprintf("```{r, child = '%s'}", file.path(guide_dir(), paste0(page, ".Rmd"))),
          "```"
        ),
        stub
      )
      output <- knitr::knit(stub, file.path(dir, "stub.md"), envir = new.env(parent = globalenv()), quiet = TRUE)
      text <- without_site_extras(paste(readLines(output, warn = FALSE), collapse = "\n"))
      expect_match(text, "###", fixed = TRUE, info = page)
      expect_false(grepl('id="palette_swap_demo"', text, fixed = TRUE), info = page)
      expect_false(grepl("data-event|shiny-html-output|shiny-text-output", text), info = page)
      expect_false(grepl("studio", text, ignore.case = TRUE), info = page)
    }
  })
})

describe("each studio control's update, generated code and default", {
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
      palette = row(
        list(list(palette = "coral_navy")),
        "theme",
        'theme = "coral_navy"',
        wait = 300,
        sent = function(p) {
          identical(p$theme$palette, "coral_navy")
        }
      ),
      mood = row(list(list(mood = "happy")), "mood", 'mood = "happy"', sent = function(p) identical(p$mood, "happy")),
      status_text = row(
        list(list(status_text = "Saving")),
        "status",
        'status = "Saving"',
        wait = 700,
        sent = function(p) identical(p$status$text, "Saving")
      ),
      bubble_text = row(
        show(bubble_text = "Hi there"),
        "bubble",
        'mascot_bubble("Hi there", duration = 8)',
        sent = function(p) identical(p$bubble$text, "Hi there") && identical(p$bubble$duration, 8)
      ),
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
      gesture = row(list(list(gesture = "wave")), "gesture", 'gesture = "wave"', ui = FALSE, sent = function(p) {
        identical(p$gesture, "wave")
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
        list(list(theme_source = "mascot", `colours-light_body` = "#1f6feb", theme_mode = "dark")),
        "theme",
        'mode = "dark"',
        wait = 400,
        sent = function(p) identical(p$theme$mode, "dark")
      ),
      light_body = row(
        list(list(theme_source = "mascot", `colours-light_body` = "#1f6feb")),
        "theme",
        'light = list(body = "#1f6feb")',
        wait = 400,
        sent = function(p) identical(tolower(p$theme$light$body), "#1f6feb")
      ),
      dark_body = row(
        list(list(theme_source = "mascot", `colours-dark_body` = "#9ec5fe")),
        "theme",
        'dark = list(body = "#9ec5fe")',
        wait = 400,
        sent = function(p) identical(tolower(p$theme$dark$body), "#9ec5fe")
      ),
      css_roles = row(
        list(list(theme_source = "mascot", `colours-css_roles` = "body")),
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
      menu_disabled = row(
        list(list(menu_on = TRUE, menu_items = "help = Help", menu_disabled = TRUE)),
        "click",
        "disabled = TRUE",
        wait = 700,
        sent = function(p) isTRUE(p$click$disabled)
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
      bubble_example = "fills the bubble controls; tested with Show bubble (#249)",
      mistake = "demonstrates invalid calls, which change nothing",
      mistake_run = "demonstrates invalid calls, which change nothing",
      task_run = "demonstrates the session argument with a timed task",
      preview_width = "the width the preview page is shown at, not an argument",
      example_name = "the Examples view, not the mascot",
      list_family = "filters the listings view (mascot_characters(family =)), not the mascot",
      example_run = "the Examples view, not the mascot"
    )
    controls <- unlist(get("studio_controls", parts$env))
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
        updates <- function() session$userData$mascot_protocol$states[[session$ns("helper")]]
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
    # The bubble controls follow the welcome demonstration without an editor-open round trip.
    start_bubble <- eval(env$start$bubble$helper)
    start_menu <- eval(env$start$click$helper)$items
    expected <- list(
      status_text = "", # status = NULL follows the mood
      bubble_text = as.character(start_bubble$text),
      bubble_duration = start_bubble$duration,
      bubble_forever = is.infinite(start_bubble$duration),
      bubble_closable = start_bubble$closable,
      bubble_html = isTRUE(start_bubble$html),
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
      menu_disabled = defaults_of("mascot_popup_menu")$disabled,
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

describe("studio phone overlays", {
  it("uses an opaque floating inspector and a bottom sheet on narrow screens", {
    css <- paste(readLines(system.file("examples", "studio", "www", "studio.css", package = "mascot")), collapse = "\n")
    expect_match(css, "background: var(--studio-panel)", fixed = TRUE)
    expect_match(css, "@media (max-width: 860px)", fixed = TRUE)
    expect_match(css, "min(76dvh", fixed = TRUE)
    expect_match(css, ".pg-inspector-shell", fixed = TRUE)
  })
})

describe("studio code builders with a CSS map", {
  it("writes each role's own CSS variable, and the value of each variable the app sets", {
    code <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "code.R"), envir = code)
    css <- c(body = "--brand", rim = "--brand-light")
    theme <- code$code_theme("mascot", c(body = "#1f6feb"), NULL, "auto", css, NULL, NULL)
    expect_identical(eval(theme$helper), mascot_theme(light = list(body = "#1f6feb"), css = as.list(css)))
    # A CSS source never becomes the plain-list shortcut, which has no css.
    expect_identical(theme$short, theme$helper)
    expect_null(eval(code$code_theme("mascot", c(body = "#1f6feb"), NULL, "auto", NULL, NULL, NULL)$helper)$css)
    expect_error(code$code_theme("mascot", NULL, NULL, "auto", "--brand", NULL, NULL), "names\\(css\\)")
    expect_error(code$code_theme("mascot", NULL, NULL, "auto", c(body = ""), NULL, NULL), "css")
    app <- code$whole_app_code(
      'mascot("helper")',
      NULL,
      c("shiny", "mascot"),
      c(`--brand` = "#111111", `--brand-light` = "#222222")
    )
    expect_match(app, 'tags$style(":root { --brand: #111111; --brand-light: #222222; }"),', fixed = TRUE)
    expect_type(parse(text = app), "expression")
    for (none in list(NULL, stats::setNames(character(), character()))) {
      expect_false(grepl("tags$style", code$whole_app_code('mascot("helper")', NULL, "mascot", none), fixed = TRUE))
    }
    expect_error(code$whole_app_code('mascot("helper")', NULL, "mascot", "#111111"), "names\\(css_values\\)")
  })
  it("writes the studio's accent variable and that variable's value into the generated code", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(theme_source = "mascot", `colours-css_roles` = "body", `colours-css_value` = "#663399")
      session$elapse(400)
      expect_match(output$code_ui, 'css = list(body = "--studio-accent")', fixed = TRUE)
      expect_match(output$code_app, 'tags$style(":root { --studio-accent: #663399; }"),', fixed = TRUE)
      session$setInputs(`colours-css_roles` = character())
      session$elapse(400)
      expect_false(grepl("tags$style", output$code_app, fixed = TRUE))
    })
  })
})

describe("studio shared tokens and inputs", {
  it("loads the shared tokens and inputs before the studio's own files", {
    page <- studio_parts()$page
    at <- function(file) regexpr(paste0('"', file, '"'), page, fixed = TRUE)[[1]]
    for (file in c("tokens.css", "shared.css", "studio.css", "inputs.js", "studio.js")) {
      expect_gt(at(file), 0)
    }
    expect_lt(at("tokens.css"), at("shared.css"))
    expect_lt(at("shared.css"), at("studio.css"))
    expect_lt(at("inputs.js"), at("studio.js"))
  })
  it("keeps the colour and spacing tokens in one file", {
    www <- file.path(dirname(mascot_example("studio", run = FALSE)), "www")
    read <- function(file) paste(readLines(file.path(www, file), warn = FALSE), collapse = "\n")
    tokens <- read("tokens.css")
    studio <- read("studio.css")
    for (token in c("--studio-accent", "--studio-panel", "--studio-ink", "--studio-primary", "--studio-shadow")) {
      expect_match(tokens, paste0(token, ":"), fixed = TRUE, info = token)
      expect_false(grepl(paste0(token, ":"), studio, fixed = TRUE), info = token)
    }
    expect_false(grepl("body:has(.pg-studio)", tokens, fixed = TRUE))
  })
})

describe("studio bubble controls", {
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
  it("explains beside the menu direction that the mascot looks towards its menu and bubble", {
    page <- studio_parts()$page
    note <- regexpr("the mascot looks towards the side the menu opened on", page, fixed = TRUE)[[1]]
    expect_gt(note, regexpr('id="menu_direction"', page, fixed = TRUE)[[1]])
    expect_match(page, "It also looks towards a bubble.", fixed = TRUE)
  })
  it("shows action clicks live and answers an action with a wave", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    expect_match(parts$page, 'id="click_last"', fixed = TRUE)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      expect_match(output$click_last, "Nothing yet", fixed = TRUE)
      updates <- function() session$userData$mascot_protocol$states[[session$ns("helper")]]
      # Turning the action on sends it, and the switches take turns.
      session$setInputs(action_on = TRUE)
      session$elapse(700)
      expect_identical(updates()$desired$click$type, "action")
      expect_identical(updates()$desired$click$label, "Open help")
      expect_match(output$code_app, "observeEvent(input$helper_click", fixed = TRUE)
      session$setInputs(helper_click = 1)
      expect_identical(output$click_last, "1 click")
      expect_match(last_call(), 'gesture = "wave"', fixed = TRUE)
      # The log is newest first: the click event, then the studio's wave in answer.
      expect_identical(log()[[2]]$code, "input$helper_click  # 1")
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

describe("studio UI call and contrast warnings", {
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
})

describe("studio listings (character data)", {
  it("reads brand slots, characters and families from the public listings", {
    env <- new.env()
    # The brand slots and families are the studio's data; the characters, the app's shared data.
    for (file in c("data.R", "shared-data.R")) {
      sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", file), env)
    }
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
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "shared-data.R"), env)
    expect_identical(unname(env$studio_characters()), c("tessa", "sela", "knurl", "neer"))
  })
})

describe("studio isolated host", {
  it("ships local engine scripts in the frame and accepts its real mount token", {
    parts <- studio_parts()
    initial <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, initial)
      expect_match(output$live_host$html, 'id="live_frame"', fixed = TRUE)
      page <- paste(readLines(file.path(preview_dir, "live.html"), warn = FALSE), collapse = "\n")
      expect_match(page, 'data-studio-host="true"', fixed = TRUE)
      expect_match(page, 'id="helper"', fixed = TRUE)
      expect_match(page, 'role="status"', fixed = TRUE)
      expect_match(page, 'name="viewport"', fixed = TRUE)
      expect_lt(regexpr("/studio.js", page, fixed = TRUE)[[1]], regexpr("mascot-host.js", page, fixed = TRUE)[[1]])
      # The frame's page colours come from the shared tokens.
      expect_lt(regexpr("/tokens.css", page, fixed = TRUE)[[1]], regexpr("/studio.css", page, fixed = TRUE)[[1]])
      expect_gt(regexpr("/tokens.css", page, fixed = TRUE)[[1]], 0)
      expect_false(grepl("shiny.min.js", page, fixed = TRUE))
      token <- regmatches(page, regexec('data-mount-token="([^"]+)"', page))[[1]][[2]]
      fixture <- list(session = session, id = "helper")
      protocol_ready(fixture, token = token, lifecycle = "reconcile")
      session$flushReact()
      expect_true(protocol_record(fixture)$live)
      expect_identical(protocol_record(fixture)$mount_token, token)
    })
  })
})

describe("studio palette controls", {
  it("offers each character's choices and builds shortcuts and override helpers", {
    parts <- studio_parts()
    for (id in builtin_characters()$id) {
      bar <- as.character(get("panel_character_bar", parts$env)(character = id))
      for (input in c("character", "palette", "mood", "gesture")) {
        expect_match(bar, paste0('<select[^>]*id="', input, '"'))
      }
      # The character's own colours always carry the value "original", whatever name they are listed under.
      for (palette in c("original", mascot_palettes(id)$name[-1L])) {
        expect_match(bar, paste0('value="', palette, '"'), fixed = TRUE)
      }
      expect_match(
        tolower(bar),
        paste0(">", tolower(get("studio_palette_sentence", parts$env)(id)$label), "</option>"),
        fixed = TRUE
      )
      expect_match(bar, 'id="gesture_play"', fixed = TRUE)
      expect_false(grepl("try_mood", bar, fixed = TRUE))
    }
    table <- get("roles_table", parts$env)
    expect_match(as.character(table("tessa", "coral_navy")), "#FFE5D9", fixed = TRUE)
    expect_error(table(1), "character")
    expect_error(table("tessa", 1), "palette")
    builder <- get("code_theme", parts$env)
    valid <- list(
      source = "own",
      light = NULL,
      dark = NULL,
      mode = "auto",
      css = NULL,
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
    value <- builder("own", NULL, NULL, "dark", NULL, "", "", palette = "orbit")
    expect_identical(value$short, quote(mascot_theme(palette = "orbit", mode = "dark")))
    expect_identical(value$helper, value$short)
    value <- builder("mascot", c(body = "#123456"), c(body = "#123456"), "auto", NULL, "", "", palette = "orbit")
    expect_identical(eval(value$short)$palette, "orbit")
    expect_identical(eval(value$short)$light$body, "#123456")
    value <- builder("mascot", c(body = "#123456"), NULL, "dark", NULL, "", "", palette = "orbit")
    expect_identical(eval(value$helper), mascot_theme(palette = "orbit", light = list(body = "#123456"), mode = "dark"))
    expect_identical(
      builder("bslib", NULL, NULL, "auto", NULL, "blue", "orange", palette = "orbit")$short,
      quote(bslib::bs_theme(primary = "blue", secondary = "orange"))
    )
  })
  it("shows colour-role argument controls and clears the palette in the low-contrast demonstration", {
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
      session$setInputs(palette = "coral_navy")
      session$elapse(301)
      session$setInputs(mistake = "Low contrast", mistake_run = 1)
      # A plain list replaces the whole theme, so the drawing has no palette: the code must say the same.
      expect_null(eval(state$theme$short)$palette)
      expect_false(grepl("coral_navy", output$code_ui, fixed = TRUE))
      expect_match(output$code_ui, 'theme = list(outline = "#f8f9fa")', fixed = TRUE)
    })
  })
  it("keeps palette selection, theme sources, previews, resets and live anchor listings in step", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      messages <- list()
      session$sendInputMessage <- function(id, message) messages[[id]] <<- message
      custom <- session$sendCustomMessage
      anchors <- NULL
      session$sendCustomMessage <- function(type, message) {
        if (identical(type, "studio:anchors")) {
          anchors <<- message
        }
        custom(type, message)
      }
      do.call(session$setInputs, start)
      studio_go_live(session)
      session$setInputs(palette = "coral_navy")
      session$elapse(301)
      expect_identical(roles(), mascot_colour_roles("tessa", palette = "coral_navy"))
      expect_identical(preview_args()$theme, "coral_navy")
      session$setInputs(preview_theme_source = "custom", preview_body = "#123456")
      expect_identical(eval(preview_args()$theme)$palette, "coral_navy")
      expect_identical(eval(preview_args()$theme)$light$body, "#123456")
      session$setInputs(theme_source = "bslib")
      expect_identical(messages$palette$value, "original")
      session$setInputs(palette = "original")
      session$setInputs(palette = "coral_navy")
      expect_identical(messages$theme_source$value, "own")
      session$setInputs(theme_source = "own", chip_reset = "theme")
      expect_identical(messages$palette$value, "original")
      expect_identical(messages$theme_source$value, "own")
      session$setInputs(palette = "original", mood = "happy", gesture = "nod", character = "neer")
      expect_identical(messages$mood$value, "happy")
      expect_identical(messages$gesture$value, "nod")
      expect_identical(anchors$character, "neer")
      expect_length(anchors$anchors, 14L)
      expect_identical(
        anchors$anchors,
        lapply(seq_len(nrow(mascot_anchors("neer"))), function(i) as.list(mascot_anchors("neer")[i, , drop = FALSE]))
      )
    })
  })
  it("refreshes choices, plays a selected gesture and replays it only when requested", {
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
      session$setInputs(palette = "coral_navy")
      session$elapse(301)
      expect_match(output$code_ui, 'theme = "coral_navy"', fixed = TRUE)
      session$setInputs(character = "sela")
      expect_match(output$code_ui, 'theme = "coral_navy"', fixed = TRUE)
      expect_match(messages$palette$options, 'value="coral_navy"', fixed = TRUE)
      expect_identical(messages$palette$value, "coral_navy")
      expect_match(choices$mood, 'value="happy"', fixed = TRUE)
      expect_match(choices$gesture, 'value="wave"', fixed = TRUE)
      session$setInputs(character = "knurl")
      expect_identical(messages$palette$value, "original")
      expect_false(grepl('theme = "coral_navy"', output$code_ui, fixed = TRUE))
      updates <- function() session$userData$mascot_protocol$states[[session$ns("helper")]]
      previous <- updates()$revision
      session$setInputs(gesture = "wave")
      expect_gt(updates()$revision, previous)
      expect_identical(updates()$pending$name, "wave")
      gesture_revision <- updates()$pending$revision
      session$setInputs(mood = "happy")
      expect_identical(updates()$pending$revision, gesture_revision)
      previous <- updates()$revision
      session$setInputs(gesture_play = 1)
      expect_gt(updates()$revision, previous)
      expect_gt(updates()$pending$revision, gesture_revision)
      expect_identical(updates()$pending$name, "wave")
    })
  })
})

describe("studio disabled menus", {
  it("sends a disabled menu and shows its reproducible helper call", {
    parts <- studio_parts()
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, studio_start_values(parts$page))
      studio_go_live(session)
      session$setInputs(menu_on = TRUE, menu_items = "help = Help", menu_disabled = TRUE)
      session$elapse(700)
      expect_true(eval(click_code()$helper)$disabled)
      expect_match(output$code_app, "disabled = TRUE", fixed = TRUE)
    })
  })
})

describe("studio palette sync", {
  it("maps every listed role to light, dark, CSS and generated theme overrides", {
    parts <- studio_parts()
    builder <- get("code_theme", parts$env)
    for (character in unname(get("studio_characters", parts$env)())) {
      for (palette in unname(get("studio_palette_choices", parts$env)(character))) {
        roles <- mascot_colour_roles(character, palette = palette)
        groups <- get("colour_groups", parts$env)(roles, character)
        expect_setequal(unlist(groups, use.names = FALSE), roles$role)
        expect_length(unlist(groups), nrow(roles))
        for (mode in c("light", "dark")) {
          html <- as.character(get("role_pickers", parts$env)(mode, roles, character = character))
          for (role in roles$role) {
            expect_match(html, paste0('id="', mode, "_", role, '"'), fixed = TRUE)
          }
        }
        # Arbitrary roles travel through all three override fields; no role allow-list limits them.
        overrides <- stats::setNames(rep("#123456", nrow(roles)), roles$role)
        css <- stats::setNames(rep("--studio-accent", nrow(roles)), roles$role)
        theme <- eval(builder("mascot", overrides, overrides, "auto", css, "", "", palette)$helper)
        expect_identical(unlist(theme$light), overrides)
        expect_identical(unlist(theme$dark), overrides)
        expect_setequal(names(theme$css), roles$role)
        table <- as.character(get("roles_table", parts$env)(character, palette))
        for (role in roles$role) {
          expect_match(table, paste0("<td>", role, "</td>"), fixed = TRUE)
        }
      }
    }
    choices <- get("studio_palette_choices", parts$env)("tessa")
    expect_identical(unname(choices[["night_teal"]]), "original")
    gestures <- get("studio_gesture_choices", parts$env)("tessa")
    expect_identical(tail(unname(gestures), 1L), "shimmer")
    expect_identical(tail(names(gestures), 1L), "shimmer (resting animation)")
    expect_error(get("studio_palette_labels", parts$env)(1), "character")
    expect_error(get("studio_gesture_choices", parts$env)(1), "character")
  })
  it("runs real kept and dropped palette swaps and sets the live long-status controls", {
    parts <- studio_parts()
    shiny::testServer(get("studio_server", parts$env), {
      messages <- list()
      session$sendInputMessage <- function(id, message) messages[[id]] <<- message
      do.call(session$setInputs, studio_start_values(parts$page))
      studio_go_live(session)
      # Evaluate the guide to initialise its separate drawn mascot with the public UI call.
      session$setInputs(select_function = "mascot_theme")
      expect_match(output$guide$html, "Colour precedence", fixed = TRUE)
      expect_match(output$guide$html, 'id="palette_swap_demo"', fixed = TRUE)
      protocol_ready(list(session = session, id = session$ns("palette_swap_demo")))
      session$flushReact()
      session$setInputs(palette_swap = "kept")
      expect_identical(output$palette_swap_result, "Palette coral_navy kept for Sela")
      expect_identical(
        session$userData$mascot_protocol$states[[session$ns("palette_swap_demo")]]$desired$theme$palette,
        "coral_navy"
      )
      session$setInputs(palette_swap = "dropped")
      expect_match(output$palette_swap_result, "mascot_palette_dropped:", fixed = TRUE)
      expect_match(output$palette_swap_result, "own colours are used", fixed = TRUE)
      expect_null(session$userData$mascot_protocol$states[[session$ns("palette_swap_demo")]]$desired$theme$palette)
      for (corner in c("top-right", "bottom-right")) {
        session$setInputs(menu_long_status = corner)
        expect_identical(messages$position$value, corner)
        expect_match(messages$status_text$value, "Review in progress", fixed = TRUE)
        expect_identical(eval(state$placement$helper)$position, corner)
        expect_identical(eval(state$status$helper)$text, get("studio_long_status", parts$env))
        expect_s3_class(eval(state$click$helper), "mascot_popup_menu")
      }
      session$setInputs(character = "tessa")
      expect_match(messages$palette$options, 'value="original"', fixed = TRUE)
      expect_match(messages$palette$options, ">Tessa's own colours (night_teal)</option>", fixed = TRUE)
      expect_match(messages$gesture$options, '>shimmer (resting animation)</option>', fixed = TRUE)
    })
  })
  it("uses live anchor listings including empty characters", {
    parts <- studio_parts()
    expect_true(all(c("fringe", "lock", "stud_l", "stud_r") %in% mascot_anchors("tessa")$name))
    expect_equal(nrow(mascot_anchors("neer")), 14L)
    fixture <- format_recipe("study_bot")
    fixture$anchors <- NULL
    character <- character_format_check(fixture)
    local_empty_registry()
    character_data_register(character)
    html <- paste(
      vapply(
        get("function_visual", parts$env)("mascot_anchors", character$id),
        as.character,
        character(1)
      ),
      collapse = "\n"
    )
    expect_match(html, paste(character$name, "has no anchors"), fixed = TRUE)
  })
})

describe("studio palette guide and examples", {
  it("derives borrowed and made-up ids and shows the messages from real calls", {
    parts <- studio_parts()
    withr::local_options(list(cli.width = 1000, cli.num_colors = 1))
    for (id in unname(get("studio_characters", parts$env)())) {
      palettes <- get("guide_mistake_palettes", parts$env)(id)
      expect_false(palettes$borrowed %in% mascot_palettes(id)$name)
      other_ids <- setdiff(builtin_characters()$id, id)
      other_palettes <- unlist(lapply(other_ids, function(other) mascot_palettes(other)$name))
      expect_true(palettes$borrowed %in% other_palettes)
      expect_false(palettes$invented %in% c(mascot_palettes(id)$name, other_palettes))
      mistakes <- get("character_mistakes", parts$env)(id)
      codes <- get("guide_mistake_calls", parts$env)("mascot", id)
      guide <- as.character(get("guide_mistakes", parts$env)("mascot", id))
      for (name in c("Borrow another character's palette", "A made-up palette id")) {
        code <- mistakes[[name]]$code
        expect_identical(codes[[name]], code)
        call <- str2lang(code)
        expect_identical(call[["character"]], id)
        expect_identical(call[["theme"]], if (name == "A made-up palette id") palettes$invented else palettes$borrowed)
        error <- tryCatch(eval(call, parts$env), mascot_error = identity)
        expect_s3_class(error, "mascot_error")
        message <- cli::ansi_strip(conditionMessage(error))
        expect_match(message, paste0('Unknown palette "', call[["theme"]], '" for character "', id, '"'), fixed = TRUE)
        expect_match(message, paste0('Choose "', mascot_palettes(id)$name[[1L]], '"'), fixed = TRUE)
        expect_identical(
          grepl("each palette belongs to its own character", message, fixed = TRUE),
          name != "A made-up palette id"
        )
        expect_match(guide, as.character(htmltools::htmlEscape(paste("Error:", message))), fixed = TRUE)
        expect_match(guide, as.character(htmltools::htmlEscape(mistakes[[name]]$why)), fixed = TRUE)
      }
      mock <- shiny::MockShinySession$new()
      shiny::withReactiveDomain(mock, {
        mascot("helper", character = id, theme = mascot_palettes(id)$name[[1L]])
        protocol_ready(
          list(session = mock, id = mock$ns("helper")),
          state = mascot_state_defaults(list(id = id, name = mascot_character(id)$name, json = character_json(id)))
        )
        update_mascot("helper", theme = mascot_palettes(id)$name[[2L]], session = mock)
        before <- serialize(mock$userData$mascot_protocol$states, NULL)
        env <- new.env(parent = parts$env)
        env$session <- mock
        code <- get("guide_mistake_calls", parts$env)("update_mascot", id)[["An unknown palette in an update"]]
        warning <- NULL
        withCallingHandlers(eval(str2lang(code), env), warning = function(w) {
          warning <<- w
          invokeRestart("muffleWarning")
        })
        expect_s3_class(warning, "mascot_update_ignored")
        expect_s3_class(warning, "mascot_warning")
        message <- cli::ansi_strip(conditionMessage(warning))
        expect_match(message, '`update_mascot()` left mascot "helper" unchanged.', fixed = TRUE)
        expect_match(message, paste0('Unknown palette "', palettes$borrowed, '"'), fixed = TRUE)
        expect_match(message, "each palette belongs to its own character.", fixed = TRUE)
        expect_false(inherits(warning, "mascot_palette_dropped"))
        expect_identical(serialize(mock$userData$mascot_protocol$states, NULL), before)
        guide <- as.character(get("guide_mistakes", parts$env)("update_mascot", id))
        expect_match(guide, as.character(htmltools::htmlEscape(paste("Warning:", message))), fixed = TRUE)
      })
      mock$close()
    }
    expect_error(get("guide_mistake_palettes", parts$env)(1), "character")
  })
  it("uses a swap example whose palette Tessa and Sela share and Knurl lacks", {
    parts <- studio_parts()
    example <- get("studio_palette_swap", parts$env)
    expect_true(example[["palette"]] %in% mascot_palettes(example[["from"]])$name)
    expect_true(example[["palette"]] %in% mascot_palettes(example[["kept"]])$name)
    expect_false(example[["palette"]] %in% mascot_palettes(example[["dropped"]])$name)
  })
  it("builds a palette base demo with one explicit role that wins in light mode", {
    parts <- studio_parts()
    for (id in builtin_characters()$id) {
      example <- get("studio_palette_base", parts$env)(id)
      expect_true(example$palette %in% mascot_palettes(id)$name)
      roles <- mascot_colour_roles(id, palette = example$palette)
      expect_true(example$role %in% roles$role)
      expect_identical(example$base, roles$colour[match(example$role, roles$role)])
      expect_false(tolower(example$base) == tolower(example$colour))
      html <- as.character(get("palette_base_demo", parts$env)(id))
      theme <- mascot_theme(palette = example$palette, light = stats::setNames(list(example$colour), example$role))
      expect_match(html, 'id="palette_base_demo"', fixed = TRUE)
      theme_json <- regmatches(html, regexpr('(?s)(?<=data-mascot-theme="">).*?(?=</script>)', html, perl = TRUE))
      expect_equal(jsonlite::fromJSON(theme_json, simplifyVector = FALSE), as_theme_arg(theme, environment(), id))
      expect_match(html, paste0('palette = "', example$palette, '"'), fixed = TRUE)
      expect_match(html, paste0(example$role, ' = "', example$colour, '"'), fixed = TRUE)
      # The wire keeps the palette base separate from the explicit role; the host applies explicit roles last.
      wire <- as_theme_arg(theme, environment(), id)
      expect_identical(tolower(wire$light[[example$role]]), example$colour)
      expect_false(
        tolower(
          if (is.null(wire$palette_colours$light[[example$role]])) {
            example$base
          } else {
            wire$palette_colours$light[[example$role]]
          }
        ) ==
          example$colour
      )
    }
    expect_error(get("studio_palette_base", parts$env)(1), "character")
    expect_error(get("palette_base_demo", parts$env)(1), "character")
  })
  it("lists the palette mistakes under mascot_theme() as well as mascot() and update_mascot()", {
    parts <- studio_parts()
    for (id in builtin_characters()$id) {
      cases <- get("guide_mistake_calls", parts$env)("mascot_theme", id)
      expect_true(any(grepl("not-a-colour", cases, fixed = TRUE)))
      expect_true(all(
        c("Borrow another character's palette", "A made-up palette id", "An unknown palette in an update") %in%
          names(cases)
      ))
    }
  })
  it("shows the dark-mode outline tip with a live default and custom example and points to it from the roles table", {
    parts <- studio_parts()
    for (id in builtin_characters()$id) {
      html <- as.character(get("dark_outline_demo", parts$env)(id))
      expect_match(html, 'id="dark_outline_tip"', fixed = TRUE)
      tip <- get("studio_help_tail", parts$env)(
        get("help_arg", parts$env)("mascot_theme", "dark"),
        "Built-in characters keep one outline colour"
      )
      expect_match(tip, "to use your own dark-mode outline", ignore.case = TRUE)
      expect_match(html, tip, fixed = TRUE)
      expect_match(html, "mascot_theme(dark = list(outline = \"#FFC93C\"))", fixed = TRUE)
      expect_match(html, 'id="dark_outline_default"', fixed = TRUE)
      expect_match(html, 'id="dark_outline_custom"', fixed = TRUE)
      themes <- regmatches(html, gregexpr('(?s)(?<=data-mascot-theme="">).*?(?=</script>)', html, perl = TRUE))[[1]]
      expect_length(themes, 2L)
      custom <- jsonlite::fromJSON(themes[[2]], simplifyVector = FALSE)
      expect_identical(custom$mode, "dark")
      expect_true(any(tolower(unlist(custom$dark)) == "#ffc93c"))
      roles <- as.character(get("roles_table", parts$env)(id))
      expect_match(roles, 'data-value="mascot_theme"', fixed = TRUE)
      expect_match(roles, "Dark-mode outline tip", fixed = TRUE)
    }
    expect_error(get("dark_outline_demo", parts$env)(1), "character")
    expect_null(get("studio_help_tail", parts$env)("No such text.", "Built-in"))
    expect_error(get("studio_help_tail", parts$env)("text", 1), "string")
  })
  it("names native colours exactly and keeps the original API value and generated code", {
    parts <- studio_parts()
    sentence <- get("studio_palette_sentence", parts$env)
    expect_identical(sentence("tessa")$label, "Tessa's own colours (night_teal)")
    expect_identical(sentence("sela")$label, "Sela's own colours (lilac_violet)")
    # A character without a native palette name reads without one.
    expect_identical(sentence("knurl")$label, "Knurl's own colours")
    expect_identical(sentence("tessa")$prefix, "in")
    expect_identical(sentence("tessa")$suffix, ",")
    expect_identical(sentence("tessa")$id, "night_teal")
    expect_identical(sentence("tessa", "sea_green")$prefix, "in the")
    expect_identical(sentence("tessa", "sea_green")$suffix, "palette,")
    expect_identical(sentence("tessa", "sea_green")$id, "sea_green")
    bar <- as.character(get("panel_character_bar", parts$env)(character = "tessa"))
    expect_match(bar, 'title="night_teal"', fixed = TRUE)
    expect_match(bar, 'title="sea_green"', fixed = TRUE)
    expect_match(bar, 'value="original"[^>]*selected')
    expect_identical(
      get("code_theme", parts$env)("own", NULL, NULL, "auto", NULL, "", "", "original")$helper,
      quote(mascot_theme())
    )
    expect_error(sentence(1), "character")
    expect_error(sentence("tessa", 1), "palette")
    shiny::testServer(get("studio_server", parts$env), {
      messages <- list()
      session$sendCustomMessage <- function(type, message) messages[[type]] <<- message
      do.call(session$setInputs, studio_start_values(parts$page))
      studio_go_live(session)
      session$setInputs(character = "sela")
      expect_identical(messages[["studio:palette"]]$label, "Sela's own colours (lilac_violet)")
      session$setInputs(character = "tessa", palette = "sea_green")
      expect_identical(messages[["studio:palette"]]$id, "sea_green")
      session$setInputs(palette = "original")
      expect_identical(messages[["studio:palette"]]$label, "Tessa's own colours (night_teal)")
      expect_identical(selected_palette(), "original")
    })
  })
})

describe("studio colour inputs, demonstration labels and guide notes", {
  it("gives a translucent colour role a text box, so it is never sent as a solid override", {
    parts <- studio_parts()
    for (id in c("knurl", "neer")) {
      roles <- mascot_colour_roles(id)
      alpha <- roles$role[!grepl("^#[0-9a-fA-F]{6}$", roles$colour)]
      expect_gt(length(alpha), 0L)
      for (role in alpha) {
        html <- as.character(get("role_picker", parts$env)("light", role, roles))
        expect_match(html, 'type="text"', fixed = TRUE, info = paste(id, role))
        expect_false(grepl('type="color"', html, fixed = TRUE), info = paste(id, role))
      }
    }
    expect_match(as.character(get("colour_input", parts$env)("x", "#112233", "label")), 'type="color"', fixed = TRUE)
    expect_error(get("colour_input", parts$env)("x", 1, "label"), "string")
    start <- studio_start_values(parts$page)
    for (who in c("knurl", "neer")) {
      shiny::testServer(get("studio_server", parts$env), {
        do.call(session$setInputs, start)
        studio_go_live(session)
        session$setInputs(character = who)
        session$elapse(400)
        roles <- mascot_colour_roles(who)
        # What the browser reports for untouched pickers: each role's listed colour.
        untouched <- stats::setNames(as.list(roles$colour), paste0("colours-light_", roles$role))
        do.call(session$setInputs, c(list(theme_source = "mascot"), untouched))
        session$elapse(400)
        expect_false(grepl("theme =", output$code_ui, fixed = TRUE), info = who)
        sent <- session$userData$mascot_protocol$states[[session$ns("helper")]]$desired$theme
        expect_length(sent$light, 0L)
      })
    }
  })
  it("does not send the previous character's colours to the new one when the character changes", {
    parts <- studio_parts()
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      tessa <- mascot_colour_roles("tessa")
      untouched <- stats::setNames(as.list(tessa$colour), paste0("colours-light_", tessa$role))
      do.call(session$setInputs, c(list(theme_source = "mascot"), untouched))
      session$elapse(400)
      session$setInputs(character = "sela")
      sent <- session$userData$mascot_protocol$states[[session$ns("helper")]]$desired$theme
      expect_length(sent$light, 0L)
      # A colour the user did change is carried over, for a role Sela has too.
      shared <- intersect(tessa$role, mascot_colour_roles("sela")$role)[[1L]]
      session$setInputs(character = "tessa")
      session$elapse(400)
      do.call(session$setInputs, stats::setNames(list("#123456"), paste0("colours-light_", shared)))
      session$setInputs(character = "sela")
      carried <- session$userData$mascot_protocol$states[[session$ns("helper")]]$desired$theme
      expect_identical(tolower(unlist(carried$light)[[1L]]), "#123456")
    })
  })
  it("marks the welcome bubble and menu as the studio's demonstration and names the button for what it copies", {
    parts <- studio_parts()
    expect_match(parts$page, "Copy your settings", fixed = TRUE)
    expect_false(grepl("Copy R code", parts$page, fixed = TRUE))
    expect_match(parts$page, "Shortcuts are plain values", fixed = TRUE)
    state <- list(
      bubble = get("code_pair", parts$env)(quote(mascot_bubble())),
      click = get("code_pair", parts$env)(quote(mascot_action()))
    )
    chips <- as.character(get("call_chips", parts$env)(state, "short", demo = c("bubble", "click")))
    expect_identical(lengths(regmatches(chips, gregexpr('data-call-demo="true"', chips, fixed = TRUE))), 2L)
    expect_match(chips, "studio demo, not copied", fixed = TRUE)
    plain <- as.character(get("call_chips", parts$env)(state, "short"))
    expect_false(grepl("data-call-demo", plain, fixed = TRUE))
    expect_error(get("call_chips", parts$env)(state, "short", demo = 1), "character")
    start <- studio_start_values(parts$page)
    shiny::testServer(get("studio_server", parts$env), {
      do.call(session$setInputs, start)
      studio_go_live(session)
      # At the start the call bar shows the welcome bubble and menu; the copied code leaves them out.
      expect_identical(
        lengths(regmatches(
          output$live_call$html,
          gregexpr('data-call-demo="true"', output$live_call$html, fixed = TRUE)
        )),
        2L
      )
      expect_false(grepl("bubble =", output$code_ui, fixed = TRUE))
    })
  })
  it("shows a warning for the unknown-mood mistake and lists every documented condition class", {
    parts <- studio_parts()
    for (id in mascot_characters()$id) {
      cases <- get("guide_mistake_cases", parts$env)("update_mascot", id)
      mood <- Filter(function(case) grepl("sleepy", case$code, fixed = TRUE), cases)[[1L]]
      expect_true(any(grepl("^Warning:", mood$messages)), info = id)
    }
    guide <- paste(
      readLines(file.path(dirname(mascot_example("studio", run = FALSE)), "guide", "update_mascot.Rmd")),
      collapse = "\n"
    )
    for (class in c(
      "mascot_error",
      "mascot_warning",
      "mascot_message",
      "mascot_update_ignored",
      "mascot_error_choice",
      "mascot_error_dots",
      "mascot_error_argument",
      "mascot_error_character",
      "mascot_error_file",
      "mascot_contrast",
      "mascot_placement_ignored",
      "mascot_palette_dropped",
      "mascot_gesture_dropped",
      "mascot_template_evicted"
    )) {
      expect_match(guide, class, fixed = TRUE)
    }
  })
  it("says so in the bslib flow when a character has no brand parts", {
    env <- studio_guide_env()
    expect_length(env$studio_brand("neer"), 0L)
    page <- paste(
      vapply(
        env$studio_guide_page(
          "mascot_theme",
          "neer",
          file.path(dirname(mascot_example("studio", run = FALSE)), "guide")
        ),
        as.character,
        character(1)
      ),
      collapse = "\n"
    )
    expect_match(page, "has no colours that bslib", fixed = TRUE)
  })
})

describe("experimental labels in the studio", {
  it("shows the help pages' own Experimental sections beside the functions and controls they name", {
    parts <- studio_parts()
    env <- parts$env
    notes <- function(fn, title = NULL) {
      paste(vapply(get("studio_experimental_notes", env)(fn, title), as.character, ""), collapse = "")
    }
    for (fn in c(
      "mascot_preview",
      "mascot_studio",
      "mascot_theme",
      "mascot_placement",
      "mascot_characters",
      "mascot_read_character",
      "mascot_check_character"
    )) {
      expect_match(notes(fn), "badge text-bg-warning", fixed = TRUE, info = fn)
      card <- as.character(get("function_card", env)(fn))
      expect_match(card, "pg-experimental", fixed = TRUE, info = fn)
    }
    # Words come from the help page, not from the studio
    expect_match(notes("mascot_preview"), "may change in a later release", fixed = TRUE)
    expect_match(notes("mascot_placement", "free dragging"), "free", fixed = TRUE)
    expect_match(notes("mascot_theme", "CSS source"), "R cannot check", fixed = TRUE)
    expect_false(grepl("R cannot check", notes("mascot_theme", "colour mapping"), fixed = TRUE))
    expect_length(get("studio_experimental_notes", env)("mascot_mood"), 0L)
    expect_false(grepl("pg-experimental", as.character(get("function_card", env)("mascot_mood")), fixed = TRUE))
    expect_error(get("studio_experimental_notes", env)(1), "string")
    expect_error(get("studio_experimental_notes", env)("mascot_theme", 1), "string")
  })
  it("marks free dragging where it is chosen, with the help page's words", {
    page <- as.character(studio_parts()$page)
    expect_match(page, "Free (experimental)", fixed = TRUE)
    expect_match(page, "is experimental: the position it reports", fixed = TRUE)
  })
})

describe("the studio public character readers", {
  it("lists read and check without enabling the authoring panel", {
    dir <- dirname(mascot_example("studio", run = FALSE))
    guide <- new.env()
    sys.source(file.path(dir, "R", "guide.R"), guide)
    sys.source(file.path(dir, "R", "data.R"), guide)
    sys.source(file.path(dir, "R", "code.R"), guide)
    expect_s3_class(eval(guide$code_read_character()), "mascot_character_data")
    expect_s3_class(eval(guide$code_check_character()), "mascot_character_data")
    for (fn in c("mascot_read_character", "mascot_check_character")) {
      expect_s3_class(eval(parse(text = guide$format_call(fn, list()))), "mascot_character_data")
    }
    for (fn in c("mascot_read_character", "mascot_check_character")) {
      expect_true(fn %in% names(guide$studio_guide))
      expect_true(fn %in% names(guide$studio_controls))
    }
  })
  it("offers the check example to copy only, with no note about editing it", {
    skip_without_studio_packages("studio")
    page <- as.character(studio_parts()$page)
    expect_match(page, 'id="check_character_call"', fixed = TRUE)
    expect_false(grepl("Edit a plain source list", page, fixed = TRUE))
  })
  it("has a guide page for each character reader, with the real output and the experimental word", {
    env <- studio_guide_env()
    dir <- file.path(dirname(mascot_example("studio", run = FALSE)), "guide")
    page <- function(fn) {
      paste(vapply(env$studio_guide_page(fn, "tessa", dir), as.character, character(1)), collapse = "\n")
    }
    read <- page("mascot_read_character")
    expect_match(read, "Experimental", fixed = TRUE)
    expect_match(read, "study_bot: Study Bot", fixed = TRUE)
    # The page never prints the build machine's path
    expect_match(read, "From: .../examples/characters/study_bot.json", fixed = TRUE)
    expect_false(grepl(normalizePath(tempdir(), winslash = "/"), read, fixed = TRUE))
    expect_false(grepl("/Users/|/home/", read))
    expect_match(read, "take the built-in characters only", fixed = TRUE)
    check <- page("mascot_check_character")
    expect_match(check, "Experimental", fixed = TRUE)
    expect_match(check, "JSON text or a plain R list", fixed = TRUE)
    expect_match(check, "Error: ", fixed = TRUE)
    expect_match(check, "format_version", fixed = TRUE)
    expect_match(check, "built-in characters only", fixed = TRUE)
  })
})
