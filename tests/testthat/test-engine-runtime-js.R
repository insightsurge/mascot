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

  it("draws default Tessa through format-v1 runtime modules", {
    host <- local_host_page(size = 160)
    install_runtime_helpers(host)
    host("T.frames(3)")
    expected <- host("T.picture(document.querySelector('#a canvas'))")
    js <- local_runtime_page(
      tags = list(mascot("a", size = 160, placement = "inline")),
      before_mount = spies_js
    )
    install_runtime_helpers(js)
    js("T.frames(3)")
    result <- js(
      "({picture: T.picture(document.querySelector('#a canvas')), frames: frames.length,
      geometry: geometryCalls.length, faces: faceCalls.length})"
    )
    expect_gt(expected$ink, 1000)
    expect_gt(result$picture$ink, 1000)
    expect_gt(result$frames, 0)
    expect_gt(result$geometry, 0)
    expect_gt(result$faces, 0)
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

# A harness for the player contract: animation frames run only when the test fires them (a timestamp in ms; the player
# turns it into frames at 30 per second), the reduced-motion preference is a stub the test sets, and the harness counts
# each clear of a canvas (one per drawn frame), the opacity of each composite and the last frame number the player
# asked its tracks for. `a` is Alpha Two and `b` is Alpha Three. Players are destroyed and the stubs restored afterwards.
contract_js <- function(code) {
  checkmate::assert_string(code)
  paste(
    "(() => {",
    "const raf = window.requestAnimationFrame, cancel = window.cancelAnimationFrame, match = window.matchMedia;",
    "const motion = mascot.motion, queued = new Map(), listeners = new Set(), players = [], composites = [];",
    "let id = 0, clears = 0, lastFrame = null;",
    "const media = { matches: false, addEventListener: (type, fn) => listeners.add(fn),",
    "  removeEventListener: (type, fn) => listeners.delete(fn) };",
    "window.requestAnimationFrame = (fn) => { queued.set(++id, fn); return id; };",
    "window.cancelAnimationFrame = (n) => queued.delete(n); window.matchMedia = () => media;",
    "const frameAt = motion.tracks.frameAt;",
    "mascot.motion = { ...motion, tracks: { ...motion.tracks,",
    "  frameAt: (tracks, state, n, options) => { lastFrame = n; return frameAt(tracks, state, n, options); } } };",
    "const a = T.load('alpha_two'), b = T.load('alpha_three');",
    "const fire = (t) => { const batch = [...queued.values()]; queued.clear(); batch.forEach((fn) => fn(t)); };",
    "const preference = (value) => { media.matches = value; listeners.forEach((fn) => fn({ matches: value })); };",
    "const attempt = (fn) => { try { fn(); } catch (e) { return e.message; } return 'no error'; };",
    "const mount = (options = {}, character = a) => {",
    "  const c = T.canvas(), ctx = c.getContext('2d'), clear = ctx.clearRect.bind(ctx), image = ctx.drawImage.bind(ctx);",
    "  ctx.clearRect = (...args) => { clears++; return clear(...args); };",
    "  ctx.drawImage = (...args) => { composites.push(ctx.globalAlpha); return image(...args); };",
    "  const p = mascot.mount(c, character, { x: 150, baseY: 270, ...options }); players.push(p); return { c, ctx, p };",
    "};",
    "try {",
    code,
    "} finally {",
    "  players.forEach((p) => p.destroy()); mascot.motion = motion;",
    "  window.requestAnimationFrame = raf; window.cancelAnimationFrame = cancel; window.matchMedia = match;",
    "} })()",
    sep = "\n"
  )
}

describe("the player contract on a format-v1 character", {
  it("refuses an onChange that is not a function before drawing or adding a listener", {
    js <- page_with()
    r <- js(contract_js(
      "const errors = [null, 42, 'bad', {}].map((onChange) => attempt(() => mount({ onChange })));
      return { errors, drawn: clears, listeners: listeners.size, queue: queued.size };"
    ))
    expect_identical(unlist(r$errors), rep("mascot: onChange: expected a function", 4))
    expect_equal(r$drawn, 0)
    expect_equal(r$listeners, 0)
    expect_equal(r$queue, 0)
  })

  it("reports a throwing onChange once through console.error and carries on playing to rest", {
    js <- page_with()
    r <- js(contract_js(
      "const error = console.error; let reports = 0, callbacks = 0;
      console.error = (...args) => { if (args[0] === 'mascot: onChange callback failed') reports++; };
      try {
        const { p } = mount({ onChange: () => { callbacks++; throw new Error('host failed'); } });
        p.update({ character: b }); fire(0); fire(1000); fire(2000); fire(5000); fire(6000);
        const result = { reports, callbacks, current: p.current(), rest: lastFrame, queue: queued.size };
        p.destroy(); p.seek(0); p.update({ mood: 'happy' }); result.afterDestroy = callbacks;
        return result;
      } finally { console.error = error; }"
    ))
    expect_equal(r$reports, 1)
    # Mounted (a, still), the swap starts (a, swapping), b fades in at frame 30, the swap ends at frame 60.
    expect_equal(r$callbacks, 4)
    expect_identical(r$current$character, "alpha_three")
    expect_false(r$current$swapping)
    # The swap started a 150-frame activity window (five seconds at 30 fps); the player rests at its end.
    expect_equal(r$rest, 150)
    expect_equal(r$queue, 0)
    expect_equal(r$afterDestroy, 4)
  })

  it("lets an onChange callback update or destroy its player, with no stale notification or animation frame", {
    js <- page_with()
    r <- js(contract_js(
      "let p, callbacks = 0; const events = [];
      const mounted = mount({ onChange: (s) => {
        callbacks++; events.push(`${s.character}:${s.swapping}`);
        if (p && s.swapping && s.character === a.id) p.update({ reduced: true });
        else if (p && s.character === b.id && !s.swapping) p.destroy();
      } });
      p = mounted.p; p.update({ character: b }); fire(0); p.redraw(); fire(100);
      return { callbacks, events, queue: queued.size, listeners: listeners.size, current: p.current() };"
    ))
    # Reduced motion finishes the swap at once, inside the callback that announced it; the next one destroys.
    expect_equal(r$callbacks, 3)
    expect_identical(unlist(r$events), c("alpha_two:false", "alpha_two:true", "alpha_three:false"))
    expect_equal(r$queue, 0)
    expect_equal(r$listeners, 0)
    expect_identical(r$current$character, "alpha_three")
  })

  it("keeps a swap's timeline through pause and play in either phase, and ignores a stale animation frame", {
    js <- page_with()
    r <- js(contract_js(
      "const rows = [];
      for (const n of [15, 45]) {
        const { p } = mount(); p.update({ character: b }); fire(0); fire((n * 1000) / 30);
        p.pause(); const paused = clears; fire(10000);
        const frozen = clears === paused && queued.size === 0;
        p.play(); fire(20000); fire(20500); const resumed = lastFrame - n;
        const stale = [...queued.values()][0], snapshot = JSON.stringify(p.current()), count = clears;
        p.destroy(); stale(30000);
        rows.push({ frozen, resumed, inert: clears === count && JSON.stringify(p.current()) === snapshot,
          queue: queued.size });
      }
      const { p } = mount(); p.update({ character: b }); fire(0); fire(500); p.pause(); p.play(); fire(1000); fire(30000);
      return { rows, rest: lastFrame, restQueue: queued.size, listeners: listeners.size };"
    ))
    for (row in r$rows) {
      expect_true(row$frozen)
      # Half a second after play is 15 frames on from where pause stopped: the paused time is not counted.
      expect_equal(row$resumed, 15)
      expect_true(row$inert)
      expect_equal(row$queue, 0)
    }
    # Play during a swap does not renew activity: the player still rests at the window the swap opened at frame 0.
    expect_equal(r$rest, 150)
    expect_equal(r$restQueue, 0)
    # Only the last player is still alive and listening.
    expect_equal(r$listeners, 1)
  })

  it("redraws the same picture at rest and in both swap phases without moving time, state or animation frames", {
    js <- page_with()
    r <- js(contract_js(
      "const { c, p } = mount(); const rows = [];
      for (const n of [0, 21, 51, 200]) {
        if (n === 21) { p.seek(6); p.update({ character: b }); }
        p.seek(n);
        const image = c.toDataURL(), snapshot = JSON.stringify(p.current()), seen = lastFrame;
        const requests = [...queued.entries()], count = clears;
        p.redraw();
        rows.push({ n, swapping: p.current().swapping, picture: image === c.toDataURL(),
          state: snapshot === JSON.stringify(p.current()), frame: lastFrame === seen, drawn: clears - count,
          raf: requests.length === queued.size && requests.every(([key, fn]) => queued.get(key) === fn) });
      }
      return rows;"
    ))
    expect_identical(vapply(r, function(x) x$swapping, logical(1)), c(FALSE, TRUE, TRUE, FALSE))
    for (row in r) {
      expect_true(row$picture, info = row$n)
      expect_true(row$state, info = row$n)
      expect_true(row$frame, info = row$n)
      expect_equal(row$drawn, 1, info = row$n)
      expect_true(row$raf, info = row$n)
    }
  })

  it("redraws without resetting the running clock, and draws nothing new while paused", {
    js <- page_with()
    r <- js(contract_js(
      "const { p } = mount(); fire(0); fire(200); const first = lastFrame;
      p.redraw(); fire(300); const next = lastFrame;
      p.pause(); const snapshot = JSON.stringify(p.current()), pausedQueue = queued.size;
      p.redraw(); fire(10000);
      return { first, next, paused: lastFrame, unchanged: snapshot === JSON.stringify(p.current()), pausedQueue,
        queue: queued.size };"
    ))
    # 200 ms is frame 6 and 300 ms frame 9, counted from the same origin before and after the redraw.
    expect_equal(r$first, 6)
    expect_equal(r$`next`, 9)
    expect_equal(r$paused, 9)
    expect_true(r$unchanged)
    expect_equal(r$pausedQueue, 0)
    expect_equal(r$queue, 0)
  })

  it("accepts colour overrides at the edges of each form and refuses malformed or out-of-range ones whole", {
    js <- page_with()
    r <- js(contract_js(
      "const { c, p } = mount(); p.pause();
      const drawn = () => geometryCalls.filter((g) => g.id !== 'shadow').at(-1).colours.shell;
      const valid = ['#ABC', '#ab12CD', 'rgb(0, 255, 2.5)', 'rgba(255, 0, .5, 0)', 'rgba(1,2,3,1)', 'rgba(1,2,3,.25)'];
      const accepted = valid.map((value) => [attempt(() => p.update({ colours: { shell: value } })), drawn()]);
      const before = { sum: T.picture(c).sum, current: JSON.stringify(p.current()), clears, shell: drawn() };
      const invalid = ['rgb(1..2, 2, 3)', 'rgb(256, 2, 3)', 'rgb(-1, 2, 3)', 'rgb(1, 2, 3, .5)', 'rgba(1, 2, 3)',
        'rgba(1, 2, 3, 1.1)', 'rgba(1, 2, 3, .)', 'rgba(1, 2, 3, -0.1)', '#abcd', 'red'];
      const refused = invalid.map((value) => attempt(() => p.update({ character: b, colours: { shell: value } })));
      return { valid, accepted, invalid, refused, unchanged: T.picture(c).sum === before.sum &&
        JSON.stringify(p.current()) === before.current && clears === before.clears && drawn() === before.shell };"
    ))
    for (i in seq_along(r$valid)) {
      expect_identical(r$accepted[[i]][[1]], "no error", info = r$valid[[i]])
      expect_identical(r$accepted[[i]][[2]], r$valid[[i]], info = r$valid[[i]])
    }
    for (i in seq_along(r$invalid)) {
      expect_match(r$refused[[i]], "update.colours.shell", fixed = TRUE, info = r$invalid[[i]])
      expect_match(r$refused[[i]], r$invalid[[i]], fixed = TRUE, info = r$invalid[[i]])
    }
    expect_true(r$unchanged)
  })

  it("keeps two players on two canvases independent, and each follows the visitor's preference", {
    js <- page_with()
    r <- js(contract_js(
      "const one = mount(), two = mount(); one.p.pause(); two.p.pause();
      two.p.seek(15); const before = T.picture(two.c).sum;
      one.p.update({ character: b, colours: { shell: '#123456' } }); one.p.seek(15);
      const out = { one: one.p.current(), two: two.p.current() };
      two.p.seek(15); out.twoSame = T.picture(two.c).sum === before;
      one.p.destroy(); out.listeners = listeners.size;
      two.p.seek(20); out.twoInk = T.picture(two.c).ink;
      preference(true); two.p.update({ character: b });
      out.reduced = two.p.current();
      return out;"
    ))
    expect_identical(r$one$character, "alpha_two")
    expect_true(r$one$swapping)
    expect_identical(r$two$character, "alpha_two")
    expect_false(r$two$swapping)
    expect_true(r$twoSame)
    expect_equal(r$listeners, 1)
    expect_gt(r$twoInk, 1000)
    # Under the visitor's reduced-motion preference the swap is an instant change.
    expect_identical(r$reduced$character, "alpha_three")
    expect_false(r$reduced$swapping)
  })

  it("refuses a description without format_version 1 in mount(), update() and the host, before any change", {
    js <- page_with()
    r <- js(contract_js(
      "const plain = { id: 'plain', name: 'Plain', format_version: 2 };
      const mounted = attempt(() => mount({}, plain));
      const afterMount = { clears, listeners: listeners.size, queue: queued.size };
      const { p } = mount(); p.pause(); const before = JSON.stringify(p.current());
      const updated = attempt(() => p.update({ character: plain }));
      const el = document.getElementById('a'), warnings = [], warn = console.warn;
      console.warn = (...args) => warnings.push(args.join(' '));
      try {
        mascot.host.receive({ id: 'a', patch: { character: { id: 'plain', name: 'Plain', json: JSON.stringify(plain) } } });
      } finally { console.warn = warn; }
      return { mounted, afterMount, updated, unchanged: JSON.stringify(p.current()) === before, warnings,
        hosted: mascot.host.state(el).character };"
    ))
    expect_identical(r$mounted, "mascot: expected a character with format_version 1")
    expect_equal(r$afterMount$clears, 0)
    expect_equal(r$afterMount$listeners, 0)
    expect_equal(r$afterMount$queue, 0)
    expect_identical(r$updated, "mascot: update.character: expected a character with format_version 1")
    expect_true(r$unchanged)
    expect_length(r$warnings, 1)
    expect_match(r$warnings[[1]], "expected a character with format_version 1", fixed = TRUE)
    expect_identical(r$hosted, "alpha_two")
  })
})

describe("the swapTiming mount option", {
  it("refuses a value that is not an object of positive finite frame counts, before drawing", {
    js <- page_with()
    r <- js(contract_js(
      "const values = [null, 'slow', [], { typo: 1 }, { outFrames: 0 }, { inFrames: -1 }, { outFrames: Infinity },
        { inFrames: NaN }, { inFrames: '30' }];
      const errors = values.map((swapTiming) => attempt(() => mount({ swapTiming })));
      return { errors, drawn: clears, listeners: listeners.size };"
    ))
    errors <- unlist(r$errors)
    expect_length(errors, 9)
    expect_true(all(startsWith(errors, "mascot: swapTiming")), info = paste(errors, collapse = " | "))
    expect_match(errors[[2]], "expected an object")
    expect_match(errors[[3]], "expected an object")
    expect_match(errors[[4]], "swapTiming.typo: unknown field 'typo'", fixed = TRUE)
    for (i in 5:9) {
      expect_match(errors[[i]], "expected a positive finite frame duration", info = i)
    }
    expect_equal(r$drawn, 0)
    expect_equal(r$listeners, 0)
  })

  # The character shown at each frame of a swap that starts at frame 0, and whether it is still swapping.
  swap_rows_js <- function(timing, frames) {
    sprintf(
      "const { p } = mount({ swapTiming: %s }); p.pause(); p.update({ character: b });
      return [%s].map((f) => { p.seek(f); const s = p.current(); return `${f}:${s.character === a.id ? 'a' : 'b'}:${s.swapping}`; });",
      timing,
      paste(frames, collapse = ", ")
    )
  }

  it("rounds each duration to whole frames, at least one", {
    js <- page_with()
    # 2.4 rounds to 2 frames out and 0.2 to 0, raised to 1 frame in: a three-frame swap.
    expect_identical(
      unlist(js(contract_js(swap_rows_js("{ outFrames: 2.4, inFrames: 0.2 }", 0:4)))),
      c("0:a:true", "1:a:true", "2:b:true", "3:b:false", "4:b:false")
    )
    # 0.4 is raised to 1 frame out and 2.6 rounds to 3 in: a four-frame swap.
    expect_identical(
      unlist(js(contract_js(swap_rows_js("{ outFrames: 0.4, inFrames: 2.6 }", 0:5)))),
      c("0:a:true", "1:b:true", "2:b:true", "3:b:true", "4:b:false", "5:b:false")
    )
  })

  it("caps each duration at 150 frames before fitting the swap into the 150-frame activity window", {
    js <- page_with()
    # Capped, 1000 and 30 become 150 and 30; fitted to 150 frames, the fade-out takes 150 * 150 / 180 = 125 of them.
    # Uncapped it would take round(150 * 1000 / 1030) = 146.
    expect_identical(
      unlist(js(contract_js(swap_rows_js("{ outFrames: 1000, inFrames: 30 }", c(124, 125, 149, 150))))),
      c("124:a:true", "125:b:true", "149:b:true", "150:b:false")
    )
    # Very large values neither overflow nor outlast the window: 150 and 150 share it equally.
    expect_identical(
      unlist(js(contract_js(swap_rows_js("{ outFrames: 1e300, inFrames: 1e300 }", c(74, 75, 149, 150))))),
      c("74:a:true", "75:b:true", "149:b:true", "150:b:false")
    )
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

describe("drawing-work bound parity and newly counted components (#304)", {
  it("reproduces R's drawing-work bounds for every canonical fixture and Tessa recipe in all bands", {
    skip_without_chrome()
    js <- page_with()
    expected <- jsonlite::fromJSON(test_path("fixtures", "format", "work-expected.json"), simplifyVector = FALSE)

    for (row in expected$rows) {
      fixture_name <- if (row$character == "study_bot") "study_bot-resolved" else row$character
      json_text <- readLines(
        test_path("fixtures", "format", paste0(fixture_name, ".json")),
        encoding = "UTF-8",
        warn = FALSE
      )
      json_str <- paste(json_text, collapse = "\n")

      browser_bound <- js(sprintf(
        "(() => {
          const character = JSON.parse(%s);
          const entry = mascot.runtime.compile(character);
          return mascot.runtime.bound(entry, '%s');
        })()",
        jsonlite::toJSON(json_str, auto_unbox = TRUE),
        row$band
      ))

      for (metric in setdiff(names(row$maxima), "inflated_glow_area_ratio")) {
        expect_equal(
          browser_bound[[metric]],
          row$maxima[[metric]],
          info = paste(row$character, row$band, metric)
        )
      }
      expect_equal(
        browser_bound[["inflated_glow_area_ratio"]],
        row$maxima[["inflated_glow_area_ratio"]],
        tolerance = 1e-12,
        info = paste(row$character, row$band, "inflated_glow_area_ratio")
      )
    }

    tessa_recipe_path <- system.file("format", "characters", "tessa.json", package = "mascot", mustWork = TRUE)
    tessa_raw <- jsonlite::fromJSON(tessa_recipe_path, simplifyVector = FALSE)
    tessa_data <- character_format_resolve(tessa_raw)
    tessa_graph <- character_format_references(tessa_data)
    tessa_beh <- character_format_behaviour(tessa_data, tessa_graph)
    tessa_json_str <- paste(readLines(tessa_recipe_path, encoding = "UTF-8", warn = FALSE), collapse = "\n")

    for (band in c("full", "small", "micro")) {
      r_work <- character_format_work(tessa_data, tessa_graph, tessa_beh, band)
      browser_bound <- js(sprintf(
        "(() => {
          const character = JSON.parse(%s);
          const entry = mascot.runtime.compile(character);
          return mascot.runtime.bound(entry, '%s');
        })()",
        jsonlite::toJSON(tessa_json_str, auto_unbox = TRUE),
        band
      ))

      for (metric in names(r_work)) {
        if (metric == "inflated_glow_area_ratio") {
          expect_equal(
            browser_bound[[metric]],
            r_work[[metric]],
            tolerance = 1e-12,
            info = paste("tessa.json", band, metric)
          )
        } else {
          expect_equal(browser_bound[[metric]], unname(r_work[[metric]]), info = paste("tessa.json", band, metric))
        }
      }
    }
  })

  it("counts face components including brows, eye primitives, lashes, eyelid, inset clip, mouth, blush and glow", {
    skip_without_chrome()
    js <- page_with()
    tessa_json <- paste(
      readLines(test_path("fixtures", "format", "tessa.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    r <- js(sprintf(
      "(() => {
        const full = JSON.parse(%s);
        const withoutFace = structuredClone(full);
        delete withoutFace.face;
        delete withoutFace.effects;
        for (const m of Object.values(withoutFace.moods ?? {})) {
          delete m.face;
          delete m.effects;
        }
        const entryFull = mascot.runtime.compile(full);
        const entryWithout = mascot.runtime.compile(withoutFace);
        const bFull = mascot.runtime.bound(entryFull, 'full');
        const bWithout = mascot.runtime.bound(entryWithout, 'full');
        return {
          paintedDiff: bFull.painted_items - bWithout.painted_items,
          passesDiff: bFull.paint_passes - bWithout.paint_passes,
          clipsDiff: bFull.clip_applications - bWithout.clip_applications,
          numbersDiff: bFull.path_numbers - bWithout.path_numbers
        };
      })()",
      jsonlite::toJSON(tessa_json, auto_unbox = TRUE)
    ))

    expect_equal(r$paintedDiff, 27)
    expect_equal(r$passesDiff, 32)
    expect_equal(r$clipsDiff, 2)
    expect_equal(r$numbersDiff, 181)
  })

  it("counts statically declared kit effects and gesture-triggered effects separately", {
    skip_without_chrome()
    js <- page_with()
    visor_json <- paste(
      readLines(test_path("fixtures", "format", "alpha_visor.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    r_static <- js(sprintf(
      "(() => {
        const full = JSON.parse(%s);
        const withoutStatic = structuredClone(full);
        withoutStatic.effects = {};
        for (const m of Object.values(withoutStatic.moods ?? {})) {
          delete m.effects;
        }
        const bFull = mascot.runtime.bound(mascot.runtime.compile(full), 'full');
        const bWithout = mascot.runtime.bound(mascot.runtime.compile(withoutStatic), 'full');
        return {
          paintedDiff: bFull.painted_items - bWithout.painted_items,
          passesDiff: bFull.paint_passes - bWithout.paint_passes,
          numbersDiff: bFull.path_numbers - bWithout.path_numbers
        };
      })()",
      jsonlite::toJSON(visor_json, auto_unbox = TRUE)
    ))

    expect_equal(r_static$paintedDiff, 2)
    expect_equal(r_static$passesDiff, 3)
    expect_equal(r_static$numbersDiff, 26)

    r_triggered <- js(sprintf(
      "(() => {
        const full = JSON.parse(%s);
        const withTriggered = structuredClone(full);
        withTriggered.gestures.nod.effects = [{ at: 0.5, effect: 'sweat', anchor: 'sweat' }];
        const bFull = mascot.runtime.bound(mascot.runtime.compile(full), 'full');
        const bWith = mascot.runtime.bound(mascot.runtime.compile(withTriggered), 'full');
        return {
          paintedDiff: bWith.painted_items - bFull.painted_items,
          passesDiff: bWith.paint_passes - bFull.paint_passes,
          numbersDiff: bWith.path_numbers - bFull.path_numbers
        };
      })()",
      jsonlite::toJSON(visor_json, auto_unbox = TRUE)
    ))

    expect_equal(r_triggered$paintedDiff, 1)
    expect_equal(r_triggered$passesDiff, 1)
    expect_equal(r_triggered$numbersDiff, 10)
  })

  it("counts ground shadow when declared", {
    skip_without_chrome()
    js <- page_with()
    tessa_json <- paste(
      readLines(test_path("fixtures", "format", "tessa.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    r <- js(sprintf(
      "(() => {
        const full = JSON.parse(%s);
        const withoutShadow = structuredClone(full);
        delete withoutShadow.ground.shadow;
        const bFull = mascot.runtime.bound(mascot.runtime.compile(full), 'full');
        const bWithout = mascot.runtime.bound(mascot.runtime.compile(withoutShadow), 'full');
        return {
          paintedDiff: bFull.painted_items - bWithout.painted_items,
          passesDiff: bFull.paint_passes - bWithout.paint_passes,
          numbersDiff: bFull.path_numbers - bWithout.path_numbers
        };
      })()",
      jsonlite::toJSON(tessa_json, auto_unbox = TRUE)
    ))

    expect_equal(r$paintedDiff, 1)
    expect_equal(r$passesDiff, 1)
    expect_equal(r$numbersDiff, 7)
  })

  it("counts mood item overrides and reduced item alternatives", {
    skip_without_chrome()
    js <- page_with()
    visor_json <- paste(
      readLines(test_path("fixtures", "format", "alpha_visor.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    r <- js(sprintf(
      "(() => {
        const base = JSON.parse(%s);
        const withMoodItems = structuredClone(base);
        withMoodItems.moods.thinking.items = {
          'head.helmet': { stroke: 'outline', width: 2 }
        };
        const withReducedItems = structuredClone(base);
        withReducedItems.moods.thinking.reduced = {
          items: {
            'head.helmet': { stroke: 'outline', width: 2 }
          }
        };
        const bBase = mascot.runtime.bound(mascot.runtime.compile(base), 'full');
        const bMood = mascot.runtime.bound(mascot.runtime.compile(withMoodItems), 'full');
        const bReduced = mascot.runtime.bound(mascot.runtime.compile(withReducedItems), 'full');
        return {
          moodPassesDiff: bMood.paint_passes - bBase.paint_passes,
          reducedPassesDiff: bReduced.paint_passes - bBase.paint_passes
        };
      })()",
      jsonlite::toJSON(visor_json, auto_unbox = TRUE)
    ))

    expect_equal(r$moodPassesDiff, 1)
    expect_equal(r$reducedPassesDiff, 1)
  })

  it("counts clip applications and gradient uses", {
    skip_without_chrome()
    js <- page_with()
    visor_json <- paste(
      readLines(test_path("fixtures", "format", "alpha_visor.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    r <- js(sprintf(
      "(() => {
        const full = JSON.parse(%s);
        const bFull = mascot.runtime.bound(mascot.runtime.compile(full), 'full');
        return {
          clips: bFull.clip_applications,
          gradients: bFull.gradient_uses
        };
      })()",
      jsonlite::toJSON(visor_json, auto_unbox = TRUE)
    ))

    expect_equal(r$clips, 2)
    expect_equal(r$gradients, 3)
  })

  it("resolves active parts through the needed ancestor tree", {
    skip_without_chrome()
    js <- page_with()
    probe_json <- paste(
      readLines(test_path("fixtures", "format", "anchor_probe.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    r <- js(sprintf(
      "(() => {
        const full = JSON.parse(%s);
        const bMicro = mascot.runtime.bound(mascot.runtime.compile(full), 'micro');
        const bFull = mascot.runtime.bound(mascot.runtime.compile(full), 'full');
        return {
          activeMicro: bMicro.active_parts,
          activeFull: bFull.active_parts
        };
      })()",
      jsonlite::toJSON(probe_json, auto_unbox = TRUE)
    ))

    expect_equal(r$activeMicro, 0)
    expect_equal(r$activeFull, 2)
  })

  it("enforces band budget limits for every capped counter", {
    skip_without_chrome()
    js <- page_with()
    tessa_json <- paste(
      readLines(test_path("fixtures", "format", "tessa.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )
    alpha_json <- paste(
      readLines(test_path("fixtures", "format", "alpha_visor.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )

    caps <- list(
      active_parts = 17,
      painted_items = 31,
      paint_passes = 61,
      path_numbers = 301,
      clip_applications = 3,
      gradient_uses = 3,
      glow_emitters = 1,
      blur_design_units = 1,
      inflated_glow_area_ratio = 0.1
    )
    for (metric in names(caps)) {
      code <- sprintf(
        "(() => {
          const work = {
            active_parts: 0, painted_items: 0, paint_passes: 0, path_numbers: 0,
            clip_applications: 0, gradient_uses: 0, glow_emitters: 0,
            blur_design_units: 0, inflated_glow_area_ratio: 0
          };
          work['%s'] = %s;
          try {
            mascot.geometry.checkWork(work, 'micro');
            return 'passed';
          } catch (e) {
            return { code: e.code, path: e.path, message: e.message };
          }
        })()",
        metric,
        caps[[metric]]
      )
      res <- js(code)
      expect_identical(res$code, "budget", info = metric)
      expect_identical(res$path, "$", info = metric)
      expect_match(res$message, metric, fixed = TRUE, info = metric)
    }

    # Micro glow budget refusal on alpha_visor
    r_micro_glow <- js(sprintf(
      "(() => {
        const c = JSON.parse(%s);
        c.lod = c.lod || {};
        c.lod.micro = c.lod.micro || {};
        c.lod.micro.glow = true;
        try {
          mascot.runtime.check(c, 'micro');
          return 'passed';
        } catch (e) {
          return { code: e.code, path: e.path, message: e.message };
        }
      })()",
      jsonlite::toJSON(alpha_json, auto_unbox = TRUE)
    ))
    expect_identical(r_micro_glow$code, "budget")
    expect_identical(r_micro_glow$path, "$")
    expect_match(r_micro_glow$message, "glow emitters")
  })

  it("computes transformed bounds for ref items, style transforms, and shapes in workBox (finding 1)", {
    skip_without_chrome()
    js <- page_with()

    # 1. Ref item with scale: 3 on circle r: 10 -> box is [-30, -30, 30, 30]
    box_ref <- js(
      "(() => {
      const it = { id: 'orb', shape: 'ref', use: 'dot', scale: 3 };
      const shapes = { dot: { shape: 'circle', r: 10, fill: 'accent' } };
      return mascot.geometry.workBox(it, shapes);
    })()"
    )
    expect_equal(unlist(box_ref), c(-30, -30, 30, 30))

    # 2. Rect with style transform [5, 10, 0]
    box_rect <- js(
      "(() => {
      const it = { shape: 'rect', x: -10, y: -5, w: 20, h: 10, transform: [5, 10, 0] };
      return mascot.geometry.workBox(it);
    })()"
    )
    expect_equal(unlist(box_rect), c(-5, 5, 15, 15))

    # 3. Hexagon circumradius bounds
    box_hex <- js(
      "(() => {
      const it = { shape: 'hexagon', r: 12, corner: 2 };
      return mascot.geometry.workBox(it);
    })()"
    )
    expect_equal(unlist(box_hex), c(-12, -12, 12, 12))
  })

  it("resolves shapes style in workGlow for ref items with fill and stroke (finding 2)", {
    skip_without_chrome()
    js <- page_with()
    alpha_json <- paste(
      readLines(test_path("fixtures", "format", "alpha_visor.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )
    res <- js(sprintf(
      "(() => {
        const c = JSON.parse(%s);
        c.shapes = c.shapes || {};
        c.shapes.badge = { shape: 'circle', r: 10, fill: 'accent', stroke: 'outline', width: 2 };
        c.parts[0].glow = { blur: 4, alpha: 1, item: 'gem' };
        c.parts[0].items.push({ id: 'gem', shape: 'ref', use: 'badge' });
        const b = mascot.runtime.bound(mascot.runtime.compile(c), 'full');
        return b;
      })()",
      jsonlite::toJSON(alpha_json, auto_unbox = TRUE)
    ))
    res_base <- js(sprintf(
      "(() => {
        const c = JSON.parse(%s);
        return mascot.runtime.bound(mascot.runtime.compile(c), 'full');
      })()",
      jsonlite::toJSON(alpha_json, auto_unbox = TRUE)
    ))
    expect_true(res$glow_emitters >= 1)
    expect_equal(res$paint_passes - res_base$paint_passes, 4)
  })

  it("counts a glow stroke that only a mood adds to a fill-only glowing item, as R does", {
    skip_without_chrome()
    js <- page_with()
    data <- format_recipe()
    item <- data$parts[[1]]$items[[1]]
    item$stroke <- NULL
    data$parts[[1]]$items[[1]] <- item
    data$parts[[1]]$glow <- list(item = item$id, colour = "accent", blur = 4, alpha = 1)
    key <- paste0(data$parts[[1]]$id, ".", item$id)
    data$moods[[1]]$items <- stats::setNames(list(list(stroke = names(data$colours)[[1]])), key)
    resolved <- character_format_resolve(data)
    graph <- character_format_references(resolved)
    r_work <- character_format_work(resolved, graph, character_format_behaviour(resolved, graph))
    payload <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null", digits = NA)
    browser <- js(sprintf("mascot.runtime.bound(mascot.runtime.compile(%s), 'full')", payload))
    expect_equal(browser[["paint_passes"]], r_work[["paint_passes"]])
    expect_equal(browser[["inflated_glow_area_ratio"]], r_work[["inflated_glow_area_ratio"]], tolerance = 1e-12)
  })

  it("bounds an unworn accessory by its resting scale and ignores null keys of set tracks, as R does", {
    skip_without_chrome()
    js <- page_with()
    recipe <- jsonlite::fromJSON(
      system.file("format", "characters", "tessa.json", package = "mascot", mustWork = TRUE),
      simplifyVector = FALSE
    )
    # The clip is declared but not worn; scaled up and glowing, it must still count at its resting scale.
    unworn <- setdiff(names(recipe$accessories), unlist(recipe$wear))[[1]]
    part <- recipe$accessories[[unworn]]$parts[[1]]
    part$scale <- 2
    part$items[[1]]$id <- "glow_source"
    part$glow <- list(item = "glow_source", colour = "accessory", blur = 5, alpha = 1)
    recipe$accessories[[unworn]]$parts[[1]] <- part
    # A set track whose first and last keys are null (hold the resting value).
    recipe$gestures$stretch <- list(
      description = "Stretch.",
      frames = 18,
      tracks = list(root.scale_x = list(mode = "set", keys = list(list(0, NULL), list(0.5, 1.5), list(1, NULL))))
    )
    resolved <- character_format_resolve(recipe)
    graph <- character_format_references(resolved)
    behaviour <- character_format_behaviour(resolved, graph)
    payload <- jsonlite::toJSON(recipe, auto_unbox = TRUE, null = "null", digits = NA)
    for (band in c("full", "small")) {
      r_work <- character_format_work(resolved, graph, behaviour, band)
      browser <- js(sprintf("mascot.runtime.bound(mascot.runtime.compile(%s), '%s')", payload, band))
      for (metric in setdiff(names(r_work), "inflated_glow_area_ratio")) {
        expect_equal(browser[[metric]], r_work[[metric]], info = paste(band, metric))
      }
      expect_equal(browser$inflated_glow_area_ratio, r_work[["inflated_glow_area_ratio"]], tolerance = 1e-12)
    }
    expect_gt(r_work[["glow_emitters"]], 0)
  })

  it("throws missing_reference at $.clip when target item is omitted in a reachable variant (finding 4)", {
    skip_without_chrome()
    js <- page_with()
    alpha_json <- paste(
      readLines(test_path("fixtures", "format", "alpha_visor.json"), encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )
    res <- js(sprintf(
      "(() => {
        const c = JSON.parse(%s);
        const headPart = c.parts.find(p => p.id === 'head');
        headPart.items.push({ id: 'target_item', shape: 'circle', r: 10, fill: 'accent' });
        headPart.items.push({ id: 'clipped_item', shape: 'circle', r: 5, fill: 'accent', clip: 'head.target_item' });
        headPart.variants = headPart.variants || {};
        headPart.variants.alt = [
          { id: 'clipped_item', shape: 'circle', r: 5, fill: 'accent', clip: 'head.target_item' }
        ];
        try {
          mascot.runtime.check(c, 'full');
          return 'passed';
        } catch (e) {
          return { code: e.code, path: e.path, message: e.message };
        }
      })()",
      jsonlite::toJSON(alpha_json, auto_unbox = TRUE)
    ))
    expect_identical(res$code, "missing_reference")
    expect_identical(res$path, "$.clip")
  })
})

describe("palette wire validation", {
  it("rejects malformed palette metadata and keeps CSS and explicit roles above the palette", {
    js <- local_runtime_page(list(mascot(
      "a",
      character = "tessa",
      theme = "peach",
      motion = FALSE,
      placement = "inline"
    )))
    result <- js(
      r"(
      (() => {
        const el = document.getElementById('a');
        const theme = mascot.host.state(el).theme;
        const errors = [];
        const variants = [
          { ...theme, palette: 1 },
          { ...theme, palette_colours: { light: null } },
          { ...theme, brand: { primary: '#000000', secondary: '#ffffff' } },
          { light: null, dark: null, mode: 'light', css: null, brand: null, palette_colours: theme.palette_colours },
          { ...theme, palette_colours: { light: { body: 'invalid' }, dark: null } },
        ];
        const warn = console.warn;
        console.warn = (...args) => errors.push(args.join(' '));
        try { for (const value of variants) mascot.host.receive({ id: 'a', patch: { theme: value } }); }
        finally { console.warn = warn; }
        document.documentElement.style.setProperty('--test-body', '#123456');
        mascot.host.receive({ id: 'a', patch: { theme: {
          ...theme, light: { body: '#654321', rim: '#112233' }, mode: 'light', css: { body: '--test-body' },
        } } });
        return { errors, colours: mascot.host.state(el).colours };
      })()
    )"
    )
    expect_match(result$errors[[1]], "theme.palette needs a palette id", fixed = TRUE)
    expect_match(result$errors[[2]], "theme.palette_colours needs light and dark maps", fixed = TRUE)
    expect_match(result$errors[[3]], "theme needs either a palette or brand colours", fixed = TRUE)
    expect_match(result$errors[[4]], "theme.palette_colours needs a palette id", fixed = TRUE)
    expect_match(result$errors[[5]], "invalid colour", fixed = TRUE)
    expect_identical(result$colours$body, "#123456")
    expect_identical(result$colours$rim, "#112233")
    expect_identical(result$colours$feature, "#2A1616")
  })
})


describe("standalone palette swaps", {
  it("drops unavailable palette colours and retains explicit theme settings across later refreshes", {
    js <- local_runtime_page(list(mascot(
      "a",
      character = "knurl",
      motion = FALSE,
      placement = "inline",
      theme = mascot_theme(palette = "orbit", light = list(outline = "#112233"), mode = "light")
    )))
    js(sprintf(
      "mascot.host.receive({id: 'a', patch: {character: %s}})",
      jsonlite::toJSON(list(id = "neer", name = "Neer", json = character_json("neer")), auto_unbox = TRUE)
    ))
    result <- js("mascot.host.state(document.getElementById('a'))")
    expect_identical(result$character, "neer")
    expect_null(result$theme$palette)
    expect_null(result$theme$palette_colours)
    expect_null(result$colours$body)
    expect_identical(result$colours$outline, "#112233")
    expect_identical(result$theme$mode, "light")
    js("mascot.host.receive({id: 'a', patch: {mood: 'happy'}})")
    expect_null(js("mascot.host.state(document.getElementById('a')).colours.body"))
  })
  it("resolves a shared palette from the incoming character instead of retaining the old map", {
    js <- local_runtime_page(list(mascot(
      "a",
      character = "tessa",
      theme = "coral_navy",
      motion = FALSE,
      placement = "inline"
    )))
    js(sprintf(
      "mascot.host.receive({id: 'a', patch: {character: %s}})",
      jsonlite::toJSON(list(id = "sela", name = "Sela", json = character_json("sela")), auto_unbox = TRUE)
    ))
    result <- js("mascot.host.state(document.getElementById('a'))")
    expect_identical(result$character, "sela")
    expect_identical(result$theme$palette, "coral_navy")
    expect_identical(result$theme$palette_colours$light$hair_purple, "#1D3557")
    expect_identical(result$colours$hair_purple, "#1D3557")
    # Tessa's coral_navy sets `accessory`; Sela's does not, so its absence shows the old map was dropped.
    expect_null(result$theme$palette_colours$light$accessory)
  })
  it("keeps the name of a character's own colours across a swap only to a character that uses the same name", {
    own_name <- list(mascot("a", character = "tessa", theme = "night_teal", motion = FALSE, placement = "inline"))
    swap <- function(js, id, json) {
      js(sprintf(
        "mascot.host.receive({id: 'a', patch: {character: %s}})",
        jsonlite::toJSON(list(id = id, name = id, json = json), auto_unbox = TRUE)
      ))
      js("mascot.host.state(document.getElementById('a'))")
    }
    # Another character that also names its own colours night_teal keeps the palette and applies no palette colours.
    twin <- sub('"id": "tessa"', '"id": "tessa_two"', character_json("tessa"), fixed = TRUE)
    kept <- swap(local_runtime_page(own_name), "tessa_two", twin)
    expect_identical(kept$theme$palette, "night_teal")
    expect_null(kept$theme$palette_colours$light)
    expect_null(kept$colours$body)
    # Sela has no palette of that name, so it is dropped.
    dropped <- swap(local_runtime_page(own_name), "sela", character_json("sela"))
    expect_null(dropped$theme$palette)
  })
})
