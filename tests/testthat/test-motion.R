describe("mascot_motion()", {
  it("returns the agreed defaults and independent swap control", {
    expect_s3_class(mascot_motion(), "mascot_motion")
    expect_identical(unclass(mascot_motion()), list(animate = TRUE, swap = TRUE))
    expect_identical(unclass(mascot_motion(FALSE, FALSE)), list(animate = FALSE, swap = FALSE))
    expect_identical(as_motion_arg(TRUE, environment()), as_motion_arg(mascot_motion(), environment()))
    expect_identical(as_motion_arg(FALSE, environment()), as_motion_arg(mascot_motion(FALSE), environment()))
    expect_identical(as_motion_arg(TRUE, environment()), list(reduced = NULL, swap = TRUE))
    expect_identical(as_motion_arg(FALSE, environment()), list(reduced = TRUE, swap = TRUE))
    expect_identical(as_motion_arg(mascot_motion(swap = FALSE), environment()), list(reduced = NULL, swap = FALSE))
    expect_identical(as_motion_arg(mascot_motion(FALSE, FALSE), environment()), list(reduced = TRUE, swap = FALSE))
    expect_null(motion_problem(mascot_motion()))
  })
  it("rejects every invalid flag with its argument named", {
    for (x in list(NULL, NA, 1, "auto", logical(), c(TRUE, FALSE))) {
      expect_error(mascot_motion(animate = x), "Assertion on 'animate' failed")
      expect_error(mascot_motion(swap = x), "Assertion on 'swap' failed")
      expect_error(as_motion_arg(x, environment()), "motion.*must be TRUE, FALSE or a mascot_motion")
    }
    expect_error(as_motion_arg(TRUE, NULL), "Assertion on 'call' failed")
    expect_snapshot(error = TRUE, as_motion_arg("sometimes", environment()))
  })
  it("rejects malformed helpers, duplicate fields, unknown fields and invalid stored flags", {
    for (x in list(
      TRUE,
      list(),
      list(animate = TRUE),
      list(animate = TRUE, swap = TRUE, seed = 1),
      setNames(list(TRUE, TRUE), c("animate", "animate")),
      unname(list(TRUE, TRUE))
    )) {
      bad <- structure(x, class = "mascot_motion")
      expect_error(as_motion_arg(bad, environment()), "motion.*animate and swap fields")
    }
    for (field in c("animate", "swap")) {
      for (x in list(NULL, NA, 1, "false", c(TRUE, FALSE))) {
        bad <- mascot_motion()
        bad[field] <- list(x)
        expect_error(as_motion_arg(bad, environment()), paste0(field, "` must be TRUE or FALSE; got"))
      }
    }
    expect_null(arg_problem(FALSE, "motion"))
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_motion(animate = 1), "animate", class = "mascot_error")
    expect_error(mascot_motion(swap = 1), "swap", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_motion(1), "x", class = "mascot_error")
    expect_error(print.mascot_motion(1), "x", class = "mascot_error")
  })
})
