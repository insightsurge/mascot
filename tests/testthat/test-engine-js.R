# The drawing engine in inst/www/ has no R file of its own.

describe("the drawing engine (inst/www)", {
  it("loads once and offers mascot.draw() and mascot.readCharacter()", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_identical(js("typeof window.mascot.draw"), "function")
    expect_identical(js("window.mascot.readCharacter('tessa').id"), "tessa")
  })

  it("draws the same pixels for the same pose and frame", {
    skip_without_chrome()
    js <- local_engine_page()
    pose <- "{ eyes: 'happy', mouth: 'grin', arms: 'up', sparkle: true }"
    first <- js(draw_js(pose, frame = 7))
    expect_true(startsWith(first, "data:image/png"))
    expect_identical(js(draw_js(pose, frame = 7)), first)
  })

  it("draws different pixels for a different pose or frame", {
    skip_without_chrome()
    js <- local_engine_page()
    pose <- "{ sparkle: true }"
    expect_false(identical(js(draw_js(pose)), js(draw_js("{ eyes: 'happy' }"))))
    expect_false(identical(js(draw_js(pose, frame = 0)), js(draw_js(pose, frame = 7))))
  })

  it("draws both characters' five moods differently and repeats each frame exactly", {
    skip_without_chrome()
    js <- local_engine_page()
    moods <- c("idle", "thinking", "happy", "worried", "celebrating")
    pictures <- list()
    for (character in c("tessa", "blob")) {
      expect_identical(
        js(sprintf("Object.keys(window.mascot.readCharacter('%s').moods).join(',')", character)),
        paste(moods, collapse = ",")
      )
      pictures[[character]] <- vapply(
        moods,
        function(m) {
          code <- draw_js(sprintf("{ mood: '%s' }", m), frame = 7, character = character)
          first <- js(code)
          expect_true(startsWith(first, "data:image/png"))
          expect_identical(js(code), first)
          first
        },
        character(1)
      )
      expect_length(unique(pictures[[character]]), 5)
    }
    for (m in moods) {
      expect_false(identical(pictures$tessa[[m]], pictures$blob[[m]]))
    }
  })

  it("applies colours for one draw without changing or sharing either palette", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const tessa = mascot.readCharacter('tessa'), blob = mascot.readCharacter('blob');",
      "const savedTessa = JSON.stringify(tessa), savedBlob = JSON.stringify(blob);",
      "const colours = Object.freeze({ body: '#ff00ff', feature: '#0000ff' });",
      "Object.freeze(tessa.colours); Object.freeze(blob.colours);",
      "const draw = (ch, overrides) => { const c = document.createElement('canvas');",
      "c.width = 300; c.height = 300; mascot.draw(c.getContext('2d'), ch, { x: 150, baseY: 280, colours: overrides });",
      "return c.toDataURL(); };",
      "const normal = draw(tessa), blobBefore = draw(blob); const changed = draw(tessa, colours);",
      "return normal !== changed && draw(tessa) === normal && draw(blob) === blobBefore &&",
      "JSON.stringify(tessa) === savedTessa && JSON.stringify(blob) === savedBlob; })()"
    )))
  })

  it("skips optional parts even when a mood asks for them", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_identical(
      js(error_js(paste(
        "delete ch.arms; delete ch.feet; delete ch.shadow; delete ch.face.blush; delete ch.accessories;",
        "delete ch.anchors.sparkle; delete ch.anchors.sweat; delete ch.pose;",
        "for (const p of Object.values(ch.moods)) { delete p.arms; delete p.accessory; }",
        "if (mascot.validateCharacter(ch).length) throw new Error(mascot.validateCharacter(ch).join('; '));",
        "for (const mood of Object.keys(ch.moods))",
        "mascot.draw(document.createElement('canvas').getContext('2d'), ch, { x: 150, baseY: 280, pose: { mood } })"
      ))),
      "no error"
    )
  })

  it("simplifies Tessa and skips parts marked for full detail", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_false(identical(js(draw_js("{ detail: 'simple' }")), js(draw_js("{ detail: 'full' }"))))
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('blob');",
      "const draw = detail => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "mascot.draw(c.getContext('2d'), ch, { x: 150, baseY: 280, pose: { detail } }); return c.toDataURL(); };",
      "const before = draw('simple'), fullBefore = draw('full');",
      "ch.body.push({ shape: 'circle', x: -40, y: 10, r: 10, fill: 'feature', detail: 'full' });",
      "return draw('simple') === before && draw('full') !== fullBefore; })()"
    )))
  })

  it("places and scales the face independently of the body", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('blob');",
      "const draw = () => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "mascot.draw(c.getContext('2d'), ch, { x: 150, baseY: 280 }); return c.toDataURL(); };",
      "const placed = draw(); ch.anchors.face.x = 0; ch.anchors.face.y = 0;",
      "const centred = draw(); ch.anchors.face.scale = 1;",
      "return placed !== centred && centred !== draw(); })()"
    )))
  })

  it("uses Tessa's face defaults when the frame and style are omitted", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { let ch = mascot.readCharacter('tessa');",
      "const draw = () => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "mascot.draw(c.getContext('2d'), ch, { x: 150, baseY: 280 }); return c.toDataURL(); };",
      "const before = draw(); delete ch.anchors.face; delete ch.face.style;",
      "const at = mascot.drawing.anchors(ch, { x: 150, baseY: 280 });",
      "return before === draw() && at.face.x === 150 && at.face.y === 176; })()"
    )))
  })

  it("accepts partial face styles for eyes, pupils, lashes and brows", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const tests = [",
      "[{ eyes: 'open' }, { open: { ew: 21, eh: 24, pr: 7 } }],",
      "[{ eyes: 'wide' }, { wide: { ew: 23 } }],",
      "[{ eyes: 'worried' }, { worried: { pupilY: 3 } }],",
      "[{ eyes: 'focused' }, { focused: { lid: 0.65 } }],",
      "[{ eyes: 'happy' }, { happy: { r: 20 } }],",
      "[{ eyes: 'blink' }, { closed: { r: 20 } }],",
      "[{ look: 1 }, { pupil: { lookX: 2 } }],",
      "[{}, { lashes: { three: [-15], length: 12 } }],",
      "[{ brows: 'raised' }, { brows: { offset: 35 } }]];",
      "return tests.every(([pose, style]) => { let ch = mascot.readCharacter('tessa');",
      "const draw = () => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "mascot.draw(c.getContext('2d'), ch, { x: 150, baseY: 280, pose }); return c.toDataURL(); };",
      "const before = draw(); ch = JSON.parse(JSON.stringify(ch)); ch.face.style = style;",
      "return mascot.validateCharacter(ch).length === 0 && before !== draw(); }); })()"
    )))
  })

  it("returns attachment points in canvas coordinates and moves the hair anchor with lift", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa');",
      "const at = mascot.drawing.anchors(ch, { x: 150, baseY: 280 });",
      "const lifted = mascot.drawing.anchors(ch, { x: 150, baseY: 280, pose: { lift: 10 } });",
      "return ['hair', 'face', 'waist', 'shoulders', 'feet', 'hands'].every(name => at[name]) &&",
      "at.face.x === 150 && at.face.y === 176 && lifted.hair.y === at.hair.y - 10 &&",
      "at.shoulders.L.x < at.shoulders.R.x && at.feet.L.x < at.feet.R.x &&",
      "Number.isFinite(at.hands.L.x) && Number.isFinite(at.hands.R.y); })()"
    )))
  })

  it("returns known attachment points with rotation, scale and reflection", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa');",
      "const a = mascot.drawing.anchors(ch, { x: 150, baseY: 280 });",
      "const b = mascot.drawing.anchors(ch, { x: 150, baseY: 280, pose: { rot: Math.PI / 2, scale: 2, flip: -1 } });",
      "return a.feet.L.x === 127 && a.feet.L.y === 280 && a.hair.rotate === -0.5 && a.hair.scale === 1.2 &&",
      "Math.abs(b.feet.R.x - 358) < 1e-10 && Math.abs(b.feet.R.y - 118) < 1e-10 &&",
      "Math.abs(b.feet.R.rotate - Math.PI / 2) < 1e-10 && b.hair.scale === 2.4 && b.hair.sx === -1; })()"
    )))
  })

  it("names invalid fields and refuses the first validation error before drawing", {
    skip_without_chrome()
    js <- local_engine_page()
    for (character in c("tessa", "blob")) {
      expect_identical(
        js(sprintf("mascot.validateCharacter(mascot.readCharacter('%s')).length", character)),
        0L
      )
    }
    mistakes <- c(
      "colours.body" = "delete ch.colours.body",
      "body[2].shape" = "ch.body[2].shape = 'star'",
      "moods.happy.arms" = "ch.moods.happy.arms = 'fly'",
      "anchors.toString" = "ch.anchors.toString = { x: 0, y: 0 }",
      "body[2].d" = "ch.body[2].d = 'M0 0 L'"
    )
    for (field in names(mistakes)) {
      expect_match(
        js(sprintf(
          "(() => { const ch = mascot.readCharacter('tessa'); %s; return mascot.validateCharacter(ch).join('; '); })()",
          mistakes[[field]]
        )),
        field,
        fixed = TRUE
      )
      expect_true(js(sprintf(
        paste(
          "(() => { const ch = mascot.readCharacter('tessa'); %s; const errors = mascot.validateCharacter(ch);",
          "try { mascot.draw(null, ch, { x: 0, baseY: 0 }); } catch (e) { return e.message === 'mascot: ' + errors[0]; }",
          "return false; })()"
        ),
        mistakes[[field]]
      )))
    }
  })

  it("draws a mood the same as the pose it stands for", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_identical(
      js(draw_js("{ mood: 'worried' }")),
      js(draw_js("{ eyes: 'worried', mouth: 'flat', brows: 'worried', sweat: 0.35, arms: 'idle' }"))
    )
  })

  it("names what is missing when a character, mood, accessory or page element is wrong", {
    skip_without_chrome()
    js <- local_engine_page()
    ctx <- "document.createElement('canvas').getContext('2d')"
    expect_match(
      js(error_js(sprintf("window.mascot.draw(%s, 'tessa', { x: 0, baseY: 0 })", ctx))),
      "needs a character description"
    )
    expect_match(
      js(error_js(sprintf("window.mascot.draw(%s, ch, { pose: { mood: 'sleepy' } })", ctx))),
      "no mood 'sleepy'"
    )
    expect_match(
      js(error_js(sprintf("window.mascot.draw(%s, ch, { pose: { accessory: 'hat' } })", ctx))),
      "no accessory 'hat'"
    )
    expect_match(js(error_js("window.mascot.readCharacter('nobody')")), "no description of the character 'nobody'")
  })

  it("draws SVG-style paths and refuses commands it does not support", {
    skip_without_chrome()
    js <- local_engine_page()
    ctx <- "document.createElement('canvas').getContext('2d')"
    expect_identical(
      js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M+0 +0 L+10 0 +1e+1 +10 z')", ctx))),
      "no error"
    )
    expect_match(
      js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 a5 5 0 0 1 10 0')", ctx))),
      "unsupported path command 'a'"
    )
    expect_match(js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 L10')", ctx))), "'L' needs 2 numbers")
  })
  it("refuses inherited pose names and unknown colour roles", {
    skip_without_chrome()
    js <- local_engine_page()
    for (field in c("arms", "accessory", "mood")) {
      expect_match(js(error_js(sprintf("mascot.draw(null, ch, { pose: { %s: 'toString' } })", field))), field)
    }
    expect_match(js(error_js("mascot.draw(null, ch, { colours: { bodyy: '#fff' } })")), "bodyy")
  })

  it("accepts theme colour forms and multiplies existing alpha", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa'), g = document.createElement('canvas').getContext('2d');",
      "for (const value of ['#abc', '#aabbcc', 'rgb(170, 187, 204)', 'rgba(170, 187, 204, 0.5)'])",
      "mascot.draw(g, ch, { colours: { body: value, blush: value } });",
      "return mascot.drawing.rgba('rgba(170, 187, 204, 0.5)', 0.4) === 'rgba(170, 187, 204, 0.2)' &&",
      "mascot.drawing.rgba('#abc', 0.4) === mascot.drawing.rgba('rgb(170, 187, 204)', 0.4); })()"
    )))
  })

  it("draws several accessories with local colours and refuses slot clashes and missing anchors", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa');",
      "ch.accessories.badge = { anchor: 'chest', slot: 'badge', colours: { accessory: '#f00' },",
      "parts: [{ shape: 'circle', x: 0, y: 0, r: 8, fill: 'accessory' }] };",
      "const saved = JSON.stringify(ch); const c = document.createElement('canvas'), g = c.getContext('2d');",
      "const fills = [], fill = g.fill.bind(g); g.fill = () => { fills.push(g.fillStyle); fill(); };",
      "mascot.draw(g, ch, { pose: { accessory: ['bow', 'badge'] } });",
      "return JSON.stringify(ch) === saved && fills.some(c => c === '#f00' || c === '#ff0000') && fills.includes(ch.colours.accessory); })()"
    )))
    expect_match(js(error_js("mascot.draw(null, ch, { pose: { accessory: ['bow', 'clip'] } })")), "slot 'hair'")
    expect_match(
      js(error_js("delete ch.anchors.hair; mascot.draw(null, ch)")),
      "accessory 'bow': missing anchor 'hair'",
      fixed = TRUE
    )
    # A complete rect (the structure check runs first), so the only fault left is its stroke.
    expect_match(
      js(error_js(
        "ch.body[0] = { shape: 'rect', x: 0, y: 0, w: 10, h: 10, fill: 'body', stroke: 'outline' }; mascot.draw(null, ch)"
      )),
      "rect is fill-only",
      fixed = TRUE
    )
  })

  it("keeps every simple stroke at least the description's minimum screen width", {
    skip_without_chrome()
    js <- local_engine_page()
    # Chrome keeps the canvas transform at lower precision than JavaScript numbers: allow 0.0001 px.
    expect_true(js(paste(
      "(() => { return ['tessa', 'blob'].every(name => [24, 32, 48].every(size => {",
      "const ch = mascot.readCharacter(name), g = document.createElement('canvas').getContext('2d');",
      "g.scale(0.75, 1.25); const widths = []; const original = g.stroke.bind(g);",
      "g.stroke = () => { const m = g.getTransform();",
      "const sum = m.a*m.a + m.b*m.b + m.c*m.c + m.d*m.d;",
      "const largest = Math.sqrt((sum + Math.sqrt(Math.max(0, sum*sum - 4*(m.a*m.d-m.b*m.c)**2))) / 2);",
      "widths.push(g.lineWidth * Math.abs(m.a*m.d-m.b*m.c) / largest); original(); };",
      "mascot.draw(g, ch, { pose: { detail: 'simple', scale: size / 220, rot: 0.2 } });",
      "return widths.length > 0 && widths.every(w => w >= ch.small.minLineWidth - 1e-4); })); })()"
    )))
  })

  it("checks a description and merges its face style only on first use", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa'); let reads = 0; const style = ch.face.style;",
      "Object.defineProperty(ch.face, 'style', { get() { reads++; return style; } });",
      "const g = document.createElement('canvas').getContext('2d'); mascot.draw(g, ch); const first = reads;",
      "mascot.draw(g, ch, { frame: 7 }); mascot.drawing.anchors(ch);",
      "return first > 0 && reads === first; })()"
    )))
  })

  it("sets stroke styles independently of the face frame and restores caller state", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const record = frame => { const ch = mascot.readCharacter('tessa'); ch.anchors.face = frame;",
      "const g = document.createElement('canvas').getContext('2d'), styles = [], original = g.stroke.bind(g);",
      "g.lineCap = 'square'; g.lineJoin = 'bevel';",
      "g.stroke = () => { styles.push([g.lineCap, g.lineJoin]); original(); }; mascot.draw(g, ch);",
      "if (g.lineCap !== 'square' || g.lineJoin !== 'bevel') throw new Error('caller state changed');",
      "return JSON.stringify(styles); };",
      "return record({ x: 0, y: 0, scale: 1 }) === record({ x: 8, y: -4, scale: 0.7 }); })()"
    )))
  })
})
