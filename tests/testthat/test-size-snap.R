describe("mascot_size()", {
  it("rejects every invalid size with a useful message naming valid forms", {
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
      "auto",
      list()
    )) {
      expect_error(mascot_size(x), "size")
    }
    for (x in list(NA_real_, Inf, 23, "0%", c(24, 48), TRUE, "bad", "auto ", "none", "px")) {
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
    expect_error(size_value_problem(48, "size", allow_auto = 1), "allow_auto")
    expect_error(check_size_value(48, NULL, environment()), "arg")
    expect_error(check_size_value(48, "size", NULL), "call")
    expect_error(check_size_value(48, "size", environment(), allow_auto = 1), "allow_auto")
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
