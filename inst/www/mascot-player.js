/**
 * Character-format v1 runtime (mascot.runtime): compiles a checked character once, draws it through the format-v1
 * modules (mascot.parts, mascot.geometry, mascot.faces and mascot.motion.tracks) and moves it with a per-canvas
 * player. The host mounts a character with format_version 1 here through mascot.mount(); every other character keeps
 * the legacy player in mascot-motion.js. Load mascot-parts.js, mascot-geometry.js, mascot-faces.js and
 * mascot-motion.js first (any order among the four; they are only read when a character is compiled).
 *
 * Nothing here reads a clock or calls Math.random(). A frame is a pure function of the compiled character, the state
 * and the frame number, so the player can seek. Compile once per character object (a weak cache that also keeps
 * failures); the detail-band budget is computed once per character and band; a frame builds no compiled data.
 *
 * Player contract (the same as the legacy player, so the host drives both alike): update({ mood, pose, colours,
 * reduced, character, messages, ...switches }) validates the whole patch before any state changes; gesture(name),
 * setMood(name), seek(n), redraw(), setBand(name), pause(), play(), holdVisibility(held), destroy(), current(), and
 * the onChange(snapshot) callback. Differences from the legacy player, all because the data is different:
 *   - pose is the held host look, { 'face.look_x': -1..1|null, 'face.look_y': -1..1|null }; a character without a
 *     gaze-capable face rejects it, so the host sends no gaze channels to faceless or no-gaze kits.
 *   - a swap without a mood chooses the incoming mood by the contract's fallback chain (mascot.parts.swapMood).
 *   - a format-v1 character cannot swap into a legacy one (or back); update() rejects it before any state changes.
 *
 * Internal. Reserved for the character-format v1 contract: engine-format-proposal.md sections 2.3 and 3.16.
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.runtime) return;

  const own = (object, key) => (object != null && Object.hasOwn(object, key) ? object[key] : undefined);
  const isFormat = (character) =>
    character !== null && typeof character === 'object' && !Array.isArray(character) && character.format_version === 1;
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const strip = (error) => String(error.message || error).replace(/^mascot: /, '');
  const gazeChannels = Object.freeze(['face.look_x', 'face.look_y']);
  const bandNames = Object.freeze(['full', 'small', 'micro']);
  const additive = Object.freeze(['active_parts', 'painted_items', 'paint_passes', 'path_numbers', 'glow_emitters']);

  function modules() {
    if (!ns.parts || !ns.geometry || !ns.faces || !ns.motion?.tracks || !ns.motion.shared)
      throw new Error('mascot: load mascot-parts.js, mascot-geometry.js, mascot-faces.js and mascot-motion.js first');
    return ns.motion.shared;
  }

  // ---- compile once ----------------------------------------------------------------------------------------------
  const entries = new WeakMap();

  /**
   * Everything a player needs from a checked character, built once. Throws the engine's { code, path } error for an
   * invalid character; the failure is cached for that object too.
   */
  function build(character) {
    if (!isFormat(character)) throw new Error('mascot: expected a character with format_version 1');
    modules();
    const parts = ns.parts.compile(character);
    const faces = ns.faces.compile(character);
    const tracks = ns.motion.tracks.compile(character);
    const motion = ns.motion.tracks.settings(character);
    const source = parts.source;
    const face = source.face ?? null;
    const byId = new Map(parts.parts.map((part) => [part.id, part]));
    // Gaze moves only elliptical pupils. A faceless character, or a kit whose eyes are all arcs, paths or dots,
    // has no gaze channels at all (contract 3.16).
    const eyeStyles = { ...face?.kit_definition?.eye_styles, ...face?.styles?.eyes };
    const gaze = face !== null && Object.values(eyeStyles).some((style) => style.op === 'eye_ellipse');
    // The draw order is fixed by the data: parts by (layer, array order), the face at its owner's layer + 0.5 and
    // each effect at its own layer; ties keep that order. Consecutive parts form one segment.
    const pieces = [...parts.parts]
      .sort((a, b) => (a.layer ?? 0) - (b.layer ?? 0) || a.index - b.index)
      .map((part) => ({ layer: part.layer ?? 0, kind: 'part', id: part.id }));
    if (face) pieces.push({ layer: face.layer ?? (byId.get(face.part)?.layer ?? 0) + 0.5, kind: 'face' });
    for (const [id, effect] of Object.entries(source.effects ?? {}))
      pieces.push({ layer: effect.layer ?? 3, kind: 'effect', id });
    pieces.sort((a, b) => a.layer - b.layer);
    const segments = [];
    for (const piece of pieces) {
      const last = segments[segments.length - 1];
      if (piece.kind === 'part' && last?.kind === 'parts') last.ids.push(piece.id);
      else if (piece.kind === 'part') segments.push({ kind: 'parts', ids: [piece.id] });
      else segments.push({ kind: piece.kind, id: piece.id });
    }
    segments.forEach(Object.freeze);
    let shadow = null;
    const declared = source.ground.shadow;
    if (declared) {
      const role = declared.colour ?? 'shadow';
      if (!Object.hasOwn(source.colours, role))
        throw Object.assign(new Error(`$.ground.shadow.colour: Name a declared colour role, not '${role}'.`), {
          code: 'invalid_colour',
          path: '$.ground.shadow.colour',
        });
      shadow = {
        role,
        alpha: declared.alpha ?? 0.3,
        compiled: ns.parts.compile({
          format_version: 1,
          ground: { centre_height: 0 },
          parts: [
            {
              id: 'ground_shadow',
              items: [{ shape: 'ellipse', rx: declared.rx, ry: declared.ry, fill: 'shadow_fill' }],
            },
          ],
        }),
      };
    }
    const moodBases = parts.moodBases;
    const rest = (mood) => own(moodBases, mood) ?? parts.resting;
    return {
      character,
      source,
      parts,
      faces,
      tracks,
      motion,
      gaze,
      segments,
      shadow,
      // frameAt() reads the base of the mood being shown through rest(), with no copy.
      rest,
      frameOptions: { settings: motion, rest, effects: face?.kit_definition?.effects ?? {} },
      bounds: new Map(),
      passed: new Set(),
    };
  }

  // The same content parsed again (an element replaced by renderUI() reads its character from the page afresh) is the
  // same character: its compiled entry is shared. A small bounded table keeps the most recent, so a Shiny app that
  // remounts a mascot repeatedly compiles it once.
  const byContent = new Map();
  const contentLimit = 8;

  function compile(character) {
    let entry = entries.get(character);
    if (entry === undefined) {
      let key = null;
      try {
        key = JSON.stringify(character);
      } catch {
        // Not JSON: it is no character, and build() says why.
      }
      entry = typeof key === 'string' ? byContent.get(key) : undefined;
      if (entry === undefined) {
        try {
          entry = build(character);
        } catch (error) {
          entry = { error };
        }
        if (typeof key === 'string') {
          byContent.set(key, entry);
          if (byContent.size > contentLimit) byContent.delete(byContent.keys().next().value);
        }
      } else if (typeof key === 'string') {
        // Most recently used last.
        byContent.delete(key);
        byContent.set(key, entry);
      }
      if (character !== null && typeof character === 'object') entries.set(character, entry);
    }
    if (entry.error) throw entry.error;
    return entry;
  }

  // ---- detail bands ----------------------------------------------------------------------------------------------
  // The browser's upper bound on the painted work of a character in one band, by the contract's componentwise rule:
  // the main anatomy, plus for each exclusive accessory slot the largest declared accessory (not the product of the
  // choices), blur by maximum. Computed once per character and band; refuses before anything is painted. It counts
  // parts and their items, as mascot.geometry.bandBound does; the face, the ground shadow and the effects are not
  // counted here (the R checker counts them; parity of the two is #304).
  function bound(entry, band) {
    if (!bandNames.includes(band)) throw new Error("mascot: band: use 'full', 'small' or 'micro'.");
    if (entry.bounds.has(band)) return entry.bounds.get(band);
    const accessories = entry.source.accessories ?? {};
    let total;
    if (Object.keys(accessories).length === 0) total = { ...ns.geometry.bandBound(entry.parts, band) };
    else {
      const without = ns.parts.compile({ ...entry.source, wear: [] });
      const main = ns.geometry.bandBound(without, band);
      total = { ...main };
      const slots = new Map();
      for (const [id, accessory] of Object.entries(accessories)) {
        const work = ns.geometry.bandBound(ns.parts.compile({ ...entry.source, wear: [id] }), band);
        const best = slots.get(accessory.slot) ?? Object.fromEntries(additive.map((key) => [key, 0]));
        for (const key of additive) best[key] = Math.max(best[key], work[key] - main[key]);
        total.blur_design_units = Math.max(total.blur_design_units, work.blur_design_units);
        slots.set(accessory.slot, best);
      }
      for (const best of slots.values()) for (const key of additive) total[key] += best[key];
    }
    Object.freeze(total);
    entry.bounds.set(band, total);
    return total;
  }

  // A band that passed once passes for good: the entry is immutable. Called for every frame, so it must be cheap.
  function checkEntry(entry, band) {
    if (entry.passed.has(band)) return;
    ns.geometry.checkWork(bound(entry, band), band);
    entry.passed.add(band);
  }

  /** Throws budget at $, painting nothing, when the character can reach more work than the band allows. */
  function check(character, band) {
    checkEntry(compile(character), band);
  }

  // ---- state checks ----------------------------------------------------------------------------------------------
  /** Throws when the character is not a valid format-v1 character or lacks the mood or gesture named in request. */
  function validate(character, request = {}) {
    const entry = compile(character);
    const { named } = modules();
    if (request.mood !== undefined) named(request.mood, entry.source.moods, 'mood');
    if (request.gesture !== undefined) named(request.gesture, entry.tracks.selected, 'gesture');
    return true;
  }

  /** The mood to show after the character changes: the contract's fallback chain, then idle. */
  function swapMood(from, mood, to) {
    return ns.parts.swapMood(compile(from).source, mood, compile(to).source);
  }

  // ---- drawing ---------------------------------------------------------------------------------------------------
  const view = { root: null, parts: null, anchors: null, layers: null, band: 'full', hidden: null };
  const controls = {};
  const noOptions = Object.freeze({});
  // The held host look is in page terms; a mirrored body (root.flip -1 in the displayed frame) mirrors the pupils too,
  // so the horizontal look is flipped back here, from the frame actually shown (reduced bases and swaps included).
  function flipHeldLook(channels, held) {
    if (held && typeof held['face.look_x'] === 'number' && channels['root.flip'] === -1)
      channels['face.look_x'] = -held['face.look_x'];
  }
  // A recovery eases numeric channels only; a discrete channel (root.flip and other choices) switches at halfway.
  function recover(entry, from, to, progress) {
    const result = ns.motion.shared.recoverPose(from, to, progress);
    const rules = entry.parts.rules;
    for (const key of Object.keys(result)) {
      const rule = rules[key];
      if (rule && rule.type !== 'number' && Object.hasOwn(from, key))
        result[key] = progress < 0.5 ? from[key] : to[key];
    }
    return result;
  }
  const shadowChannels = {};
  const shadowColours = {};

  // The user's colour overrides, then the mood's recolour (an explicit user override of a role wins).
  function paletteOf(entry, mood, overrides, reduced) {
    const merged = Object.assign({}, entry.source.colours, overrides);
    return ns.parts.resolveColours(entry.parts, mood, merged, { reduced, userOverrides: overrides });
  }

  /** Resolve one frame's geometry (validates every channel) without touching the canvas. */
  function prepare(entry, scene, host, band) {
    return ns.parts.frame(entry.parts, scene.channels, band, host, {
      items: ns.parts.resolveItems(entry.parts, scene.mood, { reduced: scene.reduced }),
    });
  }

  function paint(ctx, entry, scene, state, colours, host) {
    const channels = scene.channels;
    const shadow = entry.shadow;
    const lift = channels['root.lift'] ?? 0;
    if (shadow && channels['root.scale_x'] !== 0 && channels['root.scale_y'] !== 0) {
      // Not squashed; shrinks and fades with lift (contract 3.6). Lifts below -100 are held there: the formula
      // divides by 1 + lift / 200.
      const k = 1 / (1 + Math.max(lift, -100) / 200);
      shadowChannels['ground_shadow.scale_x'] = k * (0.6 + 0.4 * (channels['root.scale_x'] ?? 1));
      shadowChannels['ground_shadow.scale_y'] = k;
      shadowColours.shadow_fill = ns.geometry.alphaColour(colours[shadow.role], shadow.alpha * k, '$.ground.shadow');
      const drawn = ns.parts.frame(shadow.compiled, shadowChannels, 'full', { x: host.x, base_y: host.base_y - 1 });
      ns.geometry.draw(ctx, shadow.compiled, drawn, shadowColours);
    }
    view.root = state.root;
    view.parts = state.parts;
    view.anchors = state.anchors;
    view.band = state.band;
    view.hidden = state.hidden;
    view.item_overrides = state.item_overrides;
    for (const segment of entry.segments) {
      if (segment.kind === 'parts') {
        view.layers = segment.ids;
        ns.geometry.draw(ctx, entry.parts, view, colours);
      } else if (segment.kind === 'face') {
        controls.eyes = channels['face.eyes'];
        controls.mouth = channels['face.mouth'];
        controls.brows = channels['face.brows'];
        controls.blush = channels['face.blush'];
        controls.look_x = channels['face.look_x'] ?? 0;
        controls.look_y = channels['face.look_y'] ?? 0;
        controls.blink = Math.max(channels['face.blink'] ?? 0, scene.blink);
        controls.lid = channels['face.lid'] ?? 0;
        controls.open = channels['face.open'] ?? 1;
        ns.faces.draw(ctx, entry.faces, state, controls, colours, noOptions);
      } else {
        // Every triggered instance draws with its own state at its trigger's anchor; overlapping triggers do not merge.
        let triggered = false;
        for (const instance of scene.effects) {
          if (instance.effect !== segment.id) continue;
          triggered = true;
          ns.faces.effects(ctx, entry.faces, state, { [segment.id]: 1 }, colours, {
            frame: scene.elapsed,
            activity_deadline: scene.window,
            reduced: scene.reduced,
            effect_states: { [segment.id]: instance.state },
            effect_anchors: { [segment.id]: instance.anchor },
          });
        }
        if (triggered) continue;
        const value = channels[`effects.${segment.id}`];
        const control = typeof value === 'boolean' ? Number(value) : (value ?? 0);
        if (!control) continue;
        ns.faces.effects(ctx, entry.faces, state, { [segment.id]: control }, colours, {
          frame: scene.elapsed,
          activity_deadline: scene.window,
          reduced: scene.reduced,
        });
      }
    }
  }

  // ---- the player ------------------------------------------------------------------------------------------------
  /** The channel values of a wave (the swap movement) laid over a base, at progress 0..1. */
  function overlay(entry, base, progress) {
    const gesture = entry.tracks.gestures[entry.tracks.selected.wave];
    const result = { ...base };
    for (const { target, track } of gesture.tracks)
      result[target] = ns.motion.tracks.sample(track, progress, base[target] ?? 0);
    return result;
  }

  function mount(canvas, character, options = {}) {
    const shared = modules();
    const { named, object, overrides, same, swapTiming } = shared;
    const motionFlags = ns.motion.settings;
    const panelNames = ns.motion.panels;
    let entry = compile(character);
    const timing = swapTiming(options.swapTiming);
    if (options.onChange !== undefined && typeof options.onChange !== 'function')
      throw new Error('mascot: onChange: expected a function');
    const onChange = options.onChange;

    // The whole patch is built and checked here; nothing changes until it returns.
    function preparePatch(current, patch) {
      object(patch, 'update');
      for (const key of Object.keys(patch))
        if (!shared.patchFields.includes(key))
          throw new Error(
            `mascot: update.${key}: unknown field '${key}' (value '${String(patch[key])}'); valid names: ${shared.patchFields.join(', ')}`,
          );
      const next = { ...current };
      let target = current.entry;
      if (Object.hasOwn(patch, 'character')) {
        if (!isFormat(patch.character))
          throw new Error('mascot: update.character: a legacy character cannot replace a format-v1 character here');
        let incoming;
        try {
          incoming = compile(patch.character);
        } catch (error) {
          throw new Error(`mascot: update.character: ${strip(error)}`);
        }
        if (incoming.source.id !== target.source.id) {
          next.character = patch.character;
          next.entry = incoming;
          next.mood = ns.parts.swapMood(target.source, current.mood, incoming.source);
          next.colours = {};
          // Held look carries only where the incoming character can look about.
          next.pose = incoming.gaze ? { ...current.pose } : {};
          target = incoming;
        }
      }
      if (Object.hasOwn(patch, 'mood')) {
        try {
          next.mood = named(patch.mood, target.source.moods, 'mood');
        } catch (error) {
          throw new Error(`mascot: update.mood: ${strip(error)}`);
        }
      }
      if (Object.hasOwn(patch, 'pose')) {
        next.pose = overrides(next.pose, patch.pose, gazeChannels, 'update.pose');
        if (patch.pose !== null && Object.keys(patch.pose).length && !target.gaze)
          throw new Error(`mascot: update.pose: ${target.source.id} has no gaze to hold`);
        for (const [key, value] of Object.entries(next.pose))
          if (typeof value !== 'number' || !Number.isFinite(value) || value < -1 || value > 1)
            throw new Error(`mascot: update.pose.${key}: invalid value '${String(value)}'; use a number from -1 to 1`);
      }
      if (Object.hasOwn(patch, 'colours'))
        next.colours = overrides(next.colours, patch.colours, Object.keys(target.source.colours), 'update.colours');
      for (const [role, value] of Object.entries(next.colours))
        if (!ns.validColour(value))
          throw new Error(
            `mascot: update.colours.${role}: invalid colour '${String(value)}'; use #RGB, #RRGGBB, rgb() or rgba()`,
          );
      if (Object.hasOwn(patch, 'reduced')) {
        const value = patch.reduced;
        if (value !== null && typeof value !== 'boolean')
          throw new Error(`mascot: update.reduced: invalid value '${String(value)}'; valid values: true, false, null`);
        next.reduced = value;
      }
      for (const key of motionFlags) {
        if (!Object.hasOwn(patch, key)) continue;
        if (typeof patch[key] !== 'boolean')
          throw new Error(`mascot: update.${key}: invalid value '${String(patch[key])}'; valid values: true, false`);
        next[key] = patch[key];
      }
      if (Object.hasOwn(patch, 'messages')) {
        if (!Array.isArray(patch.messages) || patch.messages.some((name) => !panelNames.includes(name)))
          throw new Error('mascot: update.messages: valid panel names: bubble, tooltip, menu');
        next.messages = [...patch.messages];
      }
      return next;
    }

    const initial = {
      character,
      entry,
      mood: 'idle',
      pose: {},
      colours: {},
      reduced: null,
      ...Object.fromEntries(motionFlags.map((key) => [key, options.others ?? true])),
      messages: options.others === false ? [] : [...panelNames],
    };
    const initialPatch = Object.fromEntries(
      ['mood', 'colours', 'reduced', 'messages', ...motionFlags]
        .filter((key) => options[key] !== undefined)
        .map((key) => [key, options[key]]),
    );
    let values = preparePatch(initial, initialPatch);
    const ctx = canvas.getContext('2d');
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const state = {
      idle: values.idle,
      mood_change: values.mood_change,
      gestures: values.gestures,
      mood: values.mood,
      held: values.pose,
      colours: values.colours,
      activeAt: 0,
      activeUntil: Math.floor(entry.motion.idle.frames),
      seed: options.seed === undefined ? 0 : options.seed,
      reduced: media.matches || values.reduced === true,
    };
    if (state.reduced) state.activeAt = null;
    if (options.band !== undefined && !bandNames.includes(options.band))
      throw new Error("mascot: band: use 'full', 'small' or 'micro'.");
    let band = options.band ?? 'full';
    const host = { x: options.x ?? 150, base_y: options.baseY ?? 270 };
    let frame = 0;
    let request = null;
    let origin = null;
    let startFrame = 0;
    let paused = false;
    let visibilityHeld = false;
    let destroyed = false;
    let layer = null;
    let frameErrorReported = false;
    // Whether the last drawn frame showed a triggered effect: an effect may outlive its gesture's movement.
    let effectsShown = false;
    let notified = null;
    let callbackErrorReported = false;
    let memo = null;

    // The one channel table a plain frame is built in, reused by every frame of this player. A frame that must outlive
    // the next one (the capture of a swap) asks for its own copy instead.
    const table = {};
    let tableEntry = null;

    // Scene of the current character at frame n, without a swap: the movement of the window, then the held look.
    function resolve(n, colours = state.colours, reuse = false) {
      const result = ns.motion.tracks.frameAt(entry.tracks, state, n, entry.frameOptions);
      const reduced = Boolean(state.reduced);
      const base = reduced
        ? (own(entry.parts.reducedBases, result.mood) ?? entry.parts.resting)
        : entry.rest(result.mood);
      const elapsed = Math.max(0, n - (state.activeAt ?? n));
      let channels;
      if (reuse) {
        // Every channel of the character is in its base, so each frame overwrites the whole table.
        if (tableEntry !== entry) {
          for (const key of Object.keys(table)) delete table[key];
          tableEntry = entry;
        }
        channels = Object.assign(table, base, result.channels);
      } else channels = Object.assign({}, base, result.channels);
      flipHeldLook(channels, state.held);
      return {
        entry,
        mood: result.mood,
        channels,
        blink: result.blink,
        effects: result.effects,
        colours,
        opacity: 1,
        swapping: false,
        reduced,
        elapsed,
        window: (state.activeUntil ?? n) - (state.activeAt ?? n),
      };
    }

    function sceneFrame(n, reuse = false) {
      const swap = state.swap;
      if (!swap || state.reduced || n >= swap.until) return resolve(n, state.colours, reuse);
      const elapsed = n - swap.at;
      if (swap.outFrames > 0 && elapsed < swap.outFrames) {
        const out = swap.outgoing;
        const progress = Math.max(0, elapsed / swap.outFrames);
        let channels;
        if (out.recovery) {
          const done = clamp((n - out.recovery.at) / out.recovery.frames, 0, 1);
          channels = recover(out.entry, out.recovery.channels, out.recovery.target, done);
        } else {
          const wave = out.wave;
          const waveProgress = wave ? clamp((n - wave.at) / wave.frames, 0, 1) : progress;
          channels = overlay(out.entry, wave ? wave.channels : out.channels, waveProgress);
        }
        Object.assign(channels, out.held);
        flipHeldLook(channels, out.held);
        return {
          entry: out.entry,
          mood: out.mood,
          channels,
          blink: out.blink,
          effects: [],
          colours: out.colours,
          opacity: swap.opacity * (1 - progress),
          swapping: true,
          reduced: false,
          elapsed: n - swap.at,
          window: swap.until - swap.at,
        };
      }
      const progress = clamp((elapsed - swap.outFrames) / swap.inFrames, 0, 1);
      const base = resolve(n);
      // A reversal recovers directly from the displayed channels to rest, without restarting the wave.
      const returning = swap.outFrames === 0 && swap.outgoing.entry.source.id === entry.source.id;
      const channels = returning
        ? recover(entry, swap.outgoing.channels, base.channels, progress)
        : overlay(entry, base.channels, progress);
      Object.assign(channels, state.held);
      flipHeldLook(channels, state.held);
      return {
        ...base,
        channels,
        opacity: swap.outFrames === 0 ? swap.opacity + (1 - swap.opacity) * progress : progress,
        swapping: true,
        elapsed: n - swap.at,
        window: swap.until - swap.at,
      };
    }

    // What is shown at frame n, without building channels: the character, its mood and whether it is swapping.
    function shown(n) {
      const swap = state.swap;
      const swapping = Boolean(swap && !state.reduced && n < swap.until);
      if (swapping && swap.outFrames > 0 && n - swap.at < swap.outFrames)
        return { entry: swap.outgoing.entry, mood: swap.outgoing.mood, swapping };
      const mood = ns.motion.tracks.frameAt(entry.tracks, state, n, entry.frameOptions).mood;
      return { entry, mood, swapping };
    }

    function notifyChange() {
      if (destroyed || !onChange) return;
      const snapshot = controller.current();
      if (notified && same(notified, snapshot)) return;
      notified = { ...snapshot };
      try {
        onChange(snapshot);
      } catch (error) {
        if (!callbackErrorReported) {
          callbackErrorReported = true;
          console.error('mascot: onChange callback failed', error);
        }
      }
    }

    function moving() {
      const gesture = state.gesture ? entry.tracks.gestures[entry.tracks.selected[state.gesture]] : null;
      return (
        !state.reduced &&
        (state.idle ||
          (state.swap && frame < state.swap.until) ||
          (state.mood_change &&
            state.changedAt !== undefined &&
            frame < state.changedAt + entry.motion.change.frames) ||
          (state.gestures && gesture && frame < state.gestureAt + gesture.frames) ||
          effectsShown) &&
        state.activeAt !== null &&
        frame >= state.activeAt &&
        frame < state.activeUntil
      );
    }

    function colourSet(visible) {
      if (
        !memo ||
        memo.entry !== visible.entry ||
        memo.mood !== visible.mood ||
        memo.reduced !== visible.reduced ||
        memo.overrides !== visible.colours
      )
        memo = {
          entry: visible.entry,
          mood: visible.mood,
          reduced: visible.reduced,
          overrides: visible.colours,
          value: paletteOf(visible.entry, visible.mood, visible.colours, visible.reduced),
        };
      return memo.value;
    }

    function drawFrame() {
      if (destroyed) return;
      const visible = sceneFrame(frame, true);
      effectsShown = visible.effects.length > 0;
      // Everything that can fail is resolved before the canvas is cleared, so a refused frame keeps its pixels.
      checkEntry(visible.entry, band);
      const geometry = prepare(visible.entry, visible, host, band);
      const colours = colourSet(visible);
      ctx.save();
      try {
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
      } finally {
        ctx.restore();
      }
      if (!visible.swapping) {
        ctx.save();
        try {
          paint(ctx, visible.entry, visible, geometry, colours, host);
        } finally {
          ctx.restore();
        }
        return;
      }
      // A swap composites the whole character once through a private canvas, so item alpha cannot bypass the fade.
      if (!layer) layer = canvas.ownerDocument.createElement('canvas');
      if (layer.width !== canvas.width) layer.width = canvas.width;
      if (layer.height !== canvas.height) layer.height = canvas.height;
      const buffer = layer.getContext('2d');
      buffer.clearRect(0, 0, layer.width, layer.height);
      buffer.save();
      try {
        const transform = ctx.getTransform();
        buffer.setTransform(transform.a, transform.b, transform.c, transform.d, transform.e, transform.f);
        paint(buffer, visible.entry, visible, geometry, colours, host);
      } finally {
        buffer.restore();
      }
      ctx.save();
      try {
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.globalAlpha *= visible.opacity;
        ctx.drawImage(layer, 0, 0);
      } finally {
        ctx.restore();
      }
    }

    function stopLoop() {
      if (request !== null) window.cancelAnimationFrame(request);
      request = null;
      origin = null;
    }
    function schedule() {
      if (destroyed || paused || visibilityHeld || !moving()) stopLoop();
      else if (request === null) request = window.requestAnimationFrame(tick);
    }
    function tick(timestamp) {
      request = null;
      if (destroyed || paused || visibilityHeld || !moving()) return;
      if (origin === null) {
        origin = timestamp;
        startFrame = frame;
      }
      const next = Math.min(state.activeUntil, startFrame + Math.floor(((timestamp - origin) * ns.fps) / 1000));
      // Screens refresh faster than 30 fps: draw only when the frame number moves on.
      if (next !== frame) {
        frame = next;
        try {
          drawFrame();
        } catch (error) {
          // Every entry point checks first, so this is a bug: keep the last pixels, stop moving and say so once.
          stopLoop();
          if (!frameErrorReported) {
            frameErrorReported = true;
            console.error('mascot: a frame could not be drawn', error);
          }
          return;
        }
      }
      schedule();
      notifyChange();
    }
    function activate() {
      state.activeAt = state.reduced ? null : frame;
      state.activeUntil = state.reduced ? null : frame + Math.floor(entry.motion.idle.frames);
      origin = null;
    }
    function settle() {
      state.previous = state.mood;
      delete state.changedAt;
      delete state.gesture;
      delete state.gestureAt;
      delete state.swap;
      state.activeAt = null;
      state.activeUntil = null;
    }
    function preference(event) {
      if (destroyed || state.reduced === (event.matches || values.reduced === true)) return;
      state.reduced = event.matches || values.reduced === true;
      if (state.reduced) settle();
      drawFrame();
      schedule();
      notifyChange();
    }

    const controller = {
      /** Draw the current frame again without moving time, renewing activity or scheduling RAF. */
      redraw() {
        drawFrame();
      },
      /**
       * Set the detail band and redraw the current frame. Time, activity and the movement in progress are unchanged.
       * Atomic: a band over budget throws before anything changes. Returns true when it drew.
       */
      setBand(name) {
        if (destroyed) return false;
        if (!bandNames.includes(name)) throw new Error("mascot: band: use 'full', 'small' or 'micro'.");
        if (name === band) return false;
        // Both characters of a swap in progress must fit the new band: the incoming one is shown later in the swap.
        checkEntry(entry, name);
        if (state.swap && !state.reduced && frame < state.swap.until) checkEntry(state.swap.outgoing.entry, name);
        band = name;
        drawFrame();
        return true;
      },
      /** Draw and move to a frame; it does not count as a new action. */
      seek(n) {
        if (destroyed) return;
        frame = n;
        origin = null;
        drawFrame();
        schedule();
        notifyChange();
      },
      /** Validate the whole patch, then apply it atomically. */
      update(patch) {
        if (destroyed) return;
        const next = preparePatch(values, patch);
        const characterChanged = next.entry !== entry;
        const visibleBefore = sceneFrame(frame);
        const wasSwapping = visibleBefore.swapping;
        const moodChanged = next.mood !== values.mood;
        const heldChanged = !same(next.pose, values.pose);
        const reduced = media.matches || next.reduced === true;
        const changed =
          characterChanged ||
          moodChanged ||
          heldChanged ||
          !same(next.colours, values.colours) ||
          next.reduced !== values.reduced ||
          motionFlags.some((key) => next[key] !== values[key]) ||
          !same(next.messages, values.messages) ||
          reduced !== state.reduced;
        if (!changed) return;
        // An incoming character must fit the current band before anything changes.
        if (characterChanged) check(next.character, band);
        if (characterChanged) {
          const outgoing = {
            entry: visibleBefore.entry,
            mood: visibleBefore.mood,
            channels: visibleBefore.channels,
            blink: visibleBefore.blink,
            held: visibleBefore.entry === entry ? values.pose : state.swap.outgoing.held,
            colours: visibleBefore.colours,
          };
          // Keep an already visible wave's phase and speed when taps retarget it; only its opacity timeline changes.
          if (wasSwapping) {
            const swap = state.swap;
            if (swap.outFrames > 0 && frame < swap.at + swap.outFrames && swap.outgoing.recovery)
              outgoing.recovery = swap.outgoing.recovery;
            else if (swap.outFrames > 0 && frame < swap.at + swap.outFrames)
              outgoing.wave = swap.outgoing.wave || {
                at: swap.at,
                frames: swap.outFrames,
                channels: swap.outgoing.channels,
              };
            else if (swap.outgoing.entry.source.id !== entry.source.id)
              outgoing.wave = {
                at: swap.at + swap.outFrames,
                frames: swap.inFrames,
                channels: resolve(frame).channels,
              };
            else
              outgoing.recovery = {
                at: frame,
                frames: swap.until - frame,
                channels: outgoing.channels,
                target: resolve(frame).channels,
              };
          }
          const returning = visibleBefore.entry.source.id === next.entry.source.id;
          let outFrames = returning ? 0 : timing.outFrames * visibleBefore.opacity;
          if (wasSwapping && state.swap.outFrames > 0 && frame < state.swap.at + state.swap.outFrames && !returning)
            outFrames = state.swap.at + state.swap.outFrames - frame;
          let inFrames = timing.inFrames * (returning ? 1 - visibleBefore.opacity : 1);
          entry = next.entry;
          // Quantise once. Both completion and activity use stored absolute deadlines.
          const total = Math.min(Math.floor(entry.motion.idle.frames), Math.round(outFrames + inFrames));
          outFrames =
            outFrames === 0 || total < 2
              ? 0
              : Math.max(1, Math.min(total - 1, Math.round((outFrames * total) / (outFrames + inFrames))));
          inFrames = total - outFrames;
          state.mood = next.mood;
          state.previous = next.mood;
          delete state.changedAt;
          delete state.gesture;
          delete state.gestureAt;
          delete state.swap;
          if (!reduced && next.swap && outFrames + inFrames > 0)
            state.swap = {
              at: frame,
              until: frame + total,
              outFrames,
              inFrames,
              opacity: visibleBefore.opacity,
              outgoing,
            };
        } else if (moodChanged) {
          state.previous = shown(frame).mood;
          state.mood = next.mood;
          if (wasSwapping) {
            state.previous = next.mood;
            delete state.changedAt;
          } else state.changedAt = frame;
          delete state.gesture;
          delete state.gestureAt;
        }
        values = next;
        state.held = next.pose;
        state.colours = next.colours;
        state.reduced = reduced;
        state.idle = next.idle;
        state.mood_change = next.mood_change;
        state.gestures = next.gestures;
        if (!next.mood_change) {
          state.previous = state.mood;
          delete state.changedAt;
        }
        if (!next.gestures) {
          delete state.gesture;
          delete state.gestureAt;
        }
        if (characterChanged || (!wasSwapping && (moodChanged || heldChanged))) activate();
        if (!next.swap) delete state.swap;
        if (state.reduced) settle();
        drawFrame();
        schedule();
        notifyChange();
      },
      /** Shortcut for update({ mood: name }); repeating the target mood is a no-op. */
      setMood(name) {
        controller.update({ mood: name });
      },
      /** Replace the current action and commit its target mood, starting at the current frame. */
      gesture(name) {
        if (destroyed) return;
        named(name, entry.tracks.selected, 'gesture');
        if (!values.gestures) return;
        if (shown(frame).swapping) return;
        delete state.changedAt;
        state.previous = state.mood;
        state.gesture = name;
        state.gestureAt = frame;
        activate();
        if (state.reduced) settle();
        drawFrame();
        schedule();
        notifyChange();
      },
      /** Freeze elapsed frames, including after the player has automatically rested. */
      pause() {
        if (destroyed) return;
        paused = true;
        stopLoop();
      },
      /** Hold visibility independently of user pause, without renewing activity or drawing. */
      holdVisibility(held) {
        if (destroyed || visibilityHeld === held) return;
        visibilityHeld = held;
        stopLoop();
        schedule();
      },
      /** Resume after pause without catching up; renew activity unless a swap is still running. */
      play() {
        if (destroyed || !paused) return;
        paused = false;
        if (!shown(frame).swapping) activate();
        drawFrame();
        schedule();
        notifyChange();
      },
      /** Stop permanently and remove the media listener; safe to call repeatedly. */
      destroy() {
        if (destroyed) return;
        destroyed = true;
        stopLoop();
        media.removeEventListener('change', preference);
        layer = null;
      },
      /** The displayed state: { character: id, mood, swapping }. Readable at the final frame after destroy(). */
      current() {
        const visible = shown(frame);
        return { character: visible.entry.source.id, mood: visible.mood, swapping: visible.swapping };
      },
    };
    drawFrame();
    media.addEventListener('change', preference);
    schedule();
    notifyChange();
    return controller;
  }

  ns.runtime = Object.freeze({ isFormat, compile, bound, check, validate, swapMood, mount, flipHeldLook, recover });
})();
