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
  it("errors on code mistakes before inspecting runtime values", {
    session <- shiny::MockShinySession$new()
    expect_error(update_mascot("helper", session = NULL), "inside a Shiny server function or module")
    expect_error(update_mascot("helper", session = 1), "Assertion on 'session' failed")
    expect_error(update_mascot(), "missing")
    for (id in list(1, "", "has space", NA_character_)) {
      expect_error(update_mascot(id, session = session), "Assertion on 'id' failed")
    }
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
  })
})

describe("dev_mode()", {
  it("uses Shiny's development-mode decision", {
    expect_identical(dev_mode(), shiny::in_devmode())
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

describe("update_mascot() deferred tags, sessions and gesture help", {
  it("renders a deferred tag once and sends that exact result", {
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
  it("warns without sending when deferred tag rendering fails", {
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
  it("diagnoses an unnamed session before warning about runtime values", {
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
  it("sends untimed rendered tags and warns for unsupported dependencies", {
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
  it("names nod and wave in the gesture argument's help", {
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
      # A size helper with a field that mascot_size() does not make (simplify_when_small) is refused.
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
      expect_message(
        update_mascot("a", placement = mascot_placement("inline", drag = "free"), session = session),
        "drag.*no effect.*inline",
        class = "mascot_placement_ignored"
      )
      expect_identical(tail(captured$patches, 1)[[1]], list(placement = wire))
    })
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
        expect_warning(
          update_mascot("helper", character = "tessa", theme = theme, mood = "happy", status = "Saved"),
          "unchanged"
        )
      }
      expect_warning(
        update_mascot("helper", theme = list(Bdoy = "blue"), mood = "happy", status = "Saved"),
        "unchanged"
      )
      expect_length(captured$patches, 0)
      local_mocked_bindings(dev_mode = function() TRUE)
      withr::with_options(list(mascot.contrast_warnings = FALSE), {
        expect_warning(update_mascot("helper", theme = list(bdoy = "blue"), character = "missing"), "unchanged")
      })
      expect_named(captured$patches[[1]], "problem")
      expect_match(captured$patches[[1]]$problem, "missing")
      expect_false(grepl("bdoy", captured$patches[[1]]$problem, fixed = TRUE))
      expect_warning(update_mascot("helper", theme = mascot_theme(light = list(body = "white"))), "below 3:1")
      expect_identical(captured$patches[[2]]$theme$light$body, "#FFFFFF")
      expect_null(captured$patches[[2]]$problem)
      expect_error(update_mascot("helper", theme = session), "session")
    })
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
        list(
          type = "menu",
          items = list(about = "About"),
          direction = "right",
          label = NULL,
          tooltip = TRUE,
          disabled = FALSE
        )
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

describe("retained mascot updates", {
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
    expect_null(root$userData$mascot_protocol)
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
    expect_setequal(ls(root$userData$mascot_protocol$states), c("first-review-helper", "second-review-helper"))
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    token <- mascot_mount_token(nested$ns("helper"), state, nested)
    root$setInputs(`first-review-helper` = protocol_snapshot(token))
    root$flushReact()
    expect_identical(tail(messages, 1)[[1]]$id, "first-review-helper")
    expect_true(tail(messages, 1)[[1]]$restore)
    expect_identical(tail(messages, 1)[[1]]$state$status$text, "Complete")
  })
})

describe("inline helper errors in update_mascot()", {
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

describe("update documentation", {
  it("lists every helper reset and whole-setting replacement", {
    skip_if_not(file.exists(test_path("..", "..", "R", "update-mascot.R")), "Source-only roxygen check")
    lines <- readLines(test_path("..", "..", "R", "update-mascot.R"))
    text <- paste(lines, collapse = "\n")
    for (setting in c(
      "Character",
      "Mood",
      "Size",
      "Custom status",
      "Bubble",
      "Theme",
      "Click",
      "Placement",
      "Motion"
    )) {
      expect_match(text, paste0("| ", setting, " |"), fixed = TRUE)
    }
    expect_match(text, "Each non-`NULL` argument replaces that whole setting", fixed = TRUE)
  })
  it("keeps interactive examples with the running-app reason above the roxygen block", {
    skip_if_not(file.exists(test_path("..", "..", "R", "update-mascot.R")), "Source-only roxygen check")
    lines <- readLines(test_path("..", "..", "R", "update-mascot.R"))
    expect_match(lines[1], "^# .*running.*app")
    expect_true(any(lines == "#' @examplesIf interactive()"))
    expect_false(any(lines == "#' @examples"))
  })
})

describe("module warning ids", {
  it("uses the local id for early and state validation warnings and overlays", {
    local_mocked_bindings(dev_mode = function() TRUE)
    root <- shiny::MockShinySession$new()
    withr::defer(root$close())
    session <- root$makeScope("outer")$makeScope("inner")
    update_mascot("helper", character = "tessa", session = session)
    for (mood in list(1, "not_a_mood")) {
      warning <- expect_warning(
        update_mascot("helper", mood = mood, session = session),
        class = "mascot_update_ignored"
      )
      text <- conditionMessage(warning)
      expect_match(text, 'mascot "helper" unchanged', fixed = TRUE)
      expect_false(grepl("outer-inner-helper", text, fixed = TRUE))
      problem <- mascot_session(session)$problems[[session$ns("helper")]]
      expect_match(problem, "mascot: helper: ", fixed = TRUE)
      expect_false(grepl("outer-inner-helper", problem, fixed = TRUE))
    }
    warning <- expect_warning(
      update_mascot(session$ns("helper"), size = mascot_size(-1), session = session),
      class = "mascot_update_ignored"
    )
    expect_match(conditionMessage(warning), 'mascot "helper" unchanged', fixed = TRUE)
    expect_match(mascot_session(session)$problems[[session$ns("helper")]], "mascot: helper: ", fixed = TRUE)
  })
  it("uses the local id when a buffered module update is rejected on mount", {
    local_mocked_bindings(dev_mode = function() TRUE)
    root <- shiny::MockShinySession$new()
    withr::defer(root$close())
    session <- root$makeScope("outer")$makeScope("inner")
    update_mascot("helper", mood = "not_a_mood", session = session)
    state <- mascot_state_defaults(list(id = "tessa", name = "Tessa", json = character_json("tessa")))
    token <- mascot_mount_token(session$ns("helper"), state, session)
    warning <- expect_warning(
      mascot_snapshot(protocol_snapshot(token), session, session$ns("helper")),
      class = "mascot_update_ignored"
    )
    expect_match(conditionMessage(warning), 'mascot "helper" unchanged', fixed = TRUE)
    expect_match(mascot_session(session)$problems[[session$ns("helper")]], "mascot: helper: ", fixed = TRUE)
  })
})

describe("settle overlay in a cold-start update", {
  it("keeps the worried overlay when a buffered update fails as the anchor call settles", {
    local_mocked_bindings(dev_mode = function() TRUE)
    f <- protocol_fixture()
    withr::defer(f$session$close())
    update_mascot("helper", mood = "missing", session = f$session)
    expect_warning(
      update_mascot("helper", character = "tessa", session = f$session),
      class = "mascot_update_ignored"
    )
    protocol_ready(f)
    expect_match(protocol_flush(f)$problem, "^mascot: ")
  })
})

describe("deferred theme role checks", {
  it("warns with a suggestion and rejects the whole queued call when the page character arrives", {
    withr::local_options(mascot.contrast_warnings = FALSE)
    local_mocked_bindings(dev_mode = function() FALSE)
    fixture <- protocol_fixture()
    withr::defer(fixture$session$close())
    expect_no_warning(update_mascot(
      "helper",
      theme = list(bdoy = "blue"),
      mood = "happy",
      status = "Saved",
      session = fixture$session
    ))
    expect_null(protocol_record(fixture)$context)
    expect_length(protocol_record(fixture)$cold, 1L)
    captured <- new.env(parent = emptyenv())
    withCallingHandlers(protocol_ready(fixture), mascot_update_ignored = function(w) {
      captured$warning <- w
      invokeRestart("muffleWarning")
    })
    expect_s3_class(captured$warning, "mascot_update_ignored")
    message <- gsub("[[:space:]]+", " ", conditionMessage(captured$warning))
    expect_match(message, "Unknown theme colour role.*bdoy.*Choose")
    expect_match(message, 'Did you mean "body"?', fixed = TRUE)
    record <- protocol_record(fixture)
    expect_identical(record$desired$mood, "idle")
    expect_identical(record$desired$status, list(mode = "mood"))
    expect_identical(record$desired$theme, mascot_empty_theme())
    expect_length(record$owned, 0L)
    expect_length(record$cold, 0L)
  })
})
