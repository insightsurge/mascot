describe("mascot_gestures()", {
  it("lists the two gestures and their descriptions in a stable order", {
    expect_identical(
      mascot_gestures(),
      data.frame(
        name = c("nod", "wave"),
        description = c(
          "A short nod, such as to acknowledge an action.",
          "A wave, such as a greeting; characters without arms rock instead."
        )
      )
    )
  })
})

describe("mascot_gesture()", {
  it("makes a helper for each deliberate choice", {
    expect_identical(mascot_gesture("nod"), structure(list(name = "nod"), class = "mascot_gesture"))
    expect_identical(mascot_gesture("wave")$name, "wave")
  })
  it("requires a name and rejects invalid names and types clearly", {
    expect_error(mascot_gesture(), "missing")
    for (x in list(NULL, "", 1, NA_character_, c("nod", "wave"))) {
      expect_error(mascot_gesture(x), "Assertion on 'name' failed")
    }
    expect_snapshot(error = TRUE, mascot_gesture("jump"))
    expect_match(arg_problem("jump", "gesture"), '"nod", "wave"')
    expect_null(arg_problem(mascot_gesture("wave"), "gesture"))
    expect_match(arg_problem(structure(list(name = "jump"), class = "mascot_gesture"), "gesture"), "gesture")
    expect_error(check_arg("jump", "gesture", environment()), "not a gesture")
  })
})

describe("gesture help", {
  it("G2 names nod and wave in the name argument's help", {
    path <- system.file("man", "mascot_gesture.Rd", package = "mascot")
    rd <- if (nzchar(path)) tools::parse_Rd(path) else tools::Rd_db("mascot")[["mascot_gesture.Rd"]]
    arguments <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\arguments"), rd)[[1]]
    item <- Filter(function(x) identical(attr(x, "Rd_tag"), "\\item"), arguments)[[1]]
    text <- paste(unlist(item[[2]]), collapse = "")
    expect_match(text, '"nod"', fixed = TRUE)
    expect_match(text, '"wave"', fixed = TRUE)
  })
})

describe("mascot_gesture() named arguments", {
  it("keeps the agreed signature and rejects both forms of extra argument", {
    expect_identical(names(formals(mascot_gesture)), c("name", "..."))
    expect_error(mascot_gesture("nod", typo = 1), "Unexpected arguments", class = "mascot_error")
    expect_error(mascot_gesture("nod", 1), "Name the optional arguments", class = "mascot_error")
  })
})


describe("public argument error classes", {
  it("keeps the argument name and adds mascot_error to invalid types", {
    expect_error(mascot_gesture(name = 1), "name", class = "mascot_error")
  })
  it("adds mascot_error to the registered format and print methods", {
    expect_error(format.mascot_gesture(1), "x", class = "mascot_error")
    expect_error(print.mascot_gesture(1), "x", class = "mascot_error")
  })
})
