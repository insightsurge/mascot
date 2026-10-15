describe("character-format authored colour and contrast", {
  it("checks native colours and all presets in both modes on the reference recipes", {
    for (id in c("tessa", "alpha_visor", "study_bot", "anchor_probe")) {
      data <- character_format_resolve(format_recipe(id))
      result <- character_format_contrast(data, builtin = id %in% c("tessa", "alpha_visor"))
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
    expect_error(character_format_contrast(1))
  })

  it("matches independent WCAG 2 worst-case contrast over a two-stop linear background", {
    # Hand calculation (wcag_contrast.py):
    # 1. Base background: #0a1118 (alpha 1.0) -> RGB (10/255, 17/255, 24/255)
    # 2. Gradient stops composited over base background:
    #    Stop 1: rgba(20, 34, 48, 0.8)
    #      stop1_comp = [20/255 * 0.8 + 10/255 * 0.2, 34/255 * 0.8 + 17/255 * 0.2, 48/255 * 0.8 + 24/255 * 0.2]
    #                 = [18/255, 30.6/255, 43.2/255] ~ [0.070588235294, 0.120000000000, 0.169411764706]
    #    Stop 2: #20364c (alpha 1.0)
    #      stop2_comp = [32/255, 54/255, 76/255] ~ [0.125490196078, 0.211764705882, 0.298039215686]
    # 3. Per-channel background extrema:
    #    lower = min(stop1_comp, stop2_comp) = [0.070588235294, 0.120000000000, 0.169411764706]
    #    upper = max(stop1_comp, stop2_comp) = [0.125490196078, 0.211764705882, 0.298039215686]
    # 4. Translucent foreground: rgba(255, 255, 255, 0.6) (alpha 0.6) composited over lower and upper:
    #    fg_over_lower = 1.0 * 0.6 + lower * 0.4 = [0.628235294118, 0.648000000000, 0.667764705882]
    #    fg_over_upper = 1.0 * 0.6 + upper * 0.4 = [0.650196078431, 0.684705882353, 0.719215686275]
    # 5. Relative luminance (WCAG standard formula: c <= 0.04045 ? c/12.92 : ((c+0.055)/1.055)^2.4; 0.2126R + 0.7152G + 0.0722B):
    #    L_lower_bg = 0.012636963237
    #    L_upper_bg = 0.034672123695
    #    L_fg_lower = 0.374040326609
    #    L_fg_upper = 0.420254342090
    # 6. Closest pair contrast ratio:
    #    Foreground is brighter than background; closest pair is L_fg_lower and L_upper_bg:
    #      ratio = (0.374040326609 + 0.05) / (0.034672123695 + 0.05)
    #            = 0.424040326609 / 0.084672123695
    #            = 5.008027531447
    recipe <- format_recipe("anchor_probe")
    recipe$colours$bg_role <- "#0a1118"
    recipe$colours$stop1_role <- "rgba(20, 34, 48, 0.8)"
    recipe$colours$stop2_role <- "#20364c"
    recipe$colours$fg_role <- "rgba(255, 255, 255, 0.6)"
    recipe$paints <- list(
      linear_bg = list(
        type = "linear",
        from = list(0, 0),
        to = list(0, 100),
        stops = list(
          list(0, "stop1_role"),
          list(1, "stop2_role")
        )
      )
    )
    recipe$contrast <- list(
      list(
        fg = "fg_role",
        bg = "bg_role",
        bg_paint = "linear_bg",
        min = 3
      )
    )

    data <- character_format_resolve(recipe)
    res <- character_format_contrast(data)
    expected_ratio <- 5.008027531447
    expect_equal(res[[1L]]$ratio_lower_bound, expected_ratio, tolerance = 1e-9)

    recipe$contrast[[1L]]$min <- 5.01
    format_problem(
      "invalid_colour",
      "$.contrast[0]",
      character_format_contrast(character_format_resolve(recipe))
    )
  })
})

describe("contrast promises for built-in faces", {
  it("requires a built-in face to declare its feature contrast", {
    data <- format_recipe("tessa")
    data$contrast <- list()
    format_problem("invalid_colour", "$.contrast", character_format_check(data, builtin = TRUE))
  })

  it("follows a mapped feature role and leaves custom characters to their own promises", {
    data <- format_recipe("alpha_visor")
    data$contrast <- data$contrast[1]
    expect_s3_class(character_format_check(data, builtin = TRUE), "mascot_character_data")
    data$contrast[[1]]$fg <- "feature"
    format_problem("invalid_colour", "$.contrast", character_format_check(data, builtin = TRUE))
    custom <- format_recipe("study_bot")
    custom$contrast <- list()
    expect_s3_class(character_format_check(custom), "mascot_character_data")
  })

  it("calculates HSL follow adjustments for green and blue maximum channels", {
    # Hand calculation for green maximum:
    # Pure green: rgb = c(0, 1, 0, 1) -> high = 1, low = 0, delta = 1, light = 0.5
    # hue = (0 - 0)/1 + 2 = 2.0
    # Raising HSL lightness from 0.5 to 0.6 gives RGB (0.2, 1, 0.2).
    green_follow <- character_colour_follow(c(0, 1, 0, 1), list(amount = 0.1))
    expect_equal(green_follow, c(0.2, 1, 0.2, 1))

    # Hand calculation for blue maximum:
    # Pure blue: rgb = c(0, 0, 1, 1) -> high = 1, low = 0, delta = 1, light = 0.5
    # hue = (0 - 0)/1 + 4 = 4.0
    # Raising HSL lightness from 0.5 to 0.6 gives RGB (0.2, 0.2, 1).
    blue_follow <- character_colour_follow(c(0, 0, 1, 1), list(amount = 0.1))
    expect_equal(blue_follow, c(0.2, 0.2, 1, 1))
  })

  it("applies dark mode colour overrides and rejects undeclared palettes", {
    recipe <- format_recipe("anchor_probe")
    recipe$modes <- list(dark = list(colours = list(body = "#ffffff")))
    data <- character_format_resolve(recipe)
    cols <- character_format_colours(data, mode = "dark")
    expect_equal(cols$body, c(1, 1, 1, 1))

    # Undeclared palette preset
    format_problem("missing_reference", "$.palettes", character_format_colours(data, preset = "ghost_preset"))
  })

  it("evaluates page_light and page_dark baselines and rejects missing contrast references", {
    # Contrast pairs with page_light and page_dark baselines
    recipe <- format_recipe("anchor_probe")
    recipe$contrast <- list(
      list(fg = "outline", bg = "page_light", min = 3),
      list(fg = "body", bg = "page_dark", min = 3)
    )
    data <- character_format_resolve(recipe)
    result <- character_format_contrast(data)
    expect_true(length(result) >= 2)
    expect_true(all(vapply(result, function(r) r$ratio_lower_bound >= 3, logical(1))))

    # Undeclared foreground colour role
    data_bad_fg <- data
    data_bad_fg$contrast[[1]]$fg <- "ghost_fg"
    format_problem("invalid_colour", "$.contrast[0].fg", character_format_contrast(data_bad_fg))

    # Undeclared background colour role
    data_bad_bg <- data
    data_bad_bg$contrast[[1]]$bg <- "ghost_bg"
    format_problem("invalid_colour", "$.contrast[0].bg", character_format_contrast(data_bad_bg))

    # Undeclared bg_paint in contrast pair
    data_bad_paint <- data
    data_bad_paint$contrast[[1]]$bg <- "outline"
    data_bad_paint$contrast[[1]]$bg_paint <- "ghost_paint"
    format_problem("missing_reference", "$.contrast[0].bg_paint", character_format_contrast(data_bad_paint))
  })
})

describe("explicit built-in face provenance", {
  it("applies the face promise to a built-in regardless of its id", {
    data <- format_recipe("study_bot")
    data$contrast <- list()
    expect_s3_class(character_format_check(data), "mascot_character_data")
    format_problem("invalid_colour", "$.contrast", character_format_check(data, builtin = TRUE))
    resolved <- character_format_resolve(data)
    expect_error(character_format_contrast(resolved, builtin = NA))
    expect_error(character_format_contrast(resolved, builtin = "yes"))
  })
})
