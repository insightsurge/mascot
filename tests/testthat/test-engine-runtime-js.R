# I1 "the join": a checked format-v1 character mounts and runs in the real host. Characters are internal helper objects
# (see helper-runtime.R); every page loads the packaged scripts in the dependency's order, with no adapter switch.

# The fixtures are built when a test first uses them, so a run without Chrome (which skips every test here) pays nothing.
delayedAssign(
  "alpha",
  runtime_character(runtime_data(edit = function(recipe) {
    recipe$moods$thinking$status <- "Reading the logs"
    recipe
  }))
)
delayedAssign("other", runtime_character(runtime_other()))
delayedAssign("classic", runtime_character(runtime_data("tessa_two", "Tessa Two", base = "tessa")))
delayedAssign(
  "mirror",
  runtime_character(runtime_data(
    "tessa_mirror",
    "Tessa Mirror",
    function(recipe) {
      recipe$moods$idle$channels <- list(`root.flip` = -1)
      recipe
    },
    base = "tessa"
  ))
)
delayedAssign("faceless", runtime_faceless())
delayedAssign("everyone", list(alpha, other, classic, mirror, faceless))

# Spies on the format-v1 modules, installed before the host mounts. Each records what it was asked to draw.
spies_js <- r"(
window.frames = []; window.faceCalls = []; window.effectCalls = []; window.geometryCalls = [];
(() => {
  const wrap = (object, name, record) => {
    const original = object[name];
    return { ...object, [name]: (...a) => { record(...a); return original(...a); } };
  };
  mascot.parts = wrap(mascot.parts, 'frame', (compiled, channels, band) => frames.push({
    id: compiled.source.parts[0].id === 'ground_shadow' ? 'shadow' : compiled.source.id,
    channels: { ...channels }, band }));
  mascot.faces = wrap(mascot.faces, 'draw', (ctx, compiled, state, controls, colours) =>
    faceCalls.push({ controls: { ...controls }, colours: { ...colours }, band: state.band }));
  mascot.faces = wrap(mascot.faces, 'effects', (ctx, compiled, state, controls, colours, options) =>
    effectCalls.push({ controls: { ...controls }, options: { ...options } }));
  mascot.geometry = wrap(mascot.geometry, 'draw', (ctx, compiled, state, colours) => geometryCalls.push({
    id: compiled.source.parts[0].id === 'ground_shadow' ? 'shadow' : compiled.source.id,
    band: state.band, hidden: [...state.hidden], colours: { ...colours } }));
})();
)"

# The channel values of the last frame the character itself (not its ground shadow) was given.
last_channels_js <- "frames.filter((f) => f.id !== 'shadow').at(-1).channels"

# A paused player on a standalone canvas that shows frame n after `controller.seek(n)`.
page_with <- function(
  characters = everyone,
  tags = list(mascot("a", character = alpha, motion = FALSE, placement = "inline")),
  reduced = FALSE,
  before_mount = "",
  ...,
  env = parent.frame()
) {
  js <- local_runtime_page(
    tags = tags,
    characters = characters,
    reduced = reduced,
    before_mount = paste(spies_js, before_mount),
    ...,
    env = env
  )
  install_runtime_helpers(js)
  js
}

describe("I1 format-v1 dispatch", {
  it("draws and moves a format-v1 character through the format-v1 modules, with no adapter switch", {
    js <- page_with()
    js("T.frames(3)")
    result <- js(
      "({frame: frames.length, geometry: geometryCalls.length, faces: faceCalls.length,
        internal: typeof mascot.internal, adapter: typeof mascot.tessaAdapter, runtime: typeof mascot.runtime,
        shown: document.getElementById('a').dataset.shownCharacter,
        ink: T.picture(document.querySelector('#a canvas')).ink})"
    )
    expect_gt(result$frame, 0)
    expect_gt(result$geometry, 0)
    expect_gt(result$faces, 0)
    expect_identical(result$internal, "undefined")
    expect_identical(result$adapter, "undefined")
    expect_identical(result$runtime, "object")
    expect_identical(result$shown, "alpha_two")
    expect_gt(result$ink, 1000)
  })

  it("never reaches the legacy drawing code for a format-v1 character", {
    js <- local_runtime_page(
      tags = list(mascot("a", character = alpha, motion = FALSE, placement = "inline")),
      characters = list(alpha),
      before_mount = "window.legacyCalls = 0; const original = mascot.drawing.character;
        mascot.drawing.character = (...a) => { legacyCalls++; return original(...a); };"
    )
    js("T = {frames: async (n) => { for (let i = 0; i < n; i++) await new Promise(requestAnimationFrame); }}")
    js("T.frames(3)")
    expect_equal(js("legacyCalls"), 0)
  })

  it("draws default Tessa through format-v1 runtime modules", {
    legacy <- local_host_page(size = 160)
    install_runtime_helpers(legacy)
    legacy("T.frames(3)")
    expected <- legacy("T.picture(document.querySelector('#a canvas'))")
    js <- local_runtime_page(
      tags = list(mascot("a", size = 160, placement = "inline")),
      before_mount = spies_js
    )
    install_runtime_helpers(js)
    js("T.frames(3)")
    result <- js(
      "({picture: T.picture(document.querySelector('#a canvas')), frames: frames.length,
      geometry: geometryCalls.length, faces: faceCalls.length, drawn: typeof mascot.drawing.character})"
    )
    expect_gt(expected$ink, 1000)
    expect_gt(result$picture$ink, 1000)
    expect_gt(result$frames, 0)
    expect_gt(result$geometry, 0)
    expect_gt(result$faces, 0)
  })

  it("rejects a format-v1 character in a legacy player, and a legacy character in a format-v1 player, before any change", {
    blob_json <- paste(
      readLines(testthat::test_path("fixtures", "characters", "blob.json"), encoding = "UTF-8"),
      collapse = "\n"
    )
    js <- page_with(
      tags = list(
        mascot("a", character = alpha, motion = FALSE, placement = "inline"),
        shiny::tags$div(
          id = "b",
          `data-mascot` = "",
          `data-character` = "blob",
          shiny::tags$script(
            type = "application/json",
            `data-mascot-character` = "blob",
            shiny::HTML(blob_json)
          ),
          shiny::tags$canvas(class = "mascot-canvas"),
          shiny::tags$span(class = "mascot-status", "Idle")
        )
      )
    )
    result <- js(
      "(() => {
        const legacy = mascot.readCharacter('blob', document.getElementById('b'));
        const plain = mascot.mount(T.canvas(), legacy, { x: 150, baseY: 270, reduced: false });
        plain.pause();
        const v1 = T.player('alpha_two');
        const errors = {};
        try { plain.update({ character: T.load('alpha_two') }); } catch (e) { errors.legacy = e.message; }
        try { v1.controller.update({ character: legacy }); } catch (e) { errors.v1 = e.message; }
        return { errors, legacy: plain.current(), v1: v1.controller.current() };
      })()"
    )
    expect_match(result$errors$legacy, "format-v1 character cannot replace a legacy character")
    expect_match(result$errors$v1, "legacy character cannot replace a format-v1 character")
    expect_identical(result$legacy$character, "blob")
    expect_false(result$legacy$swapping)
    expect_identical(result$v1$character, "alpha_two")
    expect_false(result$v1$swapping)
  })
})

describe("I1 status, label and theme follow the shown character", {
  it("shows the status of the shown mood, never the title-cased id, and names the character in every label", {
    js <- page_with(reduced = TRUE)
    r <- js(
      r"(
      (() => {
        const el = document.getElementById('a');
        const receive = (patch) => mascot.host.receive({ id: 'a', patch });
        const read = () => ({ status: el.querySelector('.mascot-status').textContent,
          label: el.querySelector('canvas').getAttribute('aria-label'),
          restore: el.querySelector('.mascot-restore').getAttribute('aria-label'), shown: el.dataset.shownMood,
          colours: ['bg', 'fg', 'glow'].map((name) => el.style.getPropertyValue('--_mascot-restore-' + name)) });
        const out = { start: read() };
        receive({ mood: 'thinking' }); out.thinking = read();
        receive({ mood: 'processing' }); out.processing = read();
        receive({ status: { mode: 'custom', text: 'Waiting for you' } }); out.custom = read();
        receive({ mood: 'happy' }); out.customHappy = read();
        receive({ status: { mode: 'mood' } }); out.back = read();
        return out;
      })()
    )"
    )
    expect_identical(r$start$status, "Idle")
    expect_identical(r$start$label, "Alpha Two, Idle")
    expect_identical(r$start$restore, "Restore Alpha Two, Idle")
    # The restore control wears the brand leaders (shell and hat) and the outline, not the first colour of the table.
    expect_identical(unlist(r$start$colours), c("#8a6bff", "#1b1230", "#ffc400"))
    # The data says "Reading the logs"; a title-cased id would say "Thinking".
    expect_identical(r$thinking$status, "Reading the logs")
    expect_identical(r$thinking$label, "Alpha Two, Reading the logs")
    expect_identical(r$thinking$restore, "Restore Alpha Two, Reading the logs")
    expect_identical(r$processing$status, "Processing")
    expect_identical(r$custom$status, "Waiting for you")
    expect_identical(r$custom$label, "Alpha Two, Waiting for you")
    expect_identical(r$custom$restore, "Restore Alpha Two, Waiting for you")
    expect_identical(r$customHappy$shown, "happy")
    expect_identical(r$customHappy$status, "Waiting for you")
    expect_identical(r$back$status, "Happy")
    expect_identical(r$back$label, "Alpha Two, Happy")
  })

  it("applies theme colours, derived follows, brand leaders and the mood's recolour to the palette it draws with", {
    js <- page_with(reduced = TRUE)
    r <- js(
      r"(
      (() => {
        const receive = (patch) => mascot.host.receive({ id: 'a', patch });
        const last = () => geometryCalls.filter((call) => call.id !== 'shadow').at(-1).colours;
        const theme = (fields) => ({ theme: { light: null, dark: null, mode: 'light', css: null, brand: null, ...fields } });
        const out = { base: { shell: last().shell, shade: last().shell_shade } };
        receive(theme({ light: { shell: '#ff0000' } }));
        out.red = { shell: last().shell, shade: last().shell_shade };
        receive(theme({ dark: { shell: '#00ff00' }, mode: 'dark' }));
        out.dark = last().shell;
        receive(theme({ brand: { primary: '#aa0000', secondary: '#0000aa' } }));
        out.brand = { shell: last().shell, hat: last().hat };
        receive({ ...theme({ mode: null }), mood: 'thinking' });
        out.thinking = { light: last().light, source: last().light_thinking };
        receive(theme({ light: { light_thinking: '#123456' } }));
        out.user = last().light;
        return out;
      })()
    )"
    )
    expect_identical(r$base$shell, "#8a6bff")
    expect_identical(r$red$shell, "#ff0000")
    # shell_shade follows shell by -0.12 lightness: hsl(0, 100%, 38%) is rgb(194, 0, 0).
    expect_identical(r$red$shade, "#c20000")
    expect_identical(r$dark, "#00ff00")
    expect_identical(r$brand$shell, "#aa0000")
    expect_identical(r$brand$hat, "#0000aa")
    # The thinking mood redirects the light role to light_thinking; an explicit user colour for light_thinking wins.
    expect_identical(r$thinking$light, r$thinking$source)
    expect_identical(r$thinking$source, "#ffb020")
    expect_identical(r$user, "#123456")
  })

  it("keeps a theme across a swap for the roles the incoming character has, and ignores the ones it has not", {
    js <- page_with(reduced = TRUE)
    r <- js(
      "(() => {
        const receive = (patch) => mascot.host.receive({ id: 'a', patch });
        const last = () => geometryCalls.filter((call) => call.id !== 'shadow').at(-1).colours;
        const theme = { light: { shell: '#ff0000', outline: '#112233' }, dark: null, mode: 'light', css: null, brand: null };
        receive({ theme });
        const out = { first: [last().shell, last().outline] };
        receive({ character: CHARACTERS.alpha_three });
        out.sibling = [last().shell, last().outline];
        receive({ character: CHARACTERS.tessa_two });
        out.other = [last().outline, last().shell];
        return out;
      })()"
    )
    expect_identical(unlist(r$first), c("#ff0000", "#112233"))
    expect_identical(unlist(r$sibling), c("#ff0000", "#112233"))
    # tessa_two has an outline role but no shell role: the shared one is kept, the unknown one is dropped.
    expect_identical(r$other[[1]], "#112233")
    expect_null(r$other[[2]])
  })

  it("applies a theme given in R, in the page's light and dark mode, to the palette it draws with", {
    js <- page_with(
      tags = list(mascot(
        "a",
        character = alpha,
        theme = mascot_theme(light = list(outline = "#aa0000"), dark = list(outline = "#00aa00")),
        motion = FALSE,
        placement = "inline"
      )),
      reduced = TRUE
    )
    r <- js(
      "(async () => {
        const outline = () => geometryCalls.filter((call) => call.id !== 'shadow').at(-1).colours.outline;
        const out = { light: outline() };
        document.documentElement.dataset.bsTheme = 'dark';
        await T.frames(4);
        out.dark = outline();
        return out;
      })()"
    )
    # R spells the colours in capitals; the page keeps them as sent.
    expect_identical(r$light, "#AA0000")
    expect_identical(r$dark, "#00AA00")
  })

  it("draws the status of the incoming character when a swap replaces it, with its own name in the label", {
    js <- page_with(reduced = TRUE)
    r <- js(
      "(() => {
        const el = document.getElementById('a');
        mascot.host.receive({ id: 'a', patch: { character: CHARACTERS.alpha_three } });
        return { status: el.querySelector('.mascot-status').textContent,
          label: el.querySelector('canvas').getAttribute('aria-label'), shown: el.dataset.shownCharacter };
      })()"
    )
    expect_identical(r$shown, "alpha_three")
    expect_identical(r$status, "Standing by")
    expect_identical(r$label, "Alpha Three, Standing by")
  })
})

describe("I1 the host follows the character's mood chain across a swap", {
  it("records the mood the incoming character really shows, not its first mood", {
    js <- page_with(reduced = TRUE)
    r <- js(
      "(() => {
        const el = document.getElementById('a');
        mascot.host.receive({ id: 'a', patch: { mood: 'processing' } });
        mascot.host.receive({ id: 'a', patch: { character: CHARACTERS.alpha_three } });
        const state = mascot.host.state(el);
        return { mood: state.mood, dataset: el.dataset.mood, shown: el.dataset.shownMood, current: state.current.mood,
          status: el.querySelector('.mascot-status').textContent };
      })()"
    )
    # alpha_three has no processing mood: its fallback is thinking (status "Pondering"), never the first mood, idle.
    expect_identical(r$mood, "thinking")
    expect_identical(r$dataset, "thinking")
    expect_identical(r$shown, "thinking")
    expect_identical(r$current, "thinking")
    expect_identical(r$status, "Pondering")
  })
})

describe("I1 mood change, gestures, idle motion and reduced motion move the character", {
  it("shows the previous mood until swap_at of the change, then the target, and rests on the target", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two'), c = p.controller, shown = [];
        c.seek(0); c.update({ mood: 'happy' });
        for (const f of [0, 11, 12, 23, 24, 150]) { c.seek(f); shown.push([f, c.current().mood]); }
        return { shown, events: p.events.map((e) => e.mood) };
      })()"
    )
    moods <- vapply(r$shown, function(x) x[[2]], character(1))
    expect_identical(moods, c("idle", "idle", "happy", "happy", "happy", "happy"))
    expect_identical(unlist(r$events), c("idle", "happy"))
  })

  it("moves parts along the character's own change tracks (hat hop) and rests afterwards", {
    js <- page_with()
    r <- js(
      sprintf(
        "(() => {
          const c = T.player('alpha_two').controller, y = () => %s['hard_hat.y'];
          c.seek(0); c.update({ mood: 'happy' });
          c.seek(6); const rising = y();
          c.seek(24); const after = y();
          return { rising, after };
        })()",
        last_channels_js
      )
    )
    # hat_hop: hard_hat.y goes from 0 to -14 over the first 0.4 of 24 frames; frame 6 is 0.25, 0.625 of the way.
    expect_equal(r$rising, -14 * 0.25 / 0.4)
    expect_equal(r$after, 0)
  })

  it("moves the root with the declared wiggle and hop styles", {
    # The screen-faced fixture has no room to wiggle or hop inside the frame, so these use the classic-kit one.
    wiggle <- runtime_character(runtime_data(
      "tessa_wiggle",
      "Tessa Wiggle",
      function(recipe) {
        recipe$motion$change <- list(style = "wiggle", frames = 16, angle = 0.06, swap_at = 0.5)
        recipe
      },
      base = "tessa"
    ))
    hop <- runtime_character(runtime_data(
      "tessa_hop",
      "Tessa Hop",
      function(recipe) {
        recipe$motion$change <- list(style = "hop", frames = 16, height = 8, swap_at = 0.5)
        recipe
      },
      base = "tessa"
    ))
    js <- page_with(characters = list(alpha, wiggle, hop))
    r <- js(
      sprintf(
        "(() => {
          const out = {}, read = (key) => %s[key];
          const w = T.player('tessa_wiggle').controller;
          w.seek(0); w.update({ mood: 'happy' }); w.seek(2); out.wiggle = read('root.rotate');
          const h = T.player('tessa_hop').controller;
          h.seek(0); h.update({ mood: 'happy' }); h.seek(8); out.hop = read('root.lift');
          return out;
        })()",
        last_channels_js
      )
    )
    # wiggle: angle * sin(4 pi p) * (1 - p)^2 with p = 2 / 16; hop: height * sin(pi p) with p = 8 / 16.
    p <- 2 / 16
    expect_equal(r$wiggle, 0.06 * sin(4 * pi * p) * (1 - p)^2)
    expect_equal(r$hop, 8)
  })

  it("plays a gesture's tracks, returns to the mood's rest when it ends, and a new mood replaces it", {
    js <- page_with()
    r <- js(
      sprintf(
        "(() => {
          const out = {}, c = T.player('alpha_two').controller, read = (key) => %s[key];
          c.seek(0); c.gesture('wave');
          c.seek(3); out.early = [read('arm_r.rotate'), read('root.rotate')];
          c.seek(15); out.held = [read('arm_r.rotate'), read('root.rotate')];
          c.seek(30); out.after = [read('arm_r.rotate'), read('root.rotate')];
          const d = T.player('alpha_two').controller;
          d.seek(0); d.gesture('wave'); d.seek(10); d.update({ mood: 'happy' }); d.seek(15);
          out.replaced = read('root.rotate');
          return out;
        })()",
        last_channels_js
      )
    )
    # wave: arm_r.rotate runs from the rest (1.24) to -1.1 by 0.2 of 30 frames, so frame 3 is halfway; root.rotate adds -0.025.
    expect_equal(r$early[[1]], (1.24 - 1.1) / 2)
    expect_equal(r$held[[1]], -1.1)
    expect_equal(r$held[[2]], -0.025)
    expect_equal(r$after[[1]], 1.24)
    expect_equal(r$after[[2]], 0)
    expect_equal(r$replaced, 0)
  })

  it("breathes by a bounded multiplicative factor and blinks at the seeded frame, deterministically", {
    js <- page_with()
    r <- js(
      sprintf(
        "(() => {
          const out = {};
          const c = T.player('alpha_two').controller;
          c.seek(22); const channels = %s;
          out.breathe = [channels['root.scale_x'], channels['root.scale_y']];
          const blink = (seed, frame) => { const p = T.player('alpha_two', { seed }); p.controller.seek(frame);
            return faceCalls.at(-1).controls.blink; };
          out.zero = [blink(0, 129), blink(0, 133), blink(0, 90)];
          out.one = [blink(1, 90), blink(1, 133)];
          return out;
        })()",
        last_channels_js
      )
    )
    breathe <- 0.012 * sin(2 * pi * 22 / 90)
    expect_equal(r$breathe[[1]], 1 - breathe)
    expect_equal(r$breathe[[2]], 1 + breathe)
    # Seed 0: the first blink is centred at 120 + (1664525 * 0 + 1013904223) mod 61 - 30, and lasts three frames each way.
    centre <- 120 + 1013904223 %% 61 - 30
    expect_equal(centre, 133)
    expect_equal(unlist(r$zero), c(0, 1, 0))
    expect_equal(unlist(r$one), c(1, 0))
  })

  it("plays the idle extra once, inside the window, at a frame fixed by the seed", {
    extra <- runtime_character(runtime_data(
      "tessa_extra",
      "Tessa Extra",
      function(recipe) {
        recipe$motion$idle <- list(extra = "rock")
        recipe
      },
      base = "tessa"
    ))
    js <- page_with(characters = list(alpha, extra))
    r <- js(
      sprintf(
        "(() => {
          const rotating = (seed) => {
            const c = T.player('tessa_extra', { seed }).controller, moving = [];
            for (let f = 0; f < 150; f++) { c.seek(f); if (%s['root.rotate'] !== 0) moving.push(f); }
            return moving;
          };
          return { zero: rotating(0), again: rotating(0), other: rotating(5) };
        })()",
        last_channels_js
      )
    )
    zero <- unlist(r$zero)
    # rock lasts 18 frames; the extra starts no later than 82 (the fade begins at 100), and plays once without a gap.
    expect_lte(length(zero), 18)
    expect_gt(length(zero), 10)
    expect_identical(zero, seq(min(zero), max(zero)))
    expect_lte(max(zero), 100)
    expect_identical(unlist(r$again), zero)
    expect_false(identical(unlist(r$other), zero))
  })

  it("draws the same picture for the same frame however it was reached", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two'), c = p.controller;
        c.seek(40); const first = T.picture(p.canvas);
        c.seek(90); c.seek(5); c.seek(40);
        return { first, again: T.picture(p.canvas) };
      })()"
    )
    expect_gt(r$first$ink, 1000)
    expect_equal(r$again$sum, r$first$sum)
  })

  it("settles at the deadline on exactly the mood's rest, whatever the idle motion was doing", {
    js <- page_with()
    r <- js(
      sprintf(
        "(() => {
          const c = T.player('alpha_two').controller, out = {};
          c.seek(0); c.update({ mood: 'thinking' });
          c.seek(75); out.during = %s['root.scale_y'];
          c.seek(150); const at = %s; out.rest = [at['root.scale_y'], at['root.scale_x'], at['arm_r.rotate']];
          return out;
        })()",
        last_channels_js,
        last_channels_js
      )
    )
    expect_false(isTRUE(all.equal(r$during, 1)))
    # At rest: no breathing, and the thinking pose (the chin pose sets arm_r.rotate to -2.4).
    expect_equal(unlist(r$rest), c(1, 1, -2.4))
  })

  it("settles at once under reduced motion, with the reduced channels and no movement", {
    js <- page_with(reduced = TRUE)
    r <- js(
      sprintf(
        "(() => {
          const p = T.player('alpha_two', { reduced: null }), c = p.controller;
          c.seek(0); c.update({ mood: 'thinking' });
          const shown = c.current().mood;
          c.gesture('wave'); c.seek(15);
          const channels = %s;
          return { shown, arm: channels['arm_r.rotate'], rotate: channels['root.rotate'], hat: channels['hard_hat.y'] };
        })()",
        last_channels_js
      )
    )
    expect_identical(r$shown, "thinking")
    expect_equal(r$arm, -2.4)
    expect_equal(r$rotate, 0)
    expect_equal(r$hat, 0)
  })

  it("draws the kit effects of a mood: sweat while worried, a sparkle while celebrating, and the ground shadow", {
    js <- page_with()
    r <- js(
      "(() => {
        const out = {};
        for (const mood of ['idle', 'worried', 'celebrating']) {
          effectCalls.length = 0; frames.length = 0;
          T.player('alpha_two', { mood, reduced: true });
          out[mood] = { effects: effectCalls.map((c) => c.controls),
            shadow: frames.filter((f) => f.id === 'shadow').map((f) => f.channels) };
        }
        return out;
      })()"
    )
    expect_length(r$idle$effects, 0)
    expect_equal(r$worried$effects[[1]]$sweat, 0.35)
    expect_equal(r$celebrating$effects[[1]]$sparkle, 1)
    # Celebrating lifts the character by 8: the shadow shrinks by 1 / (1 + 8 / 200) and keeps its own scale.
    k <- 1 / (1 + 8 / 200)
    expect_equal(r$celebrating$shadow[[1]][["ground_shadow.scale_y"]], k)
    expect_equal(r$celebrating$shadow[[1]][["ground_shadow.scale_x"]], k)
    expect_equal(r$idle$shadow[[1]][["ground_shadow.scale_y"]], 1)
  })

  it("draws no ground shadow for a character that declares none", {
    js <- page_with()
    n <- js(
      "(() => { frames.length = 0; T.player('visor_probe', { reduced: true });
      return frames.filter((f) => f.id === 'shadow').length; })()"
    )
    expect_equal(n, 0)
  })
})

describe("I1 character swaps", {
  it("fades the outgoing character out, then the incoming one in, over sixty frames, one character at a time", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two'), c = p.controller;
        c.seek(0); c.update({ character: T.load('alpha_three') });
        const rows = [];
        for (const f of [0, 15, 29, 30, 45, 59, 60, 100]) {
          c.seek(f);
          rows.push({ f, ...c.current(), alpha: T.maxAlpha(p.canvas), ink: T.picture(p.canvas).ink });
        }
        return { rows, events: p.events.map((e) => [e.character, e.swapping]) };
      })()"
    )
    characters <- vapply(r$rows, function(x) x$character, character(1))
    swapping <- vapply(r$rows, function(x) x$swapping, logical(1))
    peak <- vapply(r$rows, function(x) x$alpha, numeric(1))
    expect_identical(
      characters,
      c(rep("alpha_two", 3), rep("alpha_three", 5))
    )
    expect_identical(swapping, c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE))
    # Opacity is (1 - f / 30) while fading out and (f - 30) / 30 while fading in.
    expect_equal(peak, round(255 * c(1, 0.5, 1 / 30, 0, 0.5, 29 / 30, 1, 1)), tolerance = 0.02)
    expect_equal(r$rows[[4]]$ink, 0)
    expect_identical(
      lapply(r$events, unlist),
      list(
        c("alpha_two", "FALSE"),
        c("alpha_two", "TRUE"),
        c("alpha_three", "TRUE"),
        c("alpha_three", "FALSE")
      )
    )
  })

  it("keeps the mood when the incoming character has it and follows the fallback chain when it has not", {
    js <- page_with()
    r <- js(
      "(() => {
        const mood = (from, to, name) => {
          const c = T.player(from, { mood: name }).controller;
          c.seek(0); c.update({ character: T.load(to) }); c.seek(40);
          return c.current().mood;
        };
        return { kept: mood('alpha_two', 'alpha_three', 'celebrating'), fallback: mood('alpha_two', 'alpha_three', 'processing'),
          crossKit: mood('alpha_two', 'tessa_two', 'processing') };
      })()"
    )
    expect_identical(r$kept, "celebrating")
    # processing declares thinking as its fallback; alpha_three has no processing mood.
    expect_identical(r$fallback, "thinking")
    expect_identical(r$crossKit, "thinking")
  })

  it("shows the outgoing character's own mood while it fades out, and the incoming mood once it fades in", {
    js <- page_with()
    r <- js(
      "(() => {
        const c = T.player('alpha_two', { mood: 'processing' }).controller, rows = {};
        c.seek(0); c.update({ character: T.load('alpha_three') });
        for (const f of [0, 10, 29, 30, 59]) { c.seek(f); rows[f] = c.current(); }
        return rows;
      })()"
    )
    # alpha_three has no processing mood; its fallback is thinking, but the target is not shown until its turn.
    expect_identical(r[["0"]]$mood, "processing")
    expect_identical(r[["10"]]$mood, "processing")
    expect_identical(r[["29"]]$mood, "processing")
    expect_identical(r[["29"]]$character, "alpha_two")
    expect_identical(r[["30"]]$mood, "thinking")
    expect_identical(r[["30"]]$character, "alpha_three")
    expect_identical(r[["59"]]$mood, "thinking")
  })

  it("commits a mood change during the swap without a wiggle and without extending it", {
    js <- page_with()
    r <- js(
      sprintf(
        "(() => {
          const p = T.player('alpha_two'), c = p.controller;
          c.seek(0); c.update({ character: T.load('alpha_three') });
          c.seek(40); c.update({ mood: 'happy' });
          c.seek(41); const now = c.current(), hat = %s['hard_hat.y'];
          c.seek(59); const late = c.current().swapping;
          c.seek(60); const done = c.current();
          return { now, hat, late, done };
        })()",
        last_channels_js
      )
    )
    expect_identical(r$now$mood, "happy")
    expect_true(r$now$swapping)
    # A change would run the hat hop track; a committed mood does not.
    expect_equal(r$hat, 0)
    expect_true(r$late)
    expect_false(r$done$swapping)
    expect_identical(r$done$mood, "happy")
  })

  it("shows the exiting character for the time that remains when a new target arrives mid-fade", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two'), c = p.controller, seen = {};
        c.seek(0); c.update({ character: T.load('alpha_three') });
        c.seek(10); c.update({ character: T.load('tessa_two') });
        for (let f = 0; f <= 70; f++) { c.seek(f); seen[f] = c.current(); }
        return { at29: seen[29], at30: seen[30], at59: seen[59], at60: seen[60],
          ids: [...new Set(Object.values(seen).map((s) => s.character))] };
      })()"
    )
    # Ten frames of the fade-out are over: twenty remain, then thirty to fade the new target in; alpha_three never shows.
    expect_identical(r$at29$character, "alpha_two")
    expect_identical(r$at30$character, "tessa_two")
    expect_true(r$at59$swapping)
    expect_false(r$at60$swapping)
    expect_setequal(unlist(r$ids), c("alpha_two", "tessa_two"))
  })

  it("reverses directly, without showing the other character, when the exiting character is asked for again", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two'), c = p.controller, seen = {}, alpha = {};
        c.seek(0); c.update({ character: T.load('alpha_three') });
        c.seek(10); c.update({ character: T.load('alpha_two') });
        for (let f = 10; f <= 30; f++) { c.seek(f); seen[f] = c.current(); alpha[f] = T.maxAlpha(p.canvas); }
        return { seen, alpha };
      })()"
    )
    ids <- unique(vapply(r$seen, function(x) x$character, character(1)))
    expect_identical(ids, "alpha_two")
    # Opacity was 2/3 at frame 10; the entrance lasts 30 * (1 - 2/3) = 10 frames and rises evenly to full.
    expect_true(r$seen[["19"]]$swapping)
    expect_false(r$seen[["20"]]$swapping)
    expect_equal(r$alpha[["10"]], round(255 * 2 / 3), tolerance = 0.02)
    expect_equal(r$alpha[["15"]], round(255 * (2 / 3 + 1 / 3 * 0.5)), tolerance = 0.02)
    expect_equal(r$alpha[["20"]], 255)
  })

  it("treats the same id as an ordinary update, and swap:false or reduced motion as an instant change", {
    js <- page_with()
    r <- js(
      "(() => {
        const out = {};
        const same = T.player('alpha_two').controller;
        same.seek(0); same.update({ character: structuredClone(T.load('alpha_two')) });
        out.same = same.current();
        const instant = T.player('alpha_two').controller;
        instant.seek(0); instant.update({ character: T.load('alpha_three'), swap: false });
        out.instant = instant.current();
        instant.update({ swap: true }); instant.seek(5);
        out.replayed = instant.current();
        const reduced = T.player('alpha_two').controller;
        reduced.seek(0); reduced.update({ character: T.load('alpha_three'), reduced: true });
        out.reduced = reduced.current();
        reduced.update({ reduced: null }); reduced.seek(5);
        out.afterReduced = reduced.current();
        return out;
      })()"
    )
    expect_false(r$same$swapping)
    expect_identical(r$same$character, "alpha_two")
    expect_identical(r$instant$character, "alpha_three")
    expect_false(r$instant$swapping)
    expect_false(r$replayed$swapping)
    expect_identical(r$reduced$character, "alpha_three")
    expect_false(r$reduced$swapping)
    expect_false(r$afterReduced$swapping)
  })

  it("rejects a bad patch before any change, mid-swap too, and ignores a gesture while swapping", {
    js <- page_with()
    r <- js(
      sprintf(
        "(() => {
          const out = {};
          const p = T.player('alpha_two'), c = p.controller;
          const before = T.picture(p.canvas);
          try { c.update({ character: T.load('alpha_three'), mood: 'nope' }); out.mood = 'no error'; }
          catch (e) { out.mood = e.message; }
          out.unchanged = c.current(); out.sameSum = T.picture(p.canvas).sum === before.sum;
          // Two swaps, one asked to wave in the middle of it: their frames must match exactly.
          const channelsAt = (gesture) => {
            const q = T.player('alpha_two').controller;
            q.seek(0); q.update({ character: T.load('alpha_three') });
            q.seek(40);
            try { q.update({ colours: { nowhere: '#ffffff' } }); out.role = 'no error'; } catch (e) { out.role = e.message; }
            if (gesture) q.gesture('wave');
            q.seek(45);
            return { channels: JSON.stringify(%s), swapping: q.current().swapping };
          };
          const waved = channelsAt(true), plain = channelsAt(false);
          out.same = waved.channels === plain.channels;
          out.swapping = waved.swapping;
          return out;
        })()",
        last_channels_js
      )
    )
    expect_match(r$mood, "update.mood")
    expect_false(r$unchanged$swapping)
    expect_true(r$sameSum)
    expect_match(r$role, "update.colours.nowhere")
    expect_true(r$swapping)
    expect_true(r$same)
  })

  it("runs the swap on its own private canvas and leaves the canvas state as it found it", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two'), c = p.controller, ctx = p.canvas.getContext('2d');
        ctx.globalAlpha = 0.9; ctx.fillStyle = '#123456'; ctx.lineWidth = 7;
        const transform = ctx.getTransform();
        c.seek(0); c.update({ character: T.load('alpha_three') }); c.seek(15);
        const t = ctx.getTransform();
        return { alpha: ctx.globalAlpha, fill: ctx.fillStyle, line: ctx.lineWidth,
          same: [t.a, t.b, t.c, t.d, t.e, t.f].every((v, i) => v === [transform.a, transform.b, transform.c, transform.d, transform.e, transform.f][i]),
          peak: T.maxAlpha(p.canvas) };
      })()"
    )
    expect_equal(r$alpha, 0.9)
    expect_identical(r$fill, "#123456")
    expect_equal(r$line, 7)
    expect_true(r$same)
    # The caller's alpha multiplies the fade: 0.9 * 0.5 of 255.
    expect_equal(r$peak, round(255 * 0.9 * 0.5), tolerance = 0.02)
  })
})

describe("I1 held gaze", {
  gaze_js <- r"(
    window.poses = [];
    (() => {
      const mount = mascot.mount;
      mascot.mount = (...a) => {
        const c = mount(...a), update = c.update;
        c.update = (patch) => { if (patch.pose) poses.push(patch.pose); return update(patch); };
        return c;
      };
    })();
  )"
  bubble <- mascot_bubble("Read this", duration = Inf)

  it("looks towards a shown bubble through face.look_y, and clears only the look when the bubble goes", {
    js <- page_with(
      tags = list(mascot("a", character = classic, bubble = bubble, motion = FALSE, placement = "inline")),
      before_mount = gaze_js
    )
    shown <- js("({ pose: poses.at(-1), look: faceCalls.at(-1).controls.look_y })")
    expect_identical(shown$pose[["face.look_y"]], -1L)
    expect_null(shown$pose[["face.look_x"]])
    expect_equal(shown$look, -1)
    js("mascot.host.receive({ id: 'a', patch: { bubble: { clear: true } } })")
    cleared <- js("({ pose: JSON.stringify(poses.at(-1)), look: faceCalls.at(-1).controls.look_y })")
    expect_identical(cleared$pose, '{"face.look_x":null,"face.look_y":null}')
    expect_equal(cleared$look, 0)
  })

  it("sends no gaze channels to a faceless character or to a kit whose eyes cannot look", {
    for (character in list(alpha, faceless)) {
      js <- page_with(
        tags = list(mascot("a", character = character, bubble = bubble, motion = FALSE, placement = "inline")),
        before_mount = gaze_js
      )
      r <- js(
        sprintf(
          "(() => {
            const el = document.getElementById('a'), out = { updates: poses.length, gaze: mascot.host.state(el).gaze };
            const p = T.player('%s');
            try { p.controller.update({ pose: { 'face.look_y': -1 } }); out.direct = 'no error'; }
            catch (e) { out.direct = e.message; }
            return out;
          })()",
          character$id
        )
      )
      expect_equal(r$updates, 0, info = character$id)
      # The host still knows which way the mascot looks; the player never receives a channel for it.
      expect_identical(r$gaze, "top", info = character$id)
      expect_match(r$direct, "has no gaze to hold", info = character$id)
    }
  })

  it("re-aims the gaze when the character changes under an open bubble, and says nothing to one that cannot look", {
    js <- page_with(
      tags = list(mascot("a", character = classic, bubble = bubble, motion = FALSE, placement = "inline")),
      reduced = TRUE,
      before_mount = paste(gaze_js, "window.warnings = []; console.warn = (...a) => warnings.push(a.join(' '));")
    )
    r <- js(
      "(() => {
        const el = document.getElementById('a'), out = {};
        const swap = (id) => { mascot.host.receive({ id: 'a', patch: { character: CHARACTERS[id] } });
          return { shown: el.dataset.shownCharacter, look: faceCalls.at(-1).controls.look_y }; };
        out.start = faceCalls.at(-1).controls.look_y;
        out.blind = swap('alpha_two');
        out.back = swap('tessa_mirror');
        out.warnings = warnings.length;
        return out;
      })()"
    )
    expect_equal(r$start, -1)
    expect_identical(r$blind$shown, "alpha_two")
    expect_equal(r$blind$look, 0)
    expect_identical(r$back$shown, "tessa_mirror")
    expect_equal(r$back$look, -1)
    expect_equal(r$warnings, 0)
  })

  it("draws the face looking up only where the eyes have pupils", {
    js <- page_with()
    r <- js(
      "(() => {
        const moves = (mood) => {
          const p = T.player('tessa_two', { mood, reduced: true });
          const rest = T.picture(p.canvas).sum;
          p.controller.update({ pose: { 'face.look_y': -1 } });
          return T.picture(p.canvas).sum !== rest;
        };
        return { open: moves('idle'), closed: moves('happy') };
      })()"
    )
    # Idle has open eyes with pupils; happy has closed arcs, which gaze cannot move.
    expect_true(r$open)
    expect_false(r$closed)
  })

  it("sends the look in page terms and flips it back from the root flip of the frame shown", {
    for (case in list(list(classic, -1L), list(mirror, -1L))) {
      js <- page_with(
        tags = list(htmltools::div(
          style = "margin-left: 500px",
          mascot(
            "a",
            character = case[[1]],
            click = mascot_popup_menu(c(about = "About"), direction = "left"),
            motion = FALSE,
            placement = "inline"
          )
        )),
        before_mount = gaze_js,
        shiny_stub = TRUE,
        viewport = c(1000, 700)
      )
      js("document.querySelector('#a .mascot-menu-toggle').click()")
      expect_identical(js("mascot.host.state(document.getElementById('a')).gaze"), "left", info = case[[1]]$id)
      # The host sends page terms; the runtime flips the look back from the frame it shows (reduced bases included).
      expect_identical(js("poses.at(-1)['face.look_x']"), case[[2]], info = case[[1]]$id)
    }
    flipped <- js(
      "(() => { const c = { 'root.flip': -1, 'face.look_x': -1 }; mascot.runtime.flipHeldLook(c, { 'face.look_x': -1 });
       const d = { 'root.flip': 1, 'face.look_x': -1 }; mascot.runtime.flipHeldLook(d, { 'face.look_x': -1 });
       const e = { 'root.flip': -1, 'face.look_x': 0.3 }; mascot.runtime.flipHeldLook(e, {});
       return [c['face.look_x'], d['face.look_x'], e['face.look_x']]; })()"
    )
    # Mirrored: looking left on the page is looking right in the character's own space; an animated look is untouched.
    expect_identical(unlist(flipped), c(1, -1, 0.3))
  })
})

describe("I1 detail bands follow the CSS width for a format-v1 character", {
  it("mounts at the band the canvas measures, at 128 and 48 CSS pixels exactly", {
    sizes <- c(160, 128, 100, 48, 47, 24)
    js <- page_with(
      tags = lapply(sizes, function(size) {
        mascot(paste0("s", size), character = alpha, size = size, motion = FALSE, placement = "inline")
      })
    )
    js("T.frames(3)")
    bands <- vapply(
      sizes,
      function(size) js(sprintf("mascot.host.state(document.getElementById('s%d')).band", size)),
      character(1)
    )
    expect_identical(bands, c("full", "full", "small", "small", "micro", "micro"))
  })

  it("never draws a frame in another band first, and applies the band's own hidden parts", {
    for (case in list(
      list(160, "full", character(0)),
      list(100, "small", c("torso.gloss", "head.glass")),
      list(24, "micro", c("leg_l", "leg_r", "ear_l", "ear_r", "torso.gloss", "head.glass"))
    )) {
      js <- page_with(
        tags = list(mascot("a", character = alpha, size = case[[1]], motion = FALSE, placement = "inline"))
      )
      js("T.frames(3)")
      r <- js(
        "({ bands: [...new Set(geometryCalls.filter((c) => c.id !== 'shadow').map((c) => c.band))],
          hidden: geometryCalls.filter((c) => c.id !== 'shadow').at(-1).hidden })"
      )
      expect_identical(unlist(r$bands), case[[2]], info = case[[2]])
      expect_true(all(case[[3]] %in% unlist(r$hidden)), info = case[[2]])
      if (case[[2]] == "full") expect_length(r$hidden, 0)
    }
  })

  it("redraws once for a band change with a backing resize, and once for a resize inside the band", {
    js <- page_with(
      tags = list(mascot("a", character = alpha, size = "20%", motion = FALSE, placement = "inline")),
      reduced = TRUE
    )
    js(
      "(async () => {
        window.el = document.getElementById('a'); window.box = document.createElement('div');
        box.style.cssText = 'width:500px'; el.before(box); box.append(el);
        window.count = () => frames.filter((f) => f.id !== 'shadow').length;
        await T.frames(5);
      })()"
    )
    step <- function(width) {
      before <- js("count()")
      if (!is.null(width)) {
        js(sprintf("box.style.width = '%s'", width))
      }
      js("T.frames(5)")
      js("count()") - before
    }
    expect_identical(js("mascot.host.state(el).band"), "small")
    expect_equal(step("200px"), 1) # small -> micro, backing resize: one draw
    expect_identical(js("mascot.host.state(el).band"), "micro")
    expect_equal(step("300px"), 1) # micro -> small
    expect_equal(step("320px"), 1) # inside small: the ordinary redraw
    expect_equal(step("1000px"), 1) # small -> full
    expect_identical(js("mascot.host.state(el).band"), "full")
  })

  it("keeps the old band and reports once when a resize lands on a band the character is over budget in", {
    js <- page_with(
      tags = list(mascot("a", character = alpha, size = "20%", motion = FALSE, placement = "inline")),
      reduced = TRUE,
      before_mount = "window.warnings = []; console.warn = (...a) => warnings.push(a.join(' '));"
    )
    r <- js(
      "(async () => {
        const el = document.getElementById('a'), box = document.createElement('div');
        box.style.cssText = 'width:1000px'; el.before(box); box.append(el);
        await T.frames(5);
        const planted = structuredClone(T.load('alpha_two')); planted.id = 'planted'; planted.name = 'Planted';
        planted.parts.find((part) => part.id === 'torso').items.push(
          ...Array.from({ length: 100 }, () => ({ shape: 'circle', x: 0, y: -20, r: 4, fill: 'shell' })));
        const entry = mascot.runtime.compile(planted);
        const work = { full: mascot.runtime.bound(entry, 'full').painted_items, small: mascot.runtime.bound(entry, 'small').painted_items };
        mascot.host.receive({ id: 'a', patch: { character: { id: 'planted', name: 'Planted', json: JSON.stringify(planted) } } });
        const out = { work, character: mascot.host.state(el).character, band: mascot.host.state(el).band };
        box.style.width = '500px'; await T.frames(5);
        out.afterFirst = { band: mascot.host.state(el).band, warnings: warnings.length, text: warnings[0],
          rendered: mascot.host.state(el).renderedSize, ink: T.picture(el.querySelector('canvas')).ink };
        box.style.width = '450px'; await T.frames(5);
        out.afterSecond = { band: mascot.host.state(el).band, warnings: warnings.length };
        return out;
      })()"
    )
    # The planted character is within the full caps (160 painted items) and over the small ones (90).
    expect_lte(r$work$full, 160)
    expect_gt(r$work$small, 90)
    expect_identical(r$character, "planted")
    expect_identical(r$band, "full")
    expect_identical(r$afterFirst$band, "full")
    expect_equal(r$afterFirst$warnings, 1)
    expect_match(r$afterFirst$text, "small band paints too much")
    expect_equal(r$afterFirst$rendered, 100)
    expect_gt(r$afterFirst$ink, 1000)
    expect_equal(r$afterSecond$warnings, 1)
    expect_identical(r$afterSecond$band, "full")
  })

  it("refuses an over-budget incoming character before any change, and keeps the pixels", {
    js <- page_with(
      reduced = TRUE,
      before_mount = "window.warnings = []; console.warn = (...a) => warnings.push(a.join(' '));"
    )
    r <- js(
      "(async () => {
        const el = document.getElementById('a'), canvas = el.querySelector('canvas');
        await T.frames(3);
        const before = T.picture(canvas);
        const planted = structuredClone(T.load('alpha_two')); planted.id = 'planted'; planted.name = 'Planted';
        planted.parts.find((part) => part.id === 'torso').items.push(
          ...Array.from({ length: 200 }, () => ({ shape: 'circle', x: 0, y: -20, r: 4, fill: 'shell' })));
        mascot.host.receive({ id: 'a', patch: { character: { id: 'planted', name: 'Planted', json: JSON.stringify(planted) } } });
        const refused = { character: mascot.host.state(el).character, shown: el.dataset.shownCharacter,
          current: mascot.host.state(el).current, same: T.picture(canvas).sum === before.sum, warnings: warnings.length,
          text: warnings[0] };
        // The player still answers to the old character: an ordinary patch afterwards works.
        mascot.host.receive({ id: 'a', patch: { mood: 'happy' } });
        return { ...refused, afterwards: el.dataset.shownMood, status: el.querySelector('.mascot-status').textContent };
      })()"
    )
    expect_identical(r$character, "alpha_two")
    expect_identical(r$shown, "alpha_two")
    expect_identical(r$current$character, "alpha_two")
    expect_identical(r$afterwards, "happy")
    expect_identical(r$status, "Happy")
    expect_true(r$same)
    expect_equal(r$warnings, 1)
    expect_match(r$text, "full band paints too much")
  })

  it("bounds painted work componentwise: per-part maxima plus the largest accessory of each slot, not a product", {
    js <- page_with()
    r <- js(
      "(() => {
        const base = structuredClone(T.load('tessa_two'));
        const plain = structuredClone(base); plain.accessories = {}; plain.wear = [];
        const main = mascot.runtime.bound(mascot.runtime.compile(plain), 'full').painted_items;
        const withSlots = structuredClone(plain);
        withSlots.id = 'many'; withSlots.accessories = {};
        for (let slot = 0; slot < 6; slot++) for (let k = 0; k < 3; k++)
          withSlots.accessories[`acc_${slot}_${k}`] = { description: 'Dots.', slot: `slot${slot}`, anchor: 'hair',
            parts: [{ id: 'dots', layer: 40, items: Array.from({ length: k + 1 }, () => ({ shape: 'circle', x: 0, y: 0, r: 3, fill: 'accessory' })) }] };
        let compiles = 0;
        const compile = mascot.parts.compile;
        mascot.parts = { ...mascot.parts, compile: (...a) => { compiles++; return compile(...a); } };
        const entry = mascot.runtime.compile(withSlots);
        const before = compiles;
        const bound = mascot.runtime.bound(entry, 'full');
        const used = compiles - before;
        const again = mascot.runtime.bound(entry, 'full') === bound && compiles - before === used;
        const original = mascot.runtime.bound(mascot.runtime.compile(base), 'full').painted_items;
        return { main, painted: bound.painted_items, used, again, frozen: Object.isFrozen(bound), original };
      })()"
    )
    # Six slots whose largest accessory paints three items each add 18 to the main anatomy.
    expect_equal(r$painted, r$main + 18)
    # One compile per accessory plus the main anatomy: nothing like the 4^6 selections a product would try.
    expect_lte(r$used, 19)
    expect_true(r$again)
    expect_true(r$frozen)
    # Tessa's own slot has the bow (five items) and the clip (four): the bound takes the larger.
    expect_equal(r$original, r$main + 5)
  })

  it("refuses a band whose componentwise bound is over the caps, before painting", {
    js <- page_with()
    r <- js(
      "(() => {
        const plain = structuredClone(T.load('tessa_two')); plain.accessories = {}; plain.wear = [];
        for (let slot = 0; slot < 10; slot++)
          plain.accessories[`acc_${slot}`] = { description: 'Dots.', slot: `slot${slot}`, anchor: 'hair',
            parts: [{ id: 'dots', layer: 40, items: Array.from({ length: 20 }, () => ({ shape: 'circle', x: 0, y: 0, r: 3, fill: 'accessory' })) }] };
        const out = {};
        try { mascot.runtime.check(plain, 'full'); out.code = 'no error'; } catch (e) { out.code = e.code; out.path = e.path; out.message = e.message; }
        try { mascot.runtime.check(T.load('tessa_two'), 'full'); out.fits = true; } catch (e) { out.fits = e.message; }
        return out;
      })()"
    )
    expect_identical(r$code, "budget")
    expect_identical(r$path, "$")
    expect_match(r$message, "full band paints too much \\(painted_items")
    expect_true(r$fits)
  })
})

describe("I1 the player's contract", {
  it("compiles a character once and never per frame", {
    js <- page_with()
    r <- js(
      "(() => {
        let parts = 0, faces = 0, tracks = 0;
        const count = (object, name, add) => ({ ...object, [name]: (...a) => { add(); return object[name](...a); } });
        mascot.parts = count(mascot.parts, 'compile', () => parts++);
        mascot.faces = count(mascot.faces, 'compile', () => faces++);
        mascot.motion = { ...mascot.motion, tracks: count(mascot.motion.tracks, 'compile', () => tracks++) };
        const p = T.player('alpha_two'), c = p.controller;
        const afterMount = { parts, faces, tracks };
        for (let f = 0; f < 120; f++) c.seek(f);
        c.update({ mood: 'happy' }); c.gesture('wave'); c.update({ colours: { shell: '#ff0000' } });
        c.update({ pose: null }); c.setBand('micro'); c.setBand('small'); c.redraw();
        const afterFrames = { parts, faces, tracks };
        // Asking again for a character already compiled costs a table lookup, never another serialisation.
        let serialised = 0;
        const stringify = JSON.stringify;
        JSON.stringify = (...a) => { serialised++; return stringify(...a); };
        const entry = mascot.runtime.compile(p.character);
        for (let i = 0; i < 50; i++) mascot.runtime.compile(p.character);
        JSON.stringify = stringify;
        // The same content parsed again, as a replaced element reads it, is the same character.
        const canvas = T.canvas();
        const reparsed = mascot.mount(canvas, JSON.parse(CHARACTERS.alpha_two.json), { x: 150, baseY: 270 });
        reparsed.pause();
        return { afterMount, afterFrames, afterReparse: { parts, faces, tracks }, ink: T.picture(canvas).ink,
          serialised, same: entry === mascot.runtime.compile(p.character) };
      })()"
    )
    expect_identical(r$afterFrames, r$afterMount)
    expect_identical(r$afterReparse, r$afterMount)
    expect_gt(r$ink, 1000)
    expect_equal(r$serialised, 0)
    expect_true(r$same)
  })

  it("validates a whole patch before any state change, and leaves the picture and notifications alone", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('tessa_two'), c = p.controller, errors = [];
        c.seek(30);
        const before = { sum: T.picture(p.canvas).sum, events: p.events.length, current: c.current() };
        const attempt = (patch) => { try { c.update(patch); errors.push('no error'); } catch (e) { errors.push(e.message); } };
        attempt({ mood: 'nowhere' });
        attempt({ mood: 'happy', colours: { body: 'not a colour' } });
        attempt({ mood: 'happy', colours: { nowhere: '#ffffff' } });
        attempt({ mood: 'happy', pose: { 'face.look_x': 2 } });
        attempt({ mood: 'happy', pose: { 'root.lift': 3 } });
        attempt({ mood: 'happy', reduced: 'yes' });
        attempt({ mood: 'happy', idle: 'no' });
        attempt({ mood: 'happy', messages: ['nowhere'] });
        attempt({ mood: 'happy', unknown: 1 });
        attempt({ character: { format_version: 1, parts: [] } });
        let gesture; try { c.gesture('nowhere'); gesture = 'no error'; } catch (e) { gesture = e.message; }
        let band; try { c.setBand('huge'); band = 'no error'; } catch (e) { band = e.message; }
        return { errors, gesture, band, sum: T.picture(p.canvas).sum === before.sum, events: p.events.length === before.events,
          same: c.current().mood === before.current.mood };
      })()"
    )
    messages <- unlist(r$errors)
    expect_length(messages, 10)
    expect_false(any(messages == "no error"))
    expect_match(messages[[1]], "update.mood")
    expect_match(messages[[2]], "update.colours.body")
    expect_match(messages[[3]], "update.colours.nowhere")
    expect_match(messages[[4]], "update.pose.face.look_x")
    expect_match(messages[[5]], "update.pose.root.lift")
    expect_match(messages[[6]], "update.reduced")
    expect_match(messages[[7]], "update.idle")
    expect_match(messages[[8]], "update.messages")
    expect_match(messages[[9]], "update.unknown")
    expect_match(messages[[10]], "update.character")
    expect_match(r$gesture, "unknown gesture 'nowhere'")
    expect_match(r$band, "use 'full', 'small' or 'micro'")
    expect_true(r$sum)
    expect_true(r$events)
    expect_true(r$same)
  })

  it("lets an explicit colour for a recoloured role win, and null clears an override", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('alpha_two', { mood: 'thinking', reduced: true }), c = p.controller;
        const light = () => geometryCalls.filter((g) => g.id !== 'shadow').at(-1).colours.light;
        const out = { recoloured: light() };
        c.update({ colours: { light: '#123456' } }); out.explicit = light();
        c.update({ colours: { light: null } }); out.cleared = light();
        c.update({ colours: null }); out.reset = light();
        return out;
      })()"
    )
    expect_identical(r$recoloured, "#ffb020")
    expect_identical(r$explicit, "#123456")
    expect_identical(r$cleared, "#ffb020")
    expect_identical(r$reset, "#ffb020")
  })

  it("pauses, resumes, holds visibility and destroys without drawing or notifying afterwards", {
    js <- page_with()
    r <- js(
      "(async () => {
        const canvas = T.canvas(), character = T.load('alpha_two'), events = [];
        const c = mascot.mount(canvas, character, { x: 150, baseY: 270, reduced: false, onChange: (s) => events.push(s) });
        const out = {};
        await T.frames(4); out.running = T.picture(canvas).sum;
        c.pause(); const frozen = T.picture(canvas).sum; await T.frames(6); out.frozen = T.picture(canvas).sum === frozen;
        c.play(); await T.frames(6); out.resumed = T.picture(canvas).sum !== frozen;
        c.holdVisibility(true); const held = T.picture(canvas).sum; await T.frames(6); out.held = T.picture(canvas).sum === held;
        c.holdVisibility(false); await T.frames(6); out.released = T.picture(canvas).sum !== held;
        c.destroy(); const gone = T.picture(canvas).sum, count = events.length;
        c.update({ mood: 'happy' }); c.seek(50); c.gesture('wave'); c.redraw(); c.destroy();
        await T.frames(4);
        out.inert = T.picture(canvas).sum === gone && events.length === count;
        out.readable = c.current().character;
        return out;
      })()"
    )
    expect_true(r$frozen)
    expect_true(r$resumed)
    expect_true(r$held)
    expect_true(r$released)
    expect_true(r$inert)
    expect_identical(r$readable, "alpha_two")
  })

  it("follows the visitor's reduced-motion preference as it changes, and never replays a discarded action", {
    js <- page_with()
    session <- attr(js, "session")
    r <- js(
      "(() => {
        window.live = mascot.mount(T.canvas(), T.load('alpha_two'), { x: 150, baseY: 270 });
        window.live.update({ mood: 'happy' });
        return window.live.current().mood;
      })()"
    )
    # The change is under way: the previous mood is still shown.
    expect_identical(r, "idle")
    session$Emulation$setEmulatedMedia(features = list(list(name = "prefers-reduced-motion", value = "reduce")))
    js("T.frames(2)")
    expect_identical(js("window.live.current().mood"), "happy")
    session$Emulation$setEmulatedMedia(features = list(list(name = "prefers-reduced-motion", value = "no-preference")))
    js("T.frames(4)")
    expect_identical(js("window.live.current().mood"), "happy")
    expect_false(js("window.live.current().swapping"))
  })
})

# A gesture trigger runs a track-mode kit effect (only those have frames). This gives the kit's sparkle one: 30 frames.
track_sparkle_js <- paste(
  "window.trackSparkle = (ch) => { const k = ch.face.kit_definition.effects.sparkle;",
  "ch.face.kit_definition.effects.sparkle = { ...k, mode: 'track', frames: 30, tracks: {",
  "opacity: [[0, 0], [0.2, 1], [1, 0]], scale_x: [[0, 1], [1, 1]], scale_y: [[0, 1], [1, 1]] } }; return ch; };"
)

describe("I1 recovery eases numbers and switches choices", {
  it("switches root.flip at halfway and eases a numeric channel in recover()", {
    js <- page_with()
    r <- js(
      "(() => {
        const entry = mascot.runtime.compile(T.load('alpha_two'));
        const from = { 'root.flip': 1, 'root.rotate': 0 }, to = { 'root.flip': -1, 'root.rotate': 1 };
        const at = (p) => mascot.runtime.recover(entry, from, to, p);
        return { early: at(0.4), late: at(0.6), eased: at(0.6)['root.rotate'],
          reference: mascot.motion.shared.recoverPose(from, to, 0.6)['root.rotate'] };
      })()"
    )
    expect_equal(r$early[["root.flip"]], 1)
    expect_equal(r$late[["root.flip"]], -1)
    # The numeric channel keeps the easing the swap uses: the same value recoverPose gives, strictly between the ends.
    expect_equal(r$eased, r$reference)
    expect_gt(r$eased, 0)
    expect_lt(r$eased, 1)
  })

  it("reverses a swap between moods with different root.flip without a flip value in between", {
    js <- page_with()
    r <- js(
      "(() => {
        const p = T.player('tessa_mirror'), c = p.controller, errors = [], flips = {};
        c.seek(0); c.update({ character: T.load('alpha_two') });
        c.seek(10); c.update({ character: T.load('tessa_mirror'), mood: 'celebrating' });
        for (let f = 10; f <= 40; f++) {
          try {
            c.seek(f);
            // A channel the frame leaves out is the default, 1.
            flips[f] = frames.filter((x) => x.id !== 'shadow').at(-1).channels['root.flip'] ?? 1;
          } catch (e) { errors.push([f, e.message]); }
        }
        return { errors, flips, character: c.current().character };
      })()"
    )
    expect_length(r$errors, 0)
    flips <- unlist(r$flips)
    expect_true(all(flips %in% c(-1, 1)))
    # Idle flips the mirror (-1), celebrating does not (1): the reversal starts at -1 and ends at 1.
    expect_equal(flips[["10"]], -1)
    expect_equal(flips[["40"]], 1)
    expect_identical(r$character, "tessa_mirror")
  })
})

describe("I1 a band change during a swap checks both characters", {
  it("refuses a band that either the incoming or the outgoing character is over, and keeps the band", {
    js <- page_with()
    r <- js(
      "(() => {
        const mountOf = (ch) => { const c = mascot.mount(T.canvas(), ch, { x: 150, baseY: 270, reduced: false }); c.pause(); return c; };
        const planted = structuredClone(T.load('alpha_two')); planted.id = 'planted'; planted.name = 'Planted';
        planted.parts.find((part) => part.id === 'torso').items.push(
          ...Array.from({ length: 40 }, () => ({ shape: 'circle', x: 0, y: -20, r: 4, fill: 'shell' })));
        const attempt = (c, band) => { try { c.setBand(band); return 'no error'; } catch (e) { return e.message; } };
        const out = {};
        // Incoming over the micro budget, outgoing (alpha_two) within it.
        const incoming = mountOf(T.load('alpha_two'));
        incoming.seek(0); incoming.update({ character: planted });
        out.incomingError = attempt(incoming, 'micro');
        out.incomingBandKept = incoming.setBand('full') === false;
        // Outgoing over the micro budget (still shown while it fades), incoming within it.
        const outgoing = mountOf(planted);
        outgoing.seek(0); outgoing.update({ character: T.load('alpha_two') });
        outgoing.seek(10);
        out.outgoingShown = outgoing.current().character;
        out.outgoingError = attempt(outgoing, 'micro');
        out.outgoingBandKept = outgoing.setBand('full') === false;
        // Once the swap is over, the incoming character alone decides.
        outgoing.seek(70);
        out.afterSwap = outgoing.setBand('micro');
        return out;
      })()"
    )
    expect_match(r$incomingError, "micro band paints too much")
    expect_true(r$incomingBandKept)
    expect_identical(r$outgoingShown, "planted")
    expect_match(r$outgoingError, "micro band paints too much")
    expect_true(r$outgoingBandKept)
    expect_true(r$afterSwap)
  })
})

describe("I1 a frame that cannot be drawn stops the loop and keeps the pixels", {
  it("stops the animation, keeps the last pixels and logs once, without an error leaving the frame callback", {
    js <- page_with(
      before_mount = "window.logged = []; console.error = (...a) => logged.push(String(a[0]));
        window.uncaught = []; window.addEventListener('error', (e) => uncaught.push(e.message));"
    )
    r <- js(
      "(async () => {
        const canvas = T.canvas(), c = mascot.mount(canvas, T.load('alpha_two'), { x: 150, baseY: 270, reduced: false });
        for (let i = 0; i < 200 && T.picture(canvas).ink === 0; i++) await T.frames(1);
        for (let i = 0; i < 20; i++) await T.frames(1);
        const before = T.picture(canvas).sum, real = mascot.parts.frame, saved = mascot.parts;
        let calls = 0;
        // Every frame from now on cannot be prepared: the first one that is drawn throws before the canvas is cleared.
        mascot.parts = { ...saved, frame: (...a) => { calls++; throw new Error('cannot draw this frame'); } };
        try {
          for (let i = 0; i < 200 && calls === 0; i++) await T.frames(1);
          for (let i = 0; i < 10; i++) await T.frames(1);
        } finally {
          mascot.parts = { ...saved, frame: real };
        }
        return { calls, same: T.picture(canvas).sum === before, logged: logged.length, text: logged[0] ?? null,
          uncaught: uncaught.length, ink: T.picture(canvas).ink };
      })()"
    )
    expect_equal(r$calls, 1)
    expect_true(r$same)
    expect_equal(r$logged, 1)
    expect_match(r$text, "a frame could not be drawn")
    expect_equal(r$uncaught, 0)
    expect_gt(r$ink, 1000)
  })
})

describe("I1 gesture effects", {
  it("keeps the animation running while a triggered effect is still showing after the gesture's movement has ended", {
    js <- page_with()
    js(track_sparkle_js)
    r <- js(
      "(() => {
        const character = window.trackSparkle(structuredClone(T.load('alpha_two')));
        character.gestures.wave.effects = [{ at: 0.8, effect: 'sparkle', anchor: 'sparkle' }];
        const queue = new Map(); let nextId = 0;
        window.requestAnimationFrame = (fn) => { queue.set(++nextId, fn); return nextId; };
        window.cancelAnimationFrame = (id) => queue.delete(id);
        // Idle motion off: only the gesture and its effects can keep the animation running.
        const c = mascot.mount(T.canvas(), character, { x: 150, baseY: 270, reduced: false, idle: false });
        effectCalls.length = 0;
        c.gesture('wave');
        const step = 1000 / 30 + 0.01, busy = [], effectFrames = [];
        let seen = 0;
        for (let k = 1; k <= 120 && queue.size; k++) {
          const [id, fn] = queue.entries().next().value;
          queue.delete(id);
          // Timestamps 1000 + k frames: the frame number is k, so frame k is drawn on the k-th call.
          fn(1000 + k * step);
          busy.push([k, queue.size > 0]);
          if (effectCalls.length > seen) effectFrames.push(k);
          seen = effectCalls.length;
        }
        return { lastBusy: Math.max(...busy.filter((b) => b[1]).map((b) => b[0]), 0),
          lastEffect: Math.max(...effectFrames, 0), effectFrames: effectFrames.length };
      })()"
    )
    # The wave is 30 frames long; the sparkle starts at frame 24 and is still drawn after the movement has ended,
    # and the loop runs for as long as it is drawn.
    expect_gt(r$lastEffect, 30)
    expect_gte(r$lastBusy, r$lastEffect)
    expect_gt(r$effectFrames, 0)
  })

  it("draws each trigger of one effect at its own anchor, two triggers at two anchors as two instances", {
    js <- page_with()
    js(track_sparkle_js)
    r <- js(
      "(() => {
        const withTriggers = (anchors) => {
          const ch = window.trackSparkle(structuredClone(T.load('alpha_two')));
          ch.gestures.wave.effects = anchors.map((anchor) => ({ at: 0.1, effect: 'sparkle', anchor }));
          return ch;
        };
        const shot = (anchors) => {
          const canvas = T.canvas(), c = mascot.mount(canvas, withTriggers(anchors), { x: 150, baseY: 270, reduced: false });
          c.pause(); effectCalls.length = 0;
          c.seek(0); c.gesture('wave'); c.seek(4);
          return { anchors: effectCalls.map((x) => x.options.effect_anchors?.sparkle ?? null), picture: T.picture(canvas) };
        };
        const both = shot(['crown', 'chest']), crown = shot(['crown', 'crown']), chest = shot(['chest', 'chest']);
        return { both: both.anchors, ink: both.picture.ink, same: crown.picture.sum === chest.picture.sum,
          crownAnchors: crown.anchors, chestAnchors: chest.anchors };
      })()"
    )
    expect_identical(unlist(r$both), c("crown", "chest"))
    expect_gt(r$ink, 0)
    # Each trigger draws at its own anchor: putting both triggers at the crown or at the chest paints differently.
    expect_false(r$same)
    expect_identical(unlist(r$crownAnchors), c("crown", "crown"))
    expect_identical(unlist(r$chestAnchors), c("chest", "chest"))
  })
})

describe("I1 seeking before the action", {
  it("draws a frame before the action's frame without throwing, with a continuous effect at elapsed 0", {
    js <- page_with()
    r <- js(
      "(() => {
        const c = mascot.mount(T.canvas(), T.load('alpha_two'), { x: 150, baseY: 270, reduced: false });
        c.pause();
        c.seek(0); c.update({ mood: 'celebrating' });
        c.seek(30); c.update({ mood: 'happy' });
        effectCalls.length = 0;
        const out = {};
        try { c.seek(5); out.error = 'no error'; } catch (e) { out.error = e.message; }
        out.sparkle = effectCalls.map((x) => x.controls.sparkle);
        out.frame = effectCalls.map((x) => x.options.frame);
        return out;
      })()"
    )
    expect_identical(r$error, "no error")
    # The sparkle of the mood the character is leaving still shows, at the clamped elapsed of 0.
    expect_true(length(r$sparkle) > 0)
    expect_true(all(unlist(r$sparkle) == 1))
    expect_true(all(unlist(r$frame) == 0))
  })
})

describe("I1 host replacement without a mood", {
  it("rejects a format-v1 character that replaces a legacy one with the controller's message, not a compile error", {
    blob_json <- paste(
      readLines(testthat::test_path("fixtures", "characters", "blob.json"), encoding = "UTF-8"),
      collapse = "\n"
    )
    tessa_json <- paste(
      readLines(system.file("format", "characters", "tessa.json", package = "mascot")),
      collapse = "\n"
    )
    m <- as.character(mascot("b", motion = FALSE, placement = "inline"))
    m <- sub('data-character="tessa"', 'data-character="blob"', m, fixed = TRUE)
    m <- sub('data-mascot-character="tessa"', 'data-mascot-character="blob"', m, fixed = TRUE)
    m <- sub(tessa_json, blob_json, m, fixed = TRUE)
    js <- page_with(tags = list(shiny::HTML(m)))
    r <- js(
      "(() => {
        const el = document.getElementById('b'), warnings = [], original = console.warn;
        console.warn = (...a) => warnings.push(a.join(' '));
        try {
          mascot.host.receive({ id: 'b', patch: { character: { id: 'alpha_two', name: 'Alpha Two', json: CHARACTERS.alpha_two.json } } });
        } finally { console.warn = original; }
        return { warnings, character: mascot.host.state(el).character };
      })()"
    )
    expect_length(r$warnings, 1)
    expect_match(r$warnings[[1]], "a format-v1 character cannot replace a legacy character here")
    expect_identical(r$character, "blob")
  })
})
