describe("updateMascot()", {
  it("sends only supplied fields in a module, with the namespace added once", {
    calls <- new.env(parent = emptyenv())
    calls$messages <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      calls$messages[[length(calls$messages) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$go, {
          session$userData$result <- withVisible(updateMascot("helper", mood = "happy"))
        })
      })
    }
    shiny::testServer(module, {
      session$setInputs(go = 1)
      expect_identical(session$userData$result, list(value = NULL, visible = FALSE))
      expect_identical(calls$messages[[1]], list(id = session$ns("helper"), patch = list(mood = "happy")))
      expect_identical(calls$messages[[1]]$id, "proxy1-helper")
      updateMascot("helper", character = mascot_character(), mood = mascot_mood("thinking"), session = session)
      expect_identical(
        calls$messages[[2]]$patch,
        list(
          character = list(id = "tessa", name = "Tessa", json = character_json("tessa")),
          mood = "thinking"
        )
      )
      updateMascot("helper", status = "Saving", session = session)
      expect_identical(calls$messages[[3]]$patch, list(status = list(mode = "custom", text = "Saving")))
      updateMascot("helper", status = mascot_status(), session = session)
      expect_identical(calls$messages[[4]]$patch, list(status = list(mode = "mood")))
      updateMascot("helper", status = htmltools::HTML("<b>Saving</b>"), session = session)
      expect_identical(calls$messages[[5]]$patch$status$text, "<b>Saving</b>")
      expect_invisible(updateMascot("helper", session = session))
      expect_length(calls$messages, 5)
    })
  })
  it("warns for every invalid value, without sending any part of an update", {
    calls <- new.env(parent = emptyenv())
    calls$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        calls$patches[[length(calls$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    session <- shiny::MockShinySession$new()
    expect_snapshot(updateMascot("helper", character = "neer", mood = "hapy", status = "", session = session))
    for (x in list(1, "", NA_character_, c("a", "b"))) {
      expect_warning(updateMascot("helper", character = x, session = session), "unchanged")
      expect_warning(updateMascot("helper", mood = x, session = session), "unchanged")
      expect_warning(updateMascot("helper", status = x, session = session), "mascot_status")
    }
    expect_warning(updateMascot("{helper", mood = "{oops", status = "Saved", session = session), "not a mood")
    expect_length(calls$patches, 0)
    local_mocked_bindings(dev_mode = function() TRUE)
    expect_warning(updateMascot("helper", mood = "hapy", status = "Saved", session = session), "unchanged")
    expect_length(calls$patches, 1)
    expect_named(calls$patches[[1]], "problem")
    expect_match(calls$patches[[1]]$problem, "^mascot: .*hapy")
  })
  it("errors on code mistakes before inspecting runtime values", {
    session <- shiny::MockShinySession$new()
    expect_error(updateMascot("helper", session = NULL), "inside a Shiny server function or module")
    expect_error(updateMascot("helper", session = 1), "Assertion on 'session' failed")
    expect_error(updateMascot(), "missing")
    for (id in list(1, "", "has space", NA_character_)) {
      expect_error(updateMascot(id, session = session), "Assertion on 'id' failed")
    }
    expect_snapshot(error = TRUE, updateMascot("helper", typo = 1, session = session))
    expect_snapshot(error = TRUE, updateMascot("helper", NULL, NULL, NULL, session))
  })
})

describe("send_update()", {
  it("sends a custom message with the namespace exactly once", {
    session <- shiny::MockShinySession$new()
    captured <- new.env(parent = emptyenv())
    session$sendCustomMessage <- function(type, message) {
      captured$type <- type
      captured$message <- message
    }
    send_update(session, "helper", list(mood = "happy"))
    expect_identical(captured$type, "mascot:update")
    expect_identical(captured$message, list(id = session$ns("helper"), patch = list(mood = "happy")))
    expect_error(send_update(NULL, "helper", list()), "'session'")
    expect_error(send_update(session, "has space", list()), "'id'")
    expect_error(send_update(session, "helper", 1), "'patch'")
  })
})

describe("dev_mode()", {
  it("uses Shiny's development-mode decision", {
    expect_identical(dev_mode(), shiny::in_devmode())
  })
})

describe("updateMascot() in a browser", {
  it("changes mood, sets plain status text and returns it to the mood", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      ui <- shiny::fluidPage(
        mascot(id = "helper"),
        shiny::actionButton("think", "Think"),
        shiny::actionButton("save", "Save"),
        shiny::actionButton("happy", "Happy"),
        shiny::actionButton("reset", "Follow mood")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$think, updateMascot("helper", mood = "thinking"))
        shiny::observeEvent(input$save, updateMascot("helper", status = "<b>Saved</b>"))
        shiny::observeEvent(input$happy, updateMascot("helper", mood = "happy"))
        shiny::observeEvent(input$reset, updateMascot("helper", status = mascot_status()))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'idle'")
    app$click("think")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'thinking'")
    expect_identical(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "Thinking")
    app$click("save")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent === '<b>Saved</b>'")
    app$click("happy")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').innerHTML"),
      "&lt;b&gt;Saved&lt;/b&gt;"
    )
    app$click("reset")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent === 'Happy'")
    expect_identical(app$get_js("document.querySelector('#helper canvas').getAttribute('aria-label')"), "Tessa, happy")
  })
  it("updates a module mascot using its local server id", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(mascot(id = ns("helper")), shiny::actionButton(ns("go"), "Go"))
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::observeEvent(input$go, updateMascot("helper", mood = "happy"))
        })
      }
      shiny::shinyApp(shiny::fluidPage(module_ui("mod")), function(input, output, session) module_server("mod"))
    })
    withr::defer(app$stop())
    app$click("mod-go")
    app$wait_for_js("document.querySelector('#mod-helper').dataset.shownMood === 'happy'")
    expect_identical(app$get_js("document.querySelector('#mod-helper .mascot-status').textContent"), "Happy")
  })
  it("keeps updates before renderUI and destroys the replaced element's record", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      # A permanent mascot loads the dependency and message handler before the late one exists.
      ui <- shiny::fluidPage(
        mascot(id = "anchor"),
        shiny::uiOutput("slot"),
        shiny::actionButton("prepare", "Prepare"),
        shiny::actionButton("show", "Show")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$prepare, {
          updateMascot("late", mood = "thinking")
          updateMascot("late", mood = "happy", status = "Ready")
        })
        output$slot <- shiny::renderUI({
          if (input$show > 0) mascot(id = "late")
        })
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$click("prepare")
    expect_null(app$get_js("document.getElementById('late')"))
    app$click("show")
    app$wait_for_js("document.querySelector('#late')?.dataset.shownMood === 'happy'")
    expect_identical(app$get_js("document.querySelector('#late .mascot-status').textContent"), "Ready")
    app$run_js("window.oldMascot = document.getElementById('late')")
    app$click("show")
    app$wait_for_js(
      "document.getElementById('late') !== window.oldMascot && document.getElementById('late')?.dataset.shownMood === 'idle'"
    )
    expect_null(app$get_js("mascot.host.state(window.oldMascot)"))
    expect_false(app$get_js("window.oldMascot.isConnected"))
    expect_identical(app$get_js("document.querySelector('#late .mascot-status').textContent"), "Idle")
  })
})
