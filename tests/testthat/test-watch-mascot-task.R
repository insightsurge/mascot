describe("watch_mascot_task()", {
  it("tracks ExtendedTask status transitions using default moods and status text", {
    skip_if_not_installed("later")

    shiny::testServer(
      function(input, output, session) {
        task <- shiny::ExtendedTask$new(function(fail = FALSE) {
          if (isTRUE(fail)) {
            stop("boom")
          }
          "ok"
        })
        obs <- watch_mascot_task("helper", task)
        session$userData$task <- task
        session$userData$obs <- obs
      },
      {
        expect_s3_class(session$userData$obs, "Observer")
        session$flushReact()
        state <- mascot_server_state("helper")
        expect_identical(state$mood, "idle")
        expect_identical(state$status, "Ready")

        session$userData$task$invoke(FALSE)
        session$flushReact()
        running_state <- mascot_server_state("helper")
        expect_identical(running_state$mood, "thinking")
        expect_identical(running_state$status, "Running task")

        while (!later::loop_empty()) {
          later::run_now()
        }
        session$flushReact()
        state <- mascot_server_state("helper")
        expect_identical(state$mood, "happy")
        expect_identical(state$status, "Task complete")

        suppressWarnings({
          session$userData$task$invoke(TRUE)
          while (!later::loop_empty()) {
            later::run_now()
          }
        })
        session$flushReact()
        state <- mascot_server_state("helper")
        expect_identical(state$mood, "worried")
        expect_identical(state$status, "Task failed")
      }
    )
  })

  it("shows running state before an asynchronous ExtendedTask resolves", {
    skip_if_not_installed("promises")
    skip_if_not_installed("later")

    resolve_fn <- NULL
    shiny::testServer(
      function(input, output, session) {
        task <- shiny::ExtendedTask$new(function() {
          promises::promise(function(resolve, reject) {
            resolve_fn <<- resolve
          })
        })
        watch_mascot_task("helper", task)
        session$userData$task <- task
      },
      {
        session$flushReact()
        expect_identical(mascot_server_state("helper")$mood, "idle")

        session$userData$task$invoke()
        session$flushReact()
        running_state <- mascot_server_state("helper")
        expect_identical(running_state$mood, "thinking")
        expect_identical(running_state$status, "Running task")

        resolve_fn("done")
        while (!later::loop_empty()) {
          later::run_now()
        }
        session$flushReact()
        done_state <- mascot_server_state("helper")
        expect_identical(done_state$mood, "happy")
        expect_identical(done_state$status, "Task complete")
      }
    )
  })

  it("merges key-wise overrides over defaults and supports list() as a no-op", {
    skip_if_not_installed("later")

    shiny::testServer(
      function(input, output, session) {
        task_a <- shiny::ExtendedTask$new(function(fail = FALSE) {
          if (isTRUE(fail)) {
            stop("boom")
          }
          "ok"
        })
        watch_mascot_task(
          "field_override",
          task_a,
          map = list(
            initial = list(),
            success = list(status = "Finished", bubble = mascot_bubble("All done", duration = 2000)),
            error = list(status = "Failed check", gesture = "shake")
          )
        )

        task_b <- shiny::ExtendedTask$new(function() "ok")
        watch_mascot_task(
          "char_override",
          task_b,
          map = c(initial = "happy", success = "idle")
        )

        session$userData$task_a <- task_a
        session$userData$task_b <- task_b
      },
      {
        session$flushReact()
        expect_null(mascot_server_state("field_override")$mood)
        expect_null(mascot_server_state("field_override")$status)
        expect_identical(mascot_server_state("char_override")$mood, "happy")
        expect_identical(mascot_server_state("char_override")$status, "Ready")

        session$userData$task_a$invoke(FALSE)
        while (!later::loop_empty()) {
          later::run_now()
        }
        session$flushReact()
        state_a <- mascot_server_state("field_override")
        expect_identical(state_a$mood, "happy")
        expect_identical(state_a$status, "Finished")
        expect_identical(state_a$bubble$text, "All done")

        suppressWarnings({
          session$userData$task_a$invoke(TRUE)
          while (!later::loop_empty()) {
            later::run_now()
          }
        })
        session$flushReact()
        state_err <- mascot_server_state("field_override")
        expect_identical(state_err$mood, "worried")
        expect_identical(state_err$status, "Failed check")
        expect_identical(state_err$gesture, "shake")

        session$userData$task_b$invoke()
        while (!later::loop_empty()) {
          later::run_now()
        }
        session$flushReact()
        state_b <- mascot_server_state("char_override")
        expect_identical(state_b$mood, "idle")
        expect_identical(state_b$status, "Task complete")
      }
    )
  })

  it("works inside a Shiny module, stops on $destroy(), and follows last-call-wins", {
    skip_if_not_installed("later")

    mod_server <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        task <- shiny::ExtendedTask$new(function(fail = FALSE) {
          if (isTRUE(fail)) {
            stop("boom")
          }
          "ok"
        })
        obs <- watch_mascot_task("helper", task)
        shiny::observeEvent(input$run, task$invoke(isTRUE(input$fail)))
        list(obs = obs)
      })
    }

    shiny::testServer(
      mod_server,
      {
        session$flushReact()
        state <- mascot_server_state("helper", session = session)
        expect_identical(state$id, "proxy1-helper")
        expect_identical(state$mood, "idle")

        update_mascot("helper", mood = "thinking", status = "Manual override", session = session)
        expect_identical(mascot_server_state("helper", session = session)$status, "Manual override")

        session$setInputs(fail = FALSE, run = 1)
        while (!later::loop_empty()) {
          later::run_now()
        }
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "happy")

        session$returned$obs$destroy()
        suppressWarnings({
          session$setInputs(fail = TRUE, run = 2)
          while (!later::loop_empty()) {
            later::run_now()
          }
        })
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "happy")
      }
    )
  })

  it("validates id, task, dots, session, and map keys and entries", {
    fake_task <- shiny::ExtendedTask$new(function() "ok")

    expect_error(watch_mascot_task(task = fake_task), class = "mascot_error")
    expect_error(watch_mascot_task("helper"), class = "mascot_error")
    expect_error(watch_mascot_task("", fake_task), class = "mascot_error")
    expect_error(watch_mascot_task("has space", fake_task), class = "mascot_error")
    expect_error(watch_mascot_task(123, fake_task), class = "mascot_error")
    expect_error(watch_mascot_task("helper", "not_a_task"), class = "mascot_error")
    expect_error(watch_mascot_task("helper", shiny::reactiveVal("initial")), class = "mascot_error")

    expect_error(
      watch_mascot_task("helper", fake_task, session = NULL),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot_task("helper", fake_task, session = "not_a_session"),
      class = "mascot_error"
    )
    expect_error(
      watch_mascot_task("helper", fake_task, c(initial = "idle")),
      class = "mascot_error_dots"
    )

    shiny::testServer(
      function(input, output, session) {},
      {
        expect_error(
          watch_mascot_task("helper", fake_task, map = list()),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_task("helper", fake_task, map = c("happy")),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_task("helper", fake_task, map = c(success = "happy", success = "idle")),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_task("helper", fake_task, map = mascot_mood("happy")),
          class = "mascot_error"
        )
        err <- expect_error(
          watch_mascot_task("helper", fake_task, map = c(unknown_state = "happy")),
          class = "mascot_error"
        )
        expect_match(conditionMessage(err), "unknown_state")
        expect_match(conditionMessage(err), "initial")
        expect_error(
          watch_mascot_task("helper", fake_task, map = list(success = list(bad_field = "happy"))),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_task("helper", fake_task, map = list(success = 123)),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_task("helper", fake_task, map = list(success = "has space")),
          class = "mascot_error"
        )
      }
    )
  })
})
