describe("mascot_size()", {
  it("accepts pixels, percentages and a narrow-screen override", {
    expect_identical(
      mascot_size(),
      structure(list(size = 160, small_screen = NULL), class = "mascot_size")
    )
    expect_identical(mascot_size("20%", "10%")$small_screen, "10%")
    expect_identical(as_size_arg(96, environment()), mascot_size(96))
    expect_identical(as_size_arg(mascot_size(120, 48), environment()), mascot_size(120, 48))
  })
  it("has no small-drawing switch: every size draws the full character", {
    expect_identical(names(formals(mascot_size)), c("size", "small_screen"))
    expect_error(mascot_size(24, simplify_when_small = FALSE), "unused argument")
  })
  it("rejects every invalid size with a useful message", {
    for (x in list(
      NULL,
      NA_real_,
      NaN,
      Inf,
      -1,
      0,
      23,
      c(24, 48),
      TRUE,
      "24px",
      "0%",
      "-2%",
      " 20%",
      "20 %",
      "Inf%",
      "",
      list()
    )) {
      expect_error(mascot_size(x), "size")
    }
    for (x in list(NA_real_, Inf, 23, "0%", c(24, 48), TRUE)) {
      expect_error(mascot_size(120, small_screen = x), "small_screen")
    }
    expect_snapshot(error = TRUE, mascot_size("24px"))
    expect_snapshot(error = TRUE, mascot_size(23))
    expect_snapshot(error = TRUE, mascot_size(120, small_screen = "bad"))
    bad <- mascot_size()
    bad$size <- 1
    expect_error(as_size_arg(bad, environment()), "size")
    bad <- mascot_size()
    bad$typo <- TRUE
    expect_error(as_size_arg(bad, environment()), "fields")
    expect_error(as_size_arg(48, NULL), "call")
    expect_error(size_value_problem(48, NULL), "arg")
    expect_error(check_size_value(48, NULL, environment()), "arg")
    expect_error(check_size_value(48, "size", NULL), "call")
    for (size in c(".5%", "0.5%", "200%")) {
      expect_identical(mascot_size(size)$size, size)
    }
    huge <- paste0(paste(rep("9", 400), collapse = ""), "%")
    expect_error(mascot_size(huge), "positive percentage")
    bad <- mascot_size()
    bad$small_screen <- 23
    expect_error(as_size_arg(bad, environment()), "small_screen")
    bad <- mascot_size()
    bad$simplify_when_small <- TRUE
    expect_error(as_size_arg(bad, environment()), "size and small_screen fields")
    expect_error(as_size_arg(structure(1, class = "mascot_size"), environment()), "fields")
  })
})
