describe("helper format and print methods", {
  it("checks formatter arguments", {
    expect_error(helper_format(1), "'x'")
    expect_identical(helper_format(mascot_status()), "mascot_status()")
  })

  it("formats every helper readably and returns it invisibly from print", {
    helpers <- list(
      mascot_character(),
      mascot_mood(),
      mascot_status("Saving"),
      mascot_bubble("Ready", duration = Inf),
      mascot_gesture("nod"),
      mascot_size("20%"),
      mascot_placement(),
      mascot_theme(light = list(body = "#c2185b")),
      mascot_motion_settings(others = FALSE),
      mascot_popup_menu(c(about = "About")),
      mascot_action("Open help")
    )
    for (helper in helpers) {
      expect_error(getS3method("format", class(helper)[[1]])(1), "'x'")
      expect_error(getS3method("print", class(helper)[[1]])(1), "'x'")
      expect_type(format(helper), "character")
      expect_match(format(helper), paste0("^", class(helper)[[1]], "\\("))
      utils::capture.output(returned <- withVisible(print(helper)))
      expect_false(returned$visible)
      expect_identical(returned$value, helper)
    }
  })
})

describe("helper calls", {
  it("recreates helpers using public arguments, including HTML and inline placement", {
    helpers <- list(
      mascot_character(),
      mascot_mood(),
      mascot_mood("happy"),
      mascot_status(),
      mascot_status("Saved"),
      mascot_bubble(),
      mascot_bubble("Hi", duration = 3),
      mascot_bubble(htmltools::HTML("<b>Hi</b>"), duration = Inf, closable = FALSE),
      mascot_gesture("wave"),
      mascot_size(),
      mascot_size(96, small_screen = 48),
      mascot_placement(),
      mascot_placement("inline"),
      mascot_placement("top-left", drag = "snap"),
      mascot_theme(),
      mascot_theme(light = list(body = "blue"), mode = "dark"),
      mascot_action(),
      mascot_action("Open help", disabled = TRUE),
      mascot_popup_menu(),
      mascot_popup_menu(c(help = "Help"), label = "Help menu"),
      mascot_motion_settings(),
      mascot_motion_settings(swap = FALSE)
    )
    for (helper in helpers) {
      expect_identical(eval(parse(text = format(helper))), helper, info = class(helper)[[1]])
    }
    expect_identical(format(mascot_bubble("Hi", duration = 3)), 'mascot_bubble("Hi", duration = 3)')
    expect_identical(format(mascot_bubble()), "mascot_bubble()")
    expect_identical(format(mascot_placement("inline")), 'mascot_placement("inline")')
    expect_identical(format(mascot_theme()), "mascot_theme()")
  })
})

describe("checked character helper formatting", {
  it("labels checked drawing data instead of suggesting an unusable call", {
    bot <- mascot_read_character(system.file("examples", "characters", "study_bot.json", package = "mascot"))
    helper <- mascot_character(bot)
    expected <- "<mascot_character: study_bot (checked custom character)>"
    expect_identical(format(helper), expected)
    expect_identical(capture.output(print(helper)), expected)
  })
})
