behaviour_recipe <- function(id = "anchor_probe") {
  data <- character_format_resolve(format_recipe(id))
  list(data = data, graph = character_format_references(data))
}

describe("character_format_behaviour()", {
  it("checks canonical moods and resolves missing anatomical gestures to a real fallback", {
    for (id in c("tessa", "alpha_visor", "anchor_probe", "study_bot")) {
      fixture <- behaviour_recipe(id)
      checked <- character_format_behaviour(fixture$data, fixture$graph)
      expect_setequal(names(checked$mood_bases), names(fixture$data$moods))
      if (id == "study_bot") {
        expect_identical(checked$playable$nod, "rock")
        expect_identical(checked$playable$wave, "rock")
        expect_identical(checked$playable$greet, "greet")
      }
    }
  })

  it("does not waive typos outside a gesture's explicitly absent needs", {
    fixture <- behaviour_recipe("study_bot")
    fixture$data$gestures$wave$tracks <- list("misspelt_hand.rotate" = list(list(0, 0), list(1, 0)))
    format_problem(
      "invalid_channel",
      "$.gestures.wave.tracks.misspelt_hand.rotate",
      character_format_behaviour(fixture$data, fixture$graph)
    )
    fixture <- behaviour_recipe("study_bot")
    fixture$data$gestures$rock$fallback <- "wave"
    format_problem(
      "missing_reference",
      "$.gestures.rock.fallback",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })

  it("rejects unresolved extra moods and invalid channel membership", {
    fixture <- behaviour_recipe()
    fixture$data$moods$extra <- list(description = "Extra", status = "Extra", fallback = "extra")
    format_problem(
      "missing_reference",
      "$.moods.extra.fallback",
      character_format_behaviour(fixture$data, fixture$graph)
    )
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$channels <- list("panel.variant" = "typo")
    format_problem(
      "invalid_channel",
      "$.moods.idle.channels.panel.variant",
      character_format_behaviour(fixture$data, fixture$graph)
    )
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$channels <- list("panel.opacity" = 2)
    format_problem(
      "invalid_channel",
      "$.moods.idle.channels.panel.opacity",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })

  it("requires tracks to return to rest without changing discrete values by interpolation", {
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list("panel.rotate" = list(list(0, 0), list(.5, .1), list(1, .1)))
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.rotate",
      character_format_behaviour(fixture$data, fixture$graph)
    )
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list(
      "panel.variant" = list(mode = "set", keys = list(list(0, NULL), list(.5, "raised"), list(1, NULL)))
    )
    expect_identical(character_format_behaviour(fixture$data, fixture$graph)$tracks$rock$panel.variant$mode, "set")
    fixture$data$gestures$rock$tracks$panel.variant$keys[[3]][2] <- list("raised")
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.variant",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })

  it("checks helper arguments and scalar channel types", {
    expect_error(character_format_channels(1, list()))
    expect_error(character_format_channels(list(), 1))
    expect_error(character_format_behaviour(1, list()))
    expect_error(character_format_behaviour(list(), 1))
    expect_error(
      character_channel_value(TRUE, list(type = "number", lower = 0, upper = 1), "$"),
      class = "mascot_error_character"
    )
  })
})
