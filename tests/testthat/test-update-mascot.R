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
    expect_snapshot(error = TRUE, updateMascot("helper", NULL, NULL, NULL, NULL, session))
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
    expect_identical(
      captured$message,
      list(
        id = session$ns("helper"),
        patch = list(mood = "happy"),
        revision = 1L,
        gestureRevision = 0L,
        fields = list(mood = 1L, problem = 1L),
        replay = FALSE
      )
    )
    expect_error(send_update(NULL, "helper", list()), "'session'")
    expect_error(send_update(session, "has space", list()), "'id'")
    expect_error(send_update(session, "helper", 1), "'patch'")
    expect_error(send_update(session, "helper", list(), replay = NA), "'replay'")
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
      "document.getElementById('late') !== window.oldMascot && document.getElementById('late')?.dataset.shownMood === 'happy'"
    )
    expect_null(app$get_js("mascot.host.state(window.oldMascot)"))
    expect_false(app$get_js("window.oldMascot.isConnected"))
    expect_identical(app$get_js("document.querySelector('#late .mascot-status').textContent"), "Ready")
  })
})


describe("updateMascot() bubbles and gestures", {
  it("sends complete bubble patches, JSON-safe Inf, clear and gesture names", {
    calls <- new.env(parent = emptyenv())
    calls$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      calls$patches[[length(calls$patches) + 1L]] <- patch
    })
    shiny::testServer(function(input, output, session) {}, {
      updateMascot("helper", bubble = "Ready", gesture = "nod", session = session)
      expect_identical(
        calls$patches[[1]],
        list(
          bubble = list(text = "Ready", html = FALSE, closable = TRUE, duration = 5),
          gesture = "nod"
        )
      )
      updateMascot(
        "helper",
        bubble = mascot_bubble(htmltools::HTML("<b>Ready</b>"), Inf, FALSE),
        gesture = mascot_gesture("wave"),
        session = session
      )
      expect_identical(
        calls$patches[[2]],
        list(
          bubble = list(text = "<b>Ready</b>", html = TRUE, closable = FALSE, duration = NULL),
          gesture = "wave"
        )
      )
      updateMascot("helper", bubble = htmltools::HTML("<b>Ready</b>"), session = session)
      expect_true(calls$patches[[3]]$bubble$html)
      updateMascot("helper", bubble = mascot_bubble(), session = session)
      expect_identical(calls$patches[[4]], list(bubble = list(clear = TRUE)))
      updateMascot("helper", bubble = NULL, gesture = NULL, session = session)
      expect_length(calls$patches, 4)
    })
  })
  it("warns and sends nothing for bad bubbles or gestures, or only a dev-mode problem", {
    calls <- new.env(parent = emptyenv())
    calls$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        calls$patches[[length(calls$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    session <- shiny::MockShinySession$new()
    for (x in list("", 1, NA_character_, c("a", "b"))) {
      expect_warning(updateMascot("a", mood = "happy", bubble = x, session = session), "bubble")
      expect_warning(updateMascot("a", status = "Ready", gesture = x, session = session), "gesture")
    }
    expect_warning(updateMascot("a", bubble = "Ready", gesture = "jump", session = session), "not a gesture")
    bad <- mascot_bubble("Ready")
    for (field in c("text", "html", "duration", "closable")) {
      value <- bad
      value[[field]] <- NA
      expect_warning(updateMascot("a", mood = "happy", bubble = value, session = session), "bubble")
    }
    expect_length(calls$patches, 0)
    local_mocked_bindings(dev_mode = function() TRUE)
    expect_warning(updateMascot("a", mood = "happy", bubble = "", gesture = "jump", session = session), "unchanged")
    expect_named(calls$patches[[1]], "problem")
    expect_match(calls$patches[[1]]$problem, "bubble.*gesture")
  })
})

describe("server bubbles and gestures in a browser", {
  it("shows a server bubble, accepts a gesture and lets the user close it", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      ui <- shiny::fluidPage(mascot(id = "helper"), shiny::actionButton("go", "Go"))
      server <- function(input, output, session) {
        shiny::observeEvent(input$go, {
          updateMascot("helper", bubble = mascot_bubble("Ready", Inf), gesture = "wave")
        })
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$run_js(
      "window.mascotErrors = []; const originalError = console.error;
      console.error = (...args) => { window.mascotErrors.push(args.map(String).join(' ')); originalError(...args); };
      window.addEventListener('error', event => window.mascotErrors.push(event.message));"
    )
    app$click("go")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble-text').textContent === 'Ready'")
    expect_length(app$get_js("window.mascotErrors"), 0)
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Ready")
    expect_identical(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "Idle")
    app$run_js("document.querySelector('#helper .mascot-bubble-close').click()")
    app$wait_for_js("document.querySelector('#helper .mascot-bubble').hidden")
    expect_null(app$get_js("mascot.host.state(document.getElementById('helper')).bubble"))
  })
})

describe("update review regressions", {
  it("R2 renders a deferred tag once and sends that exact result", {
    calls <- new.env(parent = emptyenv())
    calls$count <- 0L
    calls$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      calls$patches[[length(calls$patches) + 1L]] <- patch
    })
    deferred <- htmltools::tagList(htmltools::tagFunction(function() {
      calls$count <- calls$count + 1L
      if (calls$count > 1L) {
        stop("Message was rendered again")
      }
      shiny::tags$strong(paste("Saved", calls$count))
    }))
    shiny::testServer(function(input, output, session) {}, {
      updateMascot("helper", bubble = deferred, session = session)
      expect_identical(calls$count, 1L)
      expect_identical(calls$patches[[1]]$bubble$text, "<strong>Saved 1</strong>")
      expect_true(calls$patches[[1]]$bubble$html)
    })
  })
  it("R2 warns without sending when deferred tag rendering fails", {
    calls <- new.env(parent = emptyenv())
    calls$count <- 0L
    calls$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        calls$patches[[length(calls$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    deferred <- htmltools::tagList(htmltools::tagFunction(function() {
      calls$count <- calls$count + 1L
      stop("Cannot render message")
    }))
    session <- shiny::MockShinySession$new()
    expect_warning(
      updateMascot("helper", mood = "happy", bubble = deferred, session = session),
      "Cannot render message"
    )
    expect_identical(calls$count, 1L)
    expect_length(calls$patches, 0)
    local_mocked_bindings(dev_mode = function() TRUE)
    expect_warning(updateMascot("helper", bubble = deferred, session = session), "Cannot render message")
    expect_named(calls$patches[[1]], "problem")
    expect_match(calls$patches[[1]]$problem, "Cannot render message")
  })
  it("G7 diagnoses an unnamed session before warning about runtime values", {
    shiny::testServer(function(input, output, session) {}, {
      expect_error(updateMascot("helper", mood = "happy", session), "session.*must be named")
      for (arg in c("character", "mood", "status", "bubble")) {
        args <- list(id = "helper")
        args[[arg]] <- session
        expect_error(do.call(updateMascot, args), "session.*must be named")
      }
    })
    for (class in c("ShinySession", "session_proxy", "MockShinySession")) {
      misplaced <- structure(list(), class = class)
      expect_error(updateMascot("helper", misplaced, session = NULL), "session.*must be named")
    }
  })
  it("G1 and G6 send untimed rendered tags and warn for unsupported dependencies", {
    calls <- new.env(parent = emptyenv())
    calls$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        calls$patches[[length(calls$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    shiny::testServer(function(input, output, session) {}, {
      updateMascot("helper", bubble = mascot_bubble("Ready", duration = NULL), session = session)
      expect_null(calls$patches[[1]]$bubble$duration)
      updateMascot("helper", bubble = shiny::tags$strong("Saved"), session = session)
      expect_identical(calls$patches[[2]]$bubble$text, "<strong>Saved</strong>")
      expect_true(calls$patches[[2]]$bubble$html)
      updateMascot("helper", bubble = htmltools::tagList(shiny::tags$strong("Saved")), session = session)
      expect_true(calls$patches[[3]]$bubble$html)
      dependency <- htmltools::htmlDependency("bubble-test", "1.0", src = c(file = tempdir()))
      dependent <- htmltools::attachDependencies(shiny::tags$strong("Saved"), dependency)
      expect_warning(
        updateMascot("helper", mood = "happy", bubble = dependent, session = session),
        "dependencies.*not supported"
      )
      expect_length(calls$patches, 3)
    })
  })
  it("G2 names nod and wave in the gesture argument's help", {
    path <- system.file("man", "updateMascot.Rd", package = "mascot")
    rd <- if (nzchar(path)) tools::parse_Rd(path) else tools::Rd_db("mascot")[["updateMascot.Rd"]]
    arguments <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\arguments"), rd)[[1]]
    items <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\item"), arguments)
    item <- Filter(function(x) identical(paste(unlist(x[[1]]), collapse = ""), "gesture"), items)[[1]]
    text <- paste(unlist(item[[2]]), collapse = "")
    expect_match(text, '"nod"', fixed = TRUE)
    expect_match(text, '"wave"', fixed = TRUE)
  })
})


describe("updateMascot() size and placement", {
  it("sends complete normalised objects, adds the module namespace once and leaves NULL alone", {
    captured <- new.env(parent = emptyenv())
    captured$messages <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$messages[[length(captured$messages) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$layout, {
          updateMascot("helper", size = "20%", placement = list(position = "top-left"))
        })
      })
    }
    shiny::testServer(module, {
      session$setInputs(layout = 1)
      expect_identical(
        captured$messages[[1]],
        list(
          id = "proxy1-helper",
          patch = list(
            size = list(size = "20%", small_screen = NULL),
            placement = list(floating = TRUE, position = "top-left", minimise = TRUE, drag = FALSE)
          )
        )
      )
      updateMascot("helper", size = mascot_size(120, 48), placement = "inline", session = session)
      expect_identical(
        captured$messages[[2]]$patch,
        list(
          size = list(size = 120, small_screen = 48),
          placement = list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
        )
      )
      updateMascot("helper", placement = mascot_placement("top-left", drag = "free"), session = session)
      expect_identical(
        captured$messages[[3]]$patch,
        list(placement = list(floating = TRUE, position = "top-left", minimise = TRUE, drag = "free"))
      )
      updateMascot("helper", placement = list(position = "bottom-left", drag = "snap"), session = session)
      expect_identical(captured$messages[[4]]$patch$placement$drag, "snap")
      updateMascot("helper", size = NULL, placement = NULL)
      expect_length(captured$messages, 4)
      expect_error(updateMascot("helper", NULL, NULL, NULL, NULL, session), "session.*must be named")
      expect_error(updateMascot("helper", NULL, NULL, NULL, NULL, NULL, session), "session.*must be named")
    })
  })
  it("warns atomically for bad values and malformed helpers, with a dev-mode problem only", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        captured$patches[[length(captured$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    shiny::testServer(function(input, output, session) {}, {
      bad_size <- mascot_size()
      bad_size$small_screen <- "0%"
      # A helper built before simplify_when_small was removed carries an extra field.
      bad_fields <- mascot_size()
      bad_fields$simplify_when_small <- TRUE
      for (x in list(23, Inf, "24px", bad_size, bad_fields)) {
        expect_warning(updateMascot("a", size = x, mood = "happy"), "unchanged")
      }
      bad_place <- mascot_placement("inline")
      bad_place$minimise <- NA
      bad_drag <- mascot_placement("inline")
      bad_drag$drag <- "fixed"
      for (x in list("fixed", list(floating = TRUE, snap = TRUE), bad_place, bad_drag)) {
        expect_warning(updateMascot("a", placement = x, status = "Saved"), "unchanged")
      }
      expect_warning(
        updateMascot("a", placement = list(position = "top-left", drag = TRUE)),
        "unchanged.*drag.*got TRUE"
      )
      expect_warning(
        updateMascot("a", placement = list(position = "top-left", drag = "fixed")),
        'unchanged.*drag.*"fixed"'
      )
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(updateMascot("a", size = 1, placement = "fixed", mood = "happy"), "unchanged")
      expect_named(captured$patches[[1]], "problem")
      expect_match(captured$patches[[1]]$problem, "size.*placement")
    })
  })
  it("informs about explicit inline controls and still sends the complete update", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$patches[[length(captured$patches) + 1L]] <- patch
    })
    shiny::testServer(function(input, output, session) {}, {
      wire <- list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
      for (placement in list("inline", mascot_placement("inline"), list(position = "inline"))) {
        expect_silent(updateMascot("a", placement = placement, session = session))
        expect_identical(tail(captured$patches, 1)[[1]], list(placement = wire))
      }
      for (controls in list(
        list(minimise = TRUE),
        list(minimise = FALSE),
        list(drag = "snap"),
        list(drag = "free"),
        list(drag = FALSE)
      )) {
        before <- length(captured$patches)
        expect_message(
          updateMascot("a", placement = c(list(position = "inline"), controls), status = "Saved", session = session),
          paste0(names(controls), ".*no effect.*inline"),
          class = "mascot_placement_ignored"
        )
        expect_length(captured$patches, before + 1L)
        patch <- tail(captured$patches, 1)[[1]]
        expect_identical(patch$placement, wire)
        expect_identical(patch$status$text, "Saved")
        expect_null(patch$problem)
      }
      expect_snapshot(updateMascot("a", placement = list(position = "inline", minimise = TRUE), session = session))
      expect_snapshot(updateMascot("a", placement = list(position = "inline", drag = "snap"), session = session))
      expect_snapshot(updateMascot("a", placement = mascot_placement("inline", minimise = TRUE), session = session))
      expect_snapshot(updateMascot("a", placement = mascot_placement("inline", drag = "free"), session = session))
      expect_identical(tail(captured$patches, 1)[[1]], list(placement = wire))
    })
  })
})


describe("size and placement in a Shiny browser", {
  it("floats, minimises and restores with mouse, Enter and Space while retaining server updates", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "helper", size = 96, placement = mascot_placement("bottom-right", minimise = TRUE)),
          shiny::actionButton("change", "Change"),
          shiny::actionButton("inline", "Inline"),
          shiny::actionButton("notice", "Notice"),
          shiny::actionButton("remove_notice", "Remove notice")
        ),
        function(input, output, session) {
          shiny::observeEvent(
            input$change,
            updateMascot(
              "helper",
              size = 64,
              mood = "happy",
              placement = mascot_placement("top-left", TRUE),
              bubble = mascot_bubble("Saved", Inf)
            )
          )
          shiny::observeEvent(input$inline, updateMascot("helper", size = 120, placement = "inline"))
          shiny::observeEvent(input$notice, shiny::showNotification("Saved", id = "mascot-notice", duration = NULL))
          shiny::observeEvent(input$remove_notice, shiny::removeNotification("mascot-notice"))
        }
      )
    })
    withr::defer(app$stop())
    app$wait_for_js("document.querySelector('#helper canvas').width === 96 * devicePixelRatio")
    app$click("notice")
    app$wait_for_js("document.getElementById('shiny-notification-mascot-notice') !== null")
    app$wait_for_js(
      "document.getElementById('helper').getBoundingClientRect().bottom <
      document.getElementById('shiny-notification-panel').getBoundingClientRect().top"
    )
    expect_true(app$get_js(
      "document.getElementById('helper').getBoundingClientRect().bottom <=
      document.getElementById('shiny-notification-panel').getBoundingClientRect().top -
      parseFloat(getComputedStyle(document.documentElement).fontSize) + 0.1"
    ))
    app$click("remove_notice")
    app$wait_for_js("document.getElementById('shiny-notification-mascot-notice') === null")
    app$run_js(
      "window.mounts=0; const mount=mascot.mount;
      mascot.mount=(...args)=>{mounts++;return mount(...args);};"
    )
    app$click(selector = "#helper .mascot-minimise")
    app$wait_for_js("document.querySelector('#helper').dataset.minimised === 'true'")
    app$click("change")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).mood === 'happy'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Saved")
    app$click(selector = "#helper .mascot-restore")
    app$wait_for_js("document.querySelector('#helper canvas').width === 64 * devicePixelRatio")
    expect_identical(app$get_js("document.querySelector('#helper').dataset.position"), "top-left")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'happy'")
    expect_identical(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "Happy")
    # Native button activation must work for both keyboard keys, not just synthetic click events.
    browser <- app$get_chromote_session()
    for (key in c("Enter", " ")) {
      app$click(selector = "#helper .mascot-minimise")
      app$wait_for_js("document.querySelector('#helper').dataset.minimised === 'true'")
      app$run_js("document.querySelector('#helper .mascot-restore').focus()")
      code <- if (key == "Enter") "Enter" else "Space"
      number <- if (key == "Enter") 13L else 32L
      browser$Input$dispatchKeyEvent(
        type = "keyDown",
        key = key,
        code = code,
        windowsVirtualKeyCode = number,
        text = if (key == "Enter") "\r" else " "
      )
      browser$Input$dispatchKeyEvent(type = "keyUp", key = key, code = code, windowsVirtualKeyCode = number)
      app$wait_for_js("document.querySelector('#helper').dataset.minimised === 'false'")
      expect_true(app$get_js("document.activeElement===document.querySelector('#helper .mascot-minimise')"))
    }
    app$click("inline")
    app$wait_for_js("document.querySelector('#helper').dataset.floating === 'false'")
    expect_equal(app$get_js("document.querySelector('#helper canvas').getBoundingClientRect().width"), 120)
    expect_equal(app$get_js("mounts"), 0)
    expect_true(app$get_js("document.querySelector('#helper .mascot-minimise').hidden"))
  })
  it("measures a module mascot when its hidden tab opens and accepts a local-id layout update", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tags$div(
          style = "width:400px",
          mascot(id = ns("helper"), size = "20%", placement = "inline"),
          shiny::actionButton(ns("change"), "Change")
        )
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::observeEvent(input$change, updateMascot("helper", size = 48, placement = "top-right"))
        })
      }
      shiny::shinyApp(
        shiny::fluidPage(shiny::tabsetPanel(
          id = "tabs",
          shiny::tabPanel("Home", "Start"),
          shiny::tabPanel("Helper", module_ui("mod"))
        )),
        function(input, output, session) module_server("mod")
      )
    })
    withr::defer(app$stop())
    app$wait_for_js("mascot.host.state(document.getElementById('mod-helper')) !== null")
    expect_equal(app$get_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width"), 0)
    app$set_inputs(tabs = "Helper")
    app$wait_for_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width === 80")
    app$click("mod-change")
    app$wait_for_js("document.querySelector('#mod-helper').dataset.position === 'top-right'")
    expect_equal(app$get_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width"), 48)
    expect_false(app$get_js("'detail' in mascot.host.state(document.getElementById('mod-helper'))"))
  })
})


describe("floating mascots in dynamic module UI", {
  it("S3-R3 preserves tab visibility, avoids duplicate bindings and tears down the original controller on replacement", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(shiny::actionButton(ns("replace"), "Replace"), shiny::uiOutput(ns("dynamic")))
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          output$dynamic <- shiny::renderUI({
            shiny::tags$div(
              `data-generation` = input$replace,
              style = "transform:translateZ(0);width:300px;height:300px",
              mascot(
                id = session$ns("helper"),
                size = 64,
                placement = mascot_placement("bottom-right", minimise = TRUE)
              )
            )
          })
        })
      }
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "loader", size = 24, placement = "inline"),
          shiny::tabsetPanel(id = "tabs", shiny::tabPanel("Home", "Home"), shiny::tabPanel("Helper", module_ui("mod")))
        ),
        function(input, output, session) module_server("mod")
      )
    })
    withr::defer(app$stop())
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("Shiny.shinyapp.$inputValues['.clientdata_output_mod-dynamic_hidden'] === false", timeout = 15000)
    app$wait_for_js("document.querySelector('#mod-helper canvas')?.getBoundingClientRect().width === 64")
    app$run_js("window.old=document.getElementById('mod-helper')")
    expect_true(app$get_js("old.parentElement===document.body"))
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source.shiny-bound-input').length"), 1)
    expect_false(app$get_js("old.classList.contains('shiny-bound-input')"))
    app$click(selector = "#mod-replace")
    app$wait_for_js(
      "document.getElementById('mod-helper') !== old && mascot.host.state(old) === null",
      timeout = 15000
    )
    expect_equal(app$get_js("document.querySelectorAll('#mod-helper').length"), 1)
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source.shiny-bound-input').length"), 1)
    expect_false(app$get_js("old.isConnected"))
    # Hidden tab, then shown again: checked through the mascot itself (its canvas collapses and comes back). Shiny's
    # own output-hidden flag can stay stale after a second tab switch in headless Chrome (seen with an inline mascot
    # too), so the replacement above runs while the tab is still open.
    app$click(selector = "a[data-value='Home']")
    app$wait_for_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width === 0")
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("document.querySelector('#mod-helper canvas').getBoundingClientRect().width === 64")
    app$run_js(
      "window.current=document.getElementById('mod-helper');Shiny.unbindAll(document.getElementById('mod-dynamic'))"
    )
    app$wait_for_js("mascot.host.state(current) === null")
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source').length"), 0)
  })
})

describe("updateMascot() themes", {
  it("sends one normalised theme in a module and leaves NULL unchanged", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$patches[[length(captured$patches) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) shiny::moduleServer(id, function(input, output, session) {})
    shiny::testServer(module, {
      theme <- mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "auto")
      expect_invisible(updateMascot("helper", theme = theme, mood = "happy", session = session))
      expect_identical(captured$patches[[1]]$id, session$ns("helper"))
      expect_named(captured$patches[[1]]$patch, c("mood", "theme"))
      expect_identical(captured$patches[[1]]$patch$theme$mode, "auto")
      expect_identical(captured$patches[[1]]$patch$theme$dark$body, "#9EC5FE")
      updateMascot("helper", theme = NULL, session = session)
      expect_length(captured$patches, 1)
      updateMascot("helper", character = "tessa", theme = mascot_theme(), session = session)
      expect_identical(
        captured$patches[[2]]$patch$theme,
        list(light = NULL, dark = NULL, mode = "auto", css = NULL, brand = NULL)
      )
      updateMascot("helper", theme = list(body = "#1f6feb"), session = session)
      expect_identical(captured$patches[[3]]$patch$theme$light, captured$patches[[3]]$patch$theme$dark)
    })
  })
  it("warns for bad themes atomically, sends only a development problem, and retains contrast warnings", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        captured$patches[[length(captured$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    shiny::testServer(function(input, output, session) {}, {
      for (theme in list(1, list(bdoy = "blue"), list(body = "invalid"), structure(list(), class = "mascot_theme"))) {
        expect_warning(updateMascot("helper", theme = theme, mood = "happy", status = "Saved"), "unchanged")
      }
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(updateMascot("helper", theme = list(bdoy = "blue"), character = "missing"), "unchanged")
      expect_named(captured$patches[[1]], "problem")
      expect_match(captured$patches[[1]]$problem, "bdoy")
      expect_warning(updateMascot("helper", theme = mascot_theme(light = list(body = "white"))), "below 3:1")
      expect_identical(captured$patches[[2]]$theme$light$body, "#FFFFFF")
      expect_null(captured$patches[[2]]$problem)
      expect_error(updateMascot("helper", theme = session), "session.*must be named")
    })
  })
})

describe("theme in a Shiny browser", {
  it("T4 follows a bslib dark-mode input with no mode argument or server theme updates", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      shiny::shinyApp(
        bslib::page_fluid(
          bslib::input_dark_mode(id = "dark_mode", mode = "light"),
          mascot(id = "helper", theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"))),
          shiny::actionButton("reset", "Character colours")
        ),
        function(input, output, session) {
          shiny::observeEvent(input$reset, updateMascot("helper", theme = mascot_theme()))
        }
      )
    })
    withr::defer(app$stop())
    app$wait_for_js("window.mascot?.host?.state(document.getElementById('helper'))?.colours.body === '#1F6FEB'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).mode"), "light")
    app$run_js(
      "window.drawnBodies=[];const draw=mascot.draw;mascot.draw=(ctx,ch,options)=>{drawnBodies.push(options.colours.body || ch.colours.body);return draw(ctx,ch,options)}"
    )
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === '#9EC5FE'")
    app$wait_for_js("drawnBodies.at(-1)==='#9EC5FE'")
    expect_identical(app$get_js("document.documentElement.dataset.bsTheme"), "dark")
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === '#1F6FEB'")
    app$click("reset")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === null")
    expect_identical(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "Idle")
  })
})

describe("updateMascot() motion", {
  it("sends a safe motion patch once per module update and leaves NULL unchanged", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$patches[[length(captured$patches) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) shiny::moduleServer(id, function(input, output, session) {})
    shiny::testServer(module, {
      for (motion in list(TRUE, FALSE, mascot_motion(swap = FALSE), mascot_motion(FALSE, FALSE))) {
        expect_invisible(updateMascot("helper", motion = motion, mood = "happy", session = session))
        sent <- tail(captured$patches, 1)[[1]]
        expect_identical(sent$id, session$ns("helper"))
        expect_named(sent$patch, c("mood", "motion"))
        expect_false(identical(sent$patch$motion$reduced, FALSE))
      }
      expect_identical(captured$patches[[1]]$patch$motion, list(reduced = NULL, swap = TRUE))
      expect_identical(captured$patches[[2]]$patch$motion, list(reduced = TRUE, swap = TRUE))
      expect_identical(captured$patches[[3]]$patch$motion, list(reduced = NULL, swap = FALSE))
      updateMascot("helper", motion = NULL, session = session)
      expect_length(captured$patches, 4)
      expect_error(updateMascot("helper", motion = session), "session.*must be named")
    })
    expect_identical(
      tail(names(formals(updateMascot)), 6),
      c("theme", "motion", "popup_menu", "...", "gesture", "session")
    )
  })
  it("rejects the whole update with a warning and sends only development problems", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        captured$patches[[length(captured$patches) + 1L]] <- patch
      },
      dev_mode = function() FALSE
    )
    shiny::testServer(function(input, output, session) {}, {
      for (motion in list(NA, 1, "auto", list(animate = TRUE), structure(list(), class = "mascot_motion"))) {
        expect_warning(updateMascot("helper", mood = "happy", status = "Saved", motion = motion), "unchanged")
      }
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(updateMascot("helper", motion = "auto", size = 96), "motion.*TRUE, FALSE")
      expect_named(captured$patches[[1]], "problem")
      expect_match(captured$patches[[1]]$problem, 'got "auto"')
      updateMascot("helper", motion = FALSE)
      expect_identical(captured$patches[[2]], list(motion = list(reduced = TRUE, swap = TRUE)))
    })
  })
})

describe("motion in a Shiny browser", {
  it("M5 changes motion from an app setting without replacing the canvas", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "helper"),
          shiny::checkboxInput("animate", "Animate mascot", TRUE),
          shiny::actionButton("happy", "Happy")
        ),
        function(input, output, session) {
          shiny::observeEvent(input$animate, updateMascot("helper", motion = input$animate))
          shiny::observeEvent(input$happy, updateMascot("helper", mood = "happy"))
        }
      )
    })
    withr::defer(app$stop())
    app$wait_for_js("window.mascot?.host?.state(document.getElementById('helper')) !== null")
    app$run_js("window.originalCanvas=document.querySelector('#helper canvas')")
    app$set_inputs(animate = FALSE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).motion.reduced === true")
    app$click("happy")
    app$wait_for_js("document.getElementById('helper').dataset.shownMood === 'happy'")
    expect_identical(app$get_js("document.querySelector('#helper .mascot-status').textContent"), "Happy")
    expect_true(app$get_js("document.querySelector('#helper canvas') === originalCanvas"))
    app$set_inputs(animate = TRUE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).motion.reduced === null")
    expect_identical(app$get_js("document.getElementById('helper').dataset.reduced"), "auto")
  })
})

describe("updateMascot() popup menu", {
  it("sends replacement and clear patches, leaves NULL unchanged and rejects bad updates atomically", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(
      send_update = function(session, id, patch) {
        captured$patches[[length(captured$patches) + 1L]] <- list(id = session$ns(id), patch = patch)
      },
      dev_mode = function() FALSE
    )
    shiny::testServer(function(input, output, session) {}, {
      updateMascot("helper", popup_menu = c(about = "About"))
      expect_identical(captured$patches[[1]]$id, session$ns("helper"))
      expect_identical(
        captured$patches[[1]]$patch,
        list(popup_menu = list(items = list(about = "About")))
      )
      updateMascot("helper", popup_menu = NULL)
      expect_length(captured$patches, 1)
      updateMascot("helper", popup_menu = mascot_popup_menu())
      expect_identical(captured$patches[[2]]$patch$popup_menu, list(items = NULL))
      for (bad in list(1, "Help", character(), structure(list(), class = "mascot_popup_menu"))) {
        expect_warning(updateMascot("helper", mood = "happy", popup_menu = bad), "unchanged")
      }
      expect_length(captured$patches, 2)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(updateMascot("helper", mood = "happy", popup_menu = "Help"), "unchanged")
      expect_named(captured$patches[[3]]$patch, "problem")
      expect_error(updateMascot("helper", popup_menu = session), "session.*must be named")
    })
    expect_identical(names(formals(updateMascot))[9:12], c("motion", "popup_menu", "...", "gesture"))
  })
})

describe("popup menu in a Shiny browser", {
  it("P6 receives repeated choices in a module and opens the app's modal", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(
          mascot(id = ns("helper"), popup_menu = mascot_popup_menu(c(about = "About this app"))),
          shiny::textOutput(ns("count"))
        )
      }
      shiny::shinyApp(shiny::fluidPage(ui("module")), function(input, output, session) {
        shiny::moduleServer("module", function(input, output, session) {
          count <- shiny::reactiveVal(0L)
          shiny::observeEvent(input$helper_menu, {
            count(count() + 1L)
            shiny::showModal(shiny::modalDialog(paste("Choice", input$helper_menu), easyClose = TRUE))
          })
          output$count <- shiny::renderText(count())
        })
      })
    })
    withr::defer(app$stop())
    app$wait_for_js("!!document.querySelector('#module-helper .mascot-menu-toggle')")
    for (i in 1:2) {
      app$click(selector = "#module-helper .mascot-menu-toggle")
      app$click(selector = "#module-helper [role=menuitem]")
      app$wait_for_js(sprintf("document.getElementById('module-count').textContent === '%s'", i))
      app$wait_for_js("!!document.querySelector('.modal.in, .modal.show')")
      expect_match(app$get_js("document.querySelector('.modal-body').textContent"), "Choice about")
      app$click(selector = ".modal-footer button")
      app$wait_for_js("!document.querySelector('.modal.in, .modal.show')")
    }
  })
})


describe("documented Shiny settings", {
  it("D4 runs the help example for motion, light/dark colours and reset", {
    local_shiny_browser()
    rd <- local_help_page("mascot_motion")
    con <- textConnection("code", "w", local = TRUE)
    tools::Rd2ex(rd, out = con)
    close(con)
    find_app <- function(x) {
      if (!is.call(x) && !is.expression(x)) {
        return(NULL)
      }
      if (is.call(x) && identical(x[[1]], quote(shiny::shinyApp))) {
        return(x)
      }
      for (part in as.list(x)) {
        found <- find_app(part)
        if (!is.null(found)) return(found)
      }
      NULL
    }
    expression <- find_app(parse(text = code))
    expect_false(is.null(expression))
    app_function <- function() NULL
    body(app_function) <- substitute(
      {
        library(mascot)
        APP
      },
      list(APP = expression)
    )
    app <- shinytest2::AppDriver$new(app_function)
    withr::defer(app$stop())
    app$wait_for_js("!!window.mascot?.host?.state(document.getElementById('helper'))")
    app$set_inputs(animate = FALSE)
    app$wait_for_js("document.getElementById('helper').dataset.reduced==='true'")
    app$set_inputs(dark = TRUE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#9ec5fe'")
    app$set_inputs(dark = FALSE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body?.toLowerCase()==='#1f6feb'")
    app$click("reset")
    app$wait_for_js(
      "Object.values(mascot.host.state(document.getElementById('helper')).colours).every(value=>value===null)"
    )
    expect_identical(app$get_js("document.getElementById('helper').dataset.reduced"), "true")
  })
  it("D4 runs the complete module help block and receives repeated choices", {
    local_shiny_browser()
    rd <- local_help_page("mascot_popup_menu")
    details <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\details"), rd)[[1]]
    block <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\preformatted"), details)[[1]]
    expressions <- parse(text = paste(unlist(block), collapse = ""))
    app_function <- function() NULL
    body(app_function) <- as.call(c(list(quote(`{`), quote(library(mascot))), as.list(expressions)))
    app <- shinytest2::AppDriver$new(app_function)
    withr::defer(app$stop())
    app$wait_for_js("!!document.querySelector('#demo-helper .mascot-menu-toggle')")
    for (i in 1:2) {
      app$click(selector = "#demo-helper .mascot-menu-toggle")
      app$click(selector = "#demo-helper [role=menuitem]")
      app$wait_for_js("!!document.querySelector('.modal.in, .modal.show')")
      expect_match(app$get_js("document.querySelector('.modal-body').textContent"), "About this app")
      app$click(selector = ".modal-footer button")
      app$wait_for_js("!document.querySelector('.modal.in, .modal.show')")
    }
  })
})

describe("retained mascot updates", {
  it("merges fields, clears superseded moods and restores problems separately", {
    expect_identical(
      merge_update_patch(list(mood = "happy", gesture = "nod"), list(character = list(id = "blob"))),
      list(gesture = "nod", character = list(id = "blob"))
    )
    expect_identical(merge_update_patch(list(problem = "Bad"), list(mood = "happy")), list(mood = "happy"))
    expect_identical(
      merge_update_patch(list(mood = "happy"), list(problem = "Bad")),
      list(mood = "happy", problem = "Bad")
    )
    expect_error(merge_update_patch(1, list()), "'previous'")
    expect_error(merge_update_patch(list(), 1), "'patch'")
  })
  it("re-sends module state on mount without adding its namespace twice and clears it on session end", {
    captured <- new.env(parent = emptyenv())
    captured$messages <- list()
    # A module's session proxy cannot be assigned to; capture on the root mock session instead.
    root <- shiny::MockShinySession$new()
    unlockBinding("sendCustomMessage", root)
    root$sendCustomMessage <- function(type, message) {
      captured$messages[[length(captured$messages) + 1L]] <- message
    }
    session <- root$makeScope("proxy1")
    shiny::withReactiveDomain(session, {
      updateMascot("helper", mood = "thinking", gesture = "nod")
      updateMascot("helper", mood = "happy", status = "Ready", gesture = "wave")
    })
    root$setInputs(`proxy1-helper` = list(mount = 1, revision = 0))
    expect_length(captured$messages, 3)
    replay <- captured$messages[[3]]
    expect_identical(replay$id, "proxy1-helper")
    expect_true(replay$replay)
    expect_identical(
      replay$patch,
      list(mood = "happy", gesture = "wave", status = list(mode = "custom", text = "Ready"))
    )
    expect_identical(replay$revision, 2L)
    expect_identical(replay$gestureRevision, 2L)
    root$setInputs(`proxy1-helper` = list(mount = 2, revision = 2))
    expect_length(captured$messages, 3)
    root$close()
    expect_null(root$userData$mascot_updates)
  })
  it("recovers startup, earlier-cycle and same-cycle updates for the first renderUI mascots, playing gestures once", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      # Record real controller calls, including ones made while dynamic dependencies load.
      recorder <- shiny::tags$script(htmltools::HTML(
        "window.gestures=[];window.mascot={};
        Object.defineProperty(window.mascot,'mount',{configurable:true,set(fn){
          Object.defineProperty(this,'mount',{configurable:true,writable:true,value:(...args)=>{
            const p=fn(...args),gesture=p.gesture;
            p.gesture=name=>{gestures.push({id:args[0].closest('.mascot').id,name,
              mood:args[0].closest('.mascot').dataset.mood,character:p.current().character});return gesture(name);};return p;
          }});}});"
      ))
      ui <- shiny::fluidPage(
        recorder,
        shiny::actionButton("prepare", "Prepare"),
        shiny::actionButton("show", "Show"),
        shiny::uiOutput("slot")
      )
      server <- function(input, output, session) {
        visible <- shiny::reactiveVal(FALSE)
        updateMascot("startup", mood = "happy", gesture = "wave")
        shiny::observeEvent(input$prepare, {
          updateMascot("earlier", mood = "thinking", status = "Earlier", gesture = "nod")
          updateMascot("earlier", mood = "happy", gesture = "wave")
        })
        shiny::observeEvent(input$show, {
          updateMascot("same", mood = "happy", status = "Same cycle", gesture = "nod")
          visible(TRUE)
        })
        output$slot <- shiny::renderUI({
          if (visible()) shiny::tagList(mascot(id = "startup"), mascot(id = "earlier"), mascot(id = "same"))
        })
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    expect_null(app$get_js("document.querySelector('.mascot')"))
    app$click("prepare")
    app$click("show")
    app$wait_for_js("window.gestures.length === 3")
    app$wait_for_js("['startup','earlier','same'].every(id=>document.getElementById(id).dataset.shownMood==='happy')")
    for (id in c("startup", "earlier", "same")) {
      expect_identical(app$get_js(sprintf("document.getElementById('%s').dataset.shownMood", id)), "happy")
    }
    expect_identical(app$get_js("document.querySelector('#earlier .mascot-status').textContent"), "Earlier")
    expect_identical(app$get_js("document.querySelector('#same .mascot-status').textContent"), "Same cycle")
    expect_identical(app$get_js("gestures.find(x=>x.id==='earlier').name"), "wave")
    expect_identical(app$get_js("gestures.find(x=>x.id==='same').name"), "nod")
    expect_true(app$get_js("gestures.every(x=>x.mood==='happy' && x.character==='tessa')"))
    # A stale re-send and a replacement must both preserve the one-off contract.
    app$run_js(
      "const el=document.getElementById('earlier');
      mascot.host.receive({id:'earlier',patch:{gesture:'wave'},revision:1,gestureRevision:1,replay:true});
      Shiny.unbindAll(document.getElementById('slot'));
      Shiny.bindAll(document.getElementById('slot'));"
    )
    app$wait_for_idle()
    expect_equal(app$get_js("gestures.length"), 3)
  })
})

describe("bubble visibility in Shiny tabs", {
  it("pauses a timed bubble in a hidden tab and resumes its remaining lifetime", {
    local_shiny_browser()
    app <- shinytest2::AppDriver$new(function() {
      library(mascot)
      ui <- shiny::fluidPage(shiny::tabsetPanel(
        id = "tabs",
        shiny::tabPanel("Helper", mascot(id = "helper"), shiny::actionButton("say", "Say")),
        shiny::tabPanel("Other", "Other tab")
      ))
      server <- function(input, output, session) {
        shiny::observeEvent(input$say, updateMascot("helper", bubble = mascot_bubble("Timed", duration = 3)))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$click("say")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).bubble !== null")
    app$click(selector = "a[data-value='Other']")
    app$wait_for_js("document.querySelector('#helper canvas').getBoundingClientRect().width===0")
    remaining <- app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining")
    expect_gt(remaining, 0)
    app$run_js("window.hiddenUntil=Date.now()+3500")
    app$wait_for_js("Date.now() >= window.hiddenUntil", timeout = 10000)
    expect_equal(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining"), remaining)
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("document.querySelector('#helper canvas').getBoundingClientRect().width>0")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Timed")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).bubble === null", timeout = 10000)
  })
})

describe("retained development problems", {
  it("keeps the last good state with a problem overlay and clears the overlay on recovery", {
    local_mocked_bindings(dev_mode = function() TRUE)
    captured <- new.env(parent = emptyenv())
    captured$messages <- list()
    shiny::testServer(function(input, output, session) {}, {
      session$sendCustomMessage <- function(type, message) {
        captured$messages[[length(captured$messages) + 1L]] <- message
      }
      updateMascot("helper", mood = "happy", status = "Kept", session = session)
      expect_warning(updateMascot("helper", mood = "missing", status = "Wrong", session = session), "unchanged")
      session$setInputs(helper = list(mount = 1, revision = 0))
      patch <- captured$messages[[3]]$patch
      expect_identical(patch$mood, "happy")
      expect_identical(patch$status$text, "Kept")
      expect_match(patch$problem, "missing")
      updateMascot("helper", mood = "thinking", session = session)
      session$setInputs(helper = list(mount = 2, revision = 0))
      expect_null(captured$messages[[5]]$patch$problem)
      expect_identical(captured$messages[[5]]$patch$mood, "thinking")
    })
  })
})
