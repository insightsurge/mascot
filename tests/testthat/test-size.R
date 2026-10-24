describe("mascot_size()", {
  it("accepts pixels, percentages, NULL, and 'auto' by default", {
    expect_identical(
      mascot_size(),
      structure(list(size = 160, small_screen = "auto"), class = "mascot_size")
    )
    expect_identical(mascot_size("20%", small_screen = "10%")$small_screen, "10%")
    expect_identical(mascot_size(120, small_screen = NULL)$small_screen, NULL)
    expect_identical(mascot_size(120, small_screen = "auto")$small_screen, "auto")
    expect_identical(as_size_arg(96, environment()), mascot_size(96))
    expect_identical(
      as_size_arg(mascot_size(120, small_screen = 48), environment()),
      mascot_size(120, small_screen = 48)
    )
    expect_identical(
      as_size_arg(mascot_size(120, small_screen = NULL), environment()),
      mascot_size(120, small_screen = NULL)
    )
  })
  it("has no small-drawing switch: every size draws the full character", {
    expect_identical(names(formals(mascot_size)), c("size", "...", "small_screen"))
    expect_identical(formals(mascot_size)$small_screen, "auto")
    expect_error(mascot_size(24, simplify_when_small = FALSE), "Unexpected arguments", class = "mascot_error")
  })
})

describe("mascot_size() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_size)), c("size", "...", "small_screen"))
    expect_error(mascot_size(160, typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_size(160, 1), "Name the optional arguments", class = "mascot_error")
  })
})

describe("mascot_size() print and format output", {
  it("prints only arguments that differ from defaults, omitting 'auto'", {
    expect_identical(format(mascot_size()), "mascot_size()")
    expect_identical(format(mascot_size(120)), "mascot_size(120)")
    expect_identical(format(mascot_size(small_screen = NULL)), "mascot_size(small_screen = NULL)")
    expect_identical(format(mascot_size(120, small_screen = 48)), "mascot_size(120, small_screen = 48)")
    expect_identical(format(mascot_size(120, small_screen = "auto")), "mascot_size(120)")
    expect_output(print(mascot_size()), "^mascot_size\\(\\)$")
    expect_output(print(mascot_size(small_screen = NULL)), "^mascot_size\\(small_screen = NULL\\)$")
  })
})

describe("responsive size behaviour and CSS rules", {
  it("leaves inline mascots unaffected and reduces floating mascots on small screens", {
    floating <- mascot("float", placement = "bottom-right")
    expect_identical(floating$attribs$`data-floating`, "true")
    expect_identical(floating$attribs$`data-small-screen`, "auto")

    inline <- mascot("inline", placement = "inline")
    expect_identical(inline$attribs$`data-floating`, "false")
    expect_identical(inline$attribs$`data-small-screen`, "auto")

    fixed <- mascot("fixed", size = mascot_size(120, small_screen = NULL))
    expect_null(fixed$attribs$`data-small-screen`)
  })
  it("defines the phone size rule in mascot.css and reads the same value in R", {
    css_file <- system.file("www", "mascot.css", package = "mascot")
    lines <- readLines(css_file)
    css_text <- paste(lines, collapse = "\n")

    # CSS rule present
    expect_true(grepl(".mascot[data-floating=\"true\"][data-small-screen=\"auto\"]", css_text, fixed = TRUE))
    expect_true(grepl("min(var(--_mascot-size-default, 160px), 96px)", css_text, fixed = TRUE))
  })
})

describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_size(size = TRUE), "size", class = "mascot_error")
    expect_error(mascot_size(small_screen = TRUE), "small_screen", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_size(1), "x", class = "mascot_error")
    expect_error(print.mascot_size(1), "x", class = "mascot_error")
  })
})

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
