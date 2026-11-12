describe("watch_mascot()", {
  it("maps named character vectors from a reactive() and reactiveVal() through update_mascot()", {
    shiny::testServer(
      function(input, output, session) {
        status_rv <- shiny::reactiveVal("idle")
        obs <- watch_mascot(
          "helper",
          status_rv,
          c(idle = "idle", running = "thinking", done = "happy", broken = "worried")
        )
        session$userData$status_rv <- status_rv
        session$userData$obs <- obs
      },
      {
        expect_s3_class(session$userData$obs, "Observer")
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "idle")

        session$userData$status_rv("running")
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "thinking")

        session$userData$status_rv("done")
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "happy")

        # Unmatched, NA, NULL and non-scalar values leave the mascot unchanged.
        for (ignored in list("unknown", NA_character_, NULL, c("idle", "done"), list("done"))) {
          session$userData$status_rv(ignored)
          session$flushReact()
          expect_identical(mascot_server_state("helper")$mood, "happy")
        }
      }
    )
  })

  it("supports mixed list entries with key-wise overrides, helpers, and numeric/logical keys", {
    shiny::testServer(
      function(input, output, session) {
        ready <- shiny::reactive(isTRUE(input$ready))
        watch_mascot(
          "helper",
          ready,
          list(
            "FALSE" = list(
              mood = mascot_mood("worried"),
              status = "Check fields",
              bubble = mascot_bubble("Required field missing", closable = FALSE)
            ),
            "TRUE" = list(
              mood = "happy",
              status = mascot_status(),
              bubble = mascot_bubble(),
              gesture = "nod"
            )
          )
        )
        step <- shiny::reactiveVal(0L)
        watch_mascot(
          "counter",
          step,
          list(
            "0" = list(),
            "1" = "thinking",
            "2" = mascot_mood("celebrating")
          )
        )
        session$userData$step <- step
      },
      {
        session$setInputs(ready = FALSE)
        session$flushReact()
        s1 <- mascot_server_state("helper")
        expect_identical(s1$mood, "worried")
        expect_identical(s1$status, "Check fields")
        expect_identical(s1$bubble$text, "Required field missing")

        session$setInputs(ready = TRUE)
        session$flushReact()
        s2 <- mascot_server_state("helper")
        expect_identical(s2$mood, "happy")
        expect_null(s2$status)
        expect_null(s2$bubble)
        expect_identical(s2$gesture, "nod")

        session$flushReact()
        expect_null(mascot_server_state("counter")$mood)
        session$userData$step(1L)
        session$flushReact()
        expect_identical(mascot_server_state("counter")$mood, "thinking")
        session$userData$step(2L)
        session$flushReact()
        expect_identical(mascot_server_state("counter")$mood, "celebrating")

        # NULL fields in a list entry are omitted rather than overwriting earlier state.
        partial_rv <- shiny::reactiveVal("first")
        watch_mascot(
          "partial",
          partial_rv,
          list(
            first = list(mood = "thinking", status = "Working"),
            second = list(mood = "happy", status = NULL)
          )
        )
        session$flushReact()
        partial_rv("second")
        session$flushReact()
        s_partial <- mascot_server_state("partial")
        expect_identical(s_partial$mood, "happy")
        expect_identical(s_partial$status, "Working")
      }
    )
  })

  it("supports eventReactive() sources and skips silent req() errors", {
    shiny::testServer(
      function(input, output, session) {
        req_val <- shiny::reactive({
          shiny::req(input$go > 0)
          input$mode
        })
        ev <- shiny::eventReactive(input$trigger, input$mode)
        watch_mascot("req_helper", req_val, c(a = "happy", b = "worried"))
        watch_mascot("ev_helper", ev, c(a = "thinking", b = "celebrating"))
      },
      {
        session$setInputs(go = 0, mode = "a")
        session$flushReact()
        expect_null(mascot_server_state("req_helper")$mood)

        session$setInputs(go = 1, mode = "a")
        session$flushReact()
        expect_identical(mascot_server_state("req_helper")$mood, "happy")

        session$setInputs(trigger = 1, mode = "b")
        session$flushReact()
        expect_identical(mascot_server_state("ev_helper")$mood, "celebrating")
      }
    )
  })

  it("works inside a Shiny module with local mascot ids", {
    module <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        ready <- shiny::reactive(isTRUE(input$ready))
        watch_mascot(
          "helper",
          ready,
          list(
            "TRUE" = list(mood = "happy", status = "Module ready"),
            "FALSE" = list(mood = "worried", status = "Module pending")
          )
        )
      })
    }
    shiny::testServer(module, {
      session$setInputs(ready = FALSE)
      session$flushReact()
      s <- mascot_server_state("helper", session = session)
      expect_identical(s$id, "proxy1-helper")
      expect_identical(s$mood, "worried")
      expect_identical(s$status, "Module pending")

      session$setInputs(ready = TRUE)
      session$flushReact()
      s <- mascot_server_state("helper", session = session)
      expect_identical(s$mood, "happy")
      expect_identical(s$status, "Module ready")
    })
  })

  it("stops updating once $destroy() is called and obeys last-call-wins with update_mascot()", {
    shiny::testServer(
      function(input, output, session) {
        rv <- shiny::reactiveVal("go")
        obs <- watch_mascot("helper", rv, list(go = list(mood = "thinking", status = "Working"), stop = "happy"))
        shiny::observeEvent(input$manual, {
          update_mascot("helper", mood = "celebrating", status = "Manual override")
        })
        shiny::observeEvent(input$kill_watch, {
          obs$destroy()
        })
        session$userData$rv <- rv
      },
      {
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "thinking")

        session$setInputs(manual = 1)
        s <- mascot_server_state("helper")
        expect_identical(s$mood, "celebrating")
        expect_identical(s$status, "Manual override")

        # Next watcher change wins over the earlier manual update.
        session$userData$rv("stop")
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "happy")

        session$setInputs(kill_watch = 1)
        session$userData$rv("go")
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "happy")
      }
    )
  })

  it("handles factors and emits update_mascot() warnings when a character rejects a mapped value", {
    shiny::testServer(
      function(input, output, session) {
        update_mascot("helper", character = "tessa", mood = "happy")
        state <- shiny::reactiveVal(factor("ok"))
        watch_mascot("helper", state, c(ok = "idle", bad = "bogus"))
        session$userData$state <- state
      },
      {
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "idle")

        expect_warning(
          {
            session$userData$state(factor("bad"))
            session$flushReact()
          },
          class = "mascot_update_ignored"
        )
        expect_identical(mascot_server_state("helper")$mood, "idle")
      }
    )
  })

  it("validates id, source, map, ... and session eagerly with checkmate and mascot_error", {
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    src <- shiny::reactiveVal("ok")

    expect_error(watch_mascot(), "id", class = "mascot_error")
    expect_error(watch_mascot("helper"), "source", class = "mascot_error")
    expect_error(watch_mascot("helper", src), "map", class = "mascot_error")

    for (bad_id in list(1, "", "has space", NA_character_, c("a", "b"))) {
      expect_error(
        watch_mascot(bad_id, src, c(ok = "happy"), session = session),
        "Assertion on 'id' failed",
        class = "mascot_error"
      )
    }

    for (bad_src in list(NULL, "ok", function() "ok", list(1))) {
      expect_error(
        watch_mascot("helper", bad_src, c(ok = "happy"), session = session),
        "Assertion on 'source' failed",
        class = "mascot_error"
      )
    }

    for (bad_map in list(
      character(0),
      list(),
      c("happy", "worried"),
      c(a = "happy", a = "worried"),
      c(a = NA_character_),
      list("happy"),
      list(a = "happy", a = "worried"),
      structure(list(a = "happy"), class = "not_plain"),
      1:2
    )) {
      expect_error(watch_mascot("helper", src, bad_map, session = session), class = "mascot_error")
    }

    # Invalid entries inside map fail at setup time.
    expect_error(watch_mascot("helper", src, c(ok = "NotAMood!"), session = session), class = "mascot_error")
    expect_error(watch_mascot("helper", src, c(ok = ""), session = session), class = "mascot_error")
    expect_error(watch_mascot("helper", src, c(ok = "{bad}"), session = session), class = "mascot_error")
    expect_error(watch_mascot("helper", src, list(ok = NULL), session = session), class = "mascot_error")
    expect_error(watch_mascot("helper", src, list(ok = 123), session = session), class = "mascot_error")
    expect_error(watch_mascot("helper", src, list(ok = list("happy")), session = session), class = "mascot_error")
    expect_error(
      watch_mascot("helper", src, list(ok = list(mood = "happy", mood = "idle")), session = session),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot("helper", src, list(ok = list(mood = "{bad}")), session = session),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot("helper", src, list(ok = list(unknown_field = "x")), session = session),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot("helper", src, list(ok = list(status = 123)), session = session),
      class = "mascot_error"
    )

    expect_error(watch_mascot("helper", src, c(ok = "happy"), session = NULL), "Shiny server", class = "mascot_error")
    expect_error(
      watch_mascot("helper", src, c(ok = "happy"), session = 1),
      "Assertion on 'session' failed",
      class = "mascot_error"
    )
    expect_error(watch_mascot("helper", src, c(ok = "happy"), "extra", session = session), class = "mascot_error_dots")
    expect_error(watch_mascot("helper", src, c(ok = "happy"), typo = 1, session = session), class = "mascot_error_dots")
  })
})
