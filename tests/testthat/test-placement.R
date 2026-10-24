describe("mascot_placement()", {
  it("normalises every shortcut to one position and floats bottom-right by default", {
    expect_identical(
      mascot_placement(),
      structure(list(position = "bottom-right", minimise = TRUE, drag = "none"), class = "mascot_placement")
    )
    expect_identical(as_placement_arg("inline", environment()), mascot_placement("inline"))
    expect_error(as_placement_arg("floating", environment()), "bottom-right", class = "mascot_error")
    for (corner in c("top-left", "top-right", "bottom-left", "bottom-right")) {
      expect_identical(as_placement_arg(corner, environment()), mascot_placement(corner))
    }
    expect_identical(
      as_placement_arg(list(position = "top-left", minimise = TRUE), environment()),
      mascot_placement("top-left", minimise = TRUE)
    )
    expect_identical(as_placement_arg(list(), environment()), mascot_placement())
    expect_identical(
      as_placement_arg(list(minimise = TRUE), environment()),
      mascot_placement("bottom-right", minimise = TRUE)
    )
    expect_identical(
      as_placement_arg(list(drag = "snap"), environment()),
      mascot_placement("bottom-right", drag = "snap")
    )
    expect_identical(
      as_placement_arg(mascot_placement("bottom-right", minimise = TRUE), environment()),
      mascot_placement("bottom-right", minimise = TRUE)
    )
  })
  it("sends the browser's floating, corner and minimise fields", {
    expect_identical(
      placement_wire(mascot_placement()),
      list(floating = TRUE, position = "bottom-right", minimise = TRUE, drag = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("inline")),
      list(floating = FALSE, position = "bottom-right", minimise = FALSE, drag = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("top-left", minimise = TRUE)),
      list(floating = TRUE, position = "top-left", minimise = TRUE, drag = FALSE)
    )
    expect_identical(
      placement_wire(mascot_placement("bottom-left", drag = "free")),
      list(floating = TRUE, position = "bottom-left", minimise = TRUE, drag = "free")
    )
    expect_error(placement_wire(list(position = "inline")), "mascot_placement")
  })
  it("accepts drag modes with a corner, in the helper and the named-list shortcut", {
    expect_identical(mascot_placement("top-left", drag = "snap")$drag, "snap")
    expect_identical(mascot_placement("bottom-right", minimise = TRUE, drag = "free")$drag, "free")
    expect_identical(
      as_placement_arg(list(position = "top-left", drag = "snap"), environment()),
      mascot_placement("top-left", drag = "snap")
    )
    expect_identical(
      as_placement_arg(list(position = "top-right", minimise = TRUE, drag = "none"), environment()),
      mascot_placement("top-right", minimise = TRUE)
    )
    expect_identical(
      format(mascot_placement("bottom-right", drag = "snap")),
      'mascot_placement(drag = "snap")'
    )
  })
  it("writes the drag mode for the browser and drops it for inline mascots", {
    html <- as.character(mascot(id = "a", placement = list(position = "top-left", drag = "snap")))
    expect_match(html, 'data-drag="snap"', fixed = TRUE)
    expect_match(html, 'data-position="top-left"', fixed = TRUE)
    expect_match(as.character(mascot(id = "a")), 'data-drag="false"', fixed = TRUE)
  })
})

describe("mascot_placement() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_placement)), c("position", "...", "minimise", "drag"))
    expect_error(mascot_placement("bottom-right", typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_placement("bottom-right", 1), "Name the optional arguments", class = "mascot_error")
  })
})

describe("placement migration errors", {
  it("rejects both logical drag modes with the none hint in helpers and shortcuts", {
    for (drag in c(FALSE, TRUE)) {
      expect_error(mascot_placement(drag = drag), 'drag = "none"', class = "mascot_error")
      expect_error(mascot("helper", placement = list(drag = drag)), 'drag = "none"', class = "mascot_error")
    }
    expect_error(mascot("helper", placement = "floating"), "bottom-right", class = "mascot_error")
  })
  it("retains both placement and general message classes", {
    expect_message(mascot_placement("inline", drag = "none"), class = "mascot_placement_ignored")
    expect_message(mascot_placement("inline", minimise = TRUE), class = "mascot_message")
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_placement(position = 1), "position", class = "mascot_error")
    expect_error(mascot_placement(minimise = 1), "minimise", class = "mascot_error")
    expect_error(mascot_placement(drag = 1), "drag", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_placement(1), "x", class = "mascot_error")
    expect_error(print.mascot_placement(1), "x", class = "mascot_error")
  })
})

describe("drag choices", {
  it("uses the choice class for unknown strings and logical migration errors", {
    expect_error(mascot_placement(drag = "wrong"), class = "mascot_error_choice")
    expect_error(mascot_placement(drag = TRUE), class = "mascot_error_choice")
  })
})

describe("drag mode guidance", {
  it("prints logical values without quotes and explains every mode", {
    error <- tryCatch(mascot_placement(drag = TRUE), error = identity)
    message <- conditionMessage(error)
    expect_match(message, "TRUE is not a drag mode", fixed = TRUE)
    expect_match(message, '"none" disables dragging', fixed = TRUE)
    expect_match(message, '"snap" moves to the nearest corner', fixed = TRUE)
    expect_match(message, '"free" stays where dropped', fixed = TRUE)
    expect_identical(error$value, TRUE)
  })
})

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
