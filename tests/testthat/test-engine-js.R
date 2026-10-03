# The drawing engine in inst/www/ has no R file of its own: these tests draw with it in headless Chrome.

skip_without_chrome <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("chromote")
  testthat::skip_if_not_installed("withr")
  testthat::skip_if(is.null(chromote::find_chrome()), "no Chrome or Chromium found")
}

# Opens a blank page with the engine's files loaded and returns a function that evaluates JavaScript there.
local_engine_page <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  www <- system.file("www", package = "mascot")
  scripts <- file.path(www, c("mascot.js", "mascot-draw.js"))
  tessa <- system.file("characters", "tessa.json", package = "mascot")
  blob <- testthat::test_path("fixtures", "characters", "blob.json")
  page <- file.path(dir, "page.html")
  writeLines(
    c(
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>engine</title></head><body>",
      "<script type=\"application/json\" data-mascot-character=\"tessa\">",
      readLines(tessa, encoding = "UTF-8"),
      "</script>",
      "<script type=\"application/json\" data-mascot-character=\"blob\">",
      readLines(blob, encoding = "UTF-8"),
      "</script>",
      sprintf("<script src=\"file://%s\"></script>", normalizePath(scripts, winslash = "/")),
      "</body></html>"
    ),
    page
  )
  session <- chromote::ChromoteSession$new()
  withr::defer(session$close(), envir = env)
  loaded <- session$Page$loadEventFired(wait_ = FALSE)
  session$Page$navigate(paste0("file://", normalizePath(page, winslash = "/")), wait_ = FALSE)
  session$wait_for(loaded)
  function(js) session$Runtime$evaluate(js)$result$value
}

# Draws a character from the page on a new canvas and returns the picture as a PNG data URL.
draw_js <- function(pose, frame = 0, character = "tessa") {
  sprintf(
    paste(
      "(() => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "window.mascot.draw(c.getContext('2d'), window.mascot.readCharacter('%s'), 150, 280, %s, %d);",
      "return c.toDataURL(); })()"
    ),
    character,
    pose,
    frame
  )
}

# Runs `code` in the page and returns the message of the error it throws (or "no error").
error_js <- function(code) {
  sprintf(
    "(() => { const ch = window.mascot.readCharacter('tessa'); try { %s; } catch (e) { return e.message; } return 'no error'; })()",
    code
  )
}

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
      "c.width = 300; c.height = 300; mascot.draw(c.getContext('2d'), ch, 150, 280, {}, 0, overrides);",
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
        "delete ch.anchors.sparkle; delete ch.anchors.sweat;",
        "if (mascot.validateCharacter(ch).length) throw new Error(mascot.validateCharacter(ch).join('; '));",
        "for (const mood of Object.keys(ch.moods))",
        "mascot.draw(document.createElement('canvas').getContext('2d'), ch, 150, 280, { mood })"
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
      "mascot.draw(c.getContext('2d'), ch, 150, 280, { detail }); return c.toDataURL(); };",
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
      "mascot.draw(c.getContext('2d'), ch, 150, 280); return c.toDataURL(); };",
      "const placed = draw(); ch.anchors.face.x = 0; ch.anchors.face.y = 0;",
      "const centred = draw(); ch.anchors.face.scale = 1;",
      "return placed !== centred && centred !== draw(); })()"
    )))
  })

  it("uses Tessa's face defaults when the frame and style are omitted", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa');",
      "const draw = () => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "mascot.draw(c.getContext('2d'), ch, 150, 280); return c.toDataURL(); };",
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
      "return tests.every(([pose, style]) => { const ch = mascot.readCharacter('tessa');",
      "const draw = () => { const c = document.createElement('canvas'); c.width = 300; c.height = 300;",
      "mascot.draw(c.getContext('2d'), ch, 150, 280, pose); return c.toDataURL(); };",
      "const before = draw(); ch.face.style = style;",
      "return mascot.validateCharacter(ch).length === 0 && before !== draw(); }); })()"
    )))
  })

  it("returns attachment points in canvas coordinates and moves the head with lift", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa');",
      "const at = mascot.drawing.anchors(ch, { x: 150, baseY: 280 });",
      "const lifted = mascot.drawing.anchors(ch, { x: 150, baseY: 280, lift: 10 });",
      "return ['head', 'face', 'body', 'shoulders', 'feet', 'hands'].every(name => at[name]) &&",
      "at.face.x === 150 && at.face.y === 176 && lifted.head.y === at.head.y - 10 &&",
      "at.shoulders.L.x < at.shoulders.R.x && at.feet.L.x < at.feet.R.x &&",
      "Number.isFinite(at.hands.L.x) && Number.isFinite(at.hands.R.y); })()"
    )))
  })

  it("keeps attachment points aligned through rotation, squash, flip and arm jitter", {
    skip_without_chrome()
    js <- local_engine_page()
    expect_true(js(paste(
      "(() => { const ch = mascot.readCharacter('tessa');",
      "const pose = { x: 150, baseY: 280, mood: 'happy', rot: 0.2, sx: 1.2, sy: 0.8,",
      "scale: 0.7, flip: -1, lift: 4, armJitter: 0.3, frame: 5 };",
      "const at = mascot.drawing.anchors(ch, pose);",
      "const point = (x, y) => ({ x: 150 - (x * Math.cos(0.2) - y * Math.sin(0.2)) * 0.7 * 1.2,",
      "y: 276 + (x * Math.sin(0.2) + y * Math.cos(0.2) - ch.centreHeight) * 0.7 * 0.8 });",
      "const head = point(ch.anchors.head.x, ch.anchors.head.y);",
      "const angle = ch.arms.presets.wave.R - Math.sin(5 / 30 * 26) * 0.3;",
      "const hand = point(ch.anchors.shoulders.x + Math.cos(angle) * ch.arms.paw.offset,",
      "ch.anchors.shoulders.y + Math.sin(angle) * ch.arms.paw.offset);",
      "return Math.abs(at.head.x - head.x) < 1e-10 && Math.abs(at.head.y - head.y) < 1e-10 &&",
      "Math.abs(at.hands.R.x - hand.x) < 1e-10 && Math.abs(at.hands.R.y - hand.y) < 1e-10; })()"
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
      "face.style.open.ew" = "ch.face.style = { open: { ew: 'big' } }",
      "anchors.face.scale" = "ch.anchors.face.scale = -1",
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
          "try { mascot.draw(null, ch, 0, 0); } catch (e) { return e.message === 'mascot: ' + errors[0]; }",
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
    expect_match(js(error_js(sprintf("window.mascot.draw(%s, 'tessa', 0, 0)", ctx))), "needs a character description")
    expect_match(js(error_js(sprintf("window.mascot.draw(%s, ch, 0, 0, { mood: 'sleepy' })", ctx))), "no mood 'sleepy'")
    expect_match(
      js(error_js(sprintf("window.mascot.draw(%s, ch, 0, 0, { accessory: 'hat' })", ctx))),
      "no accessory 'hat'"
    )
    expect_match(js(error_js("window.mascot.readCharacter('nobody')")), "no description of the character 'nobody'")
  })

  it("draws SVG-style paths and refuses commands it does not support", {
    skip_without_chrome()
    js <- local_engine_page()
    ctx <- "document.createElement('canvas').getContext('2d')"
    expect_identical(js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 L10 0 10 10 Z')", ctx))), "no error")
    expect_match(
      js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 a5 5 0 0 1 10 0')", ctx))),
      "unsupported path command 'a'"
    )
    expect_match(js(error_js(sprintf("window.mascot.drawing.svgPath(%s, 'M0 0 L10')", ctx))), "'L' needs 2 numbers")
  })
})
