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
    # Boolean, choice, eyes, and blush channel validation
    expect_null(character_channel_value(TRUE, list(type = "boolean"), "$"))
    expect_null(character_channel_value(
      "default",
      list(type = "choice", base = "default", choices = c("default", "raised")),
      "$"
    ))
    expect_null(character_channel_value("open", list(type = "eyes", choices = c("open", "closed")), "$"))
    expect_null(character_channel_value(
      list("open", "closed"),
      list(type = "eyes", choices = c("open", "closed")),
      "$"
    ))
    expect_null(character_channel_value("strong", list(type = "blush"), "$"))
    expect_null(character_channel_value(0.5, list(type = "blush"), "$"))
    format_problem("invalid_channel", "$", character_channel_value("extreme", list(type = "blush"), "$"))
    format_problem(
      "invalid_channel",
      "$",
      character_channel_value("invalid_eye", list(type = "eyes", choices = c("open", "closed")), "$")
    )
  })

  it("checks poses and switch channel rules", {
    # Pose targeting undeclared channel
    fixture <- behaviour_recipe()
    fixture$data$poses <- list(test_pose = list(ghost_channel = 1))
    format_problem(
      "missing_reference",
      "$.poses.test_pose.ghost_channel",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Part switch referencing non-numeric channel
    fixture <- behaviour_recipe()
    fixture$graph$parts$panel$switch <- list(channel = "panel.visible", above = 0.5, variant = "raised")
    format_problem(
      "invalid_channel",
      "$.parts[0].switch.channel",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })

  it("enforces mood metadata, core fallbacks, poses, and item/recolour contracts", {
    # Nonempty description and status required
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$description <- ""
    format_problem("input_type", "$.moods.idle.description", character_format_behaviour(fixture$data, fixture$graph))

    fixture <- behaviour_recipe()
    fixture$data$moods$idle$status <- ""
    format_problem("input_type", "$.moods.idle.status", character_format_behaviour(fixture$data, fixture$graph))

    # Core mood declaring fallback is forbidden
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$fallback <- "thinking"
    format_problem("input_type", "$.moods.idle.fallback", character_format_behaviour(fixture$data, fixture$graph))

    # Extra mood referencing missing fallback target
    fixture <- behaviour_recipe()
    fixture$data$moods$extra <- list(description = "Extra", status = "Extra", fallback = "missing_mood")
    format_problem(
      "missing_reference",
      "$.moods.extra.fallback",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Mood referencing undeclared pose
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$pose <- "ghost_pose"
    format_problem("missing_reference", "$.moods.idle.pose", character_format_behaviour(fixture$data, fixture$graph))

    # Mood recolour undeclared role
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$recolour <- list(missing_role = "body")
    format_problem(
      "invalid_colour",
      "$.moods.idle.recolour.missing_role",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Mood recolour cycle
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$recolour <- list(body = "outline", outline = "body")
    format_problem(
      "invalid_colour",
      "$.moods.idle.recolour.body",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Mood items targeting undeclared item
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$items <- list("panel.ghost_item" = list(fill = "body"))
    format_problem(
      "missing_reference",
      "$.moods.idle.items.panel.ghost_item",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Mood items fill undeclared colour role
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$items <- list("panel.surface" = list(fill = "ghost_colour"))
    format_problem(
      "invalid_colour",
      "$.moods.idle.items.panel.surface.fill",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Mood items fill undeclared paint
    fixture <- behaviour_recipe()
    fixture$data$moods$idle$items <- list("panel.surface" = list(fill = list(paint = "ghost_paint")))
    format_problem(
      "missing_reference",
      "$.moods.idle.items.panel.surface.fill",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })

  it("validates required callable gestures, fallbacks, and track timing", {
    # Gesture fallback pointing to undeclared fallback
    fixture <- behaviour_recipe()
    fixture$data$gestures$nod$fallback <- "ghost_gesture"
    format_problem(
      "missing_reference",
      "$.gestures.nod.fallback",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Gesture requiring absent parts without a playable fallback
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$needs <- list("absent_part")
    fixture$data$gestures$nod$fallback <- "rock"
    fixture$data$gestures$wave$fallback <- "rock"
    format_problem(
      "missing_reference",
      "$.gestures.rock.fallback",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Gesture description missing
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$description <- NULL
    format_problem("input_type", "$.gestures.rock.description", character_format_behaviour(fixture$data, fixture$graph))

    # Track keys times must start at 0, end at 1, and increase strictly
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list(
      "panel.rotate" = list(list(0, 0), list(0.4, 0.1), list(0.3, 0.1), list(1, 0))
    )
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.rotate",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Discrete channel with mode='add' is rejected
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list(
      "panel.visible" = list(mode = "add", keys = list(list(0, 0), list(1, 0)))
    )
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.visible",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Add track with NULL key offset
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list(
      "panel.rotate" = list(list(0, 0), list(0.5, NULL), list(1, 0))
    )
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.rotate",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Add track with non-numeric offset
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list(
      "panel.rotate" = list(list(0, 0), list(0.5, "not_a_number"), list(1, 0))
    )
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.rotate",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Numeric set track ending at value that does not match all mood bases
    fixture <- behaviour_recipe()
    fixture$data$gestures$rock$tracks <- list(
      "panel.rotate" = list(mode = "set", keys = list(list(0, 0), list(1, 0.5)))
    )
    format_problem(
      "invalid_channel",
      "$.gestures.rock.tracks.panel.rotate",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Gesture effects trigger referencing undeclared kit effect
    fixture <- behaviour_recipe("study_bot")
    fixture$data$gestures$greet$effects <- list(list(effect = "ghost_eff", anchor = "badge"))
    format_problem(
      "missing_reference",
      "$.gestures.greet.effects[0]",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })

  it("checks motion idle intervals, breathe parts, and change gestures", {
    # Blink window exceeds blink interval: blink_jitter + blink_frames / 2 >= blink_every
    fixture <- behaviour_recipe()
    fixture$data$motion$idle <- list(blink_every = 30, blink_jitter = 25, blink_frames = 12)
    format_problem("input_type", "$.motion.idle.blink_every", character_format_behaviour(fixture$data, fixture$graph))

    # Breathe part not in root or declared parts
    fixture <- behaviour_recipe()
    fixture$data$motion$idle <- list(breathe_part = "ghost_part")
    format_problem(
      "missing_reference",
      "$.motion.idle.breathe_part",
      character_format_behaviour(fixture$data, fixture$graph)
    )

    # Idle extra gesture not in playable gestures
    fixture <- behaviour_recipe()
    fixture$data$motion$idle <- list(extra = "ghost_gesture")
    format_problem("missing_reference", "$.motion.idle.extra", character_format_behaviour(fixture$data, fixture$graph))

    # Change motion style gesture with undeclared change gesture
    fixture <- behaviour_recipe()
    fixture$data$motion$change <- list(style = "gesture", gesture = "ghost_gesture")
    format_problem(
      "missing_reference",
      "$.motion.change.gesture",
      character_format_behaviour(fixture$data, fixture$graph)
    )
  })
})

describe("comments in mood face controls", {
  it("reads a note in a mood's face, or its reduced face, as a comment and not as a control", {
    data <- format_recipe("tessa")
    data$id <- "tessa_noted"
    plain <- character_format_check(data)
    data$moods$happy$face$note <- "A wide smile."
    data$moods$happy$reduced <- list(face = list(note = "Still smiling."))
    noted <- character_format_check(data)
    expect_identical(noted$moods$happy$face$note, "A wide smile.")
    expect_identical(attr(noted, "mascot_manifest")$work, attr(plain, "mascot_manifest")$work)
  })
})
