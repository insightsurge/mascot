describe("watch_mascot_shiny()", {
  it("validates arguments with checkmate and descriptive mascot errors", {
    mock <- shiny::MockShinySession$new()
    on.exit(mock$close(), add = TRUE)

    expect_error(watch_mascot_shiny(), class = "mascot_error")
    expect_error(watch_mascot_shiny("", session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny("has spaces", session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny(123, session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny("helper", "extra", session = mock), class = "mascot_error_dots")
    expect_error(watch_mascot_shiny("helper", delay = -1, session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny("helper", delay = Inf, session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny("helper", delay = "1", session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny("helper", session = NULL), class = "mascot_error")
    expect_error(watch_mascot_shiny("helper", session = list()), class = "mascot_error")
  })

  it("validates map keys, formats, and overlay-only fields", {
    mock <- shiny::MockShinySession$new()
    on.exit(mock$close(), add = TRUE)

    expect_error(watch_mascot_shiny("helper", map = "thinking", session = mock), class = "mascot_error")
    expect_error(watch_mascot_shiny("helper", map = list(), session = mock), class = "mascot_error")
    expect_error(
      watch_mascot_shiny("helper", map = c(busy = "thinking", busy = "happy"), session = mock),
      class = "mascot_error"
    )
    expect_error(watch_mascot_shiny("helper", map = c(unknown = "happy"), session = mock), class = "mascot_error")
    expect_error(
      watch_mascot_shiny("helper", map = list(busy = list(size = 100)), session = mock),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot_shiny("helper", map = list(busy = list(gesture = "nod")), session = mock),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot_shiny("helper", map = list(error = list(mood = "InvalidMood")), session = mock),
      class = "mascot_error"
    )
  })

  it("delivers overlay config to live mounts without changing server state", {
    messages <- list()
    shiny::testServer(
      function(input, output, session) {
        update_mascot("helper", character = "tessa", mood = "happy", status = "Saved")
        ret <- watch_mascot_shiny(
          "helper",
          map = list(
            busy = list(mood = "thinking", status = "Crunching"),
            idle = list(),
            disconnected = list()
          ),
          delay = 0.25
        )
        expect_null(ret)
        session$userData$ret <- ret
      },
      {
        orig_send <- session$sendCustomMessage
        session$sendCustomMessage <- function(type, message) {
          messages[[length(messages) + 1L]] <<- list(type = type, message = message)
          orig_send(type, message)
        }
        on.exit(session$sendCustomMessage <- orig_send, add = TRUE)

        state_defaults <- mascot:::mascot_state_defaults(list(
          id = "tessa",
          name = "Tessa",
          json = mascot:::character_json("tessa")
        ))
        token <- mascot:::mascot_mount_token(session$ns("helper"), state_defaults, session)
        mascot:::mascot_snapshot(
          protocol_snapshot(token),
          session,
          session$ns("helper")
        )
        session$flushReact()

        env <- messages[[length(messages)]]$message
        expect_identical(env$id, session$ns("helper"))
        expect_identical(env$shiny_watch$delay_ms, 250)
        expect_identical(env$shiny_watch$map$busy$mood, "thinking")
        expect_identical(env$shiny_watch$map$busy$status, list(mode = "custom", text = "Crunching"))
        expect_null(env$shiny_watch$map$idle)
        expect_null(env$shiny_watch$map$disconnected)
        expect_identical(env$shiny_watch$map$error$mood, "worried")

        state <- mascot_server_state("helper")
        expect_identical(state$mood, "happy")
        expect_identical(state$status, "Saved")

        # Updating watcher config after mount sends kind = "shiny-watch".
        watch_mascot_shiny(
          "helper",
          map = list(
            busy = list(mood = mascot_mood("celebrating"), status = mascot_status())
          ),
          delay = 0
        )
        session$flushReact()
        watch_msg <- messages[[length(messages)]]$message
        expect_identical(watch_msg$kind, "shiny-watch")
        expect_identical(watch_msg$shiny_watch$delay_ms, 0)
        expect_identical(watch_msg$shiny_watch$map$busy$mood, "celebrating")
        expect_identical(watch_msg$shiny_watch$map$busy$status, list(mode = "mood"))
      }
    )
  })

  it("namespaces module ids and restores watch config on untouched resume", {
    messages <- list()
    mod_server <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        watch_mascot_shiny("helper", delay = 0)
      })
    }

    shiny::testServer(mod_server, {
      root <- session$rootScope()
      orig_send <- root$sendCustomMessage
      root$sendCustomMessage <- function(type, message) {
        messages[[length(messages) + 1L]] <<- list(type = type, message = message)
        orig_send(type, message)
      }
      on.exit(root$sendCustomMessage <- orig_send, add = TRUE)

      state_defaults <- mascot:::mascot_state_defaults(list(
        id = "tessa",
        name = "Tessa",
        json = mascot:::character_json("tessa")
      ))
      token <- mascot:::mascot_mount_token(session$ns("helper"), state_defaults, session)
      mascot:::mascot_snapshot(
        protocol_snapshot(token, lifecycle = "resume"),
        session,
        session$ns("helper")
      )
      session$flushReact()

      expect_length(messages, 1L)
      msg <- messages[[1L]]$message
      expect_identical(msg$kind, "shiny-watch")
      expect_identical(msg$id, session$ns("helper"))
      expect_identical(msg$shiny_watch$delay_ms, 0)
    })
  })
})
