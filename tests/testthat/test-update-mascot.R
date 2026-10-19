describe("update_mascot()", {
  it("sends only supplied fields in a module, with the namespace added once", {
    calls <- new.env(parent = emptyenv())
    calls$messages <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      calls$messages[[length(calls$messages) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$go, {
          session$userData$result <- withVisible(update_mascot("helper", mood = "happy"))
        })
      })
    }
    shiny::testServer(module, {
      session$setInputs(go = 1)
      expect_identical(session$userData$result, list(value = NULL, visible = FALSE))
      expect_identical(calls$messages[[1]], list(id = session$ns("helper"), patch = list(mood = "happy")))
      expect_identical(calls$messages[[1]]$id, "proxy1-helper")
      update_mascot("helper", character = mascot_character(), mood = mascot_mood("thinking"), session = session)
      expect_identical(
        calls$messages[[2]]$patch,
        list(
          character = list(id = "tessa", name = "Tessa", json = character_json("tessa")),
          mood = "thinking"
        )
      )
      update_mascot("helper", status = "Saving", session = session)
      expect_identical(calls$messages[[3]]$patch, list(status = list(mode = "custom", text = "Saving")))
      update_mascot("helper", status = mascot_status(), session = session)
      expect_identical(calls$messages[[4]]$patch, list(status = list(mode = "mood")))
      update_mascot("helper", status = htmltools::HTML("<b>Saving</b>"), session = session)
      expect_identical(calls$messages[[5]]$patch$status$text, "<b>Saving</b>")
      expect_invisible(update_mascot("helper", session = session))
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
    expect_snapshot(update_mascot(
      "helper",
      character = "unknown_character",
      mood = "hapy",
      status = "",
      session = session
    ))
    expect_snapshot(update_mascot("helper", mood = "ha!py", session = session))
    for (x in list(1, "", NA_character_, c("a", "b"))) {
      expect_warning(update_mascot("helper", character = x, session = session), "unchanged")
      expect_warning(update_mascot("helper", mood = x, session = session), "unchanged")
      expect_warning(update_mascot("helper", status = x, session = session), "mascot_status")
    }
    expect_warning(update_mascot("{helper", mood = "{oops", status = "Saved", session = session), "not a mood")
    expect_length(calls$patches, 0)
    local_mocked_bindings(dev_mode = function() TRUE)
    expect_warning(update_mascot("helper", mood = "ha!py", status = "Saved", session = session), "unchanged")
    expect_length(calls$patches, 1)
    expect_named(calls$patches[[1]], "problem")
    expect_match(calls$patches[[1]]$problem, "^mascot: .*ha!py")
  })
  it("lists Tessa's gestures when a well-formed id is not available", {
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    local_mocked_bindings(dev_mode = function() FALSE)
    update_mascot("a", character = "tessa", session = session)
    expect_snapshot(update_mascot("a", gesture = mascot_gesture("waev"), session = session))
  })
  it("errors on code mistakes before inspecting runtime values", {
    session <- shiny::MockShinySession$new()
    expect_error(update_mascot("helper", session = NULL), "inside a Shiny server function or module")
    expect_error(update_mascot("helper", session = 1), "Assertion on 'session' failed")
    expect_error(update_mascot(), "missing")
    for (id in list(1, "", "has space", NA_character_)) {
      expect_error(update_mascot(id, session = session), "Assertion on 'id' failed")
    }
    expect_snapshot(error = TRUE, update_mascot("helper", typo = 1, session = session))
    expect_snapshot(error = TRUE, update_mascot("helper", NULL, NULL, NULL, NULL, session))
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
    withr::defer(session$close())
    send_update(session, "helper", list(mood = "happy"))
    expect_null(captured$message) # no known/live mount yet
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    token <- mascot_mount_token(session$ns("helper"), state, session)
    mascot_snapshot(protocol_snapshot(token), session, session$ns("helper"))
    session$flushReact()
    expect_identical(captured$type, "mascot:update")
    expect_identical(captured$message$id, session$ns("helper"))
    expect_identical(captured$message$state$mood, "happy")
    expect_identical(captured$message$version, 1L)
    expect_identical(captured$message$generation, 1)
    expect_true(captured$message$restore)
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

describe("update_mascot() in a browser", {
  it("changes mood, sets plain status text and returns it to the mood", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(
        mascot(id = "helper"),
        shiny::actionButton("think", "Think"),
        shiny::actionButton("save", "Save"),
        shiny::actionButton("happy", "Happy"),
        shiny::actionButton("reset", "Follow mood")
      )
      server <- function(input, output, session) {
        shiny::observeEvent(input$think, update_mascot("helper", mood = "thinking"))
        shiny::observeEvent(input$save, update_mascot("helper", status = "<b>Saved</b>"))
        shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy"))
        shiny::observeEvent(input$reset, update_mascot("helper", status = mascot_status()))
      }
      shiny::shinyApp(ui, server)
    })
    withr::defer(app$stop())
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'idle'")
    app$click("think")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'thinking'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "Working out how the parts fit."
    )
    app$click("save")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent === '<b>Saved</b>'")
    app$click("happy")
    app$wait_for_js("document.querySelector('#helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').innerHTML"),
      "&lt;b&gt;Saved&lt;/b&gt;"
    )
    app$click("reset")
    app$wait_for_js("document.querySelector('#helper .mascot-status').textContent === 'That came together nicely.'")
    expect_identical(
      app$get_js("document.querySelector('#helper canvas').getAttribute('aria-label')"),
      "Tessa, That came together nicely."
    )
  })
  it("updates a module mascot using its local server id", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      module_ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(mascot(id = ns("helper")), shiny::actionButton(ns("go"), "Go"))
      }
      module_server <- function(id) {
        shiny::moduleServer(id, function(input, output, session) {
          shiny::observeEvent(input$go, update_mascot("helper", mood = "happy"))
        })
      }
      shiny::shinyApp(shiny::fluidPage(module_ui("mod")), function(input, output, session) module_server("mod"))
    })
    withr::defer(app$stop())
    app$click("mod-go")
    app$wait_for_js("document.querySelector('#mod-helper').dataset.shownMood === 'happy'")
    expect_identical(
      app$get_js("document.querySelector('#mod-helper .mascot-status').textContent"),
      "That came together nicely."
    )
  })
  it("keeps updates before renderUI and destroys the replaced element's record", {
    local_shiny_browser()
    app <- app_driver(function() {
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
          update_mascot("late", mood = "thinking")
          update_mascot("late", mood = "happy", status = "Ready")
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


describe("update_mascot() bubbles and gestures", {
  it("sends complete bubble patches, JSON-safe Inf, clear and gesture names", {
    calls <- new.env(parent = emptyenv())
    calls$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      calls$patches[[length(calls$patches) + 1L]] <- patch
    })
    shiny::testServer(function(input, output, session) {}, {
      update_mascot("helper", bubble = "Ready", gesture = "nod", session = session)
      expect_identical(
        calls$patches[[1]],
        list(
          bubble = list(text = "Ready", html = FALSE, closable = TRUE, duration = 5),
          gesture = "nod"
        )
      )
      update_mascot(
        "helper",
        bubble = mascot_bubble(htmltools::HTML("<b>Ready</b>"), duration = Inf, closable = FALSE),
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
      update_mascot("helper", bubble = htmltools::HTML("<b>Ready</b>"), session = session)
      expect_true(calls$patches[[3]]$bubble$html)
      update_mascot("helper", bubble = mascot_bubble(), session = session)
      expect_identical(calls$patches[[4]], list(bubble = list(clear = TRUE)))
      update_mascot("helper", bubble = NULL, gesture = NULL, session = session)
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
      expect_warning(update_mascot("a", mood = "happy", bubble = x, session = session), "bubble")
      expect_warning(update_mascot("a", status = "Ready", gesture = x, session = session), "gesture")
    }
    expect_warning(update_mascot("a", bubble = "Ready", gesture = "jump!", session = session), "not a gesture")
    bad <- mascot_bubble("Ready")
    for (field in c("text", "html", "duration", "closable")) {
      value <- bad
      value[[field]] <- NA
      expect_warning(update_mascot("a", mood = "happy", bubble = value, session = session), "bubble")
    }
    expect_length(calls$patches, 0)
    local_mocked_bindings(dev_mode = function() TRUE)
    expect_warning(update_mascot("a", mood = "happy", bubble = "", gesture = "jump!", session = session), "unchanged")
    expect_named(calls$patches[[1]], "problem")
    expect_match(calls$patches[[1]]$problem, "bubble.*gesture")
  })
})

describe("server bubbles and gestures in a browser", {
  it("shows a server bubble, accepts a gesture and lets the user close it", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(mascot(id = "helper"), shiny::actionButton("go", "Go"))
      server <- function(input, output, session) {
        shiny::observeEvent(input$go, {
          update_mascot("helper", bubble = mascot_bubble("Ready", duration = Inf), gesture = "wave")
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
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "Resting, ready for the next piece."
    )
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
      update_mascot("helper", bubble = deferred, session = session)
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
      update_mascot("helper", mood = "happy", bubble = deferred, session = session),
      "Cannot render message"
    )
    expect_identical(calls$count, 1L)
    expect_length(calls$patches, 0)
    local_mocked_bindings(dev_mode = function() TRUE)
    expect_warning(update_mascot("helper", bubble = deferred, session = session), "Cannot render message")
    expect_named(calls$patches[[1]], "problem")
    expect_match(calls$patches[[1]]$problem, "Cannot render message")
  })
  it("G7 diagnoses an unnamed session before warning about runtime values", {
    shiny::testServer(function(input, output, session) {}, {
      expect_error(update_mascot("helper", mood = "happy", session), "session")
      for (arg in c("character", "mood", "status", "bubble")) {
        args <- list(id = "helper")
        args[[arg]] <- session
        expect_error(do.call(update_mascot, args), "session")
      }
    })
    for (class in c("ShinySession", "session_proxy", "MockShinySession")) {
      misplaced <- structure(list(), class = class)
      expect_error(update_mascot("helper", misplaced, session = NULL), "session")
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
      update_mascot("helper", bubble = mascot_bubble("Ready", duration = Inf), session = session)
      expect_null(calls$patches[[1]]$bubble$duration)
      update_mascot("helper", bubble = shiny::tags$strong("Saved"), session = session)
      expect_identical(calls$patches[[2]]$bubble$text, "<strong>Saved</strong>")
      expect_true(calls$patches[[2]]$bubble$html)
      update_mascot("helper", bubble = htmltools::tagList(shiny::tags$strong("Saved")), session = session)
      expect_true(calls$patches[[3]]$bubble$html)
      dependency <- htmltools::htmlDependency("bubble-test", "1.0", src = c(file = tempdir()))
      dependent <- htmltools::attachDependencies(shiny::tags$strong("Saved"), dependency)
      expect_warning(
        update_mascot("helper", mood = "happy", bubble = dependent, session = session),
        "dependencies.*not supported"
      )
      expect_length(calls$patches, 3)
    })
  })
  it("G2 names nod and wave in the gesture argument's help", {
    path <- system.file("man", "update_mascot.Rd", package = "mascot")
    rd <- if (nzchar(path)) tools::parse_Rd(path) else tools::Rd_db("mascot")[["update_mascot.Rd"]]
    arguments <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\arguments"), rd)[[1]]
    items <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\item"), arguments)
    item <- Filter(function(x) identical(paste(unlist(x[[1]]), collapse = ""), "gesture"), items)[[1]]
    text <- paste(unlist(item[[2]]), collapse = "")
    expect_match(text, '"nod"', fixed = TRUE)
    expect_match(text, '"wave"', fixed = TRUE)
  })
})


describe("update_mascot() size and placement", {
  it("sends complete normalised objects, adds the module namespace once and leaves NULL alone", {
    captured <- new.env(parent = emptyenv())
    captured$messages <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$messages[[length(captured$messages) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$layout, {
          update_mascot("helper", size = "20%", placement = list(position = "top-left"))
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
            size = list(size = "20%", small_screen = "auto"),
            placement = list(floating = TRUE, position = "top-left", minimise = TRUE, drag = FALSE)
          )
        )
      )
      update_mascot("helper", size = mascot_size(120, small_screen = 48), placement = "inline", session = session)
      expect_identical(
        captured$messages[[2]]$patch,
        list(
          size = list(size = 120, small_screen = 48),
          placement = list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
        )
      )
      update_mascot("helper", placement = mascot_placement("top-left", drag = "free"), session = session)
      expect_identical(
        captured$messages[[3]]$patch,
        list(placement = list(floating = TRUE, position = "top-left", minimise = TRUE, drag = "free"))
      )
      update_mascot("helper", placement = list(position = "bottom-left", drag = "snap"), session = session)
      expect_identical(captured$messages[[4]]$patch$placement$drag, "snap")
      update_mascot("helper", size = NULL, placement = NULL)
      expect_length(captured$messages, 4)
      expect_error(update_mascot("helper", NULL, NULL, NULL, NULL, session), "session")
      expect_error(update_mascot("helper", NULL, NULL, NULL, NULL, NULL, session), "session")
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
        expect_warning(update_mascot("a", size = x, mood = "happy"), "unchanged")
      }
      bad_place <- mascot_placement("inline")
      bad_place$minimise <- NA
      bad_drag <- mascot_placement("inline")
      bad_drag$drag <- "fixed"
      for (x in list("fixed", list(floating = TRUE, snap = TRUE), bad_place, bad_drag)) {
        expect_warning(update_mascot("a", placement = x, status = "Saved"), "unchanged")
      }
      expect_warning(
        update_mascot("a", placement = list(position = "top-left", drag = TRUE)),
        "unchanged.*drag.*got TRUE"
      )
      expect_warning(
        update_mascot("a", placement = list(position = "top-left", drag = "fixed")),
        'unchanged.*drag.*"fixed"'
      )
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(update_mascot("a", size = 1, placement = "fixed", mood = "happy"), "unchanged")
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
        expect_silent(update_mascot("a", placement = placement, session = session))
        expect_identical(tail(captured$patches, 1)[[1]], list(placement = wire))
      }
      for (controls in list(
        list(minimise = TRUE),
        list(minimise = FALSE),
        list(drag = "snap"),
        list(drag = "free"),
        list(drag = "none")
      )) {
        before <- length(captured$patches)
        expect_message(
          update_mascot("a", placement = c(list(position = "inline"), controls), status = "Saved", session = session),
          paste0(names(controls), ".*no effect.*inline"),
          class = "mascot_placement_ignored"
        )
        expect_length(captured$patches, before + 1L)
        patch <- tail(captured$patches, 1)[[1]]
        expect_identical(patch$placement, wire)
        expect_identical(patch$status$text, "Saved")
        expect_null(patch$problem)
      }
      expect_snapshot(update_mascot("a", placement = list(position = "inline", minimise = TRUE), session = session))
      expect_snapshot(update_mascot("a", placement = list(position = "inline", drag = "snap"), session = session))
      expect_snapshot(update_mascot("a", placement = mascot_placement("inline", minimise = TRUE), session = session))
      expect_snapshot(update_mascot("a", placement = mascot_placement("inline", drag = "free"), session = session))
      expect_identical(tail(captured$patches, 1)[[1]], list(placement = wire))
    })
  })
})


describe("size and placement in a Shiny browser", {
  it("floats, minimises and restores with mouse, Enter and Space while retaining server updates", {
    local_shiny_browser()
    app <- app_driver(function() {
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
            update_mascot(
              "helper",
              size = 64,
              mood = "happy",
              placement = mascot_placement("top-left", minimise = TRUE),
              bubble = mascot_bubble("Saved", duration = Inf)
            )
          )
          shiny::observeEvent(input$inline, update_mascot("helper", size = 120, placement = "inline"))
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
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "That came together nicely."
    )
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
    # Restore scales the canvas briefly; measure its layout after that movement ends.
    app$wait_for_js("document.querySelector('#helper canvas').getAnimations().length === 0")
    expect_equal(app$get_js("document.querySelector('#helper canvas').getBoundingClientRect().width"), 120)
    expect_equal(app$get_js("mounts"), 0)
    expect_true(app$get_js("document.querySelector('#helper .mascot-minimise').hidden"))
  })
  it("measures a module mascot when its hidden tab opens and accepts a local-id layout update", {
    local_shiny_browser()
    app <- app_driver(function() {
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
          shiny::observeEvent(input$change, update_mascot("helper", size = 48, placement = "top-right"))
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
    app <- app_driver(function() {
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
    app$wait_for_js("Shiny.shinyapp.$inputValues['.clientdata_output_mod-dynamic_hidden'] === false")
    app$wait_for_js("document.querySelector('#mod-helper canvas')?.getBoundingClientRect().width === 64")
    app$run_js("window.old=document.getElementById('mod-helper')")
    expect_true(app$get_js("old.parentElement===document.body"))
    expect_equal(app$get_js("document.querySelectorAll('.mascot-source.shiny-bound-input').length"), 1)
    expect_false(app$get_js("old.classList.contains('shiny-bound-input')"))
    app$click(selector = "#mod-replace")
    app$wait_for_js(
      "document.getElementById('mod-helper') !== old && mascot.host.state(old) === null"
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

describe("update_mascot() themes", {
  it("sends one normalised theme in a module and leaves NULL unchanged", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$patches[[length(captured$patches) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) shiny::moduleServer(id, function(input, output, session) {})
    shiny::testServer(module, {
      theme <- mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"), mode = "auto")
      expect_invisible(update_mascot("helper", theme = theme, mood = "happy", session = session))
      expect_identical(captured$patches[[1]]$id, session$ns("helper"))
      expect_named(captured$patches[[1]]$patch, c("mood", "theme"))
      expect_identical(captured$patches[[1]]$patch$theme$mode, "auto")
      expect_identical(captured$patches[[1]]$patch$theme$dark$body, "#9EC5FE")
      update_mascot("helper", theme = NULL, session = session)
      expect_length(captured$patches, 1)
      update_mascot("helper", character = "tessa", theme = mascot_theme(), session = session)
      expect_identical(
        captured$patches[[2]]$patch$theme,
        list(light = NULL, dark = NULL, mode = "auto", css = NULL, brand = NULL)
      )
      update_mascot("helper", theme = list(body = "#1f6feb"), session = session)
      expect_identical(captured$patches[[3]]$patch$theme$light, captured$patches[[3]]$patch$theme$dark)
    })
  })
  it("warns for bad themes atomically, sends only a development problem, and retains contrast warnings", {
    withr::local_options(mascot.contrast_warnings = TRUE)
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
        expect_warning(update_mascot("helper", theme = theme, mood = "happy", status = "Saved"), "unchanged")
      }
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(update_mascot("helper", theme = list(bdoy = "blue"), character = "missing"), "unchanged")
      expect_named(captured$patches[[1]], "problem")
      expect_match(captured$patches[[1]]$problem, "bdoy")
      expect_warning(update_mascot("helper", theme = mascot_theme(light = list(body = "white"))), "below 3:1")
      expect_identical(captured$patches[[2]]$theme$light$body, "#FFFFFF")
      expect_null(captured$patches[[2]]$problem)
      expect_error(update_mascot("helper", theme = session), "session")
    })
  })
})

describe("theme in a Shiny browser", {
  it("T4 follows a bslib dark-mode input with no mode argument or server theme updates", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- app_driver(function() {
      library(mascot)
      shiny::shinyApp(
        bslib::page_fluid(
          bslib::input_dark_mode(id = "dark_mode", mode = "light"),
          mascot(id = "helper", theme = mascot_theme(light = list(body = "#1f6feb"), dark = list(body = "#9ec5fe"))),
          shiny::actionButton("reset", "Character colours")
        ),
        function(input, output, session) {
          shiny::observeEvent(input$reset, update_mascot("helper", theme = mascot_theme()))
        }
      )
    })
    withr::defer(app$stop())
    app$wait_for_js("window.mascot?.host?.state(document.getElementById('helper'))?.colours.body === '#1F6FEB'")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).mode"), "light")
    app$run_js(
      "window.drawnBodies=[];if (mascot.geometry) { const origGeo=mascot.geometry.draw; mascot.geometry = { ...mascot.geometry, draw: (ctx,c,s,colours,o)=>{if (colours?.body) drawnBodies.push(colours.body); return origGeo(ctx,c,s,colours,o);}}; } const draw=mascot.draw;mascot.draw=(ctx,ch,options)=>{drawnBodies.push(options.colours.body || ch.colours.body);return draw(ctx,ch,options)}"
    )
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === '#9EC5FE'")
    app$wait_for_js("drawnBodies.at(-1)==='#9EC5FE'")
    expect_identical(app$get_js("document.documentElement.dataset.bsTheme"), "dark")
    app$run_js("document.getElementById('dark_mode').shadowRoot.querySelector('button').click()")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === '#1F6FEB'")
    app$click("reset")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).colours.body === null")
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "Resting, ready for the next piece."
    )
  })
})

describe("update_mascot() motion", {
  it("sends a safe motion patch once per module update and leaves NULL unchanged", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$patches[[length(captured$patches) + 1L]] <- list(id = session$ns(id), patch = patch)
    })
    module <- function(id) shiny::moduleServer(id, function(input, output, session) {})
    shiny::testServer(module, {
      for (motion in list(TRUE, FALSE, mascot_motion_settings(swap = FALSE), mascot_motion_settings(others = FALSE))) {
        expect_invisible(update_mascot("helper", motion = motion, mood = "happy", session = session))
        sent <- tail(captured$patches, 1)[[1]]
        expect_identical(sent$id, session$ns("helper"))
        expect_named(sent$patch, c("mood", "motion"))
        expect_false(identical(sent$patch$motion$reduced, FALSE))
      }
      expect_identical(captured$patches[[1]]$patch$motion, as_motion_arg(TRUE, environment()))
      expect_identical(captured$patches[[2]]$patch$motion, as_motion_arg(FALSE, environment()))
      expect_identical(
        captured$patches[[3]]$patch$motion,
        as_motion_arg(mascot_motion_settings(swap = FALSE), environment())
      )
      update_mascot("helper", motion = NULL, session = session)
      expect_length(captured$patches, 4)
      expect_error(update_mascot("helper", motion = session), "session")
    })
    expect_identical(
      tail(names(formals(update_mascot)), 6),
      c("placement", "theme", "motion", "click", "gesture", "session")
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
      for (motion in list(NA, 1, "auto", list(animate = TRUE), structure(list(), class = "mascot_motion_settings"))) {
        expect_warning(update_mascot("helper", mood = "happy", status = "Saved", motion = motion), "unchanged")
      }
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(update_mascot("helper", motion = "auto", size = 96), "motion.*TRUE, FALSE")
      expect_named(captured$patches[[1]], "problem")
      expect_match(captured$patches[[1]]$problem, 'got "auto"')
      update_mascot("helper", motion = FALSE)
      expect_identical(captured$patches[[2]], list(motion = as_motion_arg(FALSE, environment())))
    })
  })
})

describe("motion in a Shiny browser", {
  it("M5 changes motion from an app setting without replacing the canvas", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      shiny::shinyApp(
        shiny::fluidPage(
          mascot(id = "helper"),
          shiny::checkboxInput("animate", "Animate mascot", TRUE),
          shiny::actionButton("happy", "Happy")
        ),
        function(input, output, session) {
          shiny::observeEvent(input$animate, update_mascot("helper", motion = input$animate))
          shiny::observeEvent(input$happy, update_mascot("helper", mood = "happy"))
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
    expect_identical(
      app$get_js("document.querySelector('#helper .mascot-status').textContent"),
      "That came together nicely."
    )
    expect_true(app$get_js("document.querySelector('#helper canvas') === originalCanvas"))
    app$set_inputs(animate = TRUE)
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).motion.reduced === null")
    expect_identical(app$get_js("document.getElementById('helper').dataset.reduced"), "auto")
  })
})

describe("update_mascot() popup menu", {
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
      update_mascot("helper", click = "Open help")
      expect_identical(captured$patches[[1]]$id, session$ns("helper"))
      expect_identical(
        captured$patches[[1]]$patch,
        list(click = list(type = "action", label = "Open help", tooltip = TRUE, disabled = FALSE))
      )
      # NULL leaves the click unchanged; either empty helper removes it.
      update_mascot("helper", click = NULL)
      expect_length(captured$patches, 1)
      update_mascot("helper", click = mascot_popup_menu())
      expect_identical(captured$patches[[2]]$patch$click, list(type = "none"))
      update_mascot("helper", click = mascot_action())
      expect_identical(captured$patches[[3]]$patch$click, list(type = "none"))
      update_mascot("helper", click = mascot_popup_menu(c(about = "About"), direction = "right"))
      expect_identical(
        captured$patches[[4]]$patch$click,
        list(type = "menu", items = list(about = "About"), direction = "right", label = NULL, tooltip = TRUE)
      )
      update_mascot("helper", click = mascot_action("Open help", disabled = TRUE))
      expect_true(captured$patches[[5]]$patch$click$disabled)
      for (bad in list(1, c(about = "About"), character(), structure(list(), class = "mascot_popup_menu"))) {
        expect_warning(update_mascot("helper", mood = "happy", click = bad), "unchanged")
      }
      expect_length(captured$patches, 5)
      local_mocked_bindings(dev_mode = function() TRUE)
      expect_warning(update_mascot("helper", mood = "happy", click = c(about = "About")), "unchanged")
      expect_named(captured$patches[[6]]$patch, "problem")
      expect_error(update_mascot("helper", click = session), "session")
    })
    expect_identical(utils::tail(names(formals(update_mascot)), 5), c("theme", "motion", "click", "gesture", "session"))
  })
})

describe("popup menu in a Shiny browser", {
  it("P6 receives repeated choices in a module and opens the app's modal", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      ui <- function(id) {
        ns <- shiny::NS(id)
        shiny::tagList(
          mascot(id = ns("helper"), click = mascot_popup_menu(c(about = "About this app"))),
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
  it("D4 runs the help example for idle movement and a nod", {
    local_shiny_browser()
    rd <- local_help_page("mascot_motion_settings")
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
    app <- app_driver(app_function)
    withr::defer(app$stop())
    app$wait_for_js("!!window.mascot?.host?.state(document.getElementById('helper'))")
    app$set_inputs(idle = FALSE)
    app$wait_for_js("document.getElementById('helper').dataset.idle==='false'")
    app$click("nod")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).mood === 'idle'")
    expect_identical(app$get_js("document.getElementById('helper').dataset.idle"), "false")
    app$set_inputs(idle = TRUE)
    app$wait_for_js("document.getElementById('helper').dataset.idle==='true'")
  })
  it("D4 runs the complete module help block and receives repeated choices", {
    local_shiny_browser()
    rd <- local_help_page("mascot_popup_menu")
    details <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\details"), rd)[[1]]
    block <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\preformatted"), details)[[1]]
    expressions <- parse(text = paste(unlist(block), collapse = ""))
    app_function <- function() NULL
    body(app_function) <- as.call(c(list(quote(`{`), quote(library(mascot))), as.list(expressions)))
    app <- app_driver(app_function)
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
  it("coalesces complete module state on ready and releases it on session end", {
    root <- shiny::MockShinySession$new()
    withr::defer(root$close())
    messages <- list()
    unlockBinding("sendCustomMessage", root)
    root$sendCustomMessage <- function(type, message) messages[[length(messages) + 1L]] <<- message
    session <- root$makeScope("proxy1")
    shiny::withReactiveDomain(session, {
      update_mascot("helper", mood = "thinking", gesture = "nod")
      update_mascot("helper", mood = "happy", status = "Ready", gesture = "wave")
    })
    expect_length(messages, 0)
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    token <- mascot_mount_token(session$ns("helper"), state, session)
    root$setInputs(`proxy1-helper` = protocol_snapshot(token))
    expect_length(messages, 1)
    latest <- messages[[1]]
    expect_identical(latest$id, "proxy1-helper")
    expect_identical(latest$state$mood, "happy")
    expect_identical(latest$state$status$text, "Ready")
    expect_identical(latest$gesture$name, "wave")
    root$setInputs(`proxy1-helper` = protocol_snapshot(token, 2))
    expect_length(messages, 2)
    expect_identical(messages[[2]]$revision, latest$revision)
    root$close()
    expect_null(root$userData$mascot_updates)
  })
  it("recovers startup, earlier-cycle and same-cycle updates for the first renderUI mascots, playing gestures once", {
    local_shiny_browser()
    app <- app_driver(function() {
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
        update_mascot("startup", mood = "happy", gesture = "wave")
        shiny::observeEvent(input$prepare, {
          update_mascot("earlier", mood = "thinking", status = "Earlier", gesture = "nod")
          update_mascot("earlier", mood = "happy", gesture = "wave")
        })
        shiny::observeEvent(input$show, {
          update_mascot("same", mood = "happy", status = "Same cycle", gesture = "nod")
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
    app <- app_driver(function() {
      library(mascot)
      ui <- shiny::fluidPage(shiny::tabsetPanel(
        id = "tabs",
        shiny::tabPanel("Helper", mascot(id = "helper"), shiny::actionButton("say", "Say")),
        shiny::tabPanel("Other", "Other tab")
      ))
      server <- function(input, output, session) {
        shiny::observeEvent(input$say, update_mascot("helper", bubble = mascot_bubble("Timed", duration = 3)))
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
    # Move the page's clock 3.5 seconds on (longer than the bubble's 3) instead of waiting: a countdown still
    # running while hidden would now read 0, while a paused one keeps its time.
    app$run_js(
      "window.realNow=performance.now.bind(performance);performance.now=()=>realNow()+3500;"
    )
    expect_equal(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.remaining"), remaining)
    app$run_js("performance.now=window.realNow")
    app$click(selector = "a[data-value='Helper']")
    app$wait_for_js("document.querySelector('#helper canvas').getBoundingClientRect().width>0")
    expect_identical(app$get_js("mascot.host.state(document.getElementById('helper')).bubble.text"), "Timed")
    app$wait_for_js("mascot.host.state(document.getElementById('helper')).bubble === null")
  })
})

describe("development problems and desired state", {
  it("does not let an ignored call overwrite the last good state", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    update_mascot("helper", mood = "happy", status = "Kept", session = f$session)
    before <- protocol_record(f)
    expect_warning(update_mascot("helper", mood = "missing", status = "Wrong", session = f$session), "unchanged")
    expect_identical(protocol_record(f), before)
    latest <- protocol_flush(f)
    expect_identical(latest$state$mood, "happy")
    expect_identical(latest$state$status$text, "Kept")
    update_mascot("helper", mood = "thinking", session = f$session)
    expect_identical(protocol_flush(f)$state$mood, "thinking")
  })
})

describe("update_mascot() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(
      names(formals(update_mascot)),
      c(
        "id",
        "...",
        "character",
        "mood",
        "status",
        "bubble",
        "size",
        "placement",
        "theme",
        "motion",
        "click",
        "gesture",
        "session"
      )
    )
    expect_error(
      update_mascot("helper", session = shiny::MockShinySession$new(), typo = 1),
      "Unexpected arguments",
      class = "mascot_error"
    )
    expect_error(
      update_mascot("helper", session = shiny::MockShinySession$new(), 1),
      "Name the optional arguments",
      class = "mascot_error"
    )
  })
})


describe("update conditions", {
  it("warns with both classes and sends no patch for removed or invalid values", {
    captured <- new.env(parent = emptyenv())
    captured$patches <- list()
    local_mocked_bindings(
      dev_mode = function() FALSE,
      send_update = function(session, id, patch) captured$patches <- c(captured$patches, list(patch))
    )
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    expect_warning(update_mascot("helper", mood = "sleepy!", session = session), class = "mascot_update_ignored")
    expect_warning(
      update_mascot("helper", placement = "floating", session = session),
      "bottom-right",
      class = "mascot_warning"
    )
    for (drag in c(FALSE, TRUE)) {
      expect_warning(
        update_mascot("helper", mood = "happy", placement = list(drag = drag), session = session),
        'drag = "none"',
        class = "mascot_update_ignored"
      )
    }
    expect_length(captured$patches, 0)
    expect_error(update_mascot("helper", session = NULL), class = "mascot_error")
  })
  it("applies contrast options without turning a kept colour into an ignored update", {
    local_mocked_bindings(in_devmode = function() FALSE, .package = "shiny")
    captured <- new.env(parent = emptyenv())
    local_mocked_bindings(send_update = function(session, id, patch) captured$patch <- patch)
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    theme <- mascot_theme(light = list(body = "white"))
    withr::local_options(mascot.contrast_warnings = NULL)
    expect_silent(update_mascot("helper", theme = theme, session = session))
    expect_identical(captured$patch$theme$light$body, "#FFFFFF")
    withr::local_options(mascot.contrast_warnings = TRUE)
    expect_warning(update_mascot("helper", theme = theme, session = session), class = "mascot_contrast")
    expect_identical(captured$patch$theme$light$body, "#FFFFFF")
    withr::local_options(mascot.contrast_warnings = FALSE)
    expect_silent(update_mascot("helper", theme = theme, session = session))
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(update_mascot(id = 1, session = NULL), "id", class = "mascot_error")
    expect_error(update_mascot("helper", session = 1), "session", class = "mascot_error")
  })
})

describe("motion settings payloads", {
  it("sends named overrides and a skipped gesture together with the rest of the update", {
    captured <- new.env(parent = emptyenv())
    local_mocked_bindings(send_update = function(session, id, patch) {
      captured$patch <- patch
    })
    shiny::testServer(function(input, output, session) {}, {
      update_mascot(
        "a",
        motion = mascot_motion_settings(gestures = FALSE, messages = "menu", others = TRUE),
        gesture = "wave",
        mood = "happy",
        status = "Saved",
        bubble = "Ready",
        session = session
      )
    })
    expect_false(captured$patch$motion$gestures)
    expect_true(captured$patch$motion$idle)
    expect_true(captured$patch$motion$mood_change)
    expect_true(captured$patch$motion$minimising)
    expect_true(captured$patch$motion$restoring)
    expect_identical(captured$patch$motion$messages, list("menu"))
    expect_identical(captured$patch$gesture, "wave")
    expect_identical(captured$patch$mood, "happy")
    expect_identical(captured$patch$status$text, "Saved")
    expect_identical(captured$patch$bubble$text, "Ready")
  })
})


describe("nested module ids", {
  it("accepts local and session-namespaced ids and replays the same state on remount", {
    root <- shiny::MockShinySession$new()
    withr::defer(root$close())
    messages <- list()
    unlockBinding("sendCustomMessage", root)
    root$sendCustomMessage <- function(type, message) messages[[length(messages) + 1L]] <<- message
    nested <- root$makeScope("first")$makeScope("review")
    other <- root$makeScope("second")$makeScope("review")
    shiny::withReactiveDomain(nested, {
      update_mascot(nested$ns("helper"), mood = "happy")
      update_mascot("helper", status = "Complete")
    })
    update_mascot("helper", mood = "thinking", session = other)
    expect_length(messages, 0)
    expect_setequal(ls(root$userData$mascot_updates), c("first-review-helper", "second-review-helper"))
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    token <- mascot_mount_token(nested$ns("helper"), state, nested)
    root$setInputs(`first-review-helper` = protocol_snapshot(token))
    root$flushReact()
    expect_identical(tail(messages, 1)[[1]]$id, "first-review-helper")
    expect_true(tail(messages, 1)[[1]]$restore)
    expect_identical(tail(messages, 1)[[1]]$state$status$text, "Complete")
  })
})


describe("nested modules across tabs", {
  it("keeps updates, menu inputs, dragging, minimising and motion local, including hidden dynamic UI", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    # Match the other browser tests: load the development package in the child R process.
    app_function <- function() NULL
    body(app_function) <- substitute(
      {
        library(mascot)
        shiny::shinyAppDir(DIR)
      },
      list(DIR = normalizePath(test_path("apps", "modules-tabs")))
    )
    app <- app_driver(app_function, width = 900, height = 700)
    withr::defer(app$stop())
    app$run_js("window.helperState=id=>mascot.host.state(document.getElementById(id+'-review-helper'));")
    app$wait_for_js("!!helperState('first') && !!helperState('second')")
    app$wait_for_js("document.getElementById('second-review-helper').dataset.sourceHidden === 'true'")
    # Updating a session$ns() id reaches only that nested module.
    app$click("first-review-go")
    app$wait_for_js("helperState('first').status.text === 'Complete'")
    expect_identical(app$get_js("helperState('first').mood"), "happy")
    expect_identical(app$get_js("helperState('second').mood"), "idle")
    app$click(selector = "#first-review-helper .mascot-menu-toggle")
    app$click(selector = "#first-review-helper [role=menuitem]")
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).menu === 'about'")
    events <- jsonlite::fromJSON(app$get_value(output = "first-review-events"))
    expect_identical(events$menu, "about")
    expect_null(events$click)
    expect_null(jsonlite::fromJSON(app$get_value(output = "second-review-events"))$menu)
    # A real pointer drop is received by the nested module's local input.
    app$run_js(
      "(() => {const c=document.querySelector('#first-review-helper canvas'),r=c.getBoundingClientRect();
      const x=r.left+r.width/2,y=r.top+r.height/2,send=(type,px,py)=>c.dispatchEvent(new PointerEvent(type,
      {bubbles:true,cancelable:true,pointerId:1,button:0,isPrimary:true,clientX:px,clientY:py}));
      send('pointerdown',x,y);send('pointermove',x-300,y-200);send('pointermove',x-700,y-500);
      send('pointerup',x-700,y-500);})()"
    )
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).position === 'top-left'")
    expect_identical(app$get_js("helperState('second').placement.position"), "bottom-left")
    app$click(selector = "#first-review-helper .mascot-minimise")
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).minimised === true")
    expect_false(app$get_js("helperState('second').minimised"))
    app$click(selector = "#first-review-helper .mascot-restore")
    app$wait_for_js("JSON.parse(document.getElementById('first-review-events').textContent).minimised === false")
    app$click("first-review-move")
    app$wait_for_js("helperState('first').placement.position === 'top-right' && !helperState('first').motion.others")
    expect_true(app$get_js("helperState('second').motion.mood_change"))
    expect_false(app$get_js("helperState('second').motion.idle"))
    # The second mascot accepts an update while hidden and keeps it when shown.
    app$click("hidden_update")
    app$wait_for_js("helperState('second').mood === 'thinking'")
    app$click(selector = "a[data-value=Second]")
    app$wait_for_js("document.getElementById('second-review-helper').dataset.sourceHidden === 'false'")
    expect_identical(app$get_js("helperState('second').mood"), "thinking")
    app$click("second-review-go")
    app$wait_for_js("helperState('second').status.text === 'Complete'")
    app$click(selector = "#second-review-helper .mascot-menu-toggle")
    app$click(selector = "#second-review-helper [role=menuitem]")
    app$wait_for_js("JSON.parse(document.getElementById('second-review-events').textContent).menu === 'about'")
    expect_false(app$get_js("helperState('first').menuOpen"))
    app$click("second-review-rebuild")
    app$wait_for_js(
      "document.getElementById('second-review-helper').dataset.generation === '2' && helperState('second')?.mood === 'happy'"
    )
    expect_identical(app$get_js("helperState('first').placement.position"), "top-right")
    expect_false(app$get_js("helperState('first').motion.others"))
    # Static and renderUI mascots share every engine resource, even after remount.
    for (file in c("mascot.js", "mascot-draw.js", "mascot-motion.js", "mascot-host.js")) {
      expect_equal(app$get_js(sprintf("document.querySelectorAll('script[src$=\"/%s\"]').length", file)), 1)
    }
    expect_equal(app$get_js("document.querySelectorAll('link[href$=\"/mascot.css\"]').length"), 1)
  })
})


describe("inline helper errors in update_mascot() (#349)", {
  it("sends the development overlay text when helpers fail", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    expect_warning(
      update_mascot("helper", size = mascot_size(-1), session = f$session),
      class = "mascot_update_ignored"
    )
    expect_match(protocol_flush(f)$problem, "^mascot: ")
  })
  it("lists every failed helper as its own bullet in one warning", {
    local_mocked_bindings(dev_mode = function() FALSE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    warning <- expect_warning(
      update_mascot("helper", size = mascot_size(-1), bubble = mascot_bubble(""), session = f$session),
      class = "mascot_update_ignored"
    )
    expect_equal(sum(grepl("^x ", strsplit(cli::ansi_strip(conditionMessage(warning)), "\n")[[1]])), 2)
  })
  it("warns without accepting any fields and lets the observer run again", {
    local_mocked_bindings(dev_mode = function() FALSE)
    shiny::testServer(
      function(input, output, session) {
        shiny::observeEvent(input$px, {
          update_mascot("helper", mood = "happy", size = mascot_size(input$px))
          session$userData$completed <- input$px
        })
      },
      {
        expect_warning(session$setInputs(px = -1), class = "mascot_update_ignored")
        expect_identical(session$userData$completed, -1)
        expect_null(session$userData$mascot_protocol)
        session$setInputs(px = 96)
        expect_identical(session$userData$completed, 96)
        expect_identical(
          session$userData$mascot_protocol$states[[session$ns("helper")]]$cold$free$calls[[1]]$patch$size$size,
          96
        )
      }
    )
  })
  it("catches mascot errors from every update argument without altering accepted state", {
    local_mocked_bindings(dev_mode = function() FALSE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    before <- protocol_record(f)
    for (arg in c(
      "character",
      "mood",
      "status",
      "bubble",
      "size",
      "placement",
      "theme",
      "motion",
      "click",
      "gesture"
    )) {
      call <- as.call(c(
        list(quote(update_mascot), "helper", session = f$session),
        setNames(list(quote(mascot_size(-1))), arg)
      ))
      expect_warning(eval(call), class = "mascot_update_ignored")
      expect_identical(protocol_record(f), before, info = arg)
    }
    expect_error(update_mascot("helper", size = stop("unrelated error"), session = f$session), "unrelated error")
    expect_error(update_mascot("helper", size = f$session, session = f$session), "session.*must be named")
  })
})
