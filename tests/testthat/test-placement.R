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
