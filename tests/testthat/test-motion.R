describe("mascot_motion_settings()", {
  it("resolves independent switches and leaves raw settings available for printing", {
    x <- mascot_motion_settings()
    expect_s3_class(x, "mascot_motion_settings")
    expect_null(x$idle)
    expect_true(x$others)
    on <- as_motion_arg(TRUE, environment())
    expect_identical(on, as_motion_arg(x, environment()))
    expect_null(on$reduced)
    flags <- c("idle", "mood_change", "gestures", "swap", "minimising", "restoring", "others")
    expect_true(all(vapply(on[flags], isTRUE, logical(1))))
    expect_identical(on$messages, as.list(c("bubble", "tooltip", "menu")))
    off <- as_motion_arg(FALSE, environment())
    expect_true(off$reduced)
    expect_true(all(vapply(off[flags], isFALSE, logical(1))))
    expect_identical(off$messages, list())
    expect_null(motion_problem(x))
    expect_null(arg_problem(FALSE, "motion"))
  })

  it("lets named switches win over others and NULL follow others", {
    for (flag in c("idle", "mood_change", "gestures", "swap", "minimising", "restoring")) {
      for (others in c(TRUE, FALSE)) {
        x <- do.call(mascot_motion_settings, setNames(list(!others, others), c(flag, "others")))
        payload <- as_motion_arg(x, environment())
        expect_identical(payload[[flag]], !others, info = flag)
        rest <- setdiff(c("idle", "mood_change", "gestures", "swap", "minimising", "restoring"), flag)
        expect_true(all(vapply(payload[rest], identical, logical(1), others)))
        x[flag] <- list(NULL)
        expect_identical(as_motion_arg(x, environment())[[flag]], others)
      }
    }
    menu <- as_motion_arg(mascot_motion_settings(messages = "menu", others = FALSE), environment())
    expect_identical(menu$messages, list("menu"))
    expect_false(menu$gestures)
    expect_null(menu$reduced)
    expect_identical(
      as_motion_arg(mascot_motion_settings(messages = TRUE, others = FALSE), environment())$messages,
      as.list(c("bubble", "tooltip", "menu"))
    )
    for (messages in list(FALSE, character(), NULL)) {
      expect_identical(
        as_motion_arg(mascot_motion_settings(messages = messages, others = FALSE), environment())$messages,
        list()
      )
    }
    expect_identical(
      as_motion_arg(mascot_motion_settings(messages = c("menu", "menu")), environment())$messages,
      list("menu")
    )
  })

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

  it("rejects malformed stored settings without accepting an old helper", {
    for (bad in list(
      list(),
      list(idle = TRUE),
      unname(as.list(rep(TRUE, 8))),
      setNames(as.list(rep(TRUE, 8)), rep("idle", 8))
    )) {
      expect_error(as_motion_arg(structure(bad, class = "mascot_motion_settings"), environment()), "all motion fields")
    }
    expect_error(
      as_motion_arg(structure(list(animate = TRUE, swap = TRUE), class = "mascot_motion"), environment()),
      "motion"
    )
    for (flag in c("idle", "mood_change", "gestures", "swap", "minimising", "restoring", "others", "messages")) {
      x <- mascot_motion_settings()
      x[flag] <- list(NA)
      expect_error(as_motion_arg(x, environment()), flag)
    }
    x <- mascot_motion_settings()
    x$unexpected <- TRUE
    expect_error(as_motion_arg(x, environment()), "all motion fields")
    x <- mascot_motion_settings()
    x$messages <- "dialog"
    expect_error(as_motion_arg(x, environment()), "bubble, tooltip, menu")
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


describe("motion shortcut equivalence (#349)", {
  it("uses reduced poses and drag transitions when all movement follows others off", {
    expect_identical(
      as_motion_arg(mascot_motion_settings(others = FALSE), environment()),
      as_motion_arg(FALSE, environment())
    )
  })
})

describe("motion panel choices (#350)", {
  it("reports unknown panels with the choice class and valid panel names", {
    expect_error(
      mascot_motion_settings(messages = c("menu", "dialog")),
      "messages.*bubble.*tooltip.*menu",
      class = "mascot_error_choice"
    )
  })
})
