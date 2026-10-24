describe("update_mascot()", {
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

describe("update_mascot() size and placement", {
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
