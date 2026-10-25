describe("update_mascot()", {
  it("warns for every invalid value, without sending any part of an update", {
    local_mocked_bindings(
      send_update = function(session, id, patch) NULL,
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
    expect_snapshot(error = TRUE, update_mascot("helper", typo = 1, session = session))
    expect_snapshot(error = TRUE, update_mascot("helper", NULL, NULL, NULL, NULL, session))
  })
})

describe("update_mascot() size and placement", {
  it("informs about explicit inline controls and still sends the complete update", {
    local_mocked_bindings(send_update = function(session, id, patch) NULL)
    shiny::testServer(function(input, output, session) {}, {
      expect_snapshot(update_mascot("a", placement = list(position = "inline", minimise = TRUE), session = session))
      expect_snapshot(update_mascot("a", placement = list(position = "inline", drag = "snap"), session = session))
      expect_snapshot(update_mascot("a", placement = mascot_placement("inline", minimise = TRUE), session = session))
      expect_snapshot(update_mascot("a", placement = mascot_placement("inline", drag = "free"), session = session))
    })
  })
})
