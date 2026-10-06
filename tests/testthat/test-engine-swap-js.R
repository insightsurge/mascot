# Swap tests use the shared offline page; each named JS result has an explicit R expectation.

swap_js <- function(character, code) {
  sprintf(
    paste(
      "(() => { const character = '%s';",
      "const a = mascot.readCharacter(character), b = mascot.readCharacter(character === 'tessa' ? 'blob' : 'tessa');",
      "const raf = window.requestAnimationFrame, cancel = window.cancelAnimationFrame, match = window.matchMedia;",
      "const draw = mascot.draw, queued = new Map(), listeners = new Set(), players = [], calls = [], composites = [];",
      "let id = 0, clears = 0;",
      "const media = { matches: false, addEventListener: (type, fn) => listeners.add(fn), removeEventListener: (type, fn) => listeners.delete(fn) };",
      "window.requestAnimationFrame = fn => { queued.set(++id, fn); return id; };",
      "window.cancelAnimationFrame = n => queued.delete(n); window.matchMedia = () => media;",
      "mascot.draw = (ctx, ch, options) => { calls.push({ description: ch, character: ch.id, ...options }); return draw(ctx, ch, options); };",
      "const last = () => calls[calls.length - 1];",
      "const fire = timestamp => { const batch = [...queued.values()]; queued.clear(); batch.forEach(fn => fn(timestamp)); };",
      "const preference = value => { media.matches = value; listeners.forEach(fn => fn({ matches: value })); };",
      "const clone = ch => JSON.parse(JSON.stringify(ch));",
      "const attempt = fn => { try { fn(); } catch (e) { return e.message; } return 'no error'; };",
      "const mount = (options = {}) => {",
      "  const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "  const ctx = c.getContext('2d'), clear = ctx.clearRect.bind(ctx), image = ctx.drawImage.bind(ctx);",
      "  ctx.clearRect = (...args) => { clears++; return clear(...args); };",
      "  ctx.drawImage = (...args) => { composites.push(ctx.globalAlpha); return image(...args); };",
      "  const p = mascot.mount(c, a, { x: 150, baseY: 280, ...options }); players.push(p); return { c, ctx, p };",
      "};",
      "const sample = (p, n) => {",
      "  const count = calls.length, images = composites.length; p.seek(n);",
      "  return { ...last(), ...p.current(), opacity: composites.length > images ? composites[composites.length - 1] : 1, draws: calls.length - count };",
      "};",
      "try {",
      code,
      "} finally { players.forEach(p => p.destroy()); mascot.draw = draw; window.requestAnimationFrame = raf;",
      "window.cancelAnimationFrame = cancel; window.matchMedia = match; } })()"
    ),
    character
  )
}

describe("animated character swaps", {
  it("waves and fades sequentially in sixty frames at the same position", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); p.update({ character: b });",
          "const s0 = sample(p, 0), s6 = sample(p, 6), s15 = sample(p, 15), s29 = sample(p, 29), s30 = sample(p, 30), s45 = sample(p, 45), s60 = sample(p, 60);",
          "return { oldFirst: s0.character === a.id, oldLast: s29.character === a.id, newFirst: s30.character === b.id,",
          "  zero: s30.opacity, halfOut: s15.opacity, halfIn: s45.opacity, full: s60.opacity, complete: s60.swapping,",
          "  waveRotation: s6.pose.rot, waveArm: a.arms ? s6.pose.armR : -0.9, armAbsent: a.arms ? true : !Object.hasOwn(s6.pose,'armR'),",
          "  oneDraw: [s0,s6,s15,s29,s30,s45,s60].every(s => s.draws === 1), x: s45.x, baseY: s45.baseY };"
        )
      ))
      expect_true(r$oldFirst, info = character)
      expect_true(r$oldLast, info = character)
      expect_true(r$newFirst, info = character)
      expect_equal(r$zero, 0, tolerance = 1e-6, info = character)
      expect_equal(r$halfOut, 0.5, tolerance = 1e-6, info = character)
      expect_equal(r$halfIn, 0.5, tolerance = 1e-6, info = character)
      expect_equal(r$full, 1, tolerance = 1e-6, info = character)
      expect_false(r$complete, info = character)
      expect_equal(r$waveRotation, -0.025, tolerance = 1e-6, info = character)
      expect_equal(r$waveArm, -0.9, tolerance = 1e-6, info = character)
      expect_true(r$armAbsent, info = character)
      expect_true(r$oneDraw, info = character)
      expect_equal(r$x, 150, tolerance = 1e-6, info = character)
      expect_equal(r$baseY, 280, tolerance = 1e-6, info = character)
    }
  })

  it("treats the same object and the same id as ordinary mood updates", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ colours: { body: '#abc' } }); p.pause();",
          "const count = calls.length; p.update({ character: a }); const noDraw = calls.length === count;",
          "const copy = clone(a); copy.centreHeight += 50; p.update({ character: copy, mood: 'happy' });",
          "const early = sample(p, 8), late = sample(p, 9);",
          "return { noDraw, swapping: early.swapping, early: early.mood, late: late.mood, colour: late.colours.body, unchangedDescription: last().description === a };"
        )
      ))
      expect_true(r$noDraw, info = character)
      expect_false(r$swapping, info = character)
      expect_identical(r$early, "idle", info = character)
      expect_identical(r$late, "happy", info = character)
      expect_identical(r$colour, "#abc", info = character)
      expect_true(r$unchangedDescription, info = character)
    }
  })

  it("resets the mood and colours but accepts replacements in the swap patch", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ mood: 'happy', colours: { body: '#abc' } }); p.pause();",
          "p.update({ character: b }); const plain = sample(p, 60);",
          "p.update({ character: a, mood: 'worried', colours: { body: '#def' } }); const replaced = sample(p, 120);",
          "return { mood: plain.mood, colours: Object.keys(plain.colours).length, explicitMood: replaced.mood, explicitColour: replaced.colours.body };"
        )
      ))
      expect_identical(r$mood, "idle", info = character)
      expect_equal(r$colours, 0, tolerance = 1e-6, info = character)
      expect_identical(r$explicitMood, "worried", info = character)
      expect_identical(r$explicitColour, "#def", info = character)
    }
  })

  it("skips intermediate targets during fade-out and rapid tab clicks", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const c = clone(b); c.id = 'third'; const d = clone(a); d.id = 'fourth';",
          "p.update({ character: b }); sample(p, 12); p.update({ character: c }); const after = sample(p, 12);",
          "sample(p, 18); p.update({ character: d }); const ids = [];",
          "for (let n = 18; n <= 60; n++) ids.push(sample(p,n).character);",
          "return { opacity: after.opacity, stillOld: after.character === a.id, final: p.current().character, noIntermediate: ids.every(id => id === a.id || id === 'fourth'), ended: p.current().swapping };"
        )
      ))
      expect_equal(r$opacity, 0.6, tolerance = 1e-6, info = character)
      expect_true(r$stillOld, info = character)
      expect_identical(r$final, "fourth", info = character)
      expect_true(r$noIntermediate, info = character)
      expect_false(r$ended, info = character)
    }
  })

  it("exits the partially visible incoming character when retargeted during fade-in", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const c = clone(a); c.id = 'third';",
          "p.update({ character: b }); sample(p, 45); p.update({ character: c });",
          "const immediate = sample(p,45), halfway = sample(p,52.5), boundary = sample(p,60), arrived = sample(p,90);",
          "return { visibleIncoming: immediate.character === b.id, opacity: immediate.opacity, halfExit: halfway.opacity,",
          "  boundary: boundary.character, zero: boundary.opacity, final: arrived.character, ended: arrived.swapping };"
        )
      ))
      expect_true(r$visibleIncoming, info = character)
      expect_equal(r$opacity, 0.5, tolerance = 1e-6, info = character)
      expect_equal(r$halfExit, 0.25, tolerance = 1e-6, info = character)
      expect_identical(r$boundary, "third", info = character)
      expect_equal(r$zero, 0, tolerance = 1e-6, info = character)
      expect_identical(r$final, "third", info = character)
      expect_false(r$ended, info = character)
    }
  })

  it("reverses directly when returning to the exiting character", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); p.update({ character: b }); sample(p,12); p.update({ character: a });",
          "const start = sample(p,12), middle = sample(p,18), end = sample(p,24);",
          "return { old: start.character === a.id, opacity: start.opacity, middle: middle.opacity, end: end.opacity, ended: end.swapping, onlyOriginal: calls.every(c => c.character === a.id) };"
        )
      ))
      expect_true(r$old, info = character)
      expect_equal(r$opacity, 0.6, tolerance = 1e-6, info = character)
      expect_equal(r$middle, 0.8, tolerance = 1e-6, info = character)
      expect_equal(r$end, 1, tolerance = 1e-6, info = character)
      expect_false(r$ended, info = character)
      expect_true(r$onlyOriginal, info = character)
    }
  })

  it("cancels an outgoing wiggle or gesture and keeps the visible mood", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); p.setMood('happy'); sample(p,4); p.update({ character: b });",
          "const wiggleExit = sample(p,5); sample(p,64); p.gesture('nod'); sample(p,67); p.update({ character: a });",
          "const gestureExit = sample(p,68), incoming = sample(p,127);",
          "return { outgoingMood: wiggleExit.mood, gestureOld: gestureExit.character === b.id, targetMood: incoming.mood, complete: incoming.swapping };"
        )
      ))
      expect_identical(r$outgoingMood, "idle", info = character)
      expect_true(r$gestureOld, info = character)
      expect_identical(r$targetMood, "idle", info = character)
      expect_false(r$complete, info = character)
    }
  })

  it("carries compatible held fields and drops unusable anatomy and accessories", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause();",
          "const held = { lookY: -1, rot: .75, feet: 'tuck', shadow: false, sweat: .2, sparkle: true, blush: 'strong' };",
          "if (a.arms) Object.assign(held, { arms: 'hips', armR: -.5, armJitter: .2, accessory: ['bow', 'none'] });",
          "p.update({ pose: held }); p.update({ character: b }); const incoming = sample(p,45);",
          "const rest = sample(p,150);",
          "return { lookY: rest.pose.lookY, rotation: incoming.pose.rot, restKeys: Object.keys(rest.pose).sort().join(','),",
          "  noMissingArms: b.arms || (!Object.hasOwn(rest.pose,'arms') && !Object.hasOwn(rest.pose,'armR') && !Object.hasOwn(rest.pose,'armJitter')) ? true : false,",
          "  accessories: b.arms ? 'kept' : rest.pose.accessory.join(',') };"
        )
      ))
      expect_equal(r$lookY, -1, tolerance = 1e-6, info = character)
      expect_equal(r$rotation, 0.75, tolerance = 1e-6, info = character)
      expect_identical(
        r$restKeys,
        if (character == "tessa") "accessory,lookY,mood,rot" else "blush,feet,lookY,mood,rot,shadow,sparkle,sweat",
        info = character
      )
      expect_true(r$noMissingArms, info = character)
      expect_identical(r$accessories, if (character == "tessa") "none" else "kept", info = character)
    }
  })

  it("drops unavailable arm presets while retaining usable explicit angles", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const next = clone(a); next.id = 'different';",
          "if (a.arms) { p.update({ pose: { arms: 'hips', armR: -.5 } }); delete next.arms.presets.hips; next.moods.thinking.arms = 'idle'; }",
          "else p.update({ pose: { lookY: -1 } });",
          "p.update({ character: next }); const rest = sample(p,150);",
          "return { dropped: !Object.hasOwn(rest.pose,'arms'), angle: a.arms ? rest.pose.armR : -.5 };"
        )
      ))
      expect_true(r$dropped, info = character)
      expect_equal(r$angle, -0.5, tolerance = 1e-6, info = character)
    }
  })

  it("applies mood colour and held updates only to the incoming character and drops gestures", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); p.update({ character: b }); sample(p,10);",
          "p.update({ mood: 'worried', pose: { lookY: -1 }, colours: { body: '#abc' } });",
          "const outgoing = sample(p,11); const count = calls.length; p.gesture('nod'); const dropped = calls.length === count;",
          "const incoming = sample(p,40), rest = sample(p,150);",
          "return { oldMood: outgoing.mood, oldLook: outgoing.pose.lookY, oldColours: Object.keys(outgoing.colours).length,",
          "  newMood: incoming.mood, newLook: incoming.pose.lookY, newColour: incoming.colours.body, dropped,",
          "  rest: Object.keys(rest.pose).sort().join(','), badGesture: attempt(() => p.gesture('bogus')).startsWith('mascot: unknown gesture') };"
        )
      ))
      expect_identical(r$oldMood, "idle", info = character)
      expect_equal(r$oldLook, 0, tolerance = 1e-6, info = character)
      expect_equal(r$oldColours, 0, tolerance = 1e-6, info = character)
      expect_identical(r$newMood, "worried", info = character)
      expect_equal(r$newLook, -1, tolerance = 1e-6, info = character)
      expect_identical(r$newColour, "#abc", info = character)
      expect_true(r$dropped, info = character)
      expect_identical(r$rest, "lookY,mood", info = character)
      expect_true(r$badGesture, info = character)
    }
  })

  it("rejects invalid patches atomically without drawing during an existing swap", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { c, p } = mount(); p.pause(); p.update({ character: b }); sample(p,12);",
          "const bad = clone(a); bad.id = 'bad'; bad.body[0].shape = 'toString';",
          "const badMotion = clone(a); badMotion.id = 'bad-motion'; badMotion.motion = { nope: {} };",
          "const empty = clone(a); empty.id = 'empty'; empty.moods = {};",
          "const role = a.id === 'tessa' ? 'sleeve' : 'absent';",
          "const patches = [{ character: {} }, { character: null }, { character: bad }, { character: badMotion }, { character: empty },",
          " { character: a, mood: 'toString' }, { character: mascot.readCharacter('blob'), colours: { [role]: '#abc' } },",
          " { character: a, pose: { eyes: 'bogus' } }, { character: a, pose: { rotate: 1 } },",
          " { character: a, swap: 'yes' }, { character: a, reduced: 1 }];",
          "const count = calls.length, before = c.toDataURL(), snapshot = JSON.stringify(p.current());",
          "const errors = patches.map(patch => attempt(() => p.update(patch)));",
          "return { names: errors.map(e => e.split(': ')[1]).join(','), untouched: snapshot === JSON.stringify(p.current()),",
          "  noDraw: calls.length === count, samePicture: before === c.toDataURL(), stillExiting: sample(p,15).character === a.id, opacity: composites[composites.length-1] };"
        )
      ))
      expect_identical(
        r$names,
        if (character == "tessa") {
          "update.character,update.character,update.character,update.character,update.character,update.mood,update.colours.sleeve,update.pose.eyes,update.pose.rotate,update.swap,update.reduced"
        } else {
          "update.character,update.character,update.character,update.character,update.character,update.mood,update.colours.absent,update.pose.eyes,update.pose.rotate,update.swap,update.reduced"
        },
        info = character
      )
      expect_true(r$untouched, info = character)
      expect_true(r$noDraw, info = character)
      expect_true(r$samePicture, info = character)
      expect_true(r$stillExiting, info = character)
      expect_equal(r$opacity, 0.5, tolerance = 1e-6, info = character)
    }
  })

  it("makes disabled and forced or visitor reduced swaps instant", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const results = [];",
          "for (const mode of ['switch','forced','visitor']) {",
          "  media.matches = mode === 'visitor'; const { p } = mount(mode === 'switch' ? { swap: false } : mode === 'forced' ? { reduced: true } : {});",
          "  p.pause(); p.update({ character: b }); const now = sample(p,0), later = sample(p,22.5);",
          "  results.push(now.character === b.id && !now.swapping && later.pose.sy === (mode === 'switch' ? 1.012 : undefined));",
          "}",
          "return { modes: results.join(',') };"
        )
      ))
      expect_identical(r$modes, "true,true,true", info = character)
    }
  })

  it("finishes on reduction or disabling midway and never replays the discarded swap", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const results = [];",
          "for (const n of [12,45]) for (const mode of ['forced','visitor','switch']) {",
          "  media.matches = false; const { p } = mount(); p.pause(); p.update({ character: b }); sample(p,n);",
          "  if (mode === 'visitor') preference(true); else p.update(mode === 'forced' ? { reduced: true } : { swap: false });",
          "  const immediate = p.current();",
          "  if (mode === 'visitor') preference(false); else p.update(mode === 'forced' ? { reduced: false } : { swap: true });",
          "  const back = sample(p,0);",
          "  results.push(immediate.character === b.id && !immediate.swapping && back.character === b.id && !back.swapping);",
          "}",
          "return { finished: results.join(',') };"
        )
      ))
      expect_identical(r$finished, "true,true,true,true,true,true", info = character)
    }
  })

  it("pauses freezes resumes and destroys a swap without extending its deadline", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.update({ character: b }); fire(0); fire(500); p.pause();",
          "const frozen = last().frame; fire(5000); const pauseFrame = last().frame; p.play(); fire(8000); fire(8500);",
          "const resumed = last().frame; fire(20000); const restingFrame = last().frame, restQueue = queued.size;",
          "p.update({ character: a }); fire(21000); fire(21500); const stale = [...queued.values()][0]; p.destroy();",
          "const count = calls.length; stale(30000); p.seek(0); p.update({ character: b }); p.gesture('wave'); p.play();",
          "return { frozen, pauseFrame, resumed, restingFrame, restQueue, inert: count === calls.length, listeners: listeners.size, queue: queued.size };"
        )
      ))
      expect_equal(r$frozen, 15, tolerance = 1e-6, info = character)
      expect_equal(r$pauseFrame, 15, tolerance = 1e-6, info = character)
      expect_equal(r$resumed, 30, tolerance = 1e-6, info = character)
      expect_equal(r$restingFrame, 150, tolerance = 1e-6, info = character)
      expect_equal(r$restQueue, 0, tolerance = 1e-6, info = character)
      expect_true(r$inert, info = character)
      expect_equal(r$listeners, 0, tolerance = 1e-6, info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
    }
  })

  it("reproduces sought pictures after completion and keeps snapshots independent", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { c, p } = mount({ seed: 55 }); p.pause(); p.update({ character: b }); const pictures = [];",
          "for (const n of [0,6,15,29,30,36,45,59,60,147,150]) { p.seek(n); pictures.push(c.toDataURL()); }",
          "p.seek(1000); const identical = [0,6,15,29,30,36,45,59,60,147,150].every((n,i) => { p.seek(n); return c.toDataURL() === pictures[i]; });",
          "const snap = p.current(); snap.character = 'changed'; snap.mood = 'bogus'; snap.swapping = true;",
          "return { identical, currentCharacter: p.current().character === b.id, currentMood: p.current().mood, swapping: p.current().swapping };"
        )
      ))
      expect_true(r$identical, info = character)
      expect_true(r$currentCharacter, info = character)
      expect_identical(r$currentMood, "idle", info = character)
      expect_false(r$swapping, info = character)
    }
  })

  it("restores alpha styles and transforms and clears every frame including blank ones", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { c, ctx, p } = mount(); p.pause(); ctx.globalAlpha = .375; ctx.fillStyle = '#123456'; ctx.strokeStyle = '#abcdef'; ctx.lineWidth = 7;",
          "ctx.setTransform(1.2,0,.1,.8,7,9); const transform = () => { const t = ctx.getTransform(); return [t.a,t.b,t.c,t.d,t.e,t.f].join(','); };",
          "const before = transform(), count = clears; p.update({ character: b, mood: 'worried' });",
          "const alphas = [], states = [];",
          "for (const n of [15,30,45,60,150]) {",
          "  sample(p,n); alphas.push(composites[composites.length-1]);",
          "  states.push(ctx.globalAlpha === .375 && ctx.fillStyle === '#123456' && ctx.strokeStyle === '#abcdef' && ctx.lineWidth === 7 && transform() === before);",
          "}",
          "const reduced = p.current();",
          "return { states: states.join(','), halfOut: alphas[0], zero: alphas[1], halfIn: alphas[2], clears: clears-count, width: c.width, height: c.height, atRest: reduced.swapping };"
        )
      ))
      expect_identical(r$states, "true,true,true,true,true", info = character)
      expect_equal(r$halfOut, 0.1875, tolerance = 1e-6, info = character)
      expect_equal(r$zero, 0, tolerance = 1e-6, info = character)
      expect_equal(r$halfIn, 0.1875, tolerance = 1e-6, info = character)
      expect_equal(r$clears, 6, tolerance = 1e-6, info = character)
      expect_equal(r$width, 300, tolerance = 1e-6, info = character)
      expect_equal(r$height, 300, tolerance = 1e-6, info = character)
      expect_false(r$atRest, info = character)
    }
  })

  it("ends all automatic movement by frame 150 and stops RAF at rest", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.update({ character: b }); const near = sample(p,149), end = sample(p,150), later = sample(p,500);",
          "const count = calls.length; fire(50000);",
          "return { before: near.pose.sy !== 1, atRest: Object.keys(end.pose).join(','), later: Object.keys(later.pose).join(','), queue: queued.size, noDraw: count === calls.length };"
        )
      ))
      expect_true(r$before, info = character)
      expect_identical(r$atRest, "mood", info = character)
      expect_identical(r$later, "mood", info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
      expect_true(r$noDraw, info = character)
    }
  })

  it("keeps seeded blink rules for the incoming character", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const output = [];",
          "for (const seed of [55,11,0]) {",
          "  const { p } = mount({ seed }); p.pause(); p.update({ character: b });",
          "  output.push(sample(p,147).pose.blink || 0);",
          "}",
          "return { allowed: output[0], crossingSkipped: output[1], otherSeed: output[2] };"
        )
      ))
      expect_equal(r$allowed, 1, tolerance = 1e-6, info = character)
      expect_equal(r$crossingSkipped, 0, tolerance = 1e-6, info = character)
      expect_equal(r$otherSeed, 0, tolerance = 1e-6, info = character)
    }
  })

  it("uses configured timings and caps swap plus idle to short activity windows", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ swapTiming: { outFrames: 12, inFrames: 18 } }); p.pause(); p.update({ character: b });",
          "const boundary = sample(p,12), midway = sample(p,21), complete = sample(p,30);",
          "const tiny = clone(a); tiny.id = 'tiny'; tiny.motion = { idle: { frames: 10 } }; p.update({ character: tiny });",
          "const shortBoundary = sample(p,34), shortEnd = sample(p,40);",
          "return { boundary: boundary.character === b.id, zero: boundary.opacity, midpoint: midway.opacity, complete: complete.swapping,",
          " shortBoundary: shortBoundary.character === 'tiny', shortZero: shortBoundary.opacity, shortRest: Object.keys(shortEnd.pose).join(','), shortComplete: shortEnd.swapping };"
        )
      ))
      expect_true(r$boundary, info = character)
      expect_equal(r$zero, 0, tolerance = 1e-6, info = character)
      expect_equal(r$midpoint, 0.5, tolerance = 1e-6, info = character)
      expect_false(r$complete, info = character)
      expect_true(r$shortBoundary, info = character)
      expect_equal(r$shortZero, 0, tolerance = 1e-6, info = character)
      expect_identical(r$shortRest, "mood", info = character)
      expect_false(r$shortComplete, info = character)
    }
  })

  it("validates timing and switch options before drawing or registering a listener", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const count = calls.length;",
          "const errors = [null,{ typo: 1 },{ outFrames: 0 },{ inFrames: -1 },{ outFrames: Infinity },{ inFrames: '30' }].map(swapTiming => attempt(() => mount({ swapTiming })));",
          "const badSwitch = attempt(() => mount({ swap: null }));",
          "return { messages: errors.map(e => e.startsWith('mascot: swapTiming')).join(','), badSwitch: badSwitch.startsWith('mascot: update.swap:'), noDraw: calls.length === count, listeners: listeners.size };"
        )
      ))
      expect_identical(r$messages, "true,true,true,true,true,true", info = character)
      expect_true(r$badSwitch, info = character)
      expect_true(r$noDraw, info = character)
      expect_equal(r$listeners, 0, tolerance = 1e-6, info = character)
    }
  })

  it("keeps separate canvases independent and follows preference only when unforced", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const one = mount({ reduced: false }), two = mount(); one.p.pause(); two.p.pause(); preference(true);",
          "one.p.update({ character: b }); const first = sample(one.p,15), second = sample(two.p,15);",
          "const third = clone(a); third.id = 'third'; one.p.update({ character: third, reduced: true });",
          "return { animated: first.swapping, opacity: first.opacity, otherOriginal: second.character === a.id, otherReduced: second.pose.sy === undefined,",
          " simultaneousInstant: one.p.current().character, simultaneousFinished: one.p.current().swapping };"
        )
      ))
      expect_true(r$animated, info = character)
      expect_equal(r$opacity, 0.5, tolerance = 1e-6, info = character)
      expect_true(r$otherOriginal, info = character)
      expect_true(r$otherReduced, info = character)
      expect_identical(r$simultaneousInstant, "third", info = character)
      expect_false(r$simultaneousFinished, info = character)
    }
  })

  it("computes a frozen pure swap state without modifying descriptions or snapshots", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const outgoing = Object.freeze({ character: a, pose: Object.freeze(mascot.drawing.resolvePose(a,{ mood: 'idle' })), held: Object.freeze({}), colours: Object.freeze({}) });",
          "const swap = Object.freeze({ at: 0, until: 60, outFrames: 30, inFrames: 30, opacity: 1, outgoing });",
          "const state = Object.freeze({ mood: 'idle', activeAt: 0, seed: 55, pose: Object.freeze({}), colours: Object.freeze({}), swap });",
          "const before = JSON.stringify({ a,b,state }); const s15 = mascot.motion.frame(b,state,15), s45 = mascot.motion.frame(b,state,45);",
          "mascot.motion.frame(b,state,150); const repeated = mascot.motion.frame(b,state,15);",
          "return { old: s15.character.id === a.id, half: s15.opacity, incoming: s45.character.id === b.id, incomingHalf: s45.opacity,",
          " same: JSON.stringify(s15) === JSON.stringify(repeated), unchanged: before === JSON.stringify({ a,b,state }), rest: Object.keys(mascot.motion.frame(b,state,150).pose).join(',') };"
        )
      ))
      expect_true(r$old, info = character)
      expect_equal(r$half, 0.5, tolerance = 1e-6, info = character)
      expect_true(r$incoming, info = character)
      expect_equal(r$incomingHalf, 0.5, tolerance = 1e-6, info = character)
      expect_true(r$same, info = character)
      expect_true(r$unchanged, info = character)
      expect_identical(r$rest, "mood", info = character)
    }
  })

  it("uses the first data-defined mood and accepts new-only moods and colour roles", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ mood: 'happy' }); p.pause(); const target = clone(b); target.id = 'new-default';",
          "target.moods = { greeting: { eyes: 'open', mouth: 'smile' }, ...target.moods }; target.colours.badge = '#123456';",
          "p.update({ character: target }); const defaultMood = sample(p,60).mood;",
          "p.update({ character: a }); sample(p,120); p.update({ character: target, mood: 'greeting', colours: { badge: '#abc' } });",
          "const explicit = sample(p,180); const count = calls.length;",
          "const error = attempt(() => p.update({ character: a, mood: 'greeting' }));",
          "return { defaultMood, explicitMood: explicit.mood, colour: explicit.colours.badge, invalidForOld: error.startsWith('mascot: update.mood:'), noDraw: count === calls.length };"
        )
      ))
      expect_identical(r$defaultMood, "greeting", info = character)
      expect_identical(r$explicitMood, "greeting", info = character)
      expect_identical(r$colour, "#abc", info = character)
      expect_true(r$invalidForOld, info = character)
      expect_true(r$noDraw, info = character)
    }
  })

  it("reuses a custom wave timeline and seeds idle relative to the swap action", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ seed: 55 }); p.pause(); const custom = clone(b); custom.id = 'custom-wave';",
          "custom.motion = { gestures: { wave: { timeline: [{ at: 0, pose: {} }, { at: .5, pose: { rot: .4 } }, { at: 1, pose: {} }] } } };",
          "p.seek(25); p.update({ character: custom }); const wave = sample(p,70), blink = sample(p,172), rest = sample(p,175);",
          "return { wave: wave.pose.rot, blink: blink.pose.blink, rest: Object.keys(rest.pose).join(','), complete: rest.swapping };"
        )
      ))
      expect_equal(r$wave, 0.4, tolerance = 1e-6, info = character)
      expect_equal(r$blink, 1, tolerance = 1e-6, info = character)
      expect_identical(r$rest, "mood", info = character)
      expect_false(r$complete, info = character)
    }
  })

  it("handles synchronous cancellation and canvas resize during a swap", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { c, p } = mount(); p.pause(); p.update({ character: b }); p.update({ character: a });",
          "const cancelled = p.current(); p.update({ character: b }); sample(p,15); c.width = 420; c.height = 360;",
          "const resized = sample(p,45); const image = c.toDataURL(); p.seek(45);",
          "return { original: cancelled.character === a.id, cancelled: cancelled.swapping, incoming: resized.character === b.id,",
          " opacity: resized.opacity, width: c.width, height: c.height, same: image === c.toDataURL() };"
        )
      ))
      expect_true(r$original, info = character)
      expect_false(r$cancelled, info = character)
      expect_true(r$incoming, info = character)
      expect_equal(r$opacity, 0.5, tolerance = 1e-6, info = character)
      expect_equal(r$width, 420, tolerance = 1e-6, info = character)
      expect_equal(r$height, 360, tolerance = 1e-6, info = character)
      expect_true(r$same, info = character)
    }
  })

  it("keeps patches atomic when explicit anatomy is incompatible with the target", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const armless = mascot.readCharacter('blob');",
          "const count = calls.length, snapshot = JSON.stringify(p.current());",
          "const error = attempt(() => p.update({ character: armless, pose: { arms: 'hips', accessory: 'bow' } }));",
          "return { error: error.startsWith('mascot: update.pose.arms'), noDraw: count === calls.length, unchanged: snapshot === JSON.stringify(p.current()) };"
        )
      ))
      expect_true(r$error, info = character)
      expect_true(r$noDraw, info = character)
      expect_true(r$unchanged, info = character)
    }
  })

  it("commits incoming updates without a wiggle during fade-in and keeps the original window", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); p.update({ character: b }); sample(p,45);",
          "p.update({ character: clone(b), mood: 'happy', pose: { lookY: -.75 }, colours: { body: '#abc' } });",
          "const incoming = sample(p,45), count = calls.length; p.gesture('wave');",
          "const dropped = count === calls.length, end = sample(p,150);",
          "return { incoming: incoming.character === b.id, opacity: incoming.opacity, mood: incoming.mood, lookY: incoming.pose.lookY,",
          " colour: incoming.colours.body, dropped, endKeys: Object.keys(end.pose).sort().join(','), endMood: end.mood };"
        )
      ))
      expect_true(r$incoming, info = character)
      expect_equal(r$opacity, 0.5, tolerance = 1e-6, info = character)
      expect_identical(r$mood, "happy", info = character)
      expect_equal(r$lookY, -0.75, tolerance = 1e-6, info = character)
      expect_identical(r$colour, "#abc", info = character)
      expect_true(r$dropped, info = character)
      expect_identical(r$endKeys, "lookY,mood", info = character)
      expect_identical(r$endMood, "happy", info = character)
    }
  })

  it("freezes and destroys during either phase with stale RAF callbacks inert", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const frozen = [], resumed = [], dead = [];",
          "for (const n of [12,45]) {",
          "  const { p } = mount(); p.update({ character: b }); fire(0); fire(n*1000/30);",
          "  p.pause(); const image = last().frame; fire(10000); frozen.push(last().frame === image);",
          "  p.play(); fire(20000); fire(20100); resumed.push(last().frame - image);",
          "  const stale = [...queued.values()][0], snapshot = p.current(), count = calls.length; p.destroy(); stale(30000);",
          "  dead.push(calls.length === count && p.current().character === snapshot.character && queued.size === 0);",
          "}",
          "return { frozen: frozen.join(','), resumed: resumed.join(','), dead: dead.join(','), listeners: listeners.size };"
        )
      ))
      expect_identical(r$frozen, "true,true", info = character)
      expect_identical(r$resumed, "3,3", info = character)
      expect_identical(r$dead, "true,true", info = character)
      expect_equal(r$listeners, 0, tolerance = 1e-6, info = character)
    }
  })

  it("does not resurrect dropped held fields or previous colours when returning", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ mood: 'happy', colours: { body: '#abc' } }); p.pause();",
          "p.update({ pose: a.arms ? { lookY: -1, arms: 'hips', armR: -.5 } : { lookY: -1 } });",
          "p.update({ character: b }); sample(p,12); p.update({ character: a }); const rest = sample(p,162);",
          "return { original: rest.character === a.id, mood: rest.mood, colours: Object.keys(rest.colours).length, heldKeys: Object.keys(rest.pose).sort().join(',') };"
        )
      ))
      expect_true(r$original, info = character)
      expect_identical(r$mood, "idle", info = character)
      expect_equal(r$colours, 0, tolerance = 1e-6, info = character)
      expect_identical(r$heldKeys, "lookY,mood", info = character)
    }
  })

  it("caps very long timings without overflow and rests at the deadline", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ swapTiming: { outFrames: 1e300, inFrames: 1e300 } }); p.pause(); p.update({ character: b });",
          "const exit = sample(p,37.5), boundary = sample(p,75), enter = sample(p,112.5), rest = sample(p,150);",
          "return { halfExit: exit.opacity, zero: boundary.opacity, incoming: boundary.character === b.id, halfEnter: enter.opacity, complete: rest.swapping, resting: Object.keys(rest.pose).join(',') };"
        )
      ))
      expect_equal(r$halfExit, 0.5, tolerance = 1e-6, info = character)
      expect_equal(r$zero, 0, tolerance = 1e-6, info = character)
      expect_true(r$incoming, info = character)
      expect_equal(r$halfEnter, 0.5, tolerance = 1e-6, info = character)
      expect_false(r$complete, info = character)
      expect_identical(r$resting, "mood", info = character)
    }
  })

  it("bug 1: malformed nested geometry is rejected before state or drawing changes", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const before = JSON.stringify(p.current()), count = calls.length;",
          "const bad = clone(a); bad.id = 'bad'; bad.face.eyes = null;",
          "const error = attempt(() => p.update({ character: bad, swap: false }));",
          "return { field: error.includes('update.character') && error.includes('face.eyes'), unchanged: JSON.stringify(p.current()) === before, noDraw: calls.length === count };"
        )
      ))
      expect_true(r$field, info = character)
      expect_true(r$unchanged, info = character)
      expect_true(r$noDraw, info = character)
    }
  })

  it("bug 2: rounded phase durations complete at the activity deadline", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount({ swapTiming: { outFrames: 11, inFrames: 144 } }); p.update({ character: b });",
          "const end = sample(p,150), count = calls.length; p.gesture('nod');",
          "return { complete: !end.swapping, resting: Object.keys(end.pose).join(','), gestureDrawn: calls.length === count + 1, restarted: queued.size === 1 };"
        )
      ))
      expect_true(r$complete, info = character)
      expect_identical(r$resting, "mood", info = character)
      expect_true(r$gestureDrawn, info = character)
      expect_true(r$restarted, info = character)
    }
  })

  it("bug 3: reversals and retargets preserve every displayed numeric pose field", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const sameNumbers = (before, after) => Object.keys(before).filter(k => typeof before[k] === 'number').every(k => Math.abs(before[k] - after[k]) < 1e-9);",
          "const results = [], nextSteps = [], deterministic = [];",
          "for (const [n, returning] of [[6,true],[12,false],[45,false]]) {",
          " const { c, p } = mount(); p.pause(); p.update({ character: b }); const old = sample(p,n); const before = mascot.drawing.resolvePose(last().description, old.pose, n);",
          " const target = returning ? a : clone(a); if (!returning) target.id = 'third';",
          " p.update({ character: target }); const after = mascot.drawing.resolvePose(last().description, last().pose, n); results.push(sameNumbers(before,after));",
          " const next = sample(p,n+1).pose; nextSteps.push(Math.abs(next.rot-before.rot) <= .025/6 + 1e-9 && (!a.arms || n === 45 || Math.abs(next.armR-before.armR) <= 2.15/6 + 1e-9));",
          " const image = c.toDataURL(); p.seek(150); p.seek(n+1); deterministic.push(image === c.toDataURL());",
          "}",
          "return { sameNumbers: results.join(','), bounded: nextSteps.join(','), deterministic: deterministic.join(',') };"
        )
      ))
      expect_identical(r$sameNumbers, "true,true,true", info = character)
      expect_identical(r$bounded, "true,true,true", info = character)
      expect_identical(r$deterministic, "true,true,true", info = character)
    }
  })

  it("bug 4: malformed colour syntax and out of range channels reject the whole patch", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const before = JSON.stringify(p.current()), count = calls.length;",
          "const values = ['rgb(1..2, 2, 3)','rgb(256, 2, 3)','rgb(-1, 2, 3)','rgb(1, 2, 3, .5)','rgba(1, 2, 3)','rgba(1, 2, 3, 1.1)','rgba(1, 2, 3, .)','rgba(1, 2, 3, -0.1)'];",
          "const errors = values.map(value => attempt(() => p.update({ character: b, colours: { body: value } })));",
          "return { rejected: errors.every((e,i) => e.includes('update.colours.body') && e.includes(values[i])), unchanged: JSON.stringify(p.current()) === before, noDraw: calls.length === count };"
        )
      ))
      expect_true(r$rejected, info = character)
      expect_true(r$unchanged, info = character)
      expect_true(r$noDraw, info = character)
    }
  })

  it("notifies once per displayed change across a swap ticks seek and a mood face change", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const events = [], seen = [];",
          "const { p } = mount({ onChange: snapshot => { events.push({ ...snapshot }); snapshot.mood = 'mutated'; } });",
          "seen.push(p.current().mood); p.update({ character: b }); fire(0); fire(1000); fire(2000);",
          "p.setMood('happy'); sample(p,68); sample(p,69); sample(p,69); p.redraw(); p.current();",
          "const count = events.length; mascot.motion.pose(b, { mood: 'worried' }, 5); mascot.motion.frame(b, { mood: 'happy' }, 5);",
          "const pure = events.length === count, matching = JSON.stringify(events[events.length-1]) === JSON.stringify(p.current());",
          "p.destroy(); const draws = calls.length; p.seek(0); p.update({ character: a }); p.redraw(); p.gesture('nod'); p.play(); preference(true); fire(100000);",
          "return { events: events.map(s => [s.character === a.id ? 'a' : 'b',s.mood,s.swapping].join(':')).join(','), initialMood: seen[0], pure, matching,",
          " afterDestroy: events.length === count, inert: draws === calls.length, queue: queued.size };"
        )
      ))
      expect_identical(r$events, "a:idle:false,a:idle:true,b:idle:true,b:idle:false,b:happy:false", info = character)
      expect_identical(r$initialMood, "idle", info = character)
      expect_true(r$pure, info = character)
      expect_true(r$matching, info = character)
      expect_true(r$afterDestroy, info = character)
      expect_true(r$inert, info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
    }
  })

  it("deduplicates reversal notifications and emits changed snapshots on backward seek", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const events = []; const { p } = mount({ onChange: s => events.push({ ...s }) }); p.pause();",
          "p.update({ character: b }); sample(p,6); p.update({ character: a }); sample(p,6); sample(p,12);",
          "p.setMood('happy'); sample(p,20); sample(p,21); sample(p,12); sample(p,12);",
          "const result = events.map(s => [s.character === a.id ? 'a' : 'b',s.mood,s.swapping].join(':')).join(',');",
          "return { events: result, count: events.length };"
        )
      ))
      expect_identical(r$events, "a:idle:false,a:idle:true,a:idle:false,a:happy:false,a:idle:false", info = character)
      expect_equal(r$count, 5, tolerance = 1e-6, info = character)
    }
  })

  it("notifies instant and mid-swap completion under either reduced motion setting", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const results = [];",
          "for (const mode of ['forced','visitor','instant','disabled']) {",
          " media.matches = false; const events = [];",
          " const { p } = mount({ reduced: mode === 'instant' ? true : null, onChange: s => events.push({ ...s }) }); p.pause();",
          " p.update({ character: b });",
          " if (mode === 'visitor') preference(true); else if (mode === 'forced') p.update({ reduced: true }); else if (mode === 'disabled') p.update({ swap: false });",
          " const expected = mode === 'instant' ? 2 : 3;",
          " results.push(events.length === expected && events[expected-1].character === b.id && !events[expected-1].swapping);",
          " p.destroy();",
          "}",
          "return { results: results.join(',') };"
        )
      ))
      expect_identical(r$results, "true,true,true,true", info = character)
    }
  })

  it("catches a throwing host callback reports once and carries on playing", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const error = console.error; let reports = 0, callbacks = 0;",
          "console.error = (...args) => { if (args[0] === 'mascot: onChange callback failed') reports++; };",
          "try {",
          " const { p } = mount({ onChange: () => { callbacks++; throw new Error('host failed'); } });",
          " p.update({ character: b }); fire(0); fire(1000); fire(2000); fire(5000);",
          " const result = { reports, callbacks, target: p.current().character === b.id, complete: !p.current().swapping, rest: last().frame, queue: queued.size };",
          " p.destroy(); p.seek(0); result.afterDestroy = callbacks === 4; return result;",
          "} finally { console.error = error; }"
        )
      ))
      expect_equal(r$reports, 1, tolerance = 1e-6, info = character)
      expect_equal(r$callbacks, 4, tolerance = 1e-6, info = character)
      expect_true(r$target, info = character)
      expect_true(r$complete, info = character)
      expect_equal(r$rest, 150, tolerance = 1e-6, info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
      expect_true(r$afterDestroy, info = character)
    }
  })

  it("validates the callback before drawing or registering listeners", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const count = calls.length; const errors = [null,42,'bad',{}].map(onChange => attempt(() => mount({ onChange })));",
          "return { field: errors.every(e => e === 'mascot: onChange: expected a function'), noDraw: calls.length === count, listeners: listeners.size, queue: queued.size };"
        )
      ))
      expect_true(r$field, info = character)
      expect_true(r$noDraw, info = character)
      expect_equal(r$listeners, 0, tolerance = 1e-6, info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
    }
  })

  it("redraw repeats pixels at rest and in both swap phases without touching time or RAF", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const results = [], restResults = [];",
          "const { c, ctx, p } = mount();",
          "for (const n of [0,6,45,150]) {",
          " if (n === 6) p.update({ character: b }); sample(p,n);",
          " const image = c.toDataURL(), snapshot = JSON.stringify(p.current()), currentFrame = last().frame;",
          " const requests = [...queued.entries()], draws = calls.length, count = clears;",
          " p.redraw();",
          " results.push(image === c.toDataURL() && snapshot === JSON.stringify(p.current()) && last().frame === currentFrame && calls.length === draws+1 && clears === count+1",
          "  && requests.length === queued.size && requests.every(([id,fn]) => queued.get(id) === fn));",
          " if (n === 150) {",
          "  c.width = 300; c.height = 300; p.redraw(); restResults.push(image === c.toDataURL());",
          "  ctx.setTransform(.75,0,0,.75,20,10); p.redraw(); const transformed = c.toDataURL(); p.redraw();",
          "  restResults.push(transformed === c.toDataURL() && transformed !== image && queued.size === 0 && last().frame === 150);",
          " }",
          "}",
          "p.gesture('nod'); fire(10000); fire(11000);",
          "const restDeadline = last().frame; fire(20000);",
          "return { identical: results.join(','), resizedRest: restResults[0], transformedRest: restResults[1], stillDeadline: restDeadline, finalDeadline: last().frame };"
        )
      ))
      expect_identical(r$identical, "true,true,true,true", info = character)
      expect_true(r$resizedRest, info = character)
      expect_true(r$transformedRest, info = character)
      expect_equal(r$stillDeadline, 180, tolerance = 1e-6, info = character)
      expect_equal(r$finalDeadline, 300, tolerance = 1e-6, info = character)
    }
  })

  it("redraw leaves the running clock origin and paused frame untouched", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); fire(0); fire(200); const first = last().frame;",
          "p.redraw(); fire(300); const next = last().frame; p.pause(); const snapshot = JSON.stringify(p.current()), count = queued.size;",
          "p.redraw(); fire(10000);",
          "return { first, nextFrame: next, paused: last().frame, unchanged: snapshot === JSON.stringify(p.current()), queue: queued.size, pausedQueue: count };"
        )
      ))
      expect_equal(r$first, 6, tolerance = 1e-6, info = character)
      expect_equal(r$paused, 9, tolerance = 1e-6, info = character)
      expect_true(r$unchanged, info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
      expect_equal(r$pausedQueue, 0, tolerance = 1e-6, info = character)
      expect_equal(r$nextFrame, 9, tolerance = 1e-6, info = character)
    }
  })

  it("rejects malformed drawing blocks in animated and immediate updates without touching the timeline", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const mutations = [",
          " ['face.eyes',ch => { ch.face.eyes = null; }],['face.mouth',ch => { ch.face.mouth = 1; }],",
          " ['face.style.lashes.three',ch => { ch.face.style = { lashes: { three: null } }; }],",
          " ['body[0]',ch => { ch.body[0] = null; }],['small.hide',ch => { ch.small.hide = {}; }],",
          " ['anchors.face',ch => { ch.anchors.face = null; }],['accessories.bad.parts',ch => { ch.accessories = { bad: { parts: null } }; }],",
          " ['moods.idle',ch => { ch.moods.idle = null; }],['arms.paw',ch => { ch.arms = { length: 42, width: 15, paw: null, presets: { idle: { L: 1, R: 1 } } }; }],",
          " ['arms.presets.idle',ch => { ch.arms = { length: 42, width: 15, paw: { offset: 39, r: 6 }, presets: { idle: null } }; }],",
          " ['feet.tuck.rect',ch => { ch.feet = { stand: [], tuck: { x: 0, y: 0, rotate: 0, rect: null } }; }],",
          " ['feet.stand[0]',ch => { ch.feet = { stand: [null], tuck: { x: 0, y: 0, rotate: 0, rect: { x: 0,y: 0,w: 1,h: 1,r: 1 } } }; }],",
          " ['motion.gestures.wave.timeline[0].pose',ch => { ch.motion = { gestures: { wave: { timeline: [{ at: 0, pose: null }] } } }; }]",
          "];",
          "const { c, p } = mount(); p.update({ character: b }); sample(p,6); const snapshot = JSON.stringify(p.current()), image = c.toDataURL(), count = calls.length;",
          "const requests = [...queued.entries()], errors = [];",
          "for (const swap of [true,false]) for (const [field,change] of mutations) {",
          " const bad = clone(a); bad.id = 'bad'; change(bad); const e = attempt(() => p.update({ character: bad, swap }));",
          " errors.push(e.includes('mascot: update.character:') && e.includes(field));",
          "}",
          "return { rejected: errors.every(Boolean), count: errors.length, unchanged: JSON.stringify(p.current()) === snapshot, picture: c.toDataURL() === image, noDraw: count === calls.length,",
          " queue: requests.length === queued.size && requests.every(([id,fn]) => queued.get(id) === fn) };"
        )
      ))
      expect_true(r$rejected, info = character)
      expect_equal(r$count, 26, tolerance = 1e-6, info = character)
      expect_true(r$unchanged, info = character)
      expect_true(r$picture, info = character)
      expect_true(r$noDraw, info = character)
      expect_true(r$queue, info = character)
    }
  })

  it("accepts only supported well formed colour numbers including boundary values", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const valid = ['#ABC','#ab12CD','rgb(0, 255, 2.5)','rgba(255, 0, .5, 0)','rgba(1,2,3,1)','rgba(1,2,3,.25)'];",
          "const accepted = valid.map(value => attempt(() => p.update({ colours: { body: value } })) === 'no error');",
          "return { accepted: accepted.join(','), last: last().colours.body };"
        )
      ))
      expect_identical(r$accepted, "true,true,true,true,true,true", info = character)
      expect_identical(r$last, "rgba(1,2,3,.25)", info = character)
    }
  })

  it("recovers early reversals without a completion snap even when the mood resets", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const bounded = [], starts = [], finished = [];",
          "for (const mood of ['idle','happy','celebrating']) for (const n of [1,6,12,29]) {",
          " const { p } = mount({ mood }); p.pause(); p.update({ character: b }); sample(p,n);",
          " const before = mascot.drawing.resolvePose(last().description,last().pose,n); p.update({ character: a });",
          " const immediate = mascot.drawing.resolvePose(last().description,last().pose,n);",
          " starts.push(Object.keys(before).filter(k => typeof before[k] === 'number').every(k => Math.abs(before[k]-immediate[k]) < 1e-9));",
          " let previous = immediate, smooth = true;",
          " for (let f = n+1; f <= n+150; f++) {",
          "  sample(p,f); const current = mascot.drawing.resolvePose(last().description,last().pose,f);",
          "  const angle = (ch,pose,key,side) => typeof pose[key] === 'number' ? pose[key] : ch.arms.presets[pose.arms][side];",
          "  smooth = smooth && Math.abs(current.rot - previous.rot) <= .025/6 + 1e-9;",
          "  if (a.arms) smooth = smooth && Math.abs(angle(a,current,'armR','R') - angle(a,previous,'armR','R')) <= 2.15/6 + 1e-9;",
          "  previous = current;",
          " }",
          " bounded.push(smooth); finished.push(!p.current().swapping && p.current().character === a.id);",
          "}",
          "return { starts: starts.every(Boolean), bounded: bounded.every(Boolean), finished: finished.every(Boolean), count: starts.length };"
        )
      ))
      expect_true(r$starts, info = character)
      expect_true(r$bounded, info = character)
      expect_true(r$finished, info = character)
      expect_equal(r$count, 12, tolerance = 1e-6, info = character)
    }
  })

  it("keeps the wave speed on retargets close to either phase boundary", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const starts = [], waves = [], oneDraw = [];",
          "const numeric = (ch,p,n) => { const value = mascot.drawing.resolvePose(ch,p,n); if (ch.arms) for (const [key,side] of [['armL','L'],['armR','R']]) if (value[key] === null) value[key] = ch.arms.presets[value.arms][side]; return value; };",
          "for (const n of [1,6,12,28,29,30,31,32,45,58,59]) {",
          " const { p } = mount(); p.pause(); p.update({ character: b });",
          " const original = sample(p,n+1), predicted = numeric(last().description,original.pose,n+1); const before = sample(p,n), initial = numeric(last().description,before.pose,n);",
          " const c = clone(a); c.id = 'third'; p.update({ character: c });",
          " const after = numeric(last().description,last().pose,n);",
          " starts.push(before.opacity === 0 || Object.keys(initial).filter(k => typeof initial[k] === 'number').every(k => Math.abs(initial[k]-after[k]) < 1e-9));",
          " const next = sample(p,n+1), actual = numeric(last().description,next.pose,n+1);",
          " waves.push(next.character !== before.character || (Math.abs(actual.rot-predicted.rot) < 1e-9 &&",
          "   (!last().description.arms || Math.abs(actual.armR-predicted.armR) < 1e-9)));",
          " oneDraw.push(next.draws === 1);",
          "}",
          "return { starts: starts.every(Boolean), waves: waves.every(Boolean), oneDraw: oneDraw.every(Boolean), count: starts.length };"
        )
      ))
      expect_true(r$starts, info = character)
      expect_true(r$waves, info = character)
      expect_true(r$oneDraw, info = character)
      expect_equal(r$count, 11, tolerance = 1e-6, info = character)
    }
  })

  it("caches successful and failed description checks per immutable object", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const { p } = mount(); p.pause(); const good = clone(b); good.id = 'cached'; let goodReads = 0;",
          "const hide = good.small.hide; Object.defineProperty(good.small,'hide',{ get: () => { goodReads++; return hide; } });",
          "p.update({ character: good }); const reads = goodReads; sample(p,60); p.update({ character: good }); mascot.validateCharacter(good);",
          "const bad = clone(a); bad.id = 'bad'; let badReads = 0; Object.defineProperty(bad.face,'eyes',{ get: () => { badReads++; return null; } });",
          "attempt(() => p.update({ character: bad })); const failedReads = badReads; attempt(() => p.update({ character: bad, swap: false })); mascot.validateCharacter(bad);",
          "return { good: reads > 0 && reads === goodReads, bad: failedReads > 0 && failedReads === badReads };"
        )
      ))
      expect_true(r$good, info = character)
      expect_true(r$bad, info = character)
    }
  })

  it("allows callback actions to destroy or update a player without stale notifications or RAF", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "let p, callsBack = 0; const events = []; const mounted = mount({ onChange: s => {",
          " callsBack++; events.push([s.character,s.swapping]);",
          " if (p && s.swapping && s.character === a.id) p.update({ reduced: true });",
          " else if (p && s.character === b.id && !s.swapping) p.destroy();",
          "} }); p = mounted.p; p.update({ character: b }); fire(0); p.redraw();",
          "return { callbacks: callsBack, events: events.map(s => [s[0] === a.id ? 'a' : 'b',s[1]].join(':')).join(','), queue: queued.size, listeners: listeners.size, final: p.current().character === b.id };"
        )
      ))
      expect_equal(r$callbacks, 3, tolerance = 1e-6, info = character)
      expect_identical(r$events, "a:false,a:true,b:false", info = character)
      expect_equal(r$queue, 0, tolerance = 1e-6, info = character)
      expect_equal(r$listeners, 0, tolerance = 1e-6, info = character)
      expect_true(r$final, info = character)
    }
  })

  it("rejects geometry that would throw from hidden drawing branches and the default pose", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const mutations = [",
          " ['body[0].fill',ch => { ch.body = [{ shape: 'rect', x: 0,y: 0,w: 1,h: 1 }]; }],",
          " ['body[0].r',ch => { ch.body = [{ shape: 'circle', x: 0,y: 0,r: -1, fill: 'body' }]; }],",
          " ['body[0]',ch => { ch.body = new Array(1); }],",
          " ['face.style.open.ew',ch => { ch.face.style = { open: { ew: .5 } }; }],",
          " ['face.style.closed.r',ch => { ch.face.style = { closed: { r: -1 } }; }],",
          " ['face.blush.rx',ch => { ch.face.blush = { x: 0,y: 0,rx: -1,ry: 1,alpha: .2,strongAlpha: .3 }; ch.colours.blush = '#fff'; ch.colours.blushStrong = '#fff'; }],",
          " ['motion.gestures.wave.timeline',ch => { ch.motion = { gestures: { wave: { timeline: [] } } }; }],",
          " ['pose.arms',ch => { ch.arms = { length: 42,width: 15,paw: { offset: 39,r: 6 },presets: { custom: { L: 1,R: 1 } } }; ch.pose = {}; ch.moods = { idle: {} }; ch.colours.limb = '#fff'; ch.colours.sleeve = '#fff'; }]",
          "];",
          "const { p } = mount(); p.pause(); const snapshot = JSON.stringify(p.current()), count = calls.length;",
          "const results = [];",
          "for (const [field,change] of mutations) {",
          " const bad = clone(a); bad.id = 'bad'; change(bad); const error = attempt(() => p.update({ character: bad }));",
          " results.push(error.startsWith('mascot: update.character:') && error.includes(field));",
          "}",
          "return { results: results.join(','), unchanged: JSON.stringify(p.current()) === snapshot, noDraw: calls.length === count };"
        )
      ))
      expect_identical(r$results, "true,true,true,true,true,true,true,true", info = character)
      expect_true(r$unchanged, info = character)
      expect_true(r$noDraw, info = character)
    }
  })

  it("preserves numeric recovery when a third character interrupts a reversal", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      r <- js(swap_js(
        character,
        paste(
          "const starts = [], smooth = [];",
          "for (const mood of ['idle','happy','celebrating']) for (const n of [1,6,12]) {",
          " const { p } = mount({ mood }); p.pause(); p.update({ character: b }); sample(p,n); p.update({ character: a }); sample(p,n+1);",
          " const before = mascot.drawing.resolvePose(last().description,last().pose,n+1), third = clone(b); third.id = 'third';",
          " p.update({ character: third }); const after = mascot.drawing.resolvePose(last().description,last().pose,n+1);",
          " starts.push(Object.keys(before).filter(k => typeof before[k] === 'number').every(k => Math.abs(before[k]-after[k]) < 1e-9));",
          " const next = sample(p,n+2); smooth.push(next.character !== a.id || Math.abs(next.pose.rot - before.rot) <= .025/6 + 1e-9);",
          "}",
          "return { starts: starts.every(Boolean), smooth: smooth.every(Boolean), count: starts.length };"
        )
      ))
      expect_true(r$starts, info = character)
      expect_true(r$smooth, info = character)
      expect_equal(r$count, 9, tolerance = 1e-6, info = character)
    }
  })
})
