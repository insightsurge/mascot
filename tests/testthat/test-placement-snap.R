describe("mascot_placement()", {
  it("checks positions, flags and unknown fields", {
    for (x in list(NULL, NA, 1, c(TRUE, FALSE))) {
      expect_error(mascot_placement("bottom-right", minimise = x), "minimise")
    }
    for (x in list(NULL, NA_character_, 1, "left", "floating", c("top-left", "top-right"))) {
      expect_error(mascot_placement(position = x), "position")
    }
    for (x in list(
      NULL,
      NA,
      1,
      "fixed",
      list(snap = TRUE),
      list(floating = TRUE),
      list(TRUE),
      structure(list("top-left", "top-right"), names = c("position", "position"))
    )) {
      expect_error(as_placement_arg(x, environment()), "placement|minimise")
    }
    bad <- mascot_placement()
    bad$position <- "left"
    expect_error(as_placement_arg(bad, environment()), "position")
    bad <- mascot_placement()
    bad$typo <- TRUE
    expect_error(as_placement_arg(bad, environment()), "fields")
    expect_error(as_placement_arg("inline", NULL), "call")
    expect_error(as_placement_arg(list(position = "left"), environment()), "position.*top-left")
    expect_error(as_placement_arg(list(position = "top-left", minimise = NA), environment()), "minimise.*TRUE or FALSE")
    expect_error(as_placement_arg(structure(1, class = "mascot_placement"), environment()), "placement")
    expect_snapshot(error = TRUE, mascot_placement("left"))
  })
  it("rejects TRUE, unknown and malformed drag values", {
    for (x in list(NULL, NA, NA_character_, 1, c("snap", "free"), list("snap"))) {
      expect_error(mascot_placement("bottom-right", drag = x), "drag")
    }
    expect_error(mascot_placement("bottom-right", drag = TRUE), "TRUE.*not accepted")
    expect_error(mascot_placement("bottom-right", drag = "fixed"), "\"fixed\" is not a drag mode")
    expect_error(abort_drag("left", NULL), "call")
    for (x in list(
      list(position = "top-left", drag = TRUE),
      list(position = "top-left", drag = "fixed"),
      list(position = "top-left", drag = NA),
      list(position = "top-left", drag = NULL)
    )) {
      expect_false(is.null(placement_problem(x)))
      expect_error(as_placement_arg(x, environment()), "drag|placement")
    }
    expect_match(placement_problem(list(position = "top-left", drag = TRUE)), 'got TRUE. Use drag = "none"')
    expect_match(placement_problem(list(position = "top-left", drag = "fixed")), 'got "fixed".*Use drag')
    old <- mascot_placement("top-left")
    old$drag <- NULL
    expect_match(placement_problem(old), "position, minimise and drag fields")
    expect_snapshot(error = TRUE, mascot_placement("bottom-right", drag = TRUE))
    expect_snapshot(error = TRUE, mascot_placement("bottom-right", drag = "fixed"))
    expect_snapshot(error = TRUE, mascot(id = "a", placement = list(position = "top-left", drag = TRUE)))
  })
  it("silently disables inline defaults and informs about each explicit control", {
    expect_error(inform_placement_ignored(1), "args")
    expect_error(inform_placement_ignored(NA_character_), "args")
    expect_silent(inline <- mascot_placement("inline"))
    expect_identical(inline$minimise, FALSE)
    expect_identical(inline$drag, "none")
    expect_silent(as_placement_arg(list(position = "inline"), environment()))
    for (value in c(TRUE, FALSE)) {
      expect_message(
        result <- mascot_placement("inline", minimise = value),
        "minimise.*no effect.*inline",
        class = "mascot_placement_ignored"
      )
      expect_identical(result, inline)
    }
    for (value in list("snap", "free", "none")) {
      expect_message(
        result <- mascot_placement("inline", drag = value),
        "drag.*no effect.*inline",
        class = "mascot_placement_ignored"
      )
      expect_identical(result, inline)
    }
    expect_snapshot(invisible(mascot_placement("inline", minimise = TRUE)))
    expect_snapshot(invisible(mascot_placement("inline", drag = "snap")))
    expect_snapshot(invisible(mascot_placement("inline", minimise = TRUE, drag = "free")))
    # Even a helper with active controls cannot send those controls inline.
    inline$minimise <- TRUE
    inline$drag <- "snap"
    expect_identical(
      placement_wire(inline),
      list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
    )
    expect_identical(mascot_placement(minimise = FALSE)$minimise, FALSE)
  })
})
