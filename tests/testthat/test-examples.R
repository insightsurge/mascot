describe("mascot_examples()", {
  it("lists the five teaching apps in order with readable metadata", {
    examples <- mascot_examples()
    expect_s3_class(examples, "data.frame")
    expect_named(examples, c("name", "title", "description"))
    expect_identical(examples$name, c("basic", "form-check", "long-task", "modules", "branding"))
    expect_true(all(vapply(examples, is.character, logical(1))))
    expect_true(all(nzchar(unlist(examples))))
    expect_identical(anyDuplicated(examples$name), 0L)
    expect_match(examples$description[examples$name == "branding"], "Requires bslib")
  })
  it("ships parseable scenario files that return app objects without starting a server", {
    for (name in mascot_examples()$name) {
      file <- mascot_example(name, run = FALSE)
      expect_true(file.exists(file), info = name)
      expect_type(parse(file), "expression")
      if (name == "branding" && !requireNamespace("bslib", quietly = TRUE)) {
        expect_error(source(file, local = new.env())$value, "branding example needs")
      } else {
        app <- source(file, local = new.env())$value
        expect_s3_class(app, "shiny.appobj")
        html <- as.character(app$httpHandler(list(PATH_INFO = "/"))$content)
        expect_false(any(grepl("https?://", html)), info = name)
      }
    }
  })
})

describe("mascot_example()", {
  it("returns the installed app.R path without writing or running anything", {
    path <- mascot_example("basic", run = FALSE)
    expect_identical(path, system.file("examples", "basic", "app.R", package = "mascot"))
    expect_identical(basename(path), "app.R")
    expect_true(file.exists(path))
  })
  it("checks every argument and names valid examples for unknown names", {
    for (bad in list(NULL, NA_character_, "", 1, c("basic", "modules"))) {
      expect_error(mascot_example(bad, FALSE), "Assertion on 'name' failed")
    }
    for (bad in list(NULL, NA, 1, "FALSE", c(TRUE, FALSE))) {
      expect_error(mascot_example("basic", bad), "Assertion on 'run' failed")
    }
    expect_snapshot(error = TRUE, mascot_example("typo", FALSE))
  })
  it("explains how to locate an app in a non-interactive session", {
    expect_false(interactive())
    expect_error(mascot_example("basic"), "needs an interactive R session")
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
  app_function <- function() NULL
  body(app_function) <- substitute(
    {
      library(mascot)
      source(system.file("examples", NAME, "app.R", package = "mascot"), local = new.env())$value
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
  it("E1 basic renders one helper and changes mood, text, layout and motion", {
    local_shiny_browser()
    app <- example_driver("basic")
    withr::defer(app$stop())
    wait_example_mood(app, "helper", "idle")
    expect_identical(app$get_js("document.querySelectorAll('.mascot').length"), 1L)
    app$click("mood_happy")
    wait_example_mood(app, "helper", "happy")
    app$set_inputs(status = "Check complete")
    app$click("set_status")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent==='Check complete'")
    app$click("clear_status")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent==='Happy'")
    app$set_inputs(keep = TRUE, message = "Three rows skipped")
    app$click("show_bubble")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble')?.textContent.includes('Three rows skipped')")
    app$click("clear_bubble")
    app$wait_for_js("!mascot.host.state(document.getElementById('helper')).bubble")
    app$run_js("document.querySelector('details').open=true")
    app$set_inputs(floating = TRUE, animate = FALSE, size = 120)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).placement.floating===true")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).motion.reduced===true")
    app$click("reset")
    wait_example_mood(app, "helper", "idle")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).placement.floating===false")
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
    wait_example_mood(app, "helper", "happy")
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
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#9ec5fe'")
    app$set_inputs(palette = "rose")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#f2a6cf'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.rim"), "#C5B0EB")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.sleeve"), "#F2A6CF")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.limb"), "#C5B0EB")
    expect_identical(
      app$get_js("mascot.host.state(document.getElementById('helper')).colours.accessoryDetail"),
      "#91649F"
    )
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("document.documentElement.dataset.bsTheme==='light'")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#b53d78'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.accessory"), "#A94A82")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.sleeve"), "#B53D78")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).colours.limb"), "#A94A82")
    expect_identical(
      app$get_js("mascot.host.state(document.getElementById('helper')).colours.bodyHighlight"),
      "#C95791"
    )
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
