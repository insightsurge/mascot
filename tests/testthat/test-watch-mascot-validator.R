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

        session$setInputs(email = "", age = "")
        session$flushReact()
        state <- mascot_server_state("helper")
        expect_identical(state$mood, "worried")
        expect_identical(state$status, "2 fields need attention")

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
        expect_identical(mascot_server_state("mood_only")$mood, "happy")
        expect_identical(mascot_server_state("mood_only")$status, "All fields look good")

        session$setInputs(name = "")
        session$flushReact()
        state_custom <- mascot_server_state("custom")
        expect_identical(state_custom$mood, "worried")
        expect_identical(state_custom$status, "Please enter your name")
        expect_identical(state_custom$bubble$text, "Required")

        state_mood <- mascot_server_state("mood_only")
        expect_identical(state_mood$mood, "idle")
        expect_identical(state_mood$status, "1 field needs attention")
      }
    )
  })

  it("works inside a Shiny module, stops on $destroy(), and follows last-call-wins", {
    skip_if_not_installed("shinyvalidate")

    mod_server <- function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        iv <- shinyvalidate::InputValidator$new()
        iv$add_rule("name", shinyvalidate::sv_required())
        iv$enable()
        obs <- watch_mascot_validator("helper", iv)
        list(obs = obs)
      })
    }

    shiny::testServer(
      mod_server,
      {
        session$setInputs(name = "Ada")
        session$flushReact()
        state <- mascot_server_state("helper", session = session)
        expect_identical(state$id, "proxy1-helper")
        expect_identical(state$mood, "happy")

        update_mascot("helper", mood = "thinking", status = "Manual check", session = session)
        expect_identical(mascot_server_state("helper", session = session)$status, "Manual check")

        session$setInputs(name = "")
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "worried")

        session$returned$obs$destroy()
        session$setInputs(name = "Grace")
        session$flushReact()
        expect_identical(mascot_server_state("helper", session = session)$mood, "worried")
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
    expect_identical(validator_resolve_patch(list(), defaults), list())
    expect_identical(
      validator_resolve_patch(list(email = NULL, age = NULL), defaults),
      list(mood = "happy", status = "All fields look good")
    )
    expect_identical(
      validator_resolve_patch(list(email = "Required", age = NULL), defaults),
      list(mood = "worried", status = "1 field needs attention")
    )
    expect_identical(
      validator_resolve_patch(list(email = "Required", age = list(type = "error", message = "Invalid")), defaults),
      list(mood = "worried", status = "2 fields need attention")
    )

    merged <- merge_watch_map(
      defaults,
      list(valid = list(), invalid = list(status = "Fix form errors")),
      "watch_mascot_validator",
      environment()
    )
    expect_identical(validator_resolve_patch(list(email = NULL), merged), list())
    expect_identical(
      validator_resolve_patch(list(email = "Required", age = "Missing"), merged),
      list(mood = "worried", status = "Fix form errors")
    )

    mood_only <- merge_watch_map(defaults, c(invalid = "idle"), "watch_mascot_validator", environment())
    expect_identical(
      validator_resolve_patch(list(email = "Required", age = "Missing"), mood_only),
      list(mood = "idle", status = "2 fields need attention")
    )

    silenced_invalid <- merge_watch_map(defaults, list(invalid = list()), "watch_mascot_validator", environment())
    expect_identical(validator_resolve_patch(list(email = "Required"), silenced_invalid), list())
  })

  it("validates id, validator, dots, session, map, and missing shinyvalidate", {
    expect_error(watch_mascot_validator(validator = list()), class = "mascot_error")
    expect_error(watch_mascot_validator("helper"), class = "mascot_error")
    expect_error(watch_mascot_validator("", list()), class = "mascot_error")
    expect_error(watch_mascot_validator("has space", list()), class = "mascot_error")
    expect_error(watch_mascot_validator(123, list()), class = "mascot_error")
    expect_error(watch_mascot_validator("helper", list(), session = NULL), class = "mascot_error")
    expect_error(watch_mascot_validator("helper", list(), session = "not_a_session"), class = "mascot_error")
    expect_error(watch_mascot_validator("helper", list(), c(valid = "happy")), class = "mascot_error_dots")

    shiny::testServer(
      function(input, output, session) {},
      {
        expect_error(
          watch_mascot_validator("helper", list(), map = list()),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_validator("helper", list(), map = c("happy")),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_validator("helper", list(), map = c(valid = "happy", valid = "idle")),
          class = "mascot_error"
        )
        expect_error(
          watch_mascot_validator("helper", list(), map = mascot_mood("happy")),
          class = "mascot_error"
        )
        err <- expect_error(
          watch_mascot_validator("helper", list(), map = c(unknown_key = "happy")),
          class = "mascot_error"
        )
        expect_match(conditionMessage(err), "unknown_key")
        expect_match(conditionMessage(err), "valid")
        expect_error(
          watch_mascot_validator("helper", list(), map = list(valid = list(bad_field = "happy"))),
          class = "mascot_error"
        )
        if (!requireNamespace("shinyvalidate", quietly = TRUE)) {
          missing_pkg_err <- expect_error(
            watch_mascot_validator("helper", list()),
            class = "mascot_error"
          )
          expect_match(conditionMessage(missing_pkg_err), "shinyvalidate")
        }
      }
    )
  })
})
