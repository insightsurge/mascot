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

describe("format-v1 character channels, recolour, item overrides and swap fallback in JS", {
  it("resolves channel merge order: part defaults -> named pose -> mood channels -> reduced", {
    skip_without_chrome()
    js <- local_character_engine()
    fixture <- format_recipe("anchor_probe")
    fixture$poses <- list(tilted = list("panel.rotate" = 0.2, "root.lift" = 10))
    fixture$moods$thinking$pose <- "tilted"
    fixture$moods$thinking$channels <- list("panel.rotate" = 0.35, "panel.x" = 5)
    fixture$moods$thinking$reduced <- list(channels = list("panel.rotate" = 0.1))
    payload <- as.character(jsonlite::toJSON(fixture, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.charTest = mascot.parts.compile(", payload, ")"))

    r <- js(
      "(() => {
      const compiled = window.charTest;
      const idle = mascot.parts.resolveChannels(compiled, 'idle');
      const thinking = mascot.parts.resolveChannels(compiled, 'thinking');
      const reduced = mascot.parts.resolveChannels(compiled, 'thinking', { reduced: true });
      return {
        idleRotate: idle['panel.rotate'],
        idleLift: idle['root.lift'],
        thinkingRotate: thinking['panel.rotate'],
        thinkingLift: thinking['root.lift'],
        thinkingX: thinking['panel.x'],
        reducedRotate: reduced['panel.rotate'],
        reducedLift: reduced['root.lift']
      };
    })()"
    )

    expect_equal(r$idleRotate, 0)
    expect_equal(r$idleLift, 0)
    expect_equal(r$thinkingRotate, 0.35)
    expect_equal(r$thinkingLift, 10)
    expect_equal(r$thinkingX, 5)
    expect_equal(r$reducedRotate, 0.1)
    expect_equal(r$reducedLift, 10)
  })

  it("resolves mood recolour acyclically with priority for explicit user overrides", {
    skip_without_chrome()
    js <- local_character_engine()
    fixture <- format_recipe("anchor_probe")
    fixture$colours <- list(
      body = "#111111",
      outline = "#222222",
      light = "#333333",
      light_happy = "#444444",
      light_super = "#555555"
    )
    fixture$moods$happy$recolour <- list(
      light = "light_happy",
      light_happy = "light_super"
    )
    fixture$moods$happy$reduced <- list(
      recolour = list(light = "light_happy")
    )
    payload <- as.character(jsonlite::toJSON(fixture, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.recolourChar = mascot.parts.compile(", payload, ")"))

    r <- js(
      "(() => {
      const compiled = window.recolourChar;
      const normal = mascot.parts.resolveColours(compiled, 'happy', compiled.source.colours);
      const userWin = mascot.parts.resolveColours(compiled, 'happy', compiled.source.colours, {
        userOverrides: { light: '#ffffff' }
      });
      const reduced = mascot.parts.resolveColours(compiled, 'happy', compiled.source.colours, { reduced: true });
      return {
        normalLight: normal.light,
        normalLightHappy: normal.light_happy,
        userWinLight: userWin.light,
        reducedLight: reduced.light
      };
    })()"
    )

    expect_identical(r$normalLight, "#555555")
    expect_identical(r$normalLightHappy, "#555555")
    expect_identical(r$userWinLight, "#ffffff")
    expect_identical(r$reducedLight, "#555555")
  })

  it("rejects recolour cycles and missing colour references", {
    skip_without_chrome()
    js <- local_character_engine()
    fixture <- format_recipe("anchor_probe")
    fixture$colours <- list(
      body = "#111111",
      outline = "#222222",
      light = "#333333",
      light_happy = "#444444",
      light_super = "#555555"
    )
    payload <- as.character(jsonlite::toJSON(fixture, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.baseCharSource = ", payload))

    evaluate_error <- function(mutation) {
      js(paste0(
        "(() => { const ch = JSON.parse(JSON.stringify(window.baseCharSource)); try { ",
        mutation,
        "; mascot.parts.compile(ch); return null; } catch(e) { return { code: e.code, path: e.path }; } })()"
      ))
    }

    err1 <- evaluate_error("ch.moods.happy.recolour = { light: 'light_happy', light_happy: 'light' }")
    expect_identical(err1$code, "invalid_colour")
    expect_identical(err1$path, "$.moods.happy.recolour.light")

    err2 <- evaluate_error("ch.moods.happy.recolour = { light: 'ghost_role' }")
    expect_identical(err2$code, "invalid_colour")
    expect_identical(err2$path, "$.moods.happy.recolour.light")
  })

  it("resolves mood item overrides and rejects undeclared items or paints", {
    skip_without_chrome()
    js <- local_character_engine()
    fixture <- format_recipe("anchor_probe")
    fixture$moods$worried$items <- list(
      "panel.surface" = list(fill = "outline", alpha = 0.75)
    )
    fixture$moods$worried$reduced <- list(
      items = list("panel.surface" = list(alpha = 0.5))
    )
    payload <- as.character(jsonlite::toJSON(fixture, auto_unbox = TRUE, null = "null", digits = NA))
    js(paste0("window.itemChar = mascot.parts.compile(", payload, ")"))

    r <- js(
      "(() => {
      const compiled = window.itemChar;
      const normal = mascot.parts.resolveItems(compiled, 'worried');
      const reduced = mascot.parts.resolveItems(compiled, 'worried', { reduced: true });
      return {
        normalFill: normal['panel.surface'].fill,
        normalAlpha: normal['panel.surface'].alpha,
        reducedAlpha: reduced['panel.surface'].alpha
      };
    })()"
    )

    expect_identical(r$normalFill, "outline")
    expect_equal(r$normalAlpha, 0.75)
    expect_equal(r$reducedAlpha, 0.5)

    evaluate_error <- function(mutation) {
      js(paste0(
        "(() => { const ch = JSON.parse(JSON.stringify(window.itemChar.source)); ",
        mutation,
        "; try { mascot.parts.compile(ch); return null; } catch(e) { return { code: e.code, path: e.path }; } })()"
      ))
    }

    err1 <- evaluate_error("ch.moods.worried.items = { 'panel.ghost_item': { fill: 'outline' } }")
    expect_identical(err1$code, "missing_reference")
    expect_identical(err1$path, "$.moods.worried.items.panel.ghost_item")

    err2 <- evaluate_error("ch.moods.worried.items = { 'panel.surface': { fill: 'ghost_paint' } }")
    expect_identical(err2$code, "invalid_colour")
    expect_identical(err2$path, "$.moods.worried.items.panel.surface.fill")
  })

  it("traverses character swap mood fallback chain until finding a supported incoming mood", {
    skip_without_chrome()
    js <- local_character_engine()
    r <- js(
      "(() => {
      const outgoing = {
        moods: {
          idle: {}, thinking: {}, happy: {}, worried: {}, celebrating: {},
          saved: { fallback: 'happy' },
          special: { fallback: 'saved' },
          custom_cycle: { fallback: 'custom_cycle' }
        }
      };
      const incomingA = {
        moods: { idle: {}, thinking: {}, happy: {}, worried: {}, celebrating: {} }
      };
      const incomingB = {
        moods: { idle: {}, thinking: {}, happy: {}, worried: {}, celebrating: {}, saved: {} }
      };

      return {
        directMatch: mascot.parts.swapMood(outgoing, 'celebrating', incomingA),
        singleFallback: mascot.parts.swapMood(outgoing, 'saved', incomingA),
        multiHopFallback: mascot.parts.swapMood(outgoing, 'special', incomingA),
        targetSupportedDirectly: mascot.parts.swapMood(outgoing, 'saved', incomingB),
        missingOutgoingMood: mascot.parts.swapMood(outgoing, 'unknown_mood', incomingA),
        noOutgoing: mascot.parts.swapMood(null, 'saved', incomingA)
      };
    })()"
    )

    expect_identical(r$directMatch, "celebrating")
    expect_identical(r$singleFallback, "happy")
    expect_identical(r$multiHopFallback, "happy")
    expect_identical(r$targetSupportedDirectly, "saved")
    expect_identical(r$missingOutgoingMood, "idle")
    expect_identical(r$noOutgoing, "idle")
  })

  it("calculates sweat progress and sparkle pulse numerically matching contract", {
    skip_without_chrome()
    js <- local_character_engine()
    r <- js(
      "(() => {
      const sweatHalf = mascot.parts.sweatProgress(0.5);
      const sweatFade = mascot.parts.sweatProgress(0.95);
      const sweatZero = mascot.parts.sweatProgress(0);

      const sparkleMid = mascot.parts.sparklePulse(0.5);
      const sparkleReduced = mascot.parts.sparklePulse(0.5, {}, { reduced: true });
      const sparklePast = mascot.parts.sparklePulse(6.0, {}, { activity_deadline: 150 });
      const sparkleAtDeadline = mascot.parts.sparklePulse(5.0, {}, { activity_deadline: 150 });

      return {
        sweatHalfX: sweatHalf.x,
        sweatHalfY: sweatHalf.y,
        sweatHalfOpacity: sweatHalf.opacity,
        sweatHalfVisible: sweatHalf.visible,
        sweatFadeOpacity: sweatFade.opacity,
        sweatZeroVisible: sweatZero.visible,
        sparkleMidScale: sparkleMid.scale,
        sparkleReducedScale: sparkleReduced.scale,
        sparkleReducedFlag: sparkleReduced.reduced,
        sparklePastScale: sparklePast.scale,
        sparkleAtDeadlineScale: sparkleAtDeadline.scale
      };
    })()"
    )

    expect_equal(r$sweatHalfX, 2 * sin(6), tolerance = 1e-6)
    expect_equal(r$sweatHalfY, 13, tolerance = 1e-6)
    expect_equal(r$sweatHalfOpacity, 1)
    expect_true(r$sweatHalfVisible)
    expect_equal(r$sweatFadeOpacity, 0.5, tolerance = 1e-6)
    expect_false(r$sweatZeroVisible)

    expect_equal(r$sparkleMidScale, 1 + 0.18 * sin(4.5), tolerance = 1e-6)
    expect_equal(r$sparkleReducedScale, 1)
    expect_true(r$sparkleReducedFlag)
    expect_equal(r$sparklePastScale, r$sparkleAtDeadlineScale, tolerance = 1e-12)
  })

  it("sparkle pulse under reduction returns reduced items and visibility matching presence", {
    skip_without_chrome()
    js <- local_character_engine()
    r <- js(
      "(() => {
      const withItems = mascot.parts.sparklePulse(0.5, { reduced_items: [{ id: 'star' }] }, { reduced: true });
      const emptyItems = mascot.parts.sparklePulse(0.5, { reduced_items: [] }, { reduced: true });
      const omittedItems = mascot.parts.sparklePulse(0.5, {}, { reduced: true });

      return {
        withItems: withItems,
        emptyItems: emptyItems,
        omittedItems: omittedItems
      };
    })()"
    )

    expect_identical(r$withItems$items, "reduced")
    expect_true(r$withItems$reduced)
    expect_equal(r$withItems$scale, 1)
    expect_true(r$withItems$visible)

    expect_identical(r$emptyItems$items, "reduced")
    expect_true(r$emptyItems$reduced)
    expect_equal(r$emptyItems$scale, 1)
    expect_false(r$emptyItems$visible)

    expect_identical(r$omittedItems$items, "reduced")
    expect_true(r$omittedItems$reduced)
    expect_equal(r$omittedItems$scale, 1)
    expect_false(r$omittedItems$visible)
  })

  it("rejects non-positive rate in sparkle pulse with input_type code and path", {
    skip_without_chrome()
    js <- local_character_engine()
    r <- js(
      "(() => {
      try {
        mascot.parts.sparklePulse(0.5, { rate: 0 });
        return null;
      } catch (e) {
        return { code: e.code, path: e.path };
      }
    })()"
    )

    expect_identical(r$code, "input_type")
    expect_identical(r$path, "$.sparkle.rate")
  })

  it("enforces core moods and rejects planted missing_core_mood fixture", {
    skip_without_chrome()
    js <- local_character_engine()
    fixture <- format_recipe("anchor_probe")
    fixture$moods$happy <- NULL
    payload <- as.character(jsonlite::toJSON(fixture, auto_unbox = TRUE, null = "null", digits = NA))
    res <- js(paste0(
      "(() => {
      try { mascot.parts.compile(",
      payload,
      "); return null; }
      catch(e) { return { code: e.code, path: e.path }; }
    })()"
    ))
    expect_identical(res$code, "missing_reference")
    expect_identical(res$path, "$.moods.happy")
  })
})
