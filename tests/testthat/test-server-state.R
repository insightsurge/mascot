describe("mascot_server_state()", {
  it("returns NULL fields for a mascot that was never updated without mutating the session", {
    shiny::testServer(function(input, output, session) {}, {
      expect_null(session$userData$mascot_protocol)
      state <- mascot_server_state("helper")
      expect_named(state, c("id", "character", "mood", "status", "bubble", "gesture"))
      expect_identical(
        state,
        list(
          id = session$ns("helper"),
          character = NULL,
          mood = NULL,
          status = NULL,
          bubble = NULL,
          gesture = NULL
        )
      )
      expect_null(session$userData$mascot_protocol)
    })
  })

  it("coalesces queued updates in testServer() without clearing cold calls", {
    shiny::testServer(
      function(input, output, session) {
        shiny::observeEvent(input$start, {
          update_mascot(
            "helper",
            mood = "thinking",
            status = "Checking rows",
            bubble = mascot_bubble("Hold on", duration = Inf, closable = FALSE),
            gesture = "nod"
          )
        })
        shiny::observeEvent(input$finish, {
          update_mascot(
            "helper",
            mood = "happy",
            status = mascot_status(),
            bubble = mascot_bubble()
          )
        })
      },
      {
        session$setInputs(start = 1)
        key <- session$ns("helper")
        first <- mascot_server_state("helper")
        expect_identical(first$id, key)
        expect_null(first$character)
        expect_identical(first$mood, "thinking")
        expect_identical(first$status, "Checking rows")
        expect_identical(
          first$bubble,
          list(text = "Hold on", html = FALSE, closable = FALSE, duration = Inf)
        )
        expect_identical(first$gesture, "nod")

        # Calling mascot_server_state() again is read-only and leaves cold state intact.
        cold_before <- session$userData$mascot_protocol$states[[key]]$cold
        expect_gt(length(cold_before), 0L)
        expect_identical(mascot_server_state("helper"), first)
        expect_identical(session$userData$mascot_protocol$states[[key]]$cold, cold_before)

        session$setInputs(finish = 1)
        second <- mascot_server_state("helper")
        expect_identical(second$mood, "happy")
        expect_null(second$status)
        expect_null(second$bubble)
        expect_identical(second$gesture, "nod")

        empty_cold <- list(cold = list(), desired = list(mood = "idle"))
        expect_identical(mascot_state_coalesce_cold(empty_cold), empty_cold)
      }
    )
  })

  it("resolves module namespaces once and handles session$ns() ids", {
    module <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$go, {
          update_mascot("helper", mood = "celebrating", status = "Module done", bubble = "Nice")
        })
      })
    }
    shiny::testServer(module, {
      expect_identical(mascot_server_state("helper", session = session)$id, session$ns("helper"))
      session$setInputs(go = 1)
      state <- mascot_server_state("helper", session = session)
      expect_identical(state$id, "proxy1-helper")
      expect_identical(state$mood, "celebrating")
      expect_identical(state$status, "Module done")
      expect_identical(state$bubble, list(text = "Nice", html = FALSE, closable = TRUE, duration = 5))
      expect_identical(mascot_server_state(session$ns("helper"), session = session), state)
    })
  })

  it("settles queued updates against an optional fallback character without mutating session state", {
    local_mocked_bindings(dev_mode = function() TRUE)
    shiny::testServer(
      function(input, output, session) {
        shiny::observeEvent(input$bad, {
          update_mascot("helper", mood = "happy", status = "Good")
          update_mascot("helper", mood = "bogus", status = "Should not stick")
        })
      },
      {
        session$setInputs(bad = 1)
        expect_identical(mascot_server_state("helper")$mood, "bogus")
        expect_warning(
          settled <- mascot_server_state("helper", character = "tessa"),
          class = "mascot_update_ignored"
        )
        expect_identical(settled$character, "tessa")
        expect_identical(settled$mood, "happy")
        expect_identical(settled$status, "Good")
        # Session record and dev-mode problems stay untouched.
        key <- session$ns("helper")
        expect_null(session$userData$mascot_protocol$states[[key]]$context)
        expect_null(session$userData$mascot_protocol$problems[[key]])
      }
    )
  })

  it("reads settled state after character is known or UI mounted", {
    f <- protocol_fixture()
    withr::defer(f$session$close())
    protocol_ready(f)
    protocol_flush(f)
    update_mascot("helper", mood = "worried", status = "Check input", gesture = "wave", session = f$session)
    state <- mascot_server_state("helper", character = "knurl", session = f$session)
    expect_identical(state$character, "tessa")
    expect_identical(state$mood, "worried")
    expect_identical(state$status, "Check input")
    expect_identical(state$gesture, "wave")

    # Custom character via update_mascot() sets character context immediately.
    bot <- mascot_read_character(system.file("examples", "characters", "study_bot.json", package = "mascot"))
    shiny::testServer(function(input, output, session) {}, {
      update_mascot("helper", character = bot, mood = "happy", session = session)
      state <- mascot_server_state("helper", session = session)
      expect_identical(state$character, "study_bot")
      expect_identical(state$mood, "happy")
    })
  })

  it("checks every argument and fails with mascot_error on invalid calls", {
    session <- shiny::MockShinySession$new()
    withr::defer(session$close())
    expect_error(mascot_server_state(), "id", class = "mascot_error")
    for (bad in list(1, "", "has space", NA_character_, c("a", "b"))) {
      expect_error(mascot_server_state(bad, session = session), "Assertion on 'id' failed", class = "mascot_error")
    }
    expect_error(mascot_server_state("helper", character = 1, session = session), "character", class = "mascot_error")
    expect_error(mascot_server_state("helper", character = "no_such_char", session = session), class = "mascot_error")
    expect_error(mascot_server_state("helper", session = NULL), "Shiny server", class = "mascot_error")
    expect_error(mascot_server_state("helper", session = 1), "Assertion on 'session' failed", class = "mascot_error")
    expect_error(mascot_server_state("helper", "tessa", session = session), class = "mascot_error_dots")
    expect_error(mascot_server_state("helper", typo = 1, session = session), class = "mascot_error_dots")
  })
})
