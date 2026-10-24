describe("mascot_placement()", {
  it("checks positions, flags and unknown fields", {
    expect_snapshot(error = TRUE, mascot_placement("left"))
  })
  it("rejects TRUE, unknown and malformed drag values", {
    expect_snapshot(error = TRUE, mascot_placement("bottom-right", drag = TRUE))
    expect_snapshot(error = TRUE, mascot_placement("bottom-right", drag = "fixed"))
    expect_snapshot(error = TRUE, mascot(id = "a", placement = list(position = "top-left", drag = TRUE)))
  })
  it("silently disables inline defaults and informs about each explicit control", {
    expect_snapshot(invisible(mascot_placement("inline", minimise = TRUE)))
    expect_snapshot(invisible(mascot_placement("inline", drag = "snap")))
    expect_snapshot(invisible(mascot_placement("inline", minimise = TRUE, drag = "free")))
  })
})
