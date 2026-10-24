describe("mascot_motion_settings()", {
  it("rejects every invalid flag and extra argument with mascot_error", {
    for (flag in c("idle", "mood_change", "gestures", "swap", "minimising", "restoring", "others")) {
      for (bad in list(NA, 1, "auto", logical(), c(TRUE, FALSE))) {
        expect_error(do.call(mascot_motion_settings, setNames(list(bad), flag)), flag, class = "mascot_error")
      }
    }
    expect_error(mascot_motion_settings(others = NULL), "others", class = "mascot_error")
    expect_error(mascot_motion_settings(FALSE), class = "mascot_error")
    expect_error(mascot_motion_settings(animate = FALSE), "animate", class = "mascot_error")
    expect_error(mascot_motion_settings(typo = FALSE), "typo", class = "mascot_error")
    for (bad in list(NA, 1, list(), c(TRUE, FALSE), c("menu", NA_character_))) {
      expect_error(mascot_motion_settings(messages = bad), "messages", class = "mascot_error")
    }
    for (bad in list("", "toString", c("menu", "dialog"))) {
      expect_error(mascot_motion_settings(messages = bad), "bubble.*tooltip.*menu", class = "mascot_error")
    }
    for (bad in list(NULL, NA, 1, "auto", logical(), c(TRUE, FALSE))) {
      expect_error(as_motion_arg(bad, environment()), "motion.*must be TRUE, FALSE or")
    }
    expect_error(as_motion_arg(TRUE, NULL), "call")
    expect_snapshot(error = TRUE, as_motion_arg("sometimes", environment()))
  })

  it("prints only the supplied settings and returns the helper invisibly", {
    expect_identical(format(mascot_motion_settings()), "mascot_motion_settings()")
    expect_identical(format(mascot_motion_settings(idle = FALSE)), "mascot_motion_settings(idle = FALSE)")
    expect_identical(
      format(mascot_motion_settings(messages = "menu", others = FALSE)),
      'mascot_motion_settings(messages = "menu", others = FALSE)'
    )
    expect_snapshot(print(mascot_motion_settings(messages = "menu", others = FALSE)))
    x <- mascot_motion_settings(gestures = FALSE)
    returned <- withVisible(print(x))
    expect_false(returned$visible)
    expect_identical(returned$value, x)
    expect_error(format.mascot_motion_settings(1), "x", class = "mascot_error")
    expect_error(print.mascot_motion_settings(1), "x", class = "mascot_error")
  })
})
