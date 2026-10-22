# mascot.motion.tracks: the format-v1 tracks. Pure numeric checks in the shared offline page; no canvas is needed.
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

describe("format-v1 tracks", {
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

describe("deterministic idle extra scheduling", {
  it("schedules idle extra deterministically when extraAt is omitted and suppresses on null", {
    skip_without_chrome()
    js <- local_engine_page()
    r <- js(tracks_js(paste(
      "const c = clone(); c.motion.idle.extra = 'nod';",
      "const compiled = t.compile(c), settings = t.settings(c);",
      "const rest = () => ({});",
      "const o = { settings, rest };",
      "const f1 = (n, s = {}) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 150, seed: 42, ...s }, n, o).channels['root.lift'];",
      "const fSuppressed = (n) => t.frameAt(compiled, { mood: 'idle', activeAt: 0, activeUntil: 150, seed: 42, extraAt: null }, n, o).channels['root.lift'];",
      # The same call twice gives the same series.
      "const series1 = Array.from({ length: 100 }, (_, n) => f1(n));",
      "const series2 = Array.from({ length: 100 }, (_, n) => f1(n));",
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
