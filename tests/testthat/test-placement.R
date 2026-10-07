describe("mascot_placement()", {
  it("normalises every shortcut and keeps omitted inline defaults valid", {
    expect_identical(
      mascot_placement(),
      structure(list(floating = FALSE, position = "bottom-right", minimise = FALSE), class = "mascot_placement")
    )
    expect_identical(as_placement_arg("inline", environment()), mascot_placement())
    expect_identical(as_placement_arg("floating", environment()), mascot_placement(TRUE))
    for (corner in c("top-left", "top-right", "bottom-left", "bottom-right")) {
      expect_identical(as_placement_arg(corner, environment()), mascot_placement(TRUE, corner))
    }
    expect_identical(
      as_placement_arg(list(floating = TRUE, position = "top-left"), environment()),
      mascot_placement(TRUE, "top-left")
    )
    expect_identical(
      as_placement_arg(mascot_placement(TRUE, minimise = TRUE), environment()),
      mascot_placement(TRUE, minimise = TRUE)
    )
  })
  it("checks all flags, corners, unknown fields and explicit inline options", {
    for (x in list(NULL, NA, 1, c(TRUE, FALSE))) {
      expect_error(mascot_placement(floating = x), "floating")
      expect_error(mascot_placement(TRUE, minimise = x), "minimise")
    }
    for (x in list(NULL, NA_character_, 1, "left", c("top-left", "top-right"))) {
      expect_error(mascot_placement(TRUE, position = x), "position")
    }
    expect_error(mascot_placement(position = "bottom-right"), "only works.*floating")
    expect_error(mascot_placement(minimise = FALSE), "only works.*floating")
    for (x in list(
      NULL,
      NA,
      1,
      "fixed",
      list(snap = TRUE),
      list(position = "top-left"),
      list(floating = FALSE, minimise = FALSE),
      list(TRUE),
      structure(list(TRUE, TRUE), names = c("floating", "floating"))
    )) {
      expect_error(as_placement_arg(x, environment()), "placement|floating")
    }
    bad <- mascot_placement()
    bad$floating <- NA
    expect_error(as_placement_arg(bad, environment()), "floating")
    bad <- mascot_placement()
    bad$position <- "top-left"
    expect_error(as_placement_arg(bad, environment()), "floating")
    bad <- mascot_placement()
    bad$typo <- TRUE
    expect_error(as_placement_arg(bad, environment()), "fields")
    expect_error(as_placement_arg("inline", NULL), "call")
    expect_identical(as_placement_arg(list(floating = FALSE), environment()), mascot_placement())
    expect_identical(
      as_placement_arg(list(floating = TRUE, minimise = TRUE), environment()),
      mascot_placement(TRUE, minimise = TRUE)
    )
    expect_error(as_placement_arg(list(floating = NA), environment()), "floating.*TRUE or FALSE")
    expect_error(as_placement_arg(list(floating = TRUE, position = "left"), environment()), "position.*top-left")
    expect_error(as_placement_arg(list(floating = TRUE, minimise = NA), environment()), "minimise.*TRUE or FALSE")
    expect_error(as_placement_arg(structure(1, class = "mascot_placement"), environment()), "placement")
    expect_snapshot(error = TRUE, mascot_placement(position = "top-left"))
    expect_snapshot(error = TRUE, mascot_placement(TRUE, position = "left"))
    expect_snapshot(error = TRUE, mascot_placement(minimise = TRUE))
  })
})
