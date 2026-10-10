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
  it("explains every exported function and argument in the studio", {
    guide <- new.env()
    sys.source(file.path(dirname(mascot_example("studio", run = FALSE)), "R", "guide.R"), envir = guide)
    exports <- getNamespaceExports("mascot")
    expect_setequal(names(guide$playground_guide), exports)
    for (fn in exports) {
      entry <- guide$playground_guide[[fn]]
      expect_setequal(as.character(names(entry$args)), as.character(names(formals(getExportedValue("mascot", fn)))))
      expect_true(entry$category %in% names(guide$playground_categories), info = fn)
      expect_true(all(nzchar(c(entry$what, entry$returns))), info = fn)
      for (arg in names(entry$args)) {
        expect_true(nzchar(entry$args[[arg]]$hint), info = paste(fn, arg))
        expect_true(is.null(entry$args[[arg]]$try) || entry$args[[arg]]$try %in% names(guide$playground_categories))
      }
    }
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
      pair <- code$code_placement("bottom-right", FALSE, mode)
      expect_identical(eval(pair$short), list(position = "bottom-right", drag = mode))
      expect_identical(eval(pair$helper), mascot_placement("bottom-right", drag = mode))
      for (style in c("short", "helper")) {
        expect_match(code$format_expr(pair[[style]]), paste0('drag = "', mode, '"'), fixed = TRUE)
      }
    }
    expect_false(grepl("simplify_when_small", code$format_expr(code$code_size(120, 72)$helper), fixed = TRUE))
  })
  it("labels Learn as a call to its selected function and keeps visuals in separate sections", {
    skip_if_not_installed("bslib")
    withr::local_package("shiny")
    withr::local_package("bslib")
    dir <- dirname(mascot_example("studio", run = FALSE))
    ui <- new.env()
    sys.source(file.path(dir, "R", "guide.R"), envir = ui)
    sys.source(file.path(dir, "R", "ui.R"), envir = ui)
    expect_error(ui$selected_learn(42), "string")
    for (fn in c(
      "mascot_mood",
      "mascot_bubble",
      "mascot_motion",
      "mascot_placement",
      "mascot_theme",
      "mascot_popup_menu",
      "updateMascot"
    )) {
      html <- as.character(ui$selected_learn(fn))
      expect_match(html, paste0("Example: how to call ", fn, "()"), fixed = TRUE)
      expect_match(html, 'id="code_function"', fixed = TRUE)
      expect_match(html, "pg-learn-piece", fixed = TRUE)
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
    pages <- lapply(c("", "view=preview", "view=examples"), function(query) {
      as.character(app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = query))$content)
    })
    for (page in pages) {
      ids <- regmatches(page, gregexpr(' id="[^"]+"', page))[[1]]
      expect_identical(anyDuplicated(ids), 0L)
    }
    html <- paste(unlist(pages), collapse = "\n")
    expect_match(pages[[1]], 'id="studio_panels"', fixed = TRUE)
    expect_match(pages[[1]], 'id="studio_panels_card"', fixed = TRUE)
    expect_false(grepl('id="learn_card"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="code_dock"', pages[[1]], fixed = TRUE))
    expect_match(pages[[1]], 'href="?view=preview"', fixed = TRUE)
    expect_match(pages[[1]], 'href="?view=examples"', fixed = TRUE)
    expect_match(pages[[1]], 'href="https://github.com/insightsurge/mascot"', fixed = TRUE)
    expect_match(pages[[1]], 'href="https://mascot-pkg.web.app/"', fixed = TRUE)
    expect_match(pages[[1]], "Links", fixed = TRUE)
    expect_false(grepl('id="preview_body"', pages[[1]], fixed = TRUE))
    expect_false(grepl('id="helper"', pages[[2]], fixed = TRUE))
    expect_false(grepl('id="helper"', pages[[3]], fixed = TRUE))
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
    select_function <- function(fn) {
      checkmate::assert_string(fn)
      app$click(selector = sprintf('.pg-index-link[data-value="%s"]', fn))
      app$wait_for_js(sprintf("!!document.querySelector('#learn [data-learn-function=\"%s\"]')", fn))
      app$wait_for_js(sprintf(
        "!document.querySelector('#studio_inspector [data-function=\"%s\"]').hidden && document.querySelectorAll('#studio_inspector [data-function]:not([hidden])').length === 1",
        fn
      ))
    }
    learn_panel <- "#studio_panels > .accordion-item:first-child"
    code_panel <- "#studio_panels > .accordion-item:last-child"
    expect_identical(app$get_js("document.querySelectorAll('#studio_panels > .accordion-item').length"), 2L)
    expect_true(app$get_js(
      "document.getElementById('studio_panels_card').contains(document.getElementById('studio_panels')) && document.querySelector('#studio_panels_card .bslib-full-screen-enter') !== null"
    ))
    expect_identical(
      app$get_js(sprintf("document.querySelector('%s .accordion-button').textContent.trim()", code_panel)),
      "Code"
    )
    expect_true(app$get_js(sprintf(
      "document.querySelector('%s .accordion-body').contains(document.getElementById('code_style')) && !document.querySelector('.pg-toolbar #code_style')",
      code_panel
    )))
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
      "Code for Tessa as she is now.",
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
    expect_false(app$get_js(sprintf(
      "document.querySelector('%s .accordion-collapse').classList.contains('show')",
      learn_panel
    )))
    expect_true(app$get_js(sprintf(
      "document.querySelector('%s .accordion-collapse').classList.contains('show')",
      code_panel
    )))
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
    app$click(selector = paste(learn_panel, ".accordion-button"))
    app$wait_for_js(sprintf("document.querySelector('%s .accordion-collapse').classList.contains('show')", learn_panel))
    app$wait_for_js(paste(
      "document.querySelectorAll('#studio_panels .accordion-collapse.show').length === 1",
      "&& !document.querySelector('#studio_panels .collapsing')"
    ))
    expect_false(app$get_js(sprintf(
      "document.querySelector('%s .accordion-collapse').classList.contains('show')",
      code_panel
    )))
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    expect_identical(
      app$get_js(sprintf("getComputedStyle(document.querySelector('%s .accordion-collapse')).overflowY", learn_panel)),
      "auto"
    )
    expect_identical(
      app$get_js("document.querySelector('.pg-learn-example .pg-section-title').textContent"),
      "Example: how to call mascot_mood()"
    )
    # Bslib's own full-screen button gives Learn compact columns for its example and visual sections.
    app$click(selector = "#studio_panels_card .bslib-full-screen-enter")
    app$wait_for_js("document.getElementById('studio_panels_card').getAttribute('data-full-screen') === 'true'")
    app$wait_for_js(
      "getComputedStyle(document.querySelector('.pg-learn-columns')).gridTemplateColumns.split(' ').length >= 3"
    )
    expect_true(app$get_js(
      "(() => {
      const example = document.querySelector('.pg-learn-example').getBoundingClientRect();
      const table = document.querySelector('.pg-guide-visual .pg-table').getBoundingClientRect();
      const callout = document.querySelector('.pg-guide-visual .pg-callout').getBoundingClientRect();
      return table.left > example.left && callout.left > table.left && Math.abs(table.top - example.top) < 80;
    })()"
    ))
    app$run_js(
      "document.getElementById('studio_panels_card').dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}))"
    )
    app$wait_for_js("document.getElementById('studio_panels_card').getAttribute('data-full-screen') === 'false'")
    app$wait_for_js(canvas_fits)
    expect_identical(app$get_js("getComputedStyle(document.querySelector('.pg-index-link code')).whiteSpace"), "nowrap")
    grip_height <- app$get_js("document.getElementById('studio_dock').getBoundingClientRect().height")
    app$run_js(
      "document.getElementById('dock_grip').dispatchEvent(new KeyboardEvent('keydown', {key: 'ArrowDown', bubbles: true}))"
    )
    app$wait_for_js(sprintf("document.getElementById('studio_dock').getBoundingClientRect().height < %f", grip_height))
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    expect_identical(
      app$get_js("[...document.querySelectorAll('#code_tabs .nav-link')].map(el => el.textContent.trim()).join('|')"),
      "UI|Server|App|Last|Log"
    )
    expect_true(app$get_js("document.querySelector('a[href=\"?view=preview\"]').target === '_blank'"))
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
      "!document.querySelector('#studio_inspector [data-function=mascot_status]').hidden && document.querySelector('#learn [data-learn-function=mascot_status]') !== null && document.getElementById('status_text').getClientRects().length > 0"
    ))
    expect_true(app$get_js("document.querySelector('#studio_inspector [data-function=mascot_mood]').hidden"))
    expect_true(app$get_js(
      "(() => {
      const panel = document.querySelector('#studio_inspector [data-function=mascot_status]');
      return panel.textContent.includes('Usage') && panel.textContent.includes('Returns:') &&
        panel.textContent.includes('always visible line');
    })()"
    ))
    app$set_inputs(status_text = "Checking 120 rows")
    app$wait_for_js(paste0(state, ".status.text === 'Checking 120 rows'"))
    select_function("mascot_bubble")
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
    app$set_inputs(position = "top-left")
    app$set_inputs(minimise = TRUE)
    app$wait_for_js(paste0(state, ".placement.floating && ", state, ".placement.minimise"))
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
    select_function("mascot_popup_menu")
    app$click(selector = "#helper .mascot-menu-toggle")
    app$click(selector = "#helper [role=menuitem][data-item-id=finish]")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble')?.textContent.includes('Finish review')")
    # A mistake is an error in the log, and the mascot keeps its settings.
    select_function("updateMascot")
    app$set_inputs(mistake = "Misspell an argument")
    app$click("mistake_run")
    app$wait_for_js("document.getElementById('log').textContent.includes('Unexpected arguments')")
    # The second step of the slow task runs later and names the session.
    app$click("task_run")
    wait_example_mood(app, "helper", "thinking")
    app$wait_for_js(paste0(state, ".status.text === 'All 120 rows checked'"), timeout = 15000)
    app$wait_for_js("document.getElementById('code_last').textContent.includes('session = session')")
    expect_match(app$get_value(output = "code_app"), "shinyApp(ui, server)", fixed = TRUE)
    # Switching the menu off works even while its text has a problem.
    select_function("mascot_popup_menu")
    app$set_inputs(menu_items = "no equals sign")
    app$set_inputs(menu_on = FALSE)
    app$wait_for_js(paste0(state, ".popup_menu.items === null"))
    # Switching functions reuses the same mounted inputs and their values.
    select_function("mascot_status")
    expect_identical(app$get_value(input = "status_text"), "Checking 120 rows")
    expect_true(app$get_js("document.getElementById('status_text') === window.studioStatusInput"))
    expect_true(app$get_js("document.querySelector('[data-function=mascot_bubble]').hidden"))
    expect_identical(
      app$get_js("document.querySelectorAll('#studio_inspector [data-function]:not([hidden])').length"),
      1L
    )
    app$click(selector = paste(code_panel, ".accordion-button"))
    app$wait_for_js(sprintf("document.querySelector('%s .accordion-collapse').classList.contains('show')", code_panel))
    app$wait_for_js(paste(
      "document.querySelectorAll('#studio_panels .accordion-collapse.show').length === 1",
      "&& !document.querySelector('#studio_panels .collapsing')"
    ))
    expect_false(app$get_js(sprintf(
      "document.querySelector('%s .accordion-collapse').classList.contains('show')",
      learn_panel
    )))
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    expect_identical(
      app$get_js(sprintf("getComputedStyle(document.querySelector('%s .accordion-collapse')).overflowY", code_panel)),
      "auto"
    )
    app$run_js(
      "document.getElementById('dock_grip').dispatchEvent(new KeyboardEvent('keydown', {key: 'End', bubbles: true}))"
    )
    app$wait_for_js(canvas_fits)
    expect_true(app$get_js(canvas_fits))
    app$click(selector = paste(code_panel, ".accordion-button"))
    app$wait_for_js("document.getElementById('studio_centre').classList.contains('is-dock-collapsed')")
    expect_identical(
      app$get_js(sprintf("document.querySelector('%s .accordion-button').textContent.trim()", code_panel)),
      "Code"
    )
    app$click(selector = paste(code_panel, ".accordion-button"))
    app$wait_for_js("!document.getElementById('studio_centre').classList.contains('is-dock-collapsed')")
    # Each URL starts a new Shiny session and builds only its own view.
    app$run_js("window.location.search = '?view=preview'")
    app$wait_for_js("!!document.querySelector('iframe.pg-preview')", timeout = 15000)
    expect_identical(app$get_js("document.querySelectorAll('#helper').length"), 0L)
    expect_true(app$get_js(
      "!!document.getElementById('preview_body') && !!document.getElementById('preview_menu_items')"
    ))
    app$run_js(
      "(() => {
      for (const [id, value] of [['preview_body', '#1f6feb'], ['preview_rim', '#966600']]) {
        const picker = document.getElementById(id); picker.value = value;
        picker.dispatchEvent(new Event('input'));
      }
    })()"
    )
    # A view opened by URL is a new page: shinytest2's input helpers stay with the first page, so use Shiny's own API.
    app$run_js(
      "Shiny.setInputValue('preview_menu_items', 'about = About the preview');
      document.querySelector('input[name=preview_width][value=phone]').click();"
    )
    app$wait_for_js("document.getElementById('code_preview').textContent.includes('body = \"#1f6feb\"')")
    app$wait_for_js("document.getElementById('code_preview').textContent.includes('About the preview')")
    app$run_js("document.getElementById('preview_build').click()")
    app$wait_for_js("document.querySelector('iframe.pg-preview').classList.contains('is-phone')")
    expect_match(
      app$get_js("document.getElementById('code_preview').textContent"),
      'popup_menu = c(about = "About the preview")',
      fixed = TRUE
    )
    app$run_js("window.location.search = '?view=examples'")
    app$wait_for_js("!!document.querySelector('#example_code')", timeout = 15000)
    expect_identical(app$get_js("document.querySelectorAll('#helper').length"), 0L)
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
