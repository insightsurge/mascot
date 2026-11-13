describe("watch_mascot_validator()", {
  it("tracks InputValidator results in Shiny with default moods and field-count status", {
    skip_if_not_installed("shinyvalidate")

    shiny::testServer(
      function(input, output, session) {
        iv <- shinyvalidate::InputValidator$new()
        obs <- watch_mascot_validator("helper", iv)
        session$userData$iv <- iv
        session$userData$obs <- obs
      },
      {
        expect_s3_class(session$userData$obs, "Observer")
        session$flushReact()
        expect_null(mascot_server_state("helper")$mood)

        session$userData$iv$add_rule("email", shinyvalidate::sv_required())
        session$userData$iv$add_rule("age", shinyvalidate::sv_required())
        session$userData$iv$enable()

        # The first result only sets the starting point: an empty form opens quietly.
        session$setInputs(email = "", age = "")
        session$flushReact()
        expect_null(mascot_server_state("helper")$mood)

        session$setInputs(email = "a@b.com", age = "")
        session$flushReact()
        state <- mascot_server_state("helper")
        expect_identical(state$mood, "worried")
        expect_identical(state$status, "1 field needs attention")

        session$setInputs(email = "a@b.com", age = "30")
        session$flushReact()
        state <- mascot_server_state("helper")
        expect_identical(state$mood, "happy")
        expect_identical(state$status, "All fields look good")
      }
    )
  })

  it("merges key-wise overrides over defaults and supports list() as a no-op", {
    skip_if_not_installed("shinyvalidate")

    shiny::testServer(
      function(input, output, session) {
        iv_custom <- shinyvalidate::InputValidator$new()
        iv_custom$add_rule("name", shinyvalidate::sv_required())
        iv_custom$enable()
        watch_mascot_validator(
          "custom",
          iv_custom,
          map = list(
            valid = list(),
            invalid = list(status = "Please enter your name", bubble = mascot_bubble("Required"))
          )
        )

        iv_mood_only <- shinyvalidate::InputValidator$new()
        iv_mood_only$add_rule("name", shinyvalidate::sv_required())
        iv_mood_only$enable()
        watch_mascot_validator("mood_only", iv_mood_only, map = c(invalid = "idle", valid = "happy"))
      },
      {
        session$setInputs(name = "Ada")
        session$flushReact()
        expect_null(mascot_server_state("custom")$mood)
        expect_null(mascot_server_state("mood_only")$mood)

        session$setInputs(name = "")
        session$flushReact()
        state_custom <- mascot_server_state("custom")
        expect_identical(state_custom$mood, "worried")
        expect_identical(state_custom$status, "Please enter your name")
        expect_identical(state_custom$bubble$text, "Required")

        state_mood <- mascot_server_state("mood_only")
        expect_identical(state_mood$mood, "idle")
        expect_identical(state_mood$status, "1 field needs attention")

        # valid = list() sends nothing, so the custom mascot keeps its last face.
        session$setInputs(name = "Bob")
        session$flushReact()
        expect_identical(mascot_server_state("custom")$mood, "worried")
        expect_identical(mascot_server_state("mood_only")$mood, "happy")
        expect_identical(mascot_server_state("mood_only")$status, "All fields look good")
      }
    )
  })

  it("works inside a Shiny module, stops on $destroy(), and follows last-call-wins", {
    skip_if_not_installed("shinyvalidate")

    mod_server <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        iv <- shinyvalidate::InputValidator$new()
        iv$add_rule("email", shinyvalidate::sv_email())
        iv$enable()
        obs <- watch_mascot_validator("helper", iv)
        list(obs = obs)
      })
    }

    shiny::testServer(
      mod_server,
      {
        session$setInputs(email = "ada@example.com")
        session$flushReact()
        state <- mascot_server_state("helper", session = session)
        expect_identical(state$id, "proxy1-helper")
        expect_null(state$mood)

        session$setInputs(email = "a")
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "worried")

        # A manual update stays while the number of failing fields does not change.
        update_mascot("helper", mood = "thinking", status = "Manual check", session = session)
        session$setInputs(email = "ad")
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$status, "Manual check")

        session$setInputs(email = "ada@example.com")
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "happy")

        session$returned$obs$destroy()
        session$setInputs(email = "x")
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "happy")
      }
    )
  })

  it("waits for typing to pause when delay is set", {
    skip_if_not_installed("shinyvalidate")

    shiny::testServer(
      function(input, output, session) {
        iv <- shinyvalidate::InputValidator$new()
        iv$add_rule("email", shinyvalidate::sv_email())
        iv$enable()
        watch_mascot_validator("helper", iv, delay = 1)
      },
      {
        session$setInputs(email = "a@b.com")
        session$elapse(1500)
        expect_null(mascot_server_state("helper")$mood)

        # Given the person starts typing a new address
        session$setInputs(email = "h")
        session$elapse(500)
        # Then nothing changes before the pause
        expect_null(mascot_server_state("helper")$mood)
        # And the mascot reacts once typing has paused for a second
        session$elapse(1000)
        expect_identical(mascot_server_state("helper")$mood, "worried")
      }
    )
  })

  it("follows several forms through one parent validator built with add_validator()", {
    skip_if_not_installed("shinyvalidate")

    shiny::testServer(
      function(input, output, session) {
        parent <- shinyvalidate::InputValidator$new()
        parent$add_rule("a", shinyvalidate::sv_required())
        child <- shinyvalidate::InputValidator$new()
        child$add_rule("b", shinyvalidate::sv_required())
        child$add_rule("c", shinyvalidate::sv_required())
        parent$add_validator(child)
        parent$enable()
        watch_mascot_validator("helper", parent)
      },
      {
        session$setInputs(a = "", b = "", c = "")
        session$setInputs(a = "x")
        expect_identical(mascot_server_state("helper")$status, "2 fields need attention")
        session$setInputs(b = "x", c = "y")
        expect_identical(mascot_server_state("helper")$status, "All fields look good")
      }
    )
  })

  it("rejects non-InputValidator objects when shinyvalidate is installed", {
    skip_if_not_installed("shinyvalidate")

    shiny::testServer(
      function(input, output, session) {},
      {
        expect_error(watch_mascot_validator("helper", "not_a_validator"), class = "mascot_error")
      }
    )
  })

  it("resolves validation results into mascot patches and field-count status text", {
    expect_identical(validator_invalid_status(1L), "1 field needs attention")
    expect_identical(validator_invalid_status(3L), "3 fields need attention")
    expect_error(validator_invalid_status(0L))

    defaults <- validator_default_map()
    expect_identical(validator_resolve(list(), defaults), NULL)
    expect_identical(
      validator_resolve(list(email = NULL, age = NULL), defaults),
      list(key = 0L, patch = list(mood = "happy", status = "All fields look good"))
    )
    expect_identical(
      validator_resolve(list(email = "Required", age = NULL), defaults),
      list(key = 1L, patch = list(mood = "worried", status = "1 field needs attention"))
    )
    expect_identical(
      validator_resolve(list(email = "Required", age = list(type = "error", message = "Invalid")), defaults)$patch,
      list(mood = "worried", status = "2 fields need attention")
    )

    merged <- merge_watch_map(
      defaults,
      list(valid = list(), invalid = list(status = "Fix form errors")),
      "watch_mascot_validator",
      environment()
    )
    expect_identical(validator_resolve(list(email = NULL), merged)$patch, list())
    expect_identical(
      validator_resolve(list(email = "Required", age = "Missing"), merged)$patch,
      list(mood = "worried", status = "Fix form errors")
    )

    mood_only <- merge_watch_map(defaults, c(invalid = "idle"), "watch_mascot_validator", environment())
    expect_identical(
      validator_resolve(list(email = "Required", age = "Missing"), mood_only)$patch,
      list(mood = "idle", status = "2 fields need attention")
    )

    silenced_invalid <- merge_watch_map(defaults, list(invalid = list()), "watch_mascot_validator", environment())
    expect_identical(validator_resolve(list(email = "Required"), silenced_invalid)$patch, list())
    expect_error(validator_resolve("x", defaults))
    expect_error(validator_resolve(list(), list("a")))
  })

  it("validates id, validator, dots, delay, session, map, and missing shinyvalidate", {
    fake <- structure(list(), class = c("InputValidator", "R6"))
    expect_error(watch_mascot_validator(validator = fake), class = "mascot_error")
    expect_error(watch_mascot_validator("helper"), class = "mascot_error")
    expect_error(watch_mascot_validator("", fake), class = "mascot_error")
    expect_error(watch_mascot_validator("has space", fake), class = "mascot_error")
    expect_error(watch_mascot_validator(123, fake), class = "mascot_error")
    expect_error(watch_mascot_validator("helper", list()), "InputValidator", class = "mascot_error")
    expect_error(watch_mascot_validator("helper", fake, delay = -1), "delay", class = "mascot_error")
    expect_error(watch_mascot_validator("helper", fake, delay = Inf), "delay", class = "mascot_error")
    expect_error(watch_mascot_validator("helper", fake, session = NULL), class = "mascot_error")
    expect_error(watch_mascot_validator("helper", fake, session = "not_a_session"), class = "mascot_error")
    expect_error(watch_mascot_validator("helper", fake, c(valid = "happy")), class = "mascot_error_dots")

    shiny::testServer(
      function(input, output, session) {},
      {
        expect_error(watch_mascot_validator("helper", fake, map = list()), "map", class = "mascot_error")
        expect_error(watch_mascot_validator("helper", fake, map = c("happy")), "map", class = "mascot_error")
        expect_error(
          watch_mascot_validator("helper", fake, map = c(valid = "happy", valid = "idle")),
          "map",
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_validator("helper", fake, map = mascot_mood("happy")),
          "plain named list",
          class = "mascot_error"
        )
        err <- expect_error(
          watch_mascot_validator("helper", fake, map = c(unknown_key = "happy")),
          class = "mascot_error"
        )
        expect_match(conditionMessage(err), "unknown_key")
        expect_match(conditionMessage(err), "valid")
        expect_error(
          watch_mascot_validator("helper", fake, map = list(valid = list(bad_field = "happy"))),
          class = "mascot_error"
        )
        local_mocked_bindings(validator_has_shinyvalidate = function() FALSE)
        missing_pkg_err <- expect_error(watch_mascot_validator("helper", fake), class = "mascot_error")
        expect_match(conditionMessage(missing_pkg_err), "shinyvalidate")
      }
    )
  })
})
