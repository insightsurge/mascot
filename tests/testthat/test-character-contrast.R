describe("character-format authored colour and contrast", {
  it("checks native colours and all presets in both modes on the reference recipes", {
    for (id in c("tessa", "alpha_visor", "study_bot", "anchor_probe")) {
      data <- character_format_resolve(format_recipe(id))
      result <- character_format_contrast(data)
      if (length(data$contrast)) {
        expect_true(all(vapply(result, function(row) row$ratio_lower_bound >= 3, logical(1))))
        expect_setequal(vapply(result, `[[`, character(1), "mode"), c("light", "dark"))
      } else {
        expect_length(result, 0)
      }
    }
  })

  it("computes known solid contrast and rejects uncertain gradient backdrops", {
    data <- character_format_resolve(format_recipe())
    data$colours <- list(ink = "#000", paper = "#fff", middle = "#777")
    data$contrast <- list(list(fg = "ink", bg = "paper", min = 3))
    result <- character_format_contrast(data)
    expect_equal(result[[1]]$ratio_lower_bound, 21)
    data$paints <- list(
      backdrop = list(
        type = "linear",
        from = list(0, 0),
        to = list(1, 1),
        stops = list(list(0, "paper"), list(1, "ink"))
      )
    )
    data$contrast[[1]]$bg_paint <- "backdrop"
    format_problem("invalid_colour", "$.contrast[0]", character_format_contrast(data))
    data$contrast[[1]]$bg_paint <- NULL
    data$colours$ink <- "rgba(0,0,0,0.1)"
    format_problem("invalid_colour", "$.contrast[0]", character_format_contrast(data))
  })

  it("keeps native followers unchanged and derives them only from supplied preset leaders", {
    data <- character_format_resolve(format_recipe())
    data$colours <- list(leader = "#f00", follower = "#0f0", other = "#00f")
    data$follows <- list(follower = list(from = list("leader"), shade = "same", amount = 0))
    data$palettes <- list(test = list(description = "Test", light = list(leader = "#00f")))
    native <- character_format_colours(data)
    selected <- character_format_colours(data, preset = "test")
    expect_equal(native$follower, c(0, 1, 0, 1))
    expect_equal(selected$follower, c(0, 0, 1, 1))
    changed <- character_format_colours(data, preset = "test", recolour = list(leader = "other", follower = "other"))
    expect_equal(changed$leader, c(0, 0, 1, 1))
    expect_equal(changed$follower, c(0, 0, 1, 1))
    data$follows$leader <- list(from = list("follower"))
    format_problem("invalid_colour", "$.follows.follower", character_format_colours(data))
  })

  it("rejects malformed or out-of-range authored RGBA channels", {
    expect_equal(character_colour("#abc"), c(170, 187, 204, 255) / 255)
    expect_equal(character_colour("rgba(255, 0, 0, 0.5)"), c(1, 0, 0, .5))
    for (colour in c("red", "rgba(256,0,0,1)", "rgba(1.2.3,0,0,1)", "rgba(0,0,0,2)")) {
      expect_error(character_colour(colour), class = "mascot_error_character")
    }
    expect_error(character_colour(1))
    expect_error(character_colour("#fff", path = 1))
    expect_error(character_colour_follow(1, list()))
    expect_error(character_colour_follow(c(0, 0, 0, 1), 1))
    expect_error(character_format_colours(1))
    expect_error(character_format_colours(list(), mode = "auto"))
    expect_error(character_format_colours(list(), preset = 1))
    expect_error(character_format_colours(list(), recolour = 1))
    expect_error(character_luminance(1))
    expect_error(character_format_contrast(1))
  })
})
