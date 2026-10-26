# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

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
