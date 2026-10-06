/**
 * Seekable motion and a canvas player. Load alongside mascot.js and mascot-draw.js, in any order.
 * Descriptions are immutable, like the drawing engine's descriptions. All times below are frames.
 *
 * Optional character.motion fields (each missing field keeps its default):
 * change: style = 'wiggle' ('wiggle' or 'hop'), frames = 18, angle = 0.06 radians,
 *   height = 8 canvas units, swapAt = 0.5 (fraction of the change). Wiggle makes two decaying rocks;
 *   hop follows a parabola. angle applies to wiggle, height to hop.
 * idle: frames = 150 (activity window, capped at 150), blinkEvery = 120 (spacing between blink windows),
 *   blinkJitter = 30 (centre offset limit),
 *   blinkFrames = 6 (duration), breathe = 0.012 (scale amplitude), breathePeriod = 90.
 *   Window i (starting at 0) has centre (i + 1) * blinkEvery + h(seed, i) % (2 * blinkJitter + 1)
 *   - blinkJitter, relative to activeAt. h = (1664525 * ((seed >>> 0) XOR i) + 1013904223) modulo 2^32.
 *   Blink is a triangular pulse, zero at centre +/- blinkFrames / 2 and one at the centre.
 *   Check neighbouring windows when seeking; R must keep jitter + half-duration below blinkEvery.
 *   Breathing uses sin(2*pi*(frame-activeAt)/breathePeriod), multiplying sy by 1+b and sx by 1-b.
 *   Its amplitude fades with a smoothstep over the final third of the activity window.
 *   A blink that would cross either window boundary is skipped, never truncated.
 * gestures: nod and wave, each with frames and timeline (an ordered array of { at, pose }).
 *   at is a fraction of the duration. Missing pose fields interpolate from the displayed mood;
 *   numeric fields interpolate linearly, other fields switch at their keyframe. Values are absolute
 *   pose values, not offsets. A zero or one endpoint with pose: {} means the mood's own pose.
 *   Pose keys come from drawing.defaultPose except t; gestures cannot change mood or time.
 *   Arms are ignored when the character has none.
 *   Defaults: nod lasts 18 frames, lowering sy to 0.96 and lift to -3 at 0.25 and 0.65;
 *   wave lasts 30 frames, rocks to -0.025 and alternates armR between -0.9 and -0.3.
 *
 * pose(character, state, frame) returns existing pose fields for draw(), without modifying inputs.
 * state: mood = first described mood, previous = mood, changedAt = absent (no change),
 *   gesture = absent, gestureAt = absent, activeAt = 0, seed = 0, reduced = false, pose = {}.
 * Gestures override the mood, then idle motion is applied; explicit fields supplied to draw() last
 * still win. A gesture replaces the change/gesture, committing its target mood immediately.
 * A mood change replaces any gesture and starts from the face currently displayed. Repeating the
 * target mood does nothing. Reduced motion skips every motion layer and displays the target mood.
 *
 * The five-second rule: mount, mood changes, gestures, held-pose changes and play after pause start
 * a new activity window at activeAt. Change/gesture durations are compressed to at most idle.frames
 * and 150 frames, so every action finishes within five seconds at 30 fps. At the window's end,
 * pose() returns exactly { mood, ...heldPose }, and the player draws that resting frame once and
 * stops RAF. New actions restart it, unless paused. Colours/reduction changes and seek do not reset
 * activity. Enabling reduced motion discards activity (activeAt: null); turning it off cannot replay
 * an old action. Held pose overrides mood, gestures and idle motion, including while resting.
 */
/**
 * Character data; only top-level fields are described here. Immutable after first use.
 * @typedef {Object} CharacterDescription
 * @property {string} id Character identifier.
 * @property {string} name Display name.
 * @property {number} centreHeight Body origin height in canvas units.
 * @property {Object<string, string>} colours Colour roles.
 * @property {Object[]} body Drawing parts.
 * @property {Object} face Face geometry and styles.
 * @property {Object<string, Object>} moods Named mood poses.
 * @property {Object} small Small-detail settings.
 * @property {Object} [anchors] Attachment points.
 * @property {Object} [arms] Arm geometry and presets.
 * @property {Object} [feet] Feet geometry.
 * @property {Object} [shadow] Shadow geometry.
 * @property {Object} [accessories] Named accessories.
 * @property {Object} [pose] Character's default pose.
 * @property {Object} [motion] Overrides documented above.
 */

/**
 * Seekable state; frame numbers are absolute, durations are in frames, angles in radians.
 * @typedef {Object} MotionState
 * @property {string} [mood] Target mood; defaults to the first described mood.
 * @property {string} [previous] Previously displayed mood; defaults to mood.
 * @property {number} [changedAt] Change's start frame; absent means no change.
 * @property {string} [gesture] One-off gesture name; absent means none.
 * @property {number} [gestureAt] Gesture's start frame.
 * @property {number|null} [activeAt=0] Last action's frame; null means activity was discarded.
 * @property {number} [seed=0] Unsigned 32-bit seed.
 * @property {boolean} [reduced=false] Skip motion.
 * @property {Object} [pose={}] Held explicit fields, applied last.
 */

/**
 * @typedef {Object} MountOptions
 * @property {number} [x=0] Horizontal position in canvas units.
 * @property {number} [baseY=0] Baseline in canvas units.
 * @property {string} [mood] Initial mood; defaults to the first described mood.
 * @property {number} [seed=0] Unsigned 32-bit seed.
 * @property {Object<string, string>|null} [colours] Initial colour overrides; defaults to none.
 * @property {boolean|null} [reduced=null] Force reduction, or follow the media preference.
 */

/**
 * Omitted fields stay unchanged. Null clears individual pose/colour keys, or their entire block.
 * @typedef {Object} UpdatePatch
 * @property {string} [mood] Target mood, with the same change behaviour as setMood().
 * @property {Object|null} [pose] Merge drawing fields except mood/t; null clears every held field.
 * @property {Object<string, string|null>|null} [colours] Merge colour roles; null clears all.
 * @property {boolean|null} [reduced] Force reduction, or null to follow the media preference.
 */

/**
 * @typedef {Object} MotionController
 * @property {function(number):void} seek Draw and move to an absolute frame (no activity reset).
 * @property {function(UpdatePatch):void} update Validate and apply an atomic patch.
 * @property {function(string):void} setMood Shortcut for update({ mood: name }).
 * @property {function(string):void} gesture Replace the current action with a one-off gesture.
 * @property {function():void} pause Freeze elapsed frames.
 * @property {function():void} play Resume after pause and begin a new activity window.
 * @property {function():void} destroy Stop permanently and remove the media listener.
 */

(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.motion) return;

  const defaults = {
    change: { style: 'wiggle', frames: 18, angle: 0.06, height: 8, swapAt: 0.5 },
    idle: { frames: 150, blinkEvery: 120, blinkJitter: 30, blinkFrames: 6, breathe: 0.012, breathePeriod: 90 },
    gestures: {
      nod: {
        frames: 18,
        timeline: [
          { at: 0, pose: {} },
          { at: 0.25, pose: { sy: 0.96, lift: -3 } },
          { at: 0.45, pose: {} },
          { at: 0.65, pose: { sy: 0.96, lift: -3 } },
          { at: 1, pose: {} },
        ],
      },
      wave: {
        frames: 30,
        timeline: [
          { at: 0, pose: {} },
          { at: 0.2, pose: { rot: -0.025, armR: -0.9 } },
          { at: 0.4, pose: { rot: -0.025, armR: -0.3 } },
          { at: 0.6, pose: { rot: -0.025, armR: -0.9 } },
          { at: 0.8, pose: { rot: -0.025, armR: -0.3 } },
          { at: 1, pose: {} },
        ],
      },
    },
  };
  const styles = ['wiggle', 'hop'];
  const configs = new WeakMap();
  const checked = new WeakSet();

  /**
   * Thin motion-name guard used by validateCharacter(), including after late script loading.
   * @param {CharacterDescription} ch Immutable character description.
   * @returns {string[]} Name errors; an empty array means no name errors. R owns types/ranges.
   */
  function validate(ch) {
    if (checked.has(ch)) return [];
    const errors = [];
    const keys = (value, allowed, at) => {
      for (const key of Object.keys(value || {}))
        if (!allowed.includes(key)) errors.push(`${at}: unknown name '${key}'; valid names: ${allowed.join(', ')}`);
    };
    const motion = ch.motion || {};
    keys(motion, Object.keys(defaults), 'motion');
    for (const group of ['change', 'idle']) keys(motion[group], Object.keys(defaults[group]), `motion.${group}`);
    if (motion.change?.style !== undefined && !styles.includes(motion.change.style))
      errors.push(`motion.change.style: unknown name '${motion.change.style}'; valid names: ${styles.join(', ')}`);
    keys(motion.gestures, Object.keys(defaults.gestures), 'motion.gestures');
    for (const [name, gesture] of Object.entries(motion.gestures || {})) {
      const at = `motion.gestures.${name}`;
      keys(gesture, ['frames', 'timeline'], at);
      for (const [i, point] of (gesture.timeline || []).entries()) {
        keys(point, ['at', 'pose'], `${at}.timeline[${i}]`);
        keys(point.pose, poseFields(), `${at}.timeline[${i}].pose`);
        try {
          const p = { ...point.pose };
          if (!ch.arms) {
            delete p.arms;
            delete p.armL;
            delete p.armR;
          }
          ns.drawing.guardPose(ch, p, `${at}.timeline[${i}].pose`);
        } catch (e) {
          errors.push(e.message.replace('mascot: ', ''));
        }
      }
    }
    if (!errors.length) checked.add(ch);
    return errors;
  }

  function config(ch) {
    const errors = ns.validateCharacter(ch);
    if (errors.length) throw new Error(`mascot: ${errors[0]}`);
    if (!configs.has(ch)) {
      const motion = ch.motion || {};
      const frames = Math.min(150, motion.idle?.frames === undefined ? defaults.idle.frames : motion.idle.frames);
      configs.set(ch, {
        change: {
          ...defaults.change,
          ...motion.change,
          frames: Math.min(frames, motion.change?.frames ?? defaults.change.frames),
        },
        idle: { ...defaults.idle, ...motion.idle, frames },
        gestures: Object.fromEntries(
          Object.entries(defaults.gestures).map(([name, value]) => [
            name,
            {
              ...value,
              ...motion.gestures?.[name],
              frames: Math.min(frames, motion.gestures?.[name]?.frames ?? value.frames),
            },
          ]),
        ),
      });
    }
    return configs.get(ch);
  }

  function named(name, values, kind) {
    if (!Object.hasOwn(values, name))
      throw new Error(`mascot: unknown ${kind} '${name}'; valid names: ${Object.keys(values).join(', ')}`);
    return name;
  }

  function shownMood(ch, state, frame, change) {
    const mood = named(state.mood === undefined ? Object.keys(ch.moods)[0] : state.mood, ch.moods, 'mood');
    const previous = state.previous === undefined ? mood : named(state.previous, ch.moods, 'mood');
    const replaced =
      state.gesture &&
      frame >= state.gestureAt &&
      (state.changedAt === undefined || state.gestureAt >= state.changedAt);
    return !state.reduced &&
      !replaced &&
      state.changedAt !== undefined &&
      frame < state.changedAt + change.frames * change.swapAt
      ? previous
      : mood;
  }

  function blink(seed, frame, idle) {
    const index = Math.floor(frame / idle.blinkEvery);
    let value = 0;
    for (let i = Math.max(0, index - 1); i <= index + 1; i++) {
      const hash = (Math.imul((seed >>> 0) ^ i, 1664525) + 1013904223) >>> 0;
      const centre = (i + 1) * idle.blinkEvery + (hash % (2 * idle.blinkJitter + 1)) - idle.blinkJitter;
      const half = idle.blinkFrames / 2;
      if (centre - half >= 0 && centre + half <= idle.frames)
        value = Math.max(value, 1 - Math.abs(frame - centre) / half);
    }
    return value;
  }

  function keyframe(ch, base, point) {
    const p = { ...base, ...point.pose };
    if (ch.arms) {
      for (const [field, side] of [
        ['armL', 'L'],
        ['armR', 'R'],
      ])
        if (p[field] === null) p[field] = ch.arms.presets[p.arms][side];
    } else {
      delete p.arms;
      delete p.armL;
      delete p.armR;
    }
    return p;
  }

  function gesturePose(ch, base, gesture, progress) {
    const points = gesture.timeline;
    const right = points.findIndex((point) => point.at > progress);
    if (right === -1) return keyframe(ch, base, points[points.length - 1]);
    const left = Math.max(0, right - 1);
    const a = keyframe(ch, base, points[left]);
    const b = keyframe(ch, base, points[right]);
    const span = points[right].at - points[left].at;
    const mix = span ? Math.max(0, Math.min(1, (progress - points[left].at) / span)) : 0;
    const result = {};
    for (const key of Object.keys(a))
      result[key] =
        typeof a[key] === 'number' && typeof b[key] === 'number' ? a[key] + (b[key] - a[key]) * mix : a[key];
    return result;
  }

  /**
   * Compute a frame directly, with no clock or canvas and without modifying the inputs.
   * @param {CharacterDescription} ch Immutable character description.
   * @param {MotionState} [state={}] Motion and held-pose state; activeAt defaults to frame 0.
   * @param {number} [frame=0] Absolute frame to compute, at mascot.fps (30 by default).
   * @returns {Object} Existing drawing pose fields; at rest only mood and held fields remain.
   */
  function pose(ch, state = {}, frame = 0) {
    const { change, idle, gestures } = config(ch);
    if (state.gesture !== undefined && state.gesture !== null) named(state.gesture, gestures, 'gesture');
    const activeAt = state.activeAt === undefined ? 0 : state.activeAt;
    const elapsedIdle = frame - activeAt;
    const target = named(state.mood === undefined ? Object.keys(ch.moods)[0] : state.mood, ch.moods, 'mood');
    const mood = shownMood(ch, state, frame, change);
    if (state.reduced || activeAt === null || elapsedIdle >= idle.frames) return { mood: target, ...state.pose };
    if (elapsedIdle < 0) return { mood, ...state.pose };
    const base = ns.drawing.resolvePose(ch, { mood });
    let p = { ...base, mood };
    delete p.t;
    const elapsed = frame - state.gestureAt;
    const gesture = gestures[state.gesture];
    const newerChange = state.changedAt !== undefined && frame >= state.changedAt && state.changedAt > state.gestureAt;
    if (gesture && !newerChange && elapsed >= 0 && elapsed < gesture.frames) {
      p = gesturePose(ch, p, gesture, elapsed / gesture.frames);
    } else {
      const elapsed = frame - state.changedAt;
      const replaced = state.gesture && frame >= state.gestureAt && state.gestureAt >= state.changedAt;
      if (
        !replaced &&
        state.previous !== undefined &&
        state.previous !== state.mood &&
        elapsed >= 0 &&
        elapsed < change.frames
      ) {
        const progress = elapsed / change.frames;
        if (change.style === 'hop') p.lift += change.height * 4 * progress * (1 - progress);
        else p.rot += change.angle * Math.sin(progress * 4 * Math.PI) * (1 - progress) ** 2;
      }
    }
    const fadeAt = (idle.frames * 2) / 3;
    const fraction = Math.max(0, (elapsedIdle - fadeAt) / (idle.frames - fadeAt));
    const fade = 1 - fraction * fraction * (3 - 2 * fraction);
    const breathe = idle.breathe * fade * Math.sin((2 * Math.PI * elapsedIdle) / idle.breathePeriod);
    p.sx *= 1 - breathe;
    p.sy *= 1 + breathe;
    p.blink = Math.max(p.blink, blink(state.seed === undefined ? 0 : state.seed, elapsedIdle, idle));
    const held = { ...p, ...state.pose };
    // A held arm preset wins over arm angles a gesture produced; held angles still win over the preset.
    if (ch.arms && Object.hasOwn(state.pose || {}, 'arms'))
      for (const [field, side] of [
        ['armL', 'L'],
        ['armR', 'R'],
      ])
        if (!Object.hasOwn(state.pose, field)) held[field] = ch.arms.presets[state.pose.arms][side];
    return held;
  }

  const patchFields = ['mood', 'pose', 'colours', 'reduced'];
  // The colour forms the drawing code reads: #RGB, #RRGGBB, rgb(r, g, b) and rgba(r, g, b, a).
  const colourForm = /^(#([0-9a-f]{3}|[0-9a-f]{6})|rgba?\(\s*[\d.]+\s*(,\s*[\d.]+\s*){2,3}\))$/i;
  const poseFields = () => Object.keys(ns.drawing.defaultPose).filter((key) => key !== 't');

  function object(value, field) {
    if (!value || typeof value !== 'object' || Array.isArray(value))
      throw new Error(`mascot: ${field}: invalid value '${String(value)}'; expected an object`);
  }

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

  // Build and guard every candidate before the controller changes any state or draws anything.
  function preparePatch(ch, current, patch) {
    object(patch, 'update');
    for (const [key, value] of Object.entries(patch))
      if (!patchFields.includes(key))
        throw new Error(
          `mascot: update.${key}: unknown field '${key}' (value '${String(value)}'); valid names: ${patchFields.join(', ')}`,
        );
    const next = { ...current };
    if (Object.hasOwn(patch, 'mood')) {
      try {
        next.mood = named(patch.mood, ch.moods, 'mood');
      } catch (e) {
        throw new Error(`mascot: update.mood: ${e.message.replace('mascot: ', '')}`);
      }
    }
    if (Object.hasOwn(patch, 'pose')) next.pose = overrides(current.pose, patch.pose, poseFields(), 'update.pose');
    ns.drawing.guardPose(ch, next.pose, 'update.pose');
    if (Object.hasOwn(patch, 'colours'))
      next.colours = overrides(current.colours, patch.colours, Object.keys(ch.colours), 'update.colours');
    for (const [role, value] of Object.entries(next.colours || {}))
      if (typeof value !== 'string' || !colourForm.test(value))
        throw new Error(
          `mascot: update.colours.${role}: invalid colour '${String(value)}'; use #RGB, #RRGGBB, rgb() or rgba()`,
        );
    if (Object.hasOwn(patch, 'reduced')) {
      const value = patch.reduced;
      if (value !== null && typeof value !== 'boolean')
        throw new Error(`mascot: update.reduced: invalid value '${String(value)}'; valid values: true, false, null`);
      next.reduced = value;
    }
    return next;
  }

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

  /**
   * Start a bounded player. The host owns canvas dimensions, status text and accessibility.
   * @param {HTMLCanvasElement} canvas Canvas to clear and draw.
   * @param {CharacterDescription} ch Immutable character description.
   * @param {MountOptions} [options={}] Position, initial mood, seed, colours and reduction preference.
   * @returns {MotionController} Per-canvas controller; all methods are inert after destroy().
   */
  function mount(canvas, ch, options = {}) {
    const settings = config(ch);
    const initial = { mood: Object.keys(ch.moods)[0], pose: {}, colours: {}, reduced: null };
    const initialPatch = Object.fromEntries(
      ['mood', 'colours', 'reduced'].filter((key) => options[key] !== undefined).map((key) => [key, options[key]]),
    );
    let values = preparePatch(ch, initial, initialPatch);
    const ctx = canvas.getContext('2d');
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const state = {
      mood: values.mood,
      pose: values.pose,
      activeAt: 0,
      seed: options.seed === undefined ? 0 : options.seed,
      reduced: values.reduced === null ? media.matches : values.reduced,
    };
    if (state.reduced) state.activeAt = null;
    let frame = 0;
    let request = null;
    let origin = null;
    let startFrame = 0;
    let paused = false;
    let destroyed = false;

    function moving() {
      return (
        !state.reduced &&
        state.activeAt !== null &&
        frame >= state.activeAt &&
        frame < state.activeAt + settings.idle.frames
      );
    }
    function drawFrame() {
      if (destroyed) return;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ns.draw(ctx, ch, {
        x: options.x,
        baseY: options.baseY,
        colours: values.colours,
        pose: pose(ch, state, frame),
        frame,
      });
    }
    function stopLoop() {
      if (request !== null) window.cancelAnimationFrame(request);
      request = null;
      origin = null;
    }
    function schedule() {
      if (destroyed || paused || !moving()) {
        stopLoop();
      } else if (request === null) {
        request = window.requestAnimationFrame(tick);
      }
    }
    function tick(timestamp) {
      request = null;
      if (destroyed || paused || !moving()) return;
      if (origin === null) {
        origin = timestamp;
        startFrame = frame;
      }
      const next = Math.min(
        state.activeAt + settings.idle.frames,
        startFrame + Math.floor(((timestamp - origin) * ns.fps) / 1000),
      );
      // Screens refresh faster than 30 fps: draw only when the frame number moves on.
      if (next !== frame) {
        frame = next;
        drawFrame();
      }
      schedule();
    }
    function activate() {
      state.activeAt = state.reduced ? null : frame;
      origin = null;
    }
    function settle() {
      state.previous = state.mood;
      delete state.changedAt;
      delete state.gesture;
      delete state.gestureAt;
      state.activeAt = null;
    }
    function preference(event) {
      if (destroyed || values.reduced !== null || state.reduced === event.matches) return;
      state.reduced = event.matches;
      if (state.reduced) settle();
      drawFrame();
      schedule();
    }
    const controller = {
      /**
       * Draw and move to a frame; it does not count as a new action.
       * @param {number} n Absolute frame, at mascot.fps (30 by default).
       * @returns {void}
       */
      seek(n) {
        if (destroyed) return;
        frame = n;
        origin = null;
        drawFrame();
        schedule();
      },
      /**
       * Validate the whole patch, then apply it atomically. Held pose fields are merged last.
       * @param {UpdatePatch} patch Fields to change; omitted fields stay unchanged.
       * @returns {void}
       */
      update(patch) {
        if (destroyed) return;
        const next = preparePatch(ch, values, patch);
        const moodChanged = next.mood !== values.mood;
        const poseChanged = !same(next.pose, values.pose);
        const reduced = next.reduced === null ? media.matches : next.reduced;
        const changed =
          moodChanged ||
          poseChanged ||
          !same(next.colours, values.colours) ||
          next.reduced !== values.reduced ||
          reduced !== state.reduced;
        if (!changed) return;
        if (moodChanged) {
          state.previous = shownMood(ch, state, frame, settings.change);
          state.mood = next.mood;
          state.changedAt = frame;
          delete state.gesture;
          delete state.gestureAt;
        }
        values = next;
        state.pose = next.pose;
        state.reduced = reduced;
        if (moodChanged || poseChanged) activate();
        if (state.reduced) settle();
        drawFrame();
        schedule();
      },
      /**
       * Shortcut for update({ mood: name }); repeating the target mood is a no-op.
       * @param {string} name A mood from character.moods.
       * @returns {void}
       */
      setMood(name) {
        controller.update({ mood: name });
      },
      /**
       * Replace the current action and commit its target mood, starting at the current frame.
       * @param {string} name A gesture ('nod' or 'wave', with character overrides).
       * @returns {void}
       */
      gesture(name) {
        if (destroyed) return;
        named(name, settings.gestures, 'gesture');
        delete state.changedAt;
        state.previous = state.mood;
        state.gesture = name;
        state.gestureAt = frame;
        activate();
        if (state.reduced) settle();
        drawFrame();
        schedule();
      },
      /**
       * Freeze elapsed frames, including after the player has automatically rested.
       * @returns {void}
       */
      pause() {
        if (destroyed) return;
        paused = true;
        stopLoop();
      },
      /**
       * Resume after pause without catching up; start a new activity window at this frame.
       * Calling play while already playing (including automatic rest) is a no-op.
       * @returns {void}
       */
      play() {
        if (destroyed || !paused) return;
        paused = false;
        activate();
        drawFrame();
        schedule();
      },
      /**
       * Stop permanently and remove the media listener; safe to call repeatedly.
       * @returns {void}
       */
      destroy() {
        if (destroyed) return;
        destroyed = true;
        stopLoop();
        media.removeEventListener('change', preference);
      },
    };
    drawFrame();
    media.addEventListener('change', preference);
    schedule();
    return controller;
  }

  ns.motion = { pose, validate };
  ns.mount = mount;
})();
