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
      code$code_size("20%", 72, FALSE),
      code$code_placement("top-left", TRUE),
      code$code_menu(character()),
      theme
    )
    for (pair in pairs) {
      for (style in c("short", "helper")) {
        expect_type(parse(text = code$format_expr(pair[[style]])), "expression")
      }
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
    html <- as.character(shiny::shinyAppDir(dir)$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET"))$content)
    ids <- regmatches(html, gregexpr(' id="[^"]+"', html))[[1]]
    expect_identical(anyDuplicated(ids), 0L)
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
example_driver <- function(name) {
  checkmate::assert_string(name)
  testthat::skip_if_not_installed("bslib")
  app_function <- function() NULL
  body(app_function) <- substitute(
    {
      library(mascot)
      shiny::shinyAppDir(system.file("examples", NAME, package = "mascot"))
    },
    list(NAME = name)
  )
  shinytest2::AppDriver$new(app_function, width = 1100, height = 900, load_timeout = 30000)
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
    app <- example_driver("studio")
    withr::defer(app$stop())
    state <- "mascot.host.state(document.getElementById('helper'))"
    wait_example_mood(app, "helper", "idle")
    expect_identical(app$get_js("document.querySelectorAll('.mascot').length"), 1L)
    select_function <- function(fn) {
      checkmate::assert_string(fn)
      app$click(selector = sprintf('.pg-index-link[data-value="%s"]', fn))
      app$wait_for_js(sprintf("!!document.querySelector('#guide [data-guide-function=\"%s\"]')", fn))
      app$wait_for_js(sprintf(
        "!document.querySelector('#studio_inspector [data-function=\"%s\"]').hidden",
        fn
      ))
    }
    # The mood cards are the inspector's only mood input.
    expect_identical(app$get_js("document.querySelectorAll('#mood input[type=radio]').length"), 0L)
    app$run_js("document.querySelector('[data-event=try_mood][data-value=happy]').click()")
    wait_example_mood(app, "helper", "happy")
    app$wait_for_js("document.getElementById('code_last').textContent.includes('mood = \"happy\"')")
    select_function("mascot_status")
    # The selected function owns both the inspector controls and the guide.
    expect_true(app$get_js(
      "document.querySelector('#studio_inspector [data-function=mascot_status]').open && document.querySelector('#guide [data-guide-function=mascot_status]') !== null && document.getElementById('status_text').getClientRects().length > 0"
    ))
    expect_true(app$get_js("document.querySelector('#studio_inspector [data-function=mascot_mood]').hidden"))
    app$set_inputs(status_text = "Checking 120 rows")
    app$wait_for_js(paste0(state, ".status.text === 'Checking 120 rows'"))
    select_function("mascot_bubble")
    app$set_inputs(bubble_example = "Small table")
    app$click("bubble_show")
    app$wait_for_js("!!document.querySelector('#helper .mascot-bubble table')")
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
    # Switching functions and showing all controls reuse the same inputs and their values.
    select_function("mascot_status")
    expect_identical(app$get_value(input = "status_text"), "Checking 120 rows")
    app$set_inputs(show_all_controls = TRUE)
    app$wait_for_js("!document.querySelector('[data-function=mascot_bubble]').hidden")
    expect_false(app$get_js("document.querySelector('[data-function=mascot_bubble]').open"))
    app$set_inputs(show_all_controls = FALSE)
    app$wait_for_js("document.querySelector('[data-function=mascot_bubble]').hidden")
    app$click(selector = "#guide_expand")
    app$wait_for_js("document.getElementById('studio_centre').classList.contains('is-expanded')")
    expect_identical(app$get_js("document.querySelectorAll('.mascot').length"), 1L)
    app$click(selector = "#guide_expand")
    # The first visit to the preview tab builds a preview without a click.
    app$run_js("document.querySelector('a[data-value=preview]').click()")
    app$wait_for_js("!!document.querySelector('iframe.pg-preview')", timeout = 15000)
    app$run_js("document.querySelector('a[data-value=examples]').click()")
    app$wait_for_js("!!document.querySelector('#example_code')", timeout = 15000)
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
