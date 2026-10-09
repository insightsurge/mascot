describe("mascot_placement()", {
  it("normalises every shortcut to one position and keeps inline the default", {
    expect_identical(
      mascot_placement(),
      structure(list(position = "inline", minimise = FALSE), class = "mascot_placement")
    )
    expect_identical(as_placement_arg("inline", environment()), mascot_placement())
    expect_identical(as_placement_arg("floating", environment()), mascot_placement("bottom-right"))
    for (corner in c("top-left", "top-right", "bottom-left", "bottom-right")) {
      expect_identical(as_placement_arg(corner, environment()), mascot_placement(corner))
    }
    expect_identical(
      as_placement_arg(list(position = "top-left", minimise = TRUE), environment()),
      mascot_placement("top-left", minimise = TRUE)
    )
    expect_identical(as_placement_arg(list(), environment()), mascot_placement())
    expect_identical(
      as_placement_arg(mascot_placement("bottom-right", minimise = TRUE), environment()),
      mascot_placement("bottom-right", minimise = TRUE)
    )
  })
  it("sends the browser's floating, corner and minimise fields", {
    expect_identical(
      placement_wire(mascot_placement()),
      list(floating = FALSE, position = "bottom-right", minimise = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("top-left", TRUE)),
      list(floating = TRUE, position = "top-left", minimise = TRUE)
    )
    expect_error(placement_wire(list(position = "inline")), "mascot_placement")
  })
  it("checks positions, flags, unknown fields and minimising an inline mascot", {
    for (x in list(NULL, NA, 1, c(TRUE, FALSE))) {
      expect_error(mascot_placement("bottom-right", minimise = x), "minimise")
    }
    for (x in list(NULL, NA_character_, 1, "left", "floating", c("top-left", "top-right"))) {
      expect_error(mascot_placement(position = x), "position")
    }
    expect_error(mascot_placement(minimise = TRUE), "needs a corner")
    for (x in list(
      NULL,
      NA,
      1,
      "fixed",
      list(snap = TRUE),
      list(floating = TRUE),
      list(minimise = TRUE),
      list(position = "inline", minimise = TRUE),
      list(TRUE),
      structure(list("top-left", "top-right"), names = c("position", "position"))
    )) {
      expect_error(as_placement_arg(x, environment()), "placement|minimise")
    }
    bad <- mascot_placement()
    bad$minimise <- TRUE
    expect_error(as_placement_arg(bad, environment()), "corner")
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
    expect_snapshot(error = TRUE, mascot_placement(minimise = TRUE))
  })
})
