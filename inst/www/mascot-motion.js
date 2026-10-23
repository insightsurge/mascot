/**
 * Motion (mascot.motion): the format-v1 tracks and the small guards the player shares. All times are frames.
 *
 * mascot.motion.tracks evaluates character-format v1 motion (gesture tracks, needs and fallback, the five easings,
 * interruption, reduced motion and absolute activity deadlines) as pure functions: compile() checks a v1 character,
 * frameAt() returns the channel values for one absolute frame. Nothing here draws, reads a clock or touches the DOM.
 *
 * mascot.motion.shared holds the guards the player (mascot-player.js) uses for update() patches and mount options, so
 * each rule has one copy. mascot.motion.settings names the motion switches and mascot.motion.panels the message panels;
 * the host reads both when it loads, so this file loads before mascot-host.js.
 *
 * mascot.mount(canvas, character, options) is the public mount name. It plays the character with mascot.runtime,
 * looked up when it is called, so the order of this file and mascot-player.js does not matter.
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.motion) return;

  /** A name the data declares, or an error that lists the valid names. */
  function named(name, values, kind) {
    if (!Object.hasOwn(values, name))
      throw new Error(`mascot: unknown ${kind} '${name}'; valid names: ${Object.keys(values).join(', ')}`);
    return name;
  }

  const motionFlags = ['idle', 'mood_change', 'gestures', 'swap', 'minimising', 'restoring', 'others'];
  const panelNames = ['bubble', 'tooltip', 'menu'];
  const patchFields = ['mood', 'pose', 'colours', 'reduced', 'character', 'messages', ...motionFlags];

  function object(value, field) {
    if (!value || typeof value !== 'object' || Array.isArray(value))
      throw new Error(`mascot: ${field}: invalid value '${String(value)}'; expected an object`);
  }

  /** Merge a patch of named fields into a copy of current; null clears a field, or all of them. */
  function overrides(current, patch, allowed, field) {
    if (patch === null) return {};
    object(patch, field);
    const next = { ...current };
    for (const [key, value] of Object.entries(patch)) {
      if (!allowed.includes(key))
        throw new Error(
          `mascot: ${field}.${key}: unknown field '${key}' (value '${String(value)}'); valid names: ${allowed.join(', ')}`,
        );
      if (value === null) delete next[key];
      else next[key] = Array.isArray(value) ? [...value] : value;
    }
    return next;
  }

  /**
   * The character-swap fade, a mount option: { outFrames: 30, inFrames: 30 } by default. Positive finite durations
   * are rounded to whole frames (at least one) and each is capped at 150; the player then fits the pair
   * proportionally into the incoming character's activity window.
   */
  function swapTiming(value = {}) {
    object(value, 'swapTiming');
    const timing = { outFrames: 30, inFrames: 30 };
    for (const [key, frames] of Object.entries(value)) {
      if (!Object.hasOwn(timing, key)) throw new Error(`mascot: swapTiming.${key}: unknown field '${key}'`);
      if (!Number.isFinite(frames) || frames <= 0)
        throw new Error(`mascot: swapTiming.${key}: expected a positive finite frame duration`);
      timing[key] = Math.max(1, Math.round(Math.min(150, frames)));
    }
    return timing;
  }

  /** Ease every numeric field of from towards to; other fields take the value of to. */
  function recoverPose(from, to, progress) {
    const result = { ...to };
    for (const [key, value] of Object.entries(from))
      if (key !== 't' && typeof value === 'number' && typeof to[key] === 'number')
        result[key] = value + (to[key] - value) * progress;
    return result;
  }

  /** Shallow equality of two plain objects whose values are primitives or arrays of primitives. */
  function same(a, b) {
    const keys = Object.keys(a);
    return (
      keys.length === Object.keys(b).length &&
      keys.every((key) => {
        if (!Object.hasOwn(b, key)) return false;
        return Array.isArray(a[key]) && Array.isArray(b[key])
          ? a[key].length === b[key].length && a[key].every((value, i) => value === b[key][i])
          : Object.is(a[key], b[key]);
      })
    );
  }

  // ---- Format-v1 tracks -------------------------------------------------------------------------------------------
  // Pure functions over a checked character-format v1 description; nothing here draws, reads a clock or
  // touches the DOM.
  const tracks = (() => {
    const problem = (code, path, message) => {
      throw Object.assign(new Error(`${path}: ${message}`), { code, path });
    };
    const finite = (value) => typeof value === 'number' && Number.isFinite(value);
    const own = (object, key) => (object != null && Object.hasOwn(object, key) ? object[key] : undefined);
    // Closed easing list. step holds the starting key's value until the next key.
    const easings = Object.freeze({
      linear: (t) => t,
      ease_in: (t) => t * t,
      ease_out: (t) => 1 - (1 - t) * (1 - t),
      ease_in_out: (t) => t * t * (3 - 2 * t),
      step: () => 0,
    });
    const rootChannels = ['lift', 'rotate', 'scale_x', 'scale_y', 'flip'];
    const partChannels = ['x', 'y', 'rotate', 'scale_x', 'scale_y', 'opacity', 'visible', 'variant'];
    const effectChannels = ['x', 'y', 'scale_x', 'scale_y', 'opacity'];
    const restDefaults = { scale_x: 1, scale_y: 1, opacity: 1, flip: 1, visible: true, variant: 'default' };
    const baseOf = (rest, target) => {
      const given = own(rest, target);
      if (given !== undefined) return given;
      return own(restDefaults, target.slice(target.indexOf('.') + 1)) ?? 0;
    };
    const motionDefaults = {
      change: { style: 'wiggle', frames: 18, angle: 0.06, height: 8, swap_at: 0.5, gesture: null },
      idle: {
        frames: 150,
        blink_every: 120,
        blink_jitter: 30,
        blink_frames: 6,
        breathe: 0.012,
        breathe_period: 90,
        breathe_part: 'root',
        extra: null,
      },
    };

    /**
     * Check one track and put it in canonical form.
     * @param {Array|Object} track [[at, value, ease?], ...] or { mode, keys }.
     * @param {string} path Error path.
     * @returns {{mode: string, numeric: boolean, keys: Array}} Frozen canonical track.
     */
    function normalise(track, path) {
      const wrapped = track !== null && typeof track === 'object' && !Array.isArray(track);
      const keys = wrapped ? track.keys : track;
      if (wrapped)
        for (const key of Object.keys(track))
          if (!['mode', 'keys', 'note'].includes(key) && !key.startsWith('x_'))
            problem('unknown_key', `${path}.${key}`, 'Use only mode and keys.');
      if (!Array.isArray(keys) || keys.length < 2) problem('invalid_channel', path, 'Supply at least two keys.');
      const checked = keys.map((key, index) => {
        const at = `${path}[${index}]`;
        if (!Array.isArray(key) || key.length < 2 || key.length > 3)
          problem('input_type', at, 'Use [at, value, ease?].');
        if (!finite(key[0])) problem('input_type', at, 'Use a finite number for at.');
        if (key[2] !== undefined && !Object.hasOwn(easings, key[2]))
          problem('invalid_channel', `${at}[2]`, `Choose an easing from ${Object.keys(easings).join(', ')}.`);
        const value = key[1];
        if (value !== null && !finite(value) && typeof value !== 'string' && typeof value !== 'boolean')
          problem('input_type', `${at}[1]`, 'Use a finite number, string, boolean or null.');
        return { at: key[0], value, ease: key[2] ?? 'linear' };
      });
      if (
        checked[0].at !== 0 ||
        checked[checked.length - 1].at !== 1 ||
        checked.some((k, i) => i && k.at <= checked[i - 1].at)
      )
        problem('invalid_channel', path, 'Keys must increase strictly from 0 to 1.');
      const numeric = checked.every((key) => key.value === null || finite(key.value));
      const mode = wrapped && track.mode !== undefined ? track.mode : numeric ? 'add' : 'set';
      if (mode !== 'add' && mode !== 'set') problem('invalid_channel', path, 'Choose mode add or set.');
      if (!numeric && mode !== 'set') problem('invalid_channel', path, 'Discrete channels use set tracks.');
      const first = checked[0].value;
      const last = checked[checked.length - 1].value;
      if (mode === 'add') {
        if (checked.some((key) => key.value === null))
          problem('invalid_channel', path, 'Add tracks use numeric offsets.');
        if (first !== 0 || last !== 0) problem('invalid_channel', path, 'Add tracks start and end with zero offsets.');
      } else if (!numeric && (first !== null || last !== null)) {
        problem('invalid_channel', path, 'Discrete tracks start and end with null.');
      }
      return Object.freeze({ mode, numeric, keys: Object.freeze(checked.map((key) => Object.freeze(key))) });
    }

    /**
     * Value of a canonical track at progress u. Null means the currently displayed mood's base. Numbers
     * interpolate with the starting key's easing; anything else switches at its key. At u >= 1 the result is
     * exactly the rest (base, or base + 0), with no hold after the last key.
     */
    function sample(track, u, base) {
      const keys = track.keys;
      const resolve = (key) => (key.value === null ? (track.mode === 'add' ? 0 : base) : key.value);
      const final = (value) => (track.mode === 'add' ? base + value : value);
      if (!(u > 0)) return final(resolve(keys[0]));
      if (u >= 1) return final(resolve(keys[keys.length - 1]));
      let index = keys.length - 2;
      while (keys[index].at > u) index--;
      const a = keys[index];
      const b = keys[index + 1];
      const va = resolve(a);
      const vb = resolve(b);
      if (finite(va) && finite(vb)) return final(va + (vb - va) * easings[a.ease]((u - a.at) / (b.at - a.at)));
      return final(va);
    }

    /**
     * Check every gesture and pick the playable one for each gesture id.
     * @param {Object} character Checked character-format v1 description (gestures, parts).
     * @returns {{selected: Object<string,string>, gestures: Object}} Frozen compiled gestures. Errors carry
     *   { code, path } like the part module: missing_reference, budget, input_type, invalid_channel.
     */
    function compile(character) {
      const parts = new Set((character.parts ?? []).map((part) => part.id));
      const source = character.gestures ?? {};
      for (const id of ['nod', 'wave'])
        if (!own(source, id)) problem('missing_reference', `$.gestures.${id}`, 'Declare the shared callable gesture.');
      const selected = {};
      for (const id of Object.keys(source)) {
        const seen = new Set();
        let cursor = id;
        let chosen = null;
        for (;;) {
          if (seen.has(cursor))
            problem('missing_reference', `$.gestures.${cursor}.fallback`, 'Remove the cyclic fallback chain.');
          seen.add(cursor);
          const gesture = own(source, cursor);
          if (!gesture)
            problem('missing_reference', `$.gestures.${id}.fallback`, `Name a declared fallback, not '${cursor}'.`);
          const needs = gesture.needs ?? [];
          if (!Array.isArray(needs))
            problem('input_type', `$.gestures.${cursor}.needs`, 'Supply an array of part ids.');
          if (chosen === null && needs.every((need) => parts.has(need))) chosen = cursor;
          if (gesture.fallback === null || gesture.fallback === undefined) break;
          cursor = gesture.fallback;
        }
        if (chosen === null) problem('missing_reference', `$.gestures.${id}.fallback`, 'Provide a playable fallback.');
        selected[id] = chosen;
      }
      const gestures = {};
      for (const [id, gesture] of Object.entries(source)) {
        const path = `$.gestures.${id}`;
        if (typeof gesture.description !== 'string' || gesture.description === '')
          problem('input_type', `${path}.description`, 'Describe the gesture.');
        if (!Number.isInteger(gesture.frames)) problem('input_type', `${path}.frames`, 'Use a whole number of frames.');
        if (gesture.frames < 1 || gesture.frames > 150) problem('budget', `${path}.frames`, 'Use 1 to 150 frames.');
        if (gesture.tracks === null || typeof gesture.tracks !== 'object' || Array.isArray(gesture.tracks))
          problem('input_type', `${path}.tracks`, 'Supply a map of tracks.');
        const triggers = gesture.effects ?? [];
        if (!Array.isArray(triggers)) problem('input_type', `${path}.effects`, 'Supply an array of triggers.');
        if (triggers.length > 256) problem('budget', `${path}.effects`, 'Use at most 256 effect triggers.');
        const needs = gesture.needs ?? [];
        const list = Object.entries(gesture.tracks).map(([target, track]) => {
          const at = `${path}.tracks.${target}`;
          const dot = target.indexOf('.');
          const part = dot < 0 ? '' : target.slice(0, dot);
          const channel = target.slice(dot + 1);
          const present = part === 'root' || parts.has(part);
          // An absent part is waived only when this gesture declares it and a playable fallback exists.
          const waived = !present && needs.includes(part) && selected[id] !== id;
          const known = (part === 'root' ? rootChannels : partChannels).includes(channel);
          if (dot < 0 || !(present || waived) || !(known || (waived && partChannels.includes(channel))))
            problem('invalid_channel', at, 'Name a real channel or an explicitly needed absent part with a fallback.');
          return Object.freeze({ target, part, channel, track: normalise(track, at) });
        });
        triggers.forEach((trigger, index) => {
          const at = `${path}.effects[${index}]`;
          if (!finite(trigger.at) || trigger.at < 0 || trigger.at > 1) problem('input_type', `${at}.at`, 'Use 0 to 1.');
          if (typeof trigger.effect !== 'string' || !own(character.anchors, trigger.anchor))
            problem('missing_reference', at, 'Name an effect and a declared anchor.');
        });
        gestures[id] = Object.freeze({
          frames: gesture.frames,
          needs: Object.freeze([...needs]),
          tracks: Object.freeze(list),
          effects: Object.freeze(triggers.map((trigger) => Object.freeze({ ...trigger }))),
        });
      }
      return Object.freeze({ selected: Object.freeze(selected), gestures: Object.freeze(gestures) });
    }

    /** Motion settings with defaults, in the format's own snake_case names; checked against its limits. */
    function settings(character) {
      const motion = character.motion ?? {};
      // A note and x_ extension keys are accepted in these fixed objects and never read, as in R.
      const field = (key) => key !== 'note' && !key.startsWith('x_');
      const fields = (object) => Object.fromEntries(Object.entries(object ?? {}).filter(([key]) => field(key)));
      for (const [group, allowed] of Object.entries(motionDefaults))
        for (const key of Object.keys(fields(motion[group])))
          if (!Object.hasOwn(allowed, key))
            problem('unknown_key', `$.motion.${group}.${key}`, `Use one of ${Object.keys(allowed).join(', ')}.`);
      for (const key of Object.keys(fields(motion)))
        if (!Object.hasOwn(motionDefaults, key))
          problem('unknown_key', `$.motion.${key}`, `Use one of ${Object.keys(motionDefaults).join(', ')}.`);
      const change = { ...motionDefaults.change, ...fields(motion.change) };
      const idle = { ...motionDefaults.idle, ...fields(motion.idle) };
      const frames = (value, path) => {
        if (!Number.isInteger(value) || value < 1 || value > 150) problem('budget', path, 'Use 1 to 150 whole frames.');
      };
      frames(change.frames, '$.motion.change.frames');
      frames(idle.frames, '$.motion.idle.frames');
      if (!['wiggle', 'hop', 'gesture'].includes(change.style))
        problem('input_type', '$.motion.change.style', 'Choose wiggle, hop or gesture.');
      for (const key of ['angle', 'height', 'swap_at'])
        if (!finite(change[key])) problem('input_type', `$.motion.change.${key}`, 'Use a finite number.');
      if (!finite(change.swap_at) || change.swap_at < 0 || change.swap_at > 1)
        problem('input_type', '$.motion.change.swap_at', 'Use 0 to 1.');
      for (const key of ['blink_every', 'blink_jitter', 'blink_frames', 'breathe', 'breathe_period'])
        if (!finite(idle[key]) || idle[key] < 0) problem('input_type', `$.motion.idle.${key}`, 'Use a finite number.');
      if (idle.blink_every <= 0 || idle.blink_frames <= 0 || idle.breathe_period <= 0)
        problem('input_type', '$.motion.idle', 'Durations must be positive.');
      if (idle.blink_jitter + idle.blink_frames / 2 >= idle.blink_every)
        problem('input_type', '$.motion.idle.blink_jitter', 'Keep blink_jitter + blink_frames / 2 below blink_every.');
      if (idle.breathe > 0.1) problem('input_type', '$.motion.idle.breathe', 'Use 0 to 0.1.');
      const declared = (id) => Object.hasOwn(character.gestures ?? {}, id);
      if (change.style === 'gesture' && !declared(change.gesture))
        problem('missing_reference', '$.motion.change.gesture', 'Name a declared gesture for the gesture style.');
      if (idle.extra !== null && !declared(idle.extra))
        problem('missing_reference', '$.motion.idle.extra', 'Name a declared gesture.');
      if (idle.breathe_part !== 'root' && !(character.parts ?? []).some((part) => part.id === idle.breathe_part))
        problem('missing_reference', '$.motion.idle.breathe_part', 'Name root or a declared part.');
      return { change, idle };
    }

    /** Fit a finite duration that starts late into the frames left before the deadline. */
    function fit(start, frames, deadline) {
      const left = deadline - start;
      if (!(left > 0) || !(frames > 0)) return 0;
      return Math.min(frames, left);
    }

    function blink(seed, frame, idle, window) {
      const index = Math.floor(frame / idle.blink_every);
      let value = 0;
      for (let i = Math.max(0, index - 1); i <= index + 1; i++) {
        const hash = (Math.imul((seed >>> 0) ^ i, 1664525) + 1013904223) >>> 0;
        const centre = (i + 1) * idle.blink_every + (hash % (2 * idle.blink_jitter + 1)) - idle.blink_jitter;
        const half = idle.blink_frames / 2;
        // A blink crossing either window boundary is skipped, never truncated.
        if (centre - half >= 0 && centre + half <= window) value = Math.max(value, 1 - Math.abs(frame - centre) / half);
      }
      return value;
    }

    // Effect tracks are absolute values of their own glyph (set mode, unless the track says otherwise).
    const effectCache = new WeakMap();
    function effectTracks(definition, id) {
      if (!effectCache.has(definition))
        effectCache.set(
          definition,
          Object.entries(definition.tracks ?? {}).map(([key, track]) => {
            const path = `$.effects.${id}.tracks.${key}`;
            if (!effectChannels.includes(key)) problem('invalid_channel', path, 'Unknown effect channel.');
            return [key, normalise(Array.isArray(track) ? { mode: 'set', keys: track } : track, path)];
          }),
        );
      return effectCache.get(definition);
    }

    /**
     * Channel values at one absolute frame. Pure and seekable.
     * @param {{selected: Object, gestures: Object}} compiled Result of compile().
     * @param {Object} state { mood, previous, changedAt, gesture, gestureAt, activeAt, activeUntil, reduced,
     *   seed, idle, mood_change, gestures, extraAt, held }; frames are absolute at 30 fps.
     * @param {number} frame Absolute frame.
     * @param {Object} options { settings, rest(mood) -> { target: base }, effects: { id: { frames, tracks } } }.
     * @returns {Object} { mood, settled, channels, blink, effects }. Settled means exactly the target rest
     *   plus held channels, with no effect instances.
     */
    function frameAt(compiled, state, frame, options = {}) {
      const { change, idle } = options.settings ?? settings({});
      const rest = options.rest ?? (() => ({}));
      const target = state.mood;
      const held = { ...(state.held ?? {}) };
      const activeAt = state.activeAt === undefined ? 0 : state.activeAt;
      const windowFrames = Math.min(150, idle.frames);
      const until = state.activeUntil === undefined ? (activeAt ?? 0) + windowFrames : state.activeUntil;
      const settledResult = { mood: target, settled: true, channels: held, blink: 0, effects: [] };
      if (state.reduced || activeAt === null || until === null || frame >= until) return settledResult;
      if (frame < activeAt) return { ...settledResult, settled: false, mood: state.previous ?? target };
      const hasGesture = state.gestures !== false && state.gesture != null && frame >= state.gestureAt;
      if (hasGesture && !own(compiled.selected, state.gesture))
        problem('input_type', '$.gesture', `Unknown gesture '${state.gesture}'.`);
      const changed = state.changedAt !== undefined && state.changedAt !== null && frame >= state.changedAt;
      // The newest action owns the window; a gesture commits its target mood immediately.
      const gestureWins = hasGesture && (!changed || state.gestureAt >= state.changedAt);
      const changeFrames = changed ? fit(state.changedAt, change.frames, until) : 0;
      const changing =
        !gestureWins &&
        state.mood_change !== false &&
        changed &&
        state.previous !== undefined &&
        state.previous !== target &&
        frame < state.changedAt + changeFrames;
      const mood = changing && frame < state.changedAt + changeFrames * change.swap_at ? state.previous : target;
      const base = rest(mood);
      const channels = {};
      const out = [];
      let playing = false;
      if (gestureWins) {
        const gesture = compiled.gestures[compiled.selected[state.gesture]];
        const length = fit(state.gestureAt, gesture.frames, until);
        const u = length > 0 ? (frame - state.gestureAt) / length : 1;
        playing = u >= 0 && u < 1;
        if (playing)
          for (const { target: key, track } of gesture.tracks) channels[key] = sample(track, u, baseOf(base, key));
        // Each trigger is its own instance with its own fitted lifetime; instances outlive the gesture's
        // movement and end at the latest at the deadline.
        gesture.effects.forEach((trigger, index) => {
          const definition = own(options.effects, trigger.effect);
          if (!definition)
            problem(
              'missing_reference',
              `$.gestures.${compiled.selected[state.gesture]}.effects[${index}]`,
              `Supply the kit effect '${trigger.effect}'.`,
            );
          const start = state.gestureAt + trigger.at * length;
          const frames = fit(start, definition.frames, until);
          const p = frames > 0 ? (frame - start) / frames : 1;
          if (p < 0 || p >= 1) return;
          const values = { x: 0, y: 0, scale_x: 1, scale_y: 1, opacity: 0 };
          for (const [key, track] of effectTracks(definition, trigger.effect))
            values[key] = sample(track, p, values[key]);
          out.push({ index, effect: trigger.effect, anchor: trigger.anchor, progress: p, state: values });
        });
      } else if (changing) {
        const p = (frame - state.changedAt) / changeFrames;
        if (change.style === 'hop')
          channels['root.lift'] = baseOf(base, 'root.lift') + change.height * Math.sin(Math.PI * p);
        else if (change.style === 'wiggle')
          channels['root.rotate'] =
            baseOf(base, 'root.rotate') + change.angle * Math.sin(p * 4 * Math.PI) * (1 - p) ** 2;
        else {
          const gesture = own(compiled.gestures, own(compiled.selected, change.gesture));
          if (!gesture)
            problem(
              'missing_reference',
              '$.motion.change.gesture',
              `Name a declared gesture, not '${change.gesture}'.`,
            );
          for (const { target: key, track } of gesture.tracks) channels[key] = sample(track, p, baseOf(base, key));
        }
      }
      // The idle extra plays once from a host-supplied start, or a deterministic seeded rule when omitted;
      // an action in progress wins, and a late start is fitted into the frames left (none left: discarded).
      let extraAt = state.extraAt;
      if (extraAt === undefined && idle.extra && state.idle !== false) {
        const extraGesture = own(compiled.gestures, own(compiled.selected, idle.extra));
        if (!extraGesture)
          problem('missing_reference', '$.motion.idle.extra', `Name a declared gesture, not '${idle.extra}'.`);
        const windowLen = until - activeAt;
        const fadeAt = Math.floor((windowLen * 2) / 3);
        const earliest = activeAt + changeFrames;
        const latest = activeAt + Math.max(changeFrames, fadeAt - extraGesture.frames);
        const range = latest - earliest;
        const hash = (Math.imul((state.seed >>> 0) ^ 0x65787472, 1664525) + 1013904223) >>> 0;
        extraAt = earliest + (range > 0 ? hash % (range + 1) : 0);
      }
      if (!playing && !changing && idle.extra && extraAt != null && frame >= extraAt) {
        const extra = own(compiled.gestures, own(compiled.selected, idle.extra));
        if (!extra)
          problem('missing_reference', '$.motion.idle.extra', `Name a declared gesture, not '${idle.extra}'.`);
        const length = fit(extraAt, extra.frames, until);
        const u = length > 0 ? (frame - extraAt) / length : 1;
        if (u < 1)
          for (const { target: key, track } of extra.tracks) channels[key] = sample(track, u, baseOf(base, key));
      }
      let level = 0;
      if (state.idle !== false) {
        const elapsed = frame - activeAt;
        const length = until - activeAt;
        const fadeAt = (length * 2) / 3;
        const t = Math.max(0, (elapsed - fadeAt) / (length - fadeAt));
        const fade = 1 - t * t * (3 - 2 * t);
        const b = idle.breathe * fade * Math.sin((2 * Math.PI * elapsed) / idle.breathe_period);
        const part = idle.breathe_part;
        // Multiplicative, so the factor stays within [1 - breathe, 1 + breathe] whatever the pose scale is.
        for (const [axis, factor] of [
          ['scale_x', 1 - b],
          ['scale_y', 1 + b],
        ]) {
          const key = `${part}.${axis}`;
          channels[key] = (own(channels, key) ?? baseOf(base, key)) * factor;
        }
        level = blink(state.seed ?? 0, elapsed, idle, length);
      }
      return { mood, settled: false, channels: { ...channels, ...held }, blink: level, effects: out };
    }

    /**
     * The frames a player draws for a window: every frame up to the first one at or past the deadline,
     * which is the single settled frame; nothing follows it (RAF is cancelled there).
     */
    function drawn(state, from, settingsObject = settings({})) {
      const start = state.activeAt === undefined ? 0 : state.activeAt;
      const until =
        state.activeUntil === undefined ? start + Math.min(150, settingsObject.idle.frames) : state.activeUntil;
      const frames = [];
      for (let n = from; n < until; n++) frames.push(n);
      frames.push(Math.max(from, until));
      return frames;
    }

    return Object.freeze({ easings, normalise, sample, compile, settings, fit, frameAt, drawn });
  })();

  // The guards and helpers the player (mascot.runtime) shares, so each rule has one copy. patchFields are the update()
  // keys it accepts.
  const shared = Object.freeze({
    named,
    object,
    overrides,
    same,
    swapTiming,
    recoverPose,
    patchFields: Object.freeze([...patchFields]),
  });

  ns.motion = {
    tracks,
    shared,
    settings: Object.freeze(motionFlags),
    panels: Object.freeze(panelNames),
  };
  ns.mount = (canvas, ch, options) => ns.runtime.mount(canvas, ch, options);
})();
