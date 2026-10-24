describe("mascot_preview()", {
  it("warns once, keeps colours and lists independent contrast findings in R and on the page", {
    warnings <- character()
    page <- withCallingHandlers(
      mascot_preview(theme = mascot_theme(light = list(body = "white"), dark = list(rim = "#212529"))),
      warning = function(warning) {
        warnings <<- c(warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
    expect_length(warnings, 1)
    expect_match(warnings, "colours are kept", fixed = TRUE)
    contrast <- attr(page, "contrast")
    expect_identical(contrast$role, c("body", "rim"))
    expect_identical(contrast$colour, c("#FFFFFF", "#212529"))
    expect_identical(contrast$background, c("#FFFFFF", "#212529"))
    expect_identical(contrast$mode, c("light", "dark"))
    expect_equal(contrast$ratio, c(1, 1))
    expect_length(preview_nodes(page, ".mascot-preview-contrast li"), 2)
    expect_match(as.character(page), "body: #FFFFFF against #FFFFFF, 1.00:1 (light).", fixed = TRUE)
    expect_identical(preview_theme(preview_nodes(page, ".mascot")[[1]])$light$body, "#FFFFFF")
    expect_snapshot({
      page <- mascot_preview(mood = "idle", theme = list(body = "white"))
    })
  })
  it("shares build-time errors for every shortcut and malformed helper", {
    cases <- list(
      list(character = NULL),
      list(character = "typo"),
      list(mood = "typo"),
      list(mood = 1),
      list(status = 1),
      list(bubble = 1),
      list(size = 23),
      list(size = NULL),
      list(size = Inf),
      list(placement = "middle"),
      list(placement = list(drag = TRUE)),
      list(theme = list(eye_whit = "red")),
      list(theme = list(light = "red")),
      list(motion = NULL),
      list(motion = "yes"),
      list(click = structure(list(items = c(about = "About"), extra = 1), class = "mascot_popup_menu")),
      list(size = structure(list(size = 96), class = "mascot_size")),
      list(theme = structure(list(mode = "night"), class = "mascot_theme")),
      list(motion = structure(list(animate = TRUE), class = "mascot_motion_settings"))
    )
    for (args in cases) {
      expect_error(do.call(mascot_preview, args), names(args)[[1]], fixed = TRUE)
    }
    expect_error(mascot_preview(click = c(about = "About")), class = "mascot_error_dots")
    expect_error(mascot_preview(click = mascot_action()), class = "mascot_error_dots")
    expect_error(mascot_preview(theme = list(body = "not-a-colour")), "Colour for role", fixed = TRUE)
    expect_snapshot(error = TRUE, mascot_preview(character = "typo"))
    expect_snapshot(error = TRUE, mascot_preview(mood = "typo"))
    expect_snapshot(error = TRUE, mascot_preview(theme = list(eye_whit = "red")))
  })
})
