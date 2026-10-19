# Motion uses the shared offline Chrome page. Named results make each failed assertion explain itself.

motion_js <- function(character, code) {
  sprintf(
    paste(
      "(() => { const ch = mascot.readCharacter('%s');",
      "const pose = (state, frame) => mascot.motion.pose(ch, state, frame);",
      "const picture = (p, frame) => { const c = document.createElement('canvas');",
      "c.width = 300; c.height = 300; mascot.draw(c.getContext('2d'), ch,",
      "{ x: 150, baseY: 280, pose: p, frame }); return c.toDataURL(); }; %s })()"
    ),
    character,
    code
  )
}

# Real canvas pixels, with a deterministic RAF queue and media preference. All replacements are restored.
player_js <- function(character, code) {
  motion_js(
    character,
    paste(
      "const raf = window.requestAnimationFrame, cancel = window.cancelAnimationFrame, match = window.matchMedia;",
      "const draw = mascot.draw, queued = new Map(), listeners = new Set(), players = [], calls = []; let id = 0;",
      "const media = { matches: false, addEventListener: (type, fn) => listeners.add(fn),",
      "removeEventListener: (type, fn) => listeners.delete(fn) };",
      "window.requestAnimationFrame = fn => { queued.set(++id, fn); return id; };",
      "window.cancelAnimationFrame = n => queued.delete(n); window.matchMedia = () => media;",
      "mascot.draw = (ctx, character, options) => { calls.push(options); return draw(ctx, character, options); };",
      "const last = () => calls[calls.length - 1];",
      "const fire = timestamp => { const batch = [...queued.values()]; queued.clear(); batch.forEach(fn => fn(timestamp)); };",
      "const preference = value => { media.matches = value; listeners.forEach(fn => fn({ matches: value })); };",
      "const mount = options => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "const p = mascot.mount(c, ch, { x: 150, baseY: 280, mood: 'idle', ...options }); players.push(p); return { c, p }; };",
      "try {",
      code,
      "} finally { players.forEach(p => p.destroy()); mascot.draw = draw; window.requestAnimationFrame = raf;",
      "window.cancelAnimationFrame = cancel; window.matchMedia = match; }"
    )
  )
}

describe("seekable mood motion", {
  it("seeks deterministic pictures, swaps the face at frame nine and settles", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "const state = Object.freeze({ mood: 'worried', previous: 'idle', changedAt: 0, seed: 0 });",
          "const first = picture(pose(state, 2), 2); pose(state, 10000); pose(state, 0);",
          "return { sameAgain: first === picture(pose(state, 2), 2),",
          "differsFromNew: first !== picture(pose({ mood: 'worried' }, 2), 2),",
          "differsFromOld: first !== picture(pose({ mood: 'idle' }, 2), 2),",
          "before: pose(state, 8).mood, after: pose(state, 9).mood, rotation: pose(state, 2).rot,",
          "settled: picture(pose(state, 90), 90) === picture({ mood: 'worried' }, 90),",
          "idleMatches: [18, 19, 22, 133].map(n => picture(pose(state, n), n) === picture(pose({ mood: 'worried' }, n), n)),",
          "unchanged: JSON.stringify(state) };"
        )
      ))
      expect_true(r$sameAgain, info = character)
      expect_true(r$differsFromNew, info = character)
      expect_true(r$differsFromOld, info = character)
      expect_identical(r$before, "idle")
      expect_identical(r$after, "worried")
      expect_equal(r$rotation, 0.06 * sin(4 * pi / 9) * (8 / 9)^2, tolerance = 1e-12)
      expect_true(r$settled, info = character)
      expect_identical(unlist(r$idleMatches), rep(TRUE, 4))
      expect_identical(r$unchanged, '{"mood":"worried","previous":"idle","changedAt":0,"seed":0}')
    }
  })

  it("breathes gently over the mood's own transforms", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "const p = pose({ mood: 'celebrating' }, 22.5);",
          "const base = mascot.drawing.resolvePose(ch, { mood: 'celebrating' });",
          "return { sx: p.sx / base.sx, sy: p.sy / base.sy, rotation: p.rot - base.rot, lift: p.lift - base.lift };"
        )
      ))
      expect_equal(r$sx, 0.988, tolerance = 1e-12)
      expect_equal(r$sy, 1.012, tolerance = 1e-12)
      expect_equal(r$rotation, 0)
      expect_equal(r$lift, 0)
    }
  })

  it("blinks at independently calculated seeded windows within each action", {
    skip_without_chrome()
    js <- local_engine_page()
    # h(0,0) = 1013904223 = 61 * 16621380 + 43: centre 120 + 43 - 30 = 133.
    # h(1,0) = 1015568748 = 61 * 16648668: centre 90. The pulse has half-width three.
    # Window one exchanges the XOR hashes: centres 210 and 253, both outside this activity.
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "const frames = seed => Array.from({ length: 301 }, (_, n) => n).filter(n => pose({ seed }, n).blink > 0).join(',');",
          "const s = { mood: 'idle', seed: 0 }; return { zero: frames(0), again: frames(0), one: frames(1),",
          "start: pose(s, 130).blink, opening: pose(s, 131).blink, centre: pose(s, 133).blink, end: pose(s, 136).blink,",
          "pictureChanges: picture(pose(s, 133), 133) !== picture({ mood: 'idle' }, 133),",
          "restarted: pose({ seed: 0, activeAt: 200 }, 333).blink };"
        )
      ))
      expect_identical(r$zero, "131,132,133,134,135")
      expect_identical(r$again, r$zero)
      expect_identical(r$one, "88,89,90,91,92")
      expect_equal(r$start, 0)
      expect_equal(r$opening, 1 / 3, tolerance = 1e-12)
      expect_equal(r$centre, 1)
      expect_equal(r$end, 0)
      expect_true(r$pictureChanges, info = character)
      expect_equal(r$restarted, 1)
    }
  })

  it("skips movement and immediately swaps the face under reduced motion", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "const rows = []; for (const gesture of ['nod', 'wave']) for (let n = 0; n <= 300; n++) {",
          "const p = pose({ mood: 'worried', previous: 'idle', changedAt: 0, gesture, gestureAt: 0, reduced: true }, n);",
          "rows.push(mascot.drawing.resolvePose(ch, p)); }",
          "return { moods: [...new Set(rows.map(p => p.mood))].join(','),",
          "rotation: Math.max(...rows.map(p => Math.abs(p.rot))), lift: Math.max(...rows.map(p => Math.abs(p.lift))),",
          "sx: Math.max(...rows.map(p => Math.abs(p.sx - 1))), sy: Math.max(...rows.map(p => Math.abs(p.sy - 1))),",
          "blink: Math.max(...rows.map(p => p.blink)),",
          "pictures: [0, 9, 18, 90, 133, 300].map(n => picture(pose({ mood: 'worried', reduced: true }, n), n) === picture({ mood: 'worried' }, n)) };"
        )
      ))
      expect_identical(r$moods, "worried")
      expect_equal(r$rotation, 0)
      expect_equal(r$lift, 0)
      expect_equal(r$sx, 0)
      expect_equal(r$sy, 0)
      expect_equal(r$blink, 0)
      expect_identical(unlist(r$pictures), rep(TRUE, 6))
    }
  })

  it("plays both gestures once, ignores missing arms and allows explicit poses to win", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      for (gesture in c("nod", "wave")) {
        r <- js(motion_js(
          character,
          sprintf(
            paste(
              "const gesture = '%s', state = { mood: 'idle', gesture, gestureAt: 0 };",
              "const end = gesture === 'nod' ? 18 : 30, mid = pose(state, 6);",
              "const explicit = mascot.drawing.resolvePose(ch, { ...mid, rot: 0.75, sy: 0.8 });",
              "return { moves: picture(mid, 6) !== picture(pose({ mood: 'idle' }, 6), 6),",
              "ends: picture(pose(state, end), end) === picture(pose({ mood: 'idle' }, end), end),",
              "settled: picture(pose(state, 90), 90) === picture({ mood: 'idle' }, 90),",
              "rotation: explicit.rot, scale: explicit.sy, arm: mid.armR === undefined ? 'missing' : mid.armR,",
              "nodLift: pose(state, 4.5).lift };"
            ),
            gesture
          )
        ))
        expect_true(r$moves, info = paste(character, gesture))
        expect_true(r$ends, info = paste(character, gesture))
        expect_true(r$settled, info = paste(character, gesture))
        expect_equal(r$rotation, 0.75)
        expect_equal(r$scale, 0.8)
        if (character == "blob") {
          expect_identical(r$arm, "missing")
        }
        if (character == "tessa" && gesture == "wave") {
          expect_equal(r$arm, -0.9, tolerance = 1e-12)
        }
        if (gesture == "nod") expect_equal(r$nodLift, -3)
      }
    }
  })

  it("interpolates custom numeric timelines and switches names at their keyframes", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "ch.motion = { idle: { breathe: 0 }, gestures: { nod: { frames: 10, timeline:",
          "[{ at: 0, pose: {} }, { at: 0.5, pose: { look: 1, sy: 0.8 } }, { at: 1, pose: {} }] },",
          "wave: { frames: 20, timeline: [{ at: 0, pose: {} },",
          "{ at: 0.5, pose: { eyes: 'wink', arms: 'wave', armR: -1 } },",
          "{ at: 0.75, pose: { eyes: 'wide', arms: 'idle', armR: -0.5 } }] } } };",
          "const nod = { gesture: 'nod', gestureAt: 0 }, wave = { gesture: 'wave', gestureAt: 0 };",
          "const p = pose(wave, 17); return { look: pose(nod, 2.5).look, sy: pose(nod, 2.5).sy,",
          "endLook: pose(nod, 10).look, before: pose(wave, 9).eyes, at: pose(wave, 10).eyes, after: p.eyes,",
          "arm: p.armR === undefined ? 'missing' : p.armR,",
          "endPicture: picture(pose(wave, 20), 20) === picture(pose({ mood: 'idle' }, 20), 20) };"
        )
      ))
      expect_equal(r$look, 0.5)
      expect_equal(r$sy, 0.9)
      expect_equal(r$endLook, 0)
      expect_identical(r$before, "open")
      expect_identical(r$at, "wink")
      expect_identical(r$after, "wide")
      if (character == "blob") {
        expect_identical(r$arm, "missing")
      } else {
        expect_equal(r$arm, -0.5)
      }
      expect_true(r$endPicture, info = character)
    }
  })

  it("replaces older actions without reviving them and selects a hop from data", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "ch.motion = { change: { style: 'hop', frames: 60, height: 10, swapAt: 0.25 }, idle: { breathe: 0 } };",
          "const state = { mood: 'worried', previous: 'idle', changedAt: 0, activeAt: 0 };",
          "const wave = { ...state, gesture: 'wave', gestureAt: 3, activeAt: 3 };",
          "return { lift: pose(state, 30).lift, rotation: pose(state, 30).rot, scale: pose(state, 30).sy,",
          "before: pose(state, 14).mood, after: pose(state, 15).mood, reduced: pose({ ...state, reduced: true }, 30),",
          "end: picture(pose(state, 60), 60) === picture({ mood: 'worried' }, 60),",
          "committed: pose(wave, 3).mood, noRevival: picture(pose(wave, 40), 40) === picture(pose({ mood: 'worried', activeAt: 3 }, 40), 40),",
          "newChange: picture(pose({ ...wave, changedAt: 4, activeAt: 4 }, 5), 5) === picture(pose({ ...state, changedAt: 4, activeAt: 4 }, 5), 5) };"
        )
      ))
      expect_equal(r$lift, 10)
      expect_equal(r$rotation, 0)
      expect_equal(r$scale, 1)
      expect_identical(r$before, "idle")
      expect_identical(r$after, "worried")
      expect_identical(r$reduced$mood, "worried")
      expect_true(r$end, info = character)
      expect_identical(r$committed, "worried")
      expect_true(r$noRevival, info = character)
      expect_true(r$newChange, info = character)
    }
  })

  it("reports unknown motion names while leaving numeric range checks to R", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      for (block in c(
        "{ idel: {} }",
        "{ idle: { blinkEver: 120 } }",
        "{ change: { style: 'spin' } }",
        "{ change: { angl: 0.1 } }",
        "{ gestures: { clap: {} } }",
        "{ gestures: { nod: { duration: 3 } } }",
        "{ gestures: { nod: { timeline: [{ at: 0, when: 0, pose: {} }] } } }",
        "{ gestures: { nod: { timeline: [{ at: 0, pose: { rotate: 1 } }] } } }"
      )) {
        expect_match(
          js(motion_js(character, sprintf("ch.motion = %s; return mascot.validateCharacter(ch).join('; ');", block))),
          "motion.*unknown name.*valid names"
        )
      }
      expect_identical(
        js(motion_js(
          character,
          paste(
            "ch.motion = { idle: { breathe: -0.2 }, change: { frames: -1 } }; return mascot.validateCharacter(ch).join('; ');"
          )
        )),
        ""
      )
    }
  })

  it("fades breathing, skips crossing blinks and returns exactly the held mood at rest", {
    skip_without_chrome()
    js <- local_engine_page()
    # Seed 11 gives remainder 58, hence centre 148 and pulse end 151: skip the entire blink.
    # Seed 55 gives remainder 57, hence centre 147 and pulse end 150: allow the full blink.
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "const s = { mood: 'idle', activeAt: 0 };",
          "return { moving: picture(pose(s, 22.5), 22.5) !== picture({ mood: 'idle' }, 22.5),",
          "nearEnd: Math.abs(pose(s, 149).sy - 1), rest: pose(s, 150), later: pose(s, 500),",
          "heldRest: pose({ ...s, pose: { lookY: -1 } }, 150),",
          "skipped: Array.from({ length: 150 }, (_, n) => n).filter(n => pose({ ...s, seed: 11 }, n).blink > 0).join(','),",
          "allowed: Array.from({ length: 151 }, (_, n) => n).filter(n => pose({ ...s, seed: 55 }, n).blink > 0).join(','),",
          "lastBlink: pose({ ...s, seed: 55 }, 149).blink, plain: picture(pose(s, 150), 150) === picture({ mood: 'idle' }, 150) };"
        )
      ))
      expect_true(r$moving, info = character)
      expect_gt(r$nearEnd, 0)
      expect_lt(r$nearEnd, 0.000015)
      expect_identical(r$rest, list(mood = "idle"))
      expect_identical(r$later, list(mood = "idle"))
      expect_equal(r$heldRest, list(mood = "idle", lookY = -1))
      expect_identical(r$skipped, "")
      expect_identical(r$allowed, "145,146,147,148,149")
      expect_equal(r$lastBlink, 1 / 3, tolerance = 1e-12)
      expect_true(r$plain, info = character)
    }
  })

  it("caps long configured actions and honours shorter activity windows", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "ch.motion = { change: { style: 'hop', frames: 400 }, idle: { frames: 300 }, gestures: { wave: { frames: 400 } } };",
          "const change = { mood: 'worried', previous: 'idle', changedAt: 0 }, wave = { gesture: 'wave', gestureAt: 0 };",
          "return { before: pose(change, 74).mood, after: pose(change, 75).mood,",
          "changeEnd: pose(change, 150), gestureEnd: pose(wave, 150), duration: pose({}, 150) };"
        )
      ))
      expect_identical(r$before, "idle")
      expect_identical(r$after, "worried")
      expect_identical(r$changeEnd, list(mood = "worried"))
      expect_identical(r$gestureEnd, list(mood = "idle"))
      expect_identical(r$duration, list(mood = "idle"))
      r <- js(motion_js(
        character,
        paste(
          "ch.motion = { idle: { frames: 30 } }; return { before: pose({}, 29).sy, at: pose({}, 30),",
          "afterAction: pose({ activeAt: 100 }, 130) };"
        )
      ))
      expect_false(identical(r$before, 1))
      expect_identical(r$at, list(mood = "idle"))
      expect_identical(r$afterAction, list(mood = "idle"))
    }
  })
})

describe("the canvas motion controller", {
  it("seeks to direct drawing pixels and keeps repeated moods unchanged", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { c, p } = mount({ reduced: false }); p.pause(); p.seek(133); const sought = c.toDataURL();",
          "const direct = picture(pose({ mood: 'idle' }, 133), 133); p.setMood('idle'); p.seek(135);",
          "const repeated = c.toDataURL() === picture(pose({ mood: 'idle' }, 135), 135);",
          "p.setMood('worried'); p.seek(140); const changed = c.toDataURL() === picture(pose({ mood: 'worried', previous: 'idle', changedAt: 135, activeAt: 135 }, 140), 140);",
          "return { sought: sought === direct, repeated, changed, frame: last().frame, seek: typeof p.seek, oldName: typeof p.renderFrame };"
        )
      ))
      expect_true(r$sought, info = character)
      expect_true(r$repeated, info = character)
      expect_true(r$changed, info = character)
      expect_equal(r$frame, 140)
      expect_identical(r$seek, "function")
      expect_identical(r$oldName, "undefined")
    }
  })

  it("interrupts from the displayed face and replaces actions in order", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { c, p } = mount(); p.pause();",
          "const matches = (s, n) => { p.seek(n); return c.toDataURL() === picture(pose(s, n), n); };",
          "p.setMood('happy'); p.seek(4); p.setMood('worried');",
          "const early = matches({ mood: 'worried', previous: 'idle', changedAt: 4, activeAt: 4 }, 5);",
          "p.seek(14); p.setMood('thinking'); const late = matches({ mood: 'thinking', previous: 'worried', changedAt: 14, activeAt: 14 }, 15);",
          "p.gesture('wave'); const wave = matches({ mood: 'thinking', gesture: 'wave', gestureAt: 15, activeAt: 15 }, 18);",
          "p.gesture('nod'); const nod = matches({ mood: 'thinking', gesture: 'nod', gestureAt: 18, activeAt: 18 }, 21);",
          "p.setMood('happy'); const newMood = matches({ mood: 'happy', previous: 'thinking', changedAt: 21, activeAt: 21 }, 22);",
          "return { early, late, wave, nod, newMood };"
        )
      ))
      expect_true(r$early, info = character)
      expect_true(r$late, info = character)
      expect_true(r$wave, info = character)
      expect_true(r$nod, info = character)
      expect_true(r$newMood, info = character)
    }
  })

  it("applies combined patches and preserves held pose through mood changes", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { c, p } = mount(); p.pause(); p.seek(50);",
          "p.update({ mood: 'worried', pose: { lookY: -1, rot: 0.75 }, colours: { body: '#ff00ff' }, reduced: true });",
          "const combined = last(); const coloured = c.toDataURL(); p.setMood('happy'); const held = last();",
          "p.update({ pose: { rot: null } }); const removed = last(); p.update({ pose: null }); const cleared = last();",
          "p.update({ colours: { body: null } }); const colourRemoved = last().colours;",
          "p.update({ colours: { body: '#000000', feature: '#ff0000' } }); p.update({ colours: null });",
          "return { combined: combined.pose, colour: combined.colours.body, held: held.pose, removed: removed.pose, cleared: cleared.pose,",
          "colourRemoved, allColoursCleared: last().colours, colourChangesPicture: coloured !== c.toDataURL() };"
        )
      ))
      expect_equal(r$combined, list(mood = "worried", lookY = -1, rot = 0.75))
      expect_identical(r$colour, "#ff00ff")
      expect_equal(r$held, list(mood = "happy", lookY = -1, rot = 0.75))
      expect_equal(r$removed, list(mood = "happy", lookY = -1))
      expect_identical(r$cleared, list(mood = "happy"))
      expect_length(r$colourRemoved, 0)
      expect_length(r$allColoursCleared, 0)
      expect_true(r$colourChangesPicture, info = character)
    }
  })

  it("keeps a held arm preset through gestures unless held arm angles override it", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(motion_js(
      "tessa",
      paste(
        "const arms = (held, frame) => { const p = mascot.drawing.resolvePose(ch,",
        "pose({ mood: 'idle', pose: held, gesture: 'nod', gestureAt: 0 }, frame)); return [p.armL, p.armR]; };",
        "const hips = ch.arms.presets.hips;",
        "return { during: arms({ arms: 'hips' }, 6), after: arms({ arms: 'hips' }, 40),",
        "angle: arms({ arms: 'hips', armR: -0.5 }, 6), hips: [hips.L, hips.R] };"
      )
    ))
    expect_identical(r$during, r$hips)
    expect_identical(r$after, r$hips)
    expect_identical(r$angle, list(r$hips[[1]], -0.5))
  })

  it("validates the whole patch before applying any part", {
    skip_without_chrome()
    js <- local_engine_page()
    fields <- c(
      "update.colours.typo",
      "update.pose.eyes",
      "update.pose.rotate",
      "update.reduced",
      "update.mood",
      "update.typo",
      "update.pose",
      "update.colours",
      "update.colours.outline"
    )
    bad_values <- c("#fff", "bogus", "1", "yes", "bogus", "42", "false", "false", "42")
    patches <- c(
      "{ mood: 'happy', pose: { lookY: -1 }, colours: { typo: '#fff' } }",
      "{ mood: 'happy', pose: { eyes: 'bogus' } }",
      "{ mood: 'happy', pose: { rotate: 1 } }",
      "{ mood: 'happy', reduced: 'yes' }",
      "{ pose: { lookY: -1 }, mood: 'bogus' }",
      "{ mood: 'happy', typo: 42 }",
      "{ mood: 'happy', pose: false }",
      "{ mood: 'happy', colours: false }",
      "{ mood: 'happy', colours: { outline: 42 } }"
    )
    for (character in c("tessa", "blob")) {
      for (i in seq_along(patches)) {
        patch <- patches[[i]]
        r <- js(player_js(
          character,
          sprintf(
            paste(
              "const { c, p } = mount(); p.pause(); p.seek(50); const before = c.toDataURL(), count = calls.length;",
              "let error = ''; try { p.update(%s); } catch (e) { error = e.message; }",
              "const unchanged = c.toDataURL() === before, noDraw = calls.length === count; p.seek(60);",
              "return { error, unchanged, noDraw, later: c.toDataURL() === picture(pose({ mood: 'idle' }, 60), 60) };"
            ),
            patch
          )
        ))
        expect_match(r$error, "^mascot: update\\.")
        expect_match(r$error, fields[[i]], fixed = TRUE, info = patch)
        expect_match(r$error, bad_values[[i]], fixed = TRUE, info = patch)
        expect_true(r$unchanged, info = patch)
        expect_true(r$noDraw, info = patch)
        expect_true(r$later, info = patch)
      }
    }
  })

  it("reports bad names and values with field names and valid choices", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      for (bad in c("bogus", "toString")) {
        r <- js(player_js(
          character,
          sprintf(
            paste(
              "const { p } = mount(); const attempt = fn => { try { fn(); } catch (e) { return e.message; } return 'no error'; };",
              "return { mood: attempt(() => p.setMood('%s')), gesture: attempt(() => p.gesture('%s')),",
              "pureMood: attempt(() => pose({ mood: '%s' }, 0)), pureGesture: attempt(() => pose({ gesture: '%s' }, 0)) };"
            ),
            bad,
            bad,
            bad,
            bad
          )
        ))
        expect_identical(
          r$mood,
          sprintf(
            "mascot: update.mood: unknown mood '%s'; valid names: idle, thinking, happy, worried, celebrating",
            bad
          )
        )
        expect_identical(r$gesture, sprintf("mascot: unknown gesture '%s'; valid names: nod, wave", bad))
        expect_identical(
          r$pureMood,
          sprintf("mascot: unknown mood '%s'; valid names: idle, thinking, happy, worried, celebrating", bad)
        )
        expect_identical(r$pureGesture, sprintf("mascot: unknown gesture '%s'; valid names: nod, wave", bad))
      }
      r <- js(player_js(
        character,
        paste(
          "const { p } = mount(); try { p.update({ typo: 42 }); } catch (e) { return e.message; }"
        )
      ))
      expect_identical(
        r,
        paste0(
          "mascot: update.typo: unknown field 'typo' (value '42'); valid names: ",
          "mood, pose, colours, reduced, character, messages, idle, mood_change, gestures, swap, minimising, restoring, others"
        )
      )
    }
  })

  it("always honours the media preference and resumes only on a new action", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { p } = mount({ reduced: false }); preference(true); p.seek(22.5); const forced = last().pose.sy;",
          "p.update({ reduced: null }); const following = last().pose; p.update({ reduced: false }); const resumed = last().pose;",
          "preference(false); p.update({ reduced: null }); p.update({ pose: { lookY: -1 } }); p.seek(45);",
          "return { forced, following, resumed, newAction: last().pose.sy, held: last().pose.lookY, listeners: listeners.size };"
        )
      ))
      expect_null(r$forced)
      expect_identical(r$following, list(mood = "idle"))
      expect_identical(r$resumed, list(mood = "idle"))
      expect_equal(r$newAction, 1.012, tolerance = 1e-12)
      expect_equal(r$held, -1)
      expect_equal(r$listeners, 1)
    }
  })

  it("uses RAF time, pauses without catching up and rests without further drawing", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { p } = mount(); fire(1000); fire(1500); const elapsed = last().frame; p.pause(); fire(5000);",
          "const pausedFrame = last().frame; p.play(); fire(8000); fire(8500); const resumed = last().frame;",
          "fire(20000); const atRest = last(), count = calls.length, restingQueue = queued.size; fire(21000);",
          "const noDraw = calls.length === count; p.setMood('worried'); const restarted = queued.size;",
          "fire(22000); fire(28000); const moodEnd = last();",
          "return { elapsed, pausedFrame, resumed, restFrame: atRest.frame, restPose: atRest.pose, restingQueue, noDraw, restarted, moodEnd: moodEnd.pose };"
        )
      ))
      expect_equal(r$elapsed, 15)
      expect_equal(r$pausedFrame, 15)
      expect_equal(r$resumed, 30)
      expect_equal(r$restFrame, 165)
      expect_identical(r$restPose, list(mood = "idle"))
      expect_equal(r$restingQueue, 0)
      expect_true(r$noDraw, info = character)
      expect_equal(r$restarted, 1)
      expect_identical(r$moodEnd, list(mood = "worried"))
    }
  })

  it("restarts on gestures, held pose changes and play after pause, without a new wiggle", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { p } = mount(); fire(0); fire(6000); const initialRest = queued.size;",
          "p.setMood('idle'); const sameMood = queued.size; p.update({ colours: { body: '#000000' } }); const colourOnly = queued.size;",
          "p.update({ pose: { lookY: -1 } }); const poseQueue = queued.size; p.seek(152); const poseRotation = last().pose.rot;",
          "p.seek(300); p.gesture('nod'); const gestureQueue = queued.size; p.seek(450);",
          "p.pause(); p.play(); const playQueue = queued.size; p.seek(472.5);",
          "return { initialRest, sameMood, colourOnly, poseQueue, poseRotation, gestureQueue, playQueue, breathe: last().pose.sy, held: last().pose.lookY };"
        )
      ))
      expect_equal(r$initialRest, 0)
      expect_equal(r$sameMood, 0)
      expect_equal(r$colourOnly, 0)
      expect_equal(r$poseQueue, 1)
      expect_equal(r$poseRotation, 0)
      expect_equal(r$gestureQueue, 1)
      expect_equal(r$playQueue, 1)
      expect_equal(r$breathe, 1.012, tolerance = 1e-12)
      expect_equal(r$held, -1)
    }
  })

  it("finishes on media reduction and makes every method inert after destroy", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(player_js(
        character,
        paste(
          "const { p } = mount(); const stale = [...queued.values()][0]; p.setMood('worried'); p.seek(1); preference(true);",
          "const reduced = last().pose, stopped = queued.size; preference(false); const noReplay = last().pose;",
          "p.update({ pose: { lookY: -1 } }); p.destroy(); p.destroy(); const count = calls.length;",
          "stale(2000); p.seek(133); p.setMood('happy'); p.gesture('wave'); p.update({ typo: 42 }); p.pause(); p.play();",
          "return { reduced, stopped, noReplay, noMoreDraws: calls.length === count, listeners: listeners.size, queue: queued.size };"
        )
      ))
      expect_identical(r$reduced, list(mood = "worried"))
      expect_equal(r$stopped, 0)
      expect_identical(r$noReplay, list(mood = "worried"))
      expect_true(r$noMoreDraws, info = character)
      expect_equal(r$listeners, 0)
      expect_equal(r$queue, 0)
    }
  })
})

describe("independent motion settings", {
  it("turns off idle without dropping a mood change or gesture", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(motion_js(
        character,
        paste(
          "const base = mascot.drawing.resolvePose(ch, {mood:'idle'});",
          "const still = pose({idle:false}, 22.5);",
          "const changing = pose({idle:false,mood:'happy',previous:'idle',changedAt:0}, 2);",
          "const nodding = pose({idle:false,gesture:'nod',gestureAt:0}, 4.5);",
          "return {still:still.sy===base.sy && still.sx===base.sx && still.blink===base.blink,",
          "changing:changing.rot!==base.rot,nodding:nodding.sy!==base.sy};"
        )
      ))
      expect_true(r$still, info = character)
      expect_true(r$changing, info = character)
      expect_true(r$nodding, info = character)
    }
  })
  it("makes mood changes instant while idle and gestures remain independent", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(player_js(
      "tessa",
      paste(
        "const {p} = mount({idle:false,mood_change:false}); p.setMood('happy');",
        "const mood=p.current().mood; p.seek(2); const change=last().pose.rot;",
        "p.gesture('nod');p.seek(6.5);const nod=last().pose.sy;",
        "p.update({gestures:false});p.gesture('wave');p.seek(8);",
        "return {mood,change,nod,skipped:last().pose.rot};"
      )
    ))
    expect_identical(r$mood, "happy")
    expect_equal(r$change, 0)
    expect_equal(r$nod, 0.96)
    expect_equal(r$skipped, 0)
  })
  it("cancels disabled layers without replaying them when re-enabled", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(player_js(
      "tessa",
      paste(
        "const {p}=mount({idle:false});p.setMood('happy');p.seek(2);",
        "p.update({mood_change:false});const shown=p.current().mood;",
        "p.update({mood_change:true});const noChange=last().pose.rot;",
        "p.gesture('wave');p.seek(5);p.update({gestures:false});",
        "p.update({gestures:true});const noGesture=last().pose.rot;",
        "return {shown,noChange,noGesture,queued:queued.size};"
      )
    ))
    expect_identical(r$shown, "happy")
    expect_equal(r$noChange, 0)
    expect_equal(r$noGesture, 0)
    expect_equal(r$queued, 0)
  })
  it("validates each switch and refuses to override the visitor preference", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(player_js(
      "tessa",
      paste(
        "const {p}=mount();const errors=[];",
        "for(const name of ['idle','mood_change','gestures','swap','minimising','restoring','others'])",
        "try{p.update({[name]:'yes'});}catch(e){errors.push(e.message.includes(name));}",
        "try{p.update({messages:['dialog']});}catch(e){errors.push(e.message.includes('bubble, tooltip, menu'));}",
        "preference(true);p.update({reduced:false,idle:true,mood_change:true,gestures:true});",
        "p.setMood('happy');p.gesture('wave');p.seek(4);",
        "return {errors,pose:last().pose,queued:queued.size};"
      )
    ))
    expect_identical(unlist(r$errors), rep(TRUE, 8))
    expect_identical(r$pose, list(mood = "happy"))
    expect_equal(r$queued, 0)
  })
})


# E4a: format-v1 tracks. Pure numeric checks in the shared offline page; no canvas is needed.
tracks_js <- function(code) {
  v1 <- paste(readLines(system.file("format", "characters", "tessa.json", package = "mascot")), collapse = "\n")
  sprintf(
    paste(
      "(() => { const t = mascot.motion.tracks, v1 = %s;",
      "const fail = f => { try { f(); return null; } catch (e) { return { code: e.code, path: e.path }; } };",
      "const clone = () => JSON.parse(JSON.stringify(v1));",
      "const knurl = () => { const c = clone(); c.parts = c.parts.filter(p => p.id !== 'arm_r');",
      "c.gestures.wave.tracks['arm_r.rotate'] = { mode: 'set', keys: [[0, null], [0.5, -1], [1, null]] };",
      "return c; }; %s })()"
    ),
    v1,
    code
  )
}

describe("E4a format-v1 tracks", {
  it("evaluates the five easings at exact fractions and holds a step key", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const at = [0, 0.25, 0.5, 0.75, 1];",
      "const out = Object.fromEntries(Object.keys(t.easings).map(n => [n, at.map(u => t.easings[n](u))]));",
      "const step = t.normalise([[0, 0, 'step'], [0.5, 10], [1, 0]], '$.s');",
      "return { out, step: [0.25, 0.4999, 0.5, 0.75].map(u => t.sample(step, u, 0)) };"
    )))
    expect_equal(unlist(r$out$linear), c(0, 0.25, 0.5, 0.75, 1))
    expect_equal(unlist(r$out$ease_in), c(0, 0.0625, 0.25, 0.5625, 1))
    expect_equal(unlist(r$out$ease_out), c(0, 0.4375, 0.75, 0.9375, 1))
    expect_equal(unlist(r$out$ease_in_out), c(0, 0.15625, 0.5, 0.84375, 1))
    expect_equal(unlist(r$step), c(0, 0, 10, 5))
  })

  it("samples add and set tracks, reads null as the mood base and ends exactly at rest", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const add = t.normalise([[0, 0], [0.5, 2, 'ease_in'], [1, 0]], '$.a');",
      "const set = t.normalise({ mode: 'set', keys: [[0, null], [0.5, 4], [1, null]] }, '$.s');",
      "const discrete = t.normalise({ mode: 'set', keys: [[0, null], [0.2, 'blue'], [0.6, null], [1, null]] }, '$.d');",
      "const us = [0, 0.25, 0.5, 0.75, 1, 1.5];",
      "return { add: us.map(u => t.sample(add, u, 10)), set: us.map(u => t.sample(set, u, 1)),",
      "discrete: [0, 0.19, 0.2, 0.5, 0.6, 0.9, 1].map(u => t.sample(discrete, u, 'base')),",
      "mode: [add.mode, set.mode, t.normalise([[0, 0], [1, 0]], '$.m').mode, discrete.numeric] };"
    )))
    # add: 10 + offset; each span uses its starting key's easing (linear up, then ease_in back down: 2 * (1 - 0.25)).
    expect_equal(unlist(r$add), c(10, 11, 12, 11.5, 10, 10))
    # set: null endpoints mean the base (1); linear towards 4 and back.
    expect_equal(unlist(r$set), c(1, 2.5, 4, 2.5, 1, 1))
    # discrete: switches at keys; an intermediate null switches back to the base, never blends.
    expect_identical(unlist(r$discrete), c("base", "base", "blue", "blue", "base", "base", "base"))
    expect_identical(unlist(r$mode), c("add", "set", "add", FALSE))
  })

  it("rejects malformed tracks with their path", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const bad = k => fail(() => t.normalise(k, '$.t'));",
      "return [bad([[0, 0]]), bad([[0.1, 0], [1, 0]]), bad([[0, 0], [0.5, 1], [0.5, 2], [1, 0]]),",
      "bad([[0, 0], [1.2, 0]]), bad([[0, 0], [0.5, 1, 'bounce'], [1, 0]]), bad([[0, 0], [1, 1]]),",
      "bad([[0, null], [0.5, 1], [1, 0]]), bad({ mode: 'add', keys: [[0, 0], [0.5, 'x'], [1, 0]] }),",
      "bad({ mode: 'set', keys: [[0, 'a'], [1, null]] }), bad({ keys: [[0, 0], [1, 0]], extra: 1 }),",
      "bad([[0, 0], [0.5, NaN], [1, 0]])];"
    )))
    codes <- vapply(r, function(x) x$code, character(1))
    expect_identical(
      codes,
      c(
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "invalid_channel",
        "unknown_key",
        "input_type"
      )
    )
    expect_identical(r[[10]]$path, "$.t.extra")
    expect_identical(r[[5]]$path, "$.t[1][2]")
  })

  it("selects the playable gesture through needs and fallback, and rejects broken chains", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const own = t.compile(v1).selected, absent = t.compile(knurl()).selected;",
      "const cycle = clone(); cycle.gestures.rock.fallback = 'wave'; cycle.gestures.wave.needs = ['ghost_part'];",
      "const noNod = clone(); delete noNod.gestures.nod;",
      "const missing = clone(); missing.gestures.wave.needs = ['ghost_part']; missing.gestures.wave.fallback = 'nowhere';",
      "const unplayable = clone(); unplayable.gestures.rock.needs = ['ghost_part'];",
      "unplayable.gestures.wave.needs = ['ghost_part']; unplayable.gestures.nod.needs = ['ghost_part'];",
      "const typo = knurl(); typo.gestures.wave.tracks['arm_r.rotate'] = [[0, 0], [1, 0]]; typo.gestures.wave.needs = [];",
      "const ghost = clone(); ghost.gestures.rock.tracks = { 'ghost.rotate': [[0, 0], [1, 0]] };",
      "const long = clone(); long.gestures.rock.frames = 151; const zero = clone(); zero.gestures.rock.frames = 0.5;",
      "return { own, absent, cycle: fail(() => t.compile(cycle)), noNod: fail(() => t.compile(noNod)),",
      "missing: fail(() => t.compile(missing)), unplayable: fail(() => t.compile(unplayable)),",
      "typo: fail(() => t.compile(typo)), ghost: fail(() => t.compile(ghost)), long: fail(() => t.compile(long)),",
      "zero: fail(() => t.compile(zero)) };"
    )))
    expect_identical(r$own, list(rock = "rock", nod = "nod", wave = "wave", shimmer = "shimmer"))
    expect_identical(r$absent$wave, "rock")
    expect_identical(r$cycle, list(code = "missing_reference", path = "$.gestures.rock.fallback"))
    expect_identical(r$noNod, list(code = "missing_reference", path = "$.gestures.nod"))
    expect_identical(r$missing, list(code = "missing_reference", path = "$.gestures.wave.fallback"))
    expect_identical(r$unplayable$code, "missing_reference")
    expect_identical(r$typo, list(code = "invalid_channel", path = "$.gestures.wave.tracks.arm_r.rotate"))
    expect_identical(r$ghost, list(code = "invalid_channel", path = "$.gestures.rock.tracks.ghost.rotate"))
    expect_identical(r$long, list(code = "budget", path = "$.gestures.rock.frames"))
    expect_identical(r$zero, list(code = "input_type", path = "$.gestures.rock.frames"))
  })

  it("plays a gesture frame by frame and returns exactly to rest at its end", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = t.compile(v1), settings = t.settings(v1);",
      "const rest = () => ({ 'root.scale_y': 1, 'root.lift': 0, 'root.rotate': 0, 'arm_r.rotate': 1.25 });",
      "const at = (g, n, extra = {}) => t.frameAt(c, { mood: 'idle', gesture: g, gestureAt: 0, idle: false, ...extra }, n, { settings, rest }).channels;",
      "return { nod: [0, 4.5, 9, 13.5, 18, 40].map(n => at('nod', n)), wave: [0, 6, 12, 24, 30].map(n => at('wave', n)) };"
    )))
    nod <- r$nod
    expect_equal(nod[[1]][["root.scale_y"]], 1)
    expect_equal(nod[[2]][["root.scale_y"]], 0.96)
    expect_equal(nod[[2]][["root.lift"]], -3)
    expect_equal(nod[[3]][["root.scale_y"]], 0.99, tolerance = 1e-12)
    expect_equal(nod[[4]][["root.lift"]], -3 * (1 - (0.75 - 0.65) / 0.35), tolerance = 1e-12)
    expect_length(nod[[5]], 0)
    expect_length(nod[[6]], 0)
    wave <- r$wave
    expect_equal(wave[[1]][["arm_r.rotate"]], 1.25)
    # The hanging arm lifts to 150 degrees at a fifth of the wave and eases back to 120 degrees at two fifths.
    expect_equal(wave[[2]][["arm_r.rotate"]], -150 * pi / 180, tolerance = 1e-3)
    expect_equal(wave[[3]][["arm_r.rotate"]], -120 * pi / 180, tolerance = 1e-3)
    expect_equal(wave[[2]][["root.rotate"]], -0.025)
    expect_length(wave[[5]], 0)
  })

  it("lets the newest action win: gesture commits the mood, a change starts from the shown face", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = t.compile(v1), settings = t.settings(v1), rest = () => ({}), o = { settings, rest };",
      "const f = (s, n) => t.frameAt(c, { idle: false, ...s }, n, o);",
      "const change = { mood: 'happy', previous: 'idle', changedAt: 0 };",
      "const gestureLater = { ...change, gesture: 'nod', gestureAt: 4 };",
      "const changeLater = { ...change, gesture: 'nod', gestureAt: 0, changedAt: 4 };",
      "return { early: f(change, 3).mood, late: f(change, 9).mood, wiggle: Object.keys(f(change, 3).channels),",
      "gesture: [f(gestureLater, 3).mood, f(gestureLater, 5).mood, f(gestureLater, 5).channels['root.lift']],",
      "replaced: [f(changeLater, 5).mood, f(changeLater, 5).channels['root.lift'], Object.keys(f(changeLater, 5).channels)],",
      "off: f({ ...change, mood_change: false }, 3), gestureOff: f({ ...gestureLater, gestures: false }, 5).mood };"
    )))
    expect_identical(r$early, "idle")
    expect_identical(r$late, "happy")
    expect_identical(r$wiggle, list("root.rotate"))
    expect_identical(r$gesture[1:2], list("idle", "happy"))
    expect_equal(r$gesture[[3]], -3 * (1 / 18) / 0.25, tolerance = 1e-12)
    expect_identical(r$replaced[[1]], "idle")
    expect_identical(r$replaced[[3]], list("root.rotate"))
    expect_identical(r$off$mood, "happy")
    expect_identical(r$gestureOff, "idle")
  })

  it("settles at the deadline, under reduced motion and for held channels", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = t.compile(v1), settings = t.settings(v1), o = { settings, rest: () => ({}) };",
      "const s = { mood: 'happy', previous: 'idle', changedAt: 0, gesture: 'wave', gestureAt: 10, activeAt: 10 };",
      "const f = (state, n) => t.frameAt(c, state, n, o);",
      "return { before: f(s, 9).settled, during: f(s, 20).settled, at: f(s, 160), after: f(s, 400),",
      "reduced: f({ ...s, reduced: true }, 20), discarded: f({ ...s, activeAt: null }, 20),",
      "held: f({ ...s, held: { 'root.rotate': 0.3 } }, 20).channels['root.rotate'],",
      "heldRest: f({ ...s, held: { 'root.rotate': 0.3 } }, 400).channels, short: f({ ...s, activeUntil: 12 }, 12).settled,",
      "drawn: t.drawn({ activeAt: 0, activeUntil: 5 }, 3), none: t.drawn({ activeAt: 0, activeUntil: 5 }, 9) };"
    )))
    expect_false(r$during)
    expect_true(r$at$settled)
    expect_identical(r$at$mood, "happy")
    expect_length(r$at$channels, 0)
    expect_identical(r$after, r$at)
    expect_true(r$reduced$settled)
    expect_identical(r$reduced$mood, "happy")
    expect_true(r$discarded$settled)
    expect_equal(r$held, 0.3)
    expect_equal(r$heldRest[["root.rotate"]], 0.3)
    expect_true(r$short)
    expect_equal(unlist(r$drawn), c(3, 4, 5))
    expect_equal(unlist(r$none), 9)
  })

  it("fits late effects into the remaining frames, discards them at the deadline and keeps instances apart", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = clone(); c.gestures.nod.effects = [{ at: 0, effect: 'pop', anchor: 'face' },",
      "{ at: 0.5, effect: 'pop', anchor: 'face' }, { at: 1, effect: 'pop', anchor: 'face' }];",
      "const compiled = t.compile(c), settings = t.settings(c);",
      "const effects = { pop: { frames: 20, tracks: { opacity: [[0, 1], [1, 1]], y: [[0, 0], [1, -10]] } } };",
      "const run = (until, n) => t.frameAt(compiled, { mood: 'idle', gesture: 'nod', gestureAt: 0, activeAt: 0, activeUntil: until, idle: false },",
      "n, { settings, rest: () => ({}), effects }).effects.map(e => [e.index, +e.progress.toFixed(6), e.state.y]);",
      "return { full: run(150, 10), tight: run(14, 8), fit: t.fit(9, 20, 14), gone: t.fit(14, 20, 14),",
      "bad: fail(() => t.frameAt(compiled, { mood: 'idle', gesture: 'nod', gestureAt: 0, activeAt: 0 }, 1, { settings, rest: () => ({}),",
      "effects: { pop: { frames: 5, tracks: { ghost: [[0, 0], [1, 0]] } } } })),",
      "unknown: fail(() => t.frameAt(compiled, { mood: 'idle', gesture: 'nod', gestureAt: 0, activeAt: 0 }, 1, { settings, rest: () => ({}), effects: {} })) };"
    )))
    # At frame 10: first instance 10/20 through; the second started at 4.5 (its frame 18 * 0.5 = 9) -> index 1.
    expect_equal(r$full[[1]][[1]], 0)
    expect_equal(r$full[[1]][[3]], -5)
    # The trigger at 1 begins at the gesture end (frame 18) and has not started at frame 10; the second at 9.
    expect_identical(vapply(r$full, function(x) x[[1]], numeric(1)), c(0, 1))
    expect_equal(r$full[[2]][[2]], 0.05)
    # A 14-frame window: durations fit the remaining frames proportionally; the last trigger is discarded.
    expect_equal(vapply(r$tight, function(x) x[[2]], numeric(1)), c(8 / 14, 1 / 7), tolerance = 1e-5)
    expect_equal(r$fit, 5)
    expect_equal(r$gone, 0)
    expect_identical(r$bad$code, "invalid_channel")
    expect_identical(r$unknown$code, "missing_reference")
  })

  it("plays the idle extra once from the host's start, fitted into the window", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = clone(); c.motion.idle.extra = 'nod'; const compiled = t.compile(c), settings = t.settings(c);",
      "const f = (n, extra = {}) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 100, idle: false, extraAt: 40, ...extra }, n,",
      "{ settings, rest: () => ({}) }).channels['root.lift'];",
      "const late = n => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 100, idle: false, extraAt: 91 }, n,",
      "{ settings, rest: () => ({}) }).channels['root.lift'];",
      "return { before: f(39), peak: f(44.5), done: f(58), none: f(44.5, { extraAt: null }), late: late(93.25), gone: late(100),",
      "busy: f(44.5, { gesture: 'wave', gestureAt: 40 }), bad: fail(() => { c.motion.idle.extra = 'spin'; t.frameAt(t.compile(c), { mood: 'idle', activeAt: 0, extraAt: 0 }, 1, { settings: t.settings(c) }); }) };"
    )))
    expect_null(r$before)
    expect_equal(r$peak, -3)
    expect_null(r$done)
    expect_null(r$none)
    # Nine frames remain at 91, so the 18-frame nod is compressed to nine: its first peak is at 91 + 9 * 0.25 = 93.25.
    expect_equal(r$late, -3, tolerance = 1e-12)
    expect_null(r$gone)
    expect_null(r$busy)
    expect_identical(r$bad$code, "missing_reference")
  })

  it("keeps effect instances alive after the movement, lets a finished gesture yield to the extra and checks references", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = clone(); c.gestures.nod.effects = [{ at: 1, effect: 'pop', anchor: 'face' }]; c.motion.idle.extra = 'wave';",
      "const compiled = t.compile(c), settings = t.settings(c), effects = { pop: { frames: 10, tracks: { y: [[0, 0], [1, -10]] } } };",
      "const at = (n, s = {}) => t.frameAt(compiled, { mood: 'idle', gesture: 'nod', gestureAt: 0, activeAt: 0, activeUntil: 100, idle: false, ...s },",
      "n, { settings, rest: () => ({}), effects });",
      "const withChange = clone(); withChange.motion.change = { style: 'gesture', gesture: 'nod' };",
      "const g = t.compile(withChange), gs = t.settings(withChange);",
      "const viaChange = t.frameAt(g, { mood: 'happy', previous: 'idle', changedAt: 0, idle: false }, 4.5, { settings: gs, rest: () => ({}) });",
      "const badAnchor = clone(); badAnchor.gestures.nod.effects = [{ at: 0, effect: 'pop', anchor: 'nowhere' }];",
      "const noText = clone(); noText.gestures.nod.description = '';",
      "const ex = (f) => fail(() => { const x = clone(); f(x); t.settings(x); });",
      "return { instance: at(23).effects.map(e => +e.progress.toFixed(6)), none: at(28.1).effects.length, moving: Object.keys(at(23).channels),",
      "extra: at(40, { extraAt: 36 }).channels['arm_r.rotate'], viaChange: viaChange.channels['root.lift'], anchor: fail(() => t.compile(badAnchor)),",
      "text: fail(() => t.compile(noText)), part: ex(x => { x.motion.idle.breathe_part = 'tail'; }),",
      "key: ex(x => { x.motion.idle.sparkle = 1; }), group: ex(x => { x.motion.wobble = {}; }),",
      "style: ex(x => { x.motion.change = { style: 'gesture' }; }), extraName: ex(x => { x.motion.idle.extra = 'spin'; }) };"
    )))
    # The trigger at 1 starts at frame 18 and lives for its own 10 frames, past the movement.
    expect_equal(unlist(r$instance), 0.5)
    expect_equal(r$none, 0)
    expect_length(r$moving, 0)
    # Frame 40 is 4 frames into a wave that started at 36 (30 frames long); the finished nod no longer blocks it.
    expect_lt(r$extra, 1.25)
    expect_equal(r$viaChange, -3)
    expect_identical(r$anchor, list(code = "missing_reference", path = "$.gestures.nod.effects[0]"))
    expect_identical(r$text, list(code = "input_type", path = "$.gestures.nod.description"))
    expect_identical(r$part$path, "$.motion.idle.breathe_part")
    expect_identical(r$key, list(code = "unknown_key", path = "$.motion.idle.sparkle"))
    expect_identical(r$group, list(code = "unknown_key", path = "$.motion.wobble"))
    expect_identical(r$style$path, "$.motion.change.gesture")
    expect_identical(r$extraName$path, "$.motion.idle.extra")
  })

  it("keeps idle breathing within its bounds, fades it and skips blinks that cross the window", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = t.compile(v1), settings = t.settings(v1), o = { settings, rest: () => ({ 'root.scale_x': 2, 'root.scale_y': 0.5 }) };",
      "const f = (n, s = {}) => t.frameAt(c, { mood: 'idle', activeAt: 0, seed: 7, ...s }, n, o);",
      "let low = Infinity, high = -Infinity, blinks = [];",
      "for (let n = 0; n < 150; n++) { const r = f(n); const k = r.channels['root.scale_y'] / 0.5; low = Math.min(low, k);",
      "high = Math.max(high, k); blinks.push(r.blink); }",
      "const short = Array.from({ length: 60 }, (_, n) => f(n, { activeUntil: 60 }).blink);",
      "return { low, high, x: f(22.5).channels['root.scale_x'] / 2, late: f(149).channels['root.scale_y'],",
      "maxBlink: Math.max(...blinks), short: Math.max(...short), settled: f(150).channels };"
    )))
    expect_gte(r$low, 1 - 0.012 - 1e-12)
    expect_lte(r$high, 1 + 0.012 + 1e-12)
    expect_gt(r$high, 1.005)
    expect_equal(r$x, 0.988, tolerance = 1e-12)
    expect_equal(r$late, 0.5, tolerance = 1e-3)
    expect_gt(r$maxBlink, 0)
    expect_equal(r$short, 0)
    expect_length(r$settled, 0)
  })
})

describe("E4a deterministic idle extra scheduling", {
  it("schedules idle extra deterministically when extraAt is omitted and suppresses on null", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = clone(); c.motion.idle.extra = 'nod';",
      "const compiled = t.compile(c), settings = t.settings(c);",
      "const rest = () => ({});",
      "const o = { settings, rest };",
      "const f1 = (n, s = {}) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 150, seed: 42, ...s }, n, o).channels['root.lift'];",
      "const f2 = (n, s = {}) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 150, seed: 42, ...s }, n, o).channels['root.lift'];",
      "const fDiffSeed = (n) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 150, seed: 99 }, n, o).channels['root.lift'];",
      "const fSuppressed = (n) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 150, seed: 42, extraAt: null }, n, o).channels['root.lift'];",
      "const series1 = Array.from({ length: 100 }, (_, n) => f1(n));",
      "const series2 = Array.from({ length: 100 }, (_, n) => f2(n));",
      "const seriesSuppressed = Array.from({ length: 100 }, (_, n) => fSuppressed(n));",
      "const hasNod1 = series1.some(v => typeof v === 'number' && v < -2);",
      "const hasNodSuppressed = seriesSuppressed.some(v => v !== undefined);",
      "const sameSeries = JSON.stringify(series1) === JSON.stringify(series2);",
      "return { hasNod1, hasNodSuppressed, sameSeries };"
    )))
    expect_true(r$hasNod1)
    expect_false(r$hasNodSuppressed)
    expect_true(r$sameSeries)
  })
})
