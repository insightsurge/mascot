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
 * Independent settings idle, mood_change and gestures default to true; false skips that layer.
 * The host owns minimising, restoring and messages; others supplies defaults for future switches.
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
 *
 * Character swaps: update({ character }) selects an immutable description. A different id resets
 * mood to its first described mood and colours to {}, unless supplied in that patch. Held fields
 * carry over except arms/armL/armR/armJitter without arms, unavailable arm presets, feet without
 * feet, shadow without a shadow, sweat/sparkle without those anchors, blush without face.blush,
 * and unavailable accessories (arrays retain available entries). Explicit patch fields are guarded.
 * Dropped held fields are not resurrected by a later swap back.
 * The same id keeps the mounted description and is an ordinary update, even for a different object.
 * swap defaults to true; swapTiming = { outFrames: 30, inFrames: 30 } is a mount option.
 * Positive finite durations are rounded to whole frames (at least one), individually capped at 150,
 * then proportionally fitted to the incoming whole-frame activity budget (at most 150).
 * Swap completion (swap.until) and activity completion (activeUntil) are computed once and stored.
 * frame(character, state, n) adds a pure, seekable selection of character, pose, colours and opacity.
 * SwapState retains the outgoing snapshot, so seeking backwards never depends on previous draws.
 * Each phase reuses the wave timeline; held fields still win. Idle starts at the swap's action frame
 * and ends within that character's activity window, including the swap itself.
 * Retargeting snapshots the visible character, resolved pose and opacity. During fade-out it keeps the
 * remaining exit time; during fade-in it exits in outFrames * current opacity. Returning to the
 * exiting character reverses directly into an entrance lasting inFrames * (1 - current opacity).
 * Recovery can extend that entrance enough to keep numeric steps within the target wave's speed;
 * fields the wave does not move use change.frames, always within the activity budget.
 * A reversal interpolates the captured numeric pose back to rest; other exits start their wave
 * at the captured pose. A retarget during either wave preserves its phase and speed, even with
 * only a few exit frames left. Pending targets never appear. Mood/pose/colour updates affect only the incoming character;
 * mood updates during the swap commit without a wiggle, and valid gestures are dropped.
 * These updates and play during a swap do not extend its window. Pause freezes absolute frames.
 * Reduction or swap:false finishes immediately on the target; later enabling either motion setting
 * never replays a discarded swap. current() reports the displayed id/mood and whether it is swapping.
 * Swap frames use a private canvas before compositing once with globalAlpha, so part-specific alpha
 * cannot bypass the fade. Canvas transforms/styles are saved/restored and clearing uses identity.
 * onChange(snapshot) receives the initial current() snapshot, then once per change of id, shown mood
 * or swapping, after player actions/ticks/seek (never pure pose/frame). Exceptions are reported once
 * per player via console.error and cannot stop it. No notifications follow destroy().
 * redraw() repeats the current drawing, including at rest, without changing time/state or RAF.
 * It is inert after destroy(). Hosts use it after canvas resize or a drawing-transform change.
 *
 * Internal, E4a: mascot.motion.tracks evaluates character-format v1 gestures (tracks, needs/fallback, the five
 * easings, interruption, reduction and absolute activity deadlines) as pure functions: compile() checks a v1
 * character, frameAt() returns channel values for one absolute frame. pose() uses them only while
 * mascot.internal.useCharacterAdapter is true and mascot.internal.tracks[id] = { compiled, settings } is
 * registered for the character; otherwise the legacy path above runs unchanged.
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
 * @property {number|null} [activeUntil] Stored activity deadline; defaults to activeAt + idle.frames.
 * @property {number} [seed=0] Unsigned 32-bit seed.
 * @property {boolean} [reduced=false] Skip motion.
 * @property {Object} [pose={}] Held explicit fields, applied last.
 * @property {Object<string, string>} [colours={}] Target colour overrides (used by frame()).
 * @property {SwapState} [swap] Retained swap timeline (used by frame()).
 */

/**
 * @typedef {Object} SwapState
 * @property {number} at Start frame.
 * @property {number} until Explicit absolute completion frame, computed once from whole durations.
 * @property {number} outFrames Exit duration; zero for a reversal.
 * @property {number} inFrames Entrance duration.
 * @property {number} opacity Visible opacity at the start.
 * @property {Object} outgoing Snapshot with character, resolved pose, held, colours and optional wave
 *   continuation { at, frames, pose, start }; start overrides the original wave's first endpoint.
 *   A recovery continuation { at, frames, pose, target } retains a reversal interrupted by a retarget.
 */

/**
 * @typedef {Object} MountOptions
 * @property {number} [x=0] Horizontal position in canvas units.
 * @property {number} [baseY=0] Baseline in canvas units.
 * @property {string} [mood] Initial mood; defaults to the first described mood.
 * @property {number} [seed=0] Unsigned 32-bit seed.
 * @property {Object<string, string>|null} [colours] Initial colour overrides; defaults to none.
 * @property {boolean|null} [reduced=null] Force reduction, or follow the media preference.
 * @property {boolean} [swap=true] Animate character swaps.
 * @property {Object} [swapTiming] Positive finite outFrames/inFrames rounded to whole frames; defaults 30/30.
 * @property {function(Object):void} [onChange] Initial and changed { character, mood, swapping } snapshots.
 */

/**
 * Omitted fields stay unchanged, except mood/colours reset on a different character id.
 * Null clears individual pose/colour keys, or their entire block.
 * @typedef {Object} UpdatePatch
 * @property {string} [mood] Target mood, with the same change behaviour as setMood().
 * @property {Object|null} [pose] Merge drawing fields except mood/t; null clears every held field.
 * @property {Object<string, string|null>|null} [colours] Merge colour roles; null clears all.
 * @property {boolean|null} [reduced] Force reduction, or null to follow the media preference.
 * @property {CharacterDescription} [character] Target description; identity is its id.
 * @property {boolean} [swap] Animate future swaps; false also finishes a running swap.
 */

/**
 * @typedef {Object} MotionController
 * @property {function(number):void} seek Draw and move to an absolute frame (no activity reset).
 * @property {function():void} redraw Draw the current frame without changing state/time/activity/RAF.
 * @property {function(UpdatePatch):void} update Validate and apply an atomic patch.
 * @property {function(string):void} setMood Shortcut for update({ mood: name }).
 * @property {function(string):void} gesture Replace the current action with a one-off gesture.
 * @property {function():void} pause Freeze elapsed frames.
 * @property {function():void} play Resume frozen frames; renew activity unless a swap is running.
 * @property {function():void} destroy Stop permanently and remove the media listener.
 * @property {function():Object} current Fresh snapshot { character: id, mood, swapping }.
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
  const checked = new WeakMap();

  /**
   * Thin motion-name guard used by validateCharacter(), including after late script loading.
   * @param {CharacterDescription} ch Immutable character description.
   * @returns {string[]} Name errors; an empty array means no name errors. R owns types/ranges.
   */
  function validate(ch) {
    if (checked.has(ch)) return [...checked.get(ch)];
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
    checked.set(ch, [...errors]);
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
      state.gestures !== false &&
      state.gesture &&
      frame >= state.gestureAt &&
      (state.changedAt === undefined || state.gestureAt >= state.changedAt);
    return !state.reduced &&
      state.mood_change !== false &&
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

  function gesturePose(ch, base, gesture, progress, start) {
    const points = gesture.timeline;
    const right = points.findIndex((point) => point.at > progress);
    if (right === -1) return keyframe(ch, base, points[points.length - 1]);
    const left = Math.max(0, right - 1);
    const a = start && left === 0 ? start : keyframe(ch, base, points[left]);
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
    const activeUntil = state.activeUntil === undefined ? activeAt + idle.frames : state.activeUntil;
    const target = named(state.mood === undefined ? Object.keys(ch.moods)[0] : state.mood, ch.moods, 'mood');
    const mood = shownMood(ch, state, frame, change);
    if (state.reduced || activeAt === null || frame >= activeUntil) return { mood: target, ...state.pose };
    if (elapsedIdle < 0) return { mood, ...state.pose };
    const base = ns.drawing.resolvePose(ch, { mood });
    let p = { ...base, mood };
    delete p.t;
    const bridge = ns.internal?.useCharacterAdapter === true ? ns.internal.tracks?.[ch.id] : undefined;
    const elapsed = frame - state.gestureAt;
    const gesture = gestures[state.gesture];
    const newerChange = state.changedAt !== undefined && frame >= state.changedAt && state.changedAt > state.gestureAt;
    if (bridge) {
      // Internal adapter switch: v1 tracks replace the legacy change and gesture layers; idle stays legacy.
      const { channels } = tracks.frameAt(
        bridge.compiled,
        { ...state, mood: target, idle: false, reduced: false, activeAt, activeUntil, held: {} },
        frame,
        { settings: bridge.settings, rest: () => bridgeRest(ch, p) },
      );
      p = bridgePose(ch, p, channels);
    } else if (state.gestures !== false && gesture && !newerChange && elapsed >= 0 && elapsed < gesture.frames) {
      p = gesturePose(ch, p, gesture, elapsed / gesture.frames);
    } else {
      const elapsed = frame - state.changedAt;
      const replaced =
        state.gestures !== false && state.gesture && frame >= state.gestureAt && state.gestureAt >= state.changedAt;
      if (
        state.mood_change !== false &&
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
    if (state.idle === false) return heldPose(ch, p, state.pose);
    const fadeAt = (idle.frames * 2) / 3;
    const fraction = Math.max(0, (elapsedIdle - fadeAt) / (idle.frames - fadeAt));
    const fade = 1 - fraction * fraction * (3 - 2 * fraction);
    const breathe = idle.breathe * fade * Math.sin((2 * Math.PI * elapsedIdle) / idle.breathePeriod);
    p.sx *= 1 - breathe;
    p.sy *= 1 + breathe;
    p.blink = Math.max(p.blink, blink(state.seed === undefined ? 0 : state.seed, elapsedIdle, idle));
    return heldPose(ch, p, state.pose);
  }

  function heldPose(ch, p, explicit) {
    const held = { ...p, ...explicit };
    // A held arm preset wins over arm angles a gesture produced; held angles still win over the preset.
    if (ch.arms && Object.hasOwn(explicit || {}, 'arms'))
      for (const [field, side] of [
        ['armL', 'L'],
        ['armR', 'R'],
      ])
        if (!Object.hasOwn(explicit, field)) held[field] = ch.arms.presets[explicit.arms][side];
    return held;
  }

  /**
   * Select exactly one character and compute its drawing fields, without mutation or a clock.
   * @param {CharacterDescription} ch Target immutable description.
   * @param {MotionState} [state={}] Target state, optionally with an outgoing swap snapshot.
   * @param {number} [n=0] Absolute frame.
   * @returns {Object} { character, pose, colours, opacity, swapping }; character is a description.
   */
  function sceneFrame(ch, state = {}, n = 0) {
    const swap = state.swap;
    const elapsed = swap ? n - swap.at : 0;
    const swapping = Boolean(swap && !state.reduced && n < swap.until);
    if (!swapping)
      return { character: ch, pose: pose(ch, state, n), colours: state.colours || {}, opacity: 1, swapping: false };
    if (swap.outFrames > 0 && elapsed < swap.outFrames) {
      const out = swap.outgoing;
      const progress = Math.max(0, elapsed / swap.outFrames);
      const wave = out.wave;
      const recovery = out.recovery;
      const waveProgress = wave ? Math.max(0, Math.min(1, (n - wave.at) / wave.frames)) : progress;
      return {
        character: out.character,
        pose: heldPose(
          out.character,
          recovery
            ? recoverPose(recovery.pose, recovery.target, Math.max(0, Math.min(1, (n - recovery.at) / recovery.frames)))
            : gesturePose(
                out.character,
                wave ? wave.pose : out.pose,
                config(out.character).gestures.wave,
                waveProgress,
                wave ? wave.start : out.pose,
              ),
          out.held,
        ),
        colours: out.colours,
        opacity: swap.opacity * (1 - progress),
        swapping: true,
      };
    }
    const progress = Math.max(0, Math.min(1, (elapsed - swap.outFrames) / swap.inFrames));
    const base = pose(ch, state, n);
    const resolved = ns.drawing.resolvePose(ch, base);
    // A reversal recovers directly from the displayed pose to rest, without restarting the wave.
    // Interpolate all numeric fields, including resolved arm angles; no numeric jump at progress zero.
    const returning = swap.outFrames === 0 && swap.outgoing.character.id === ch.id;
    const incoming = returning
      ? recoverPose(swap.outgoing.pose, keyframe(ch, resolved, { pose: {} }), progress)
      : gesturePose(ch, resolved, config(ch).gestures.wave, progress);
    return {
      character: ch,
      pose: heldPose(ch, incoming, state.pose),
      colours: state.colours || {},
      opacity: swap.outFrames === 0 ? swap.opacity + (1 - swap.opacity) * progress : progress,
      swapping: true,
    };
  }

  const motionFlags = ['idle', 'mood_change', 'gestures', 'swap', 'minimising', 'restoring', 'others'];
  const panelNames = ['bubble', 'tooltip', 'menu'];
  const patchFields = ['mood', 'pose', 'colours', 'reduced', 'character', 'messages', ...motionFlags];
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
    if (Object.hasOwn(patch, 'character')) {
      try {
        config(patch.character);
      } catch (e) {
        throw new Error(`mascot: update.character: ${e.message.replace('mascot: ', '')}`);
      }
      if (patch.character.id !== ch.id) {
        ch = patch.character;
        next.character = ch;
        next.mood = Object.keys(ch.moods)[0];
        next.colours = {};
        next.pose = carryPose(ch, current.pose);
      }
    }
    if (Object.hasOwn(patch, 'mood')) {
      try {
        next.mood = named(patch.mood, ch.moods, 'mood');
      } catch (e) {
        throw new Error(`mascot: update.mood: ${e.message.replace('mascot: ', '')}`);
      }
    }
    if (Object.hasOwn(patch, 'pose')) next.pose = overrides(next.pose, patch.pose, poseFields(), 'update.pose');
    ns.drawing.guardPose(ch, next.pose, 'update.pose');
    if (Object.hasOwn(patch, 'colours'))
      next.colours = overrides(next.colours, patch.colours, Object.keys(ch.colours), 'update.colours');
    for (const [role, value] of Object.entries(next.colours || {}))
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

  function carryPose(ch, current) {
    const p = { ...current };
    if (!ch.arms) for (const key of ['arms', 'armL', 'armR', 'armJitter']) delete p[key];
    else if (p.arms !== undefined && !Object.hasOwn(ch.arms.presets, p.arms)) delete p.arms;
    for (const [field, usable] of [
      ['feet', ch.feet],
      ['shadow', ch.shadow],
      ['sweat', ch.anchors?.sweat],
      ['sparkle', ch.anchors?.sparkle],
      ['blush', ch.face.blush],
    ])
      if (!usable) delete p[field];
    if (p.accessory !== undefined) {
      const available = (name) => name === 'none' || Object.hasOwn(ch.accessories || {}, name);
      if (Array.isArray(p.accessory)) p.accessory = p.accessory.filter(available);
      else if (!available(p.accessory)) delete p.accessory;
    }
    return p;
  }

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

  function recoverPose(from, to, progress) {
    const result = { ...to };
    for (const [key, value] of Object.entries(from))
      if (key !== 't' && typeof value === 'number' && typeof to[key] === 'number')
        result[key] = value + (to[key] - value) * progress;
    return result;
  }

  // A very early reversal may reset a different mood's arm angles. Give that recovery enough
  // whole frames to stay within the target wave's numeric speed, rather than snapping at completion.
  // Fields the wave does not move recover over the ordinary mood-change duration. The activity cap wins.
  function recoveryFrames(ch, from, next) {
    const { gestures, change } = config(ch);
    const base = keyframe(ch, ns.drawing.resolvePose(ch, { mood: next.mood, ...next.pose }), { pose: {} });
    const points = gestures.wave.timeline.map((point) => keyframe(ch, base, point));
    let frames = 0;
    for (const [key, value] of Object.entries(from)) {
      if (key === 't' || typeof value !== 'number' || typeof base[key] !== 'number') continue;
      const distance = Math.abs(value - base[key]);
      if (distance < 1e-12) continue;
      let rate = 0;
      for (let i = 1; i < points.length; i++) {
        const span = gestures.wave.frames * (gestures.wave.timeline[i].at - gestures.wave.timeline[i - 1].at);
        if (typeof points[i][key] === 'number' && typeof points[i - 1][key] === 'number')
          rate = Math.max(rate, Math.abs(points[i][key] - points[i - 1][key]) / span);
      }
      frames = Math.max(frames, rate ? distance / rate : change.frames);
    }
    return Math.ceil(frames - 1e-9);
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
   * @param {MountOptions} [options={}] Position, mood, seed, colours, reduction, swap settings and change callback.
   * @returns {MotionController} Per-canvas controller; mutations are inert after destroy().
   */
  function mount(canvas, ch, options = {}) {
    let settings = config(ch);
    const timing = swapTiming(options.swapTiming);
    if (options.onChange !== undefined && typeof options.onChange !== 'function')
      throw new Error('mascot: onChange: expected a function');
    const onChange = options.onChange;
    const initial = {
      character: ch,
      mood: Object.keys(ch.moods)[0],
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
    let values = preparePatch(ch, initial, initialPatch);
    const ctx = canvas.getContext('2d');
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const state = {
      idle: values.idle,
      mood_change: values.mood_change,
      gestures: values.gestures,
      mood: values.mood,
      pose: values.pose,
      colours: values.colours,
      activeAt: 0,
      activeUntil: Math.floor(settings.idle.frames),
      seed: options.seed === undefined ? 0 : options.seed,
      reduced: media.matches || values.reduced === true,
    };
    if (state.reduced) state.activeAt = null;
    let frame = 0;
    let request = null;
    let origin = null;
    let startFrame = 0;
    let paused = false;
    let visibilityHeld = false;
    let destroyed = false;
    let layer = null;
    let notified = null;
    let callbackErrorReported = false;

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
      return (
        !state.reduced &&
        (state.idle ||
          (state.swap && frame < state.swap.until) ||
          (state.mood_change && state.changedAt !== undefined && frame < state.changedAt + settings.change.frames) ||
          (state.gestures && state.gesture && frame < state.gestureAt + settings.gestures[state.gesture].frames)) &&
        state.activeAt !== null &&
        frame >= state.activeAt &&
        frame < state.activeUntil
      );
    }
    function drawFrame() {
      if (destroyed) return;
      const visible = sceneFrame(ch, state, frame);
      ctx.save();
      try {
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        // Ordinary frames retain the host's drawing transform and alpha, as before.
      } finally {
        ctx.restore();
      }
      const drawing = { x: options.x, baseY: options.baseY, colours: visible.colours, pose: visible.pose, frame };
      if (!visible.swapping) {
        ctx.save();
        try {
          ns.draw(ctx, visible.character, drawing);
        } finally {
          ctx.restore();
        }
        return;
      }
      if (!layer) layer = canvas.ownerDocument.createElement('canvas');
      if (layer.width !== canvas.width) layer.width = canvas.width;
      if (layer.height !== canvas.height) layer.height = canvas.height;
      const buffer = layer.getContext('2d');
      buffer.clearRect(0, 0, layer.width, layer.height);
      buffer.save();
      try {
        const transform = ctx.getTransform();
        buffer.setTransform(transform.a, transform.b, transform.c, transform.d, transform.e, transform.f);
        ns.draw(buffer, visible.character, drawing);
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
      if (destroyed || paused || visibilityHeld || !moving()) {
        stopLoop();
      } else if (request === null) {
        request = window.requestAnimationFrame(tick);
      }
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
        drawFrame();
      }
      schedule();
      notifyChange();
    }
    function activate() {
      state.activeAt = state.reduced ? null : frame;
      state.activeUntil = state.reduced ? null : frame + Math.floor(settings.idle.frames);
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
      /** Draw the current frame again without moving time, renewing activity or scheduling RAF.
       * @returns {void}
       */
      redraw() {
        drawFrame();
      },
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
        notifyChange();
      },
      /**
       * Validate the whole patch, then apply it atomically. Held pose fields are merged last.
       * @param {UpdatePatch} patch Fields to change; omitted fields stay unchanged.
       * @returns {void}
       */
      update(patch) {
        if (destroyed) return;
        const next = preparePatch(ch, values, patch);
        const characterChanged = next.character !== ch;
        const wasSwapping = sceneFrame(ch, state, frame).swapping;
        const moodChanged = next.mood !== values.mood;
        const poseChanged = !same(next.pose, values.pose);
        const reduced = media.matches || next.reduced === true;
        const changed =
          characterChanged ||
          moodChanged ||
          poseChanged ||
          !same(next.colours, values.colours) ||
          next.reduced !== values.reduced ||
          motionFlags.some((key) => next[key] !== values[key]) ||
          !same(next.messages, values.messages) ||
          reduced !== state.reduced;
        if (!changed) return;
        if (characterChanged) {
          const visible = sceneFrame(ch, state, frame);
          const outgoing = {
            character: visible.character,
            pose: keyframe(visible.character, ns.drawing.resolvePose(visible.character, visible.pose, frame), {
              pose: {},
            }),
            held: visible.character === ch ? values.pose : state.swap.outgoing.held,
            colours: visible.colours,
          };
          // Keep an already visible wave's phase and speed when tabs retarget it. Only its
          // opacity timeline changes; restarting a wave in the remaining exit time would jerk.
          if (wasSwapping) {
            if (
              state.swap.outFrames > 0 &&
              frame < state.swap.at + state.swap.outFrames &&
              state.swap.outgoing.recovery
            )
              outgoing.recovery = state.swap.outgoing.recovery;
            else if (state.swap.outFrames > 0 && frame < state.swap.at + state.swap.outFrames)
              outgoing.wave = state.swap.outgoing.wave || {
                at: state.swap.at,
                frames: state.swap.outFrames,
                pose: state.swap.outgoing.pose,
                start: state.swap.outgoing.pose,
              };
            else if (state.swap.outgoing.character.id !== ch.id)
              outgoing.wave = {
                at: state.swap.at + state.swap.outFrames,
                frames: state.swap.inFrames,
                pose: ns.drawing.resolvePose(ch, pose(ch, state, frame), frame),
              };
            else
              outgoing.recovery = {
                at: frame,
                frames: state.swap.until - frame,
                pose: outgoing.pose,
                target: keyframe(ch, ns.drawing.resolvePose(ch, pose(ch, state, frame), frame), { pose: {} }),
              };
          }
          const returning = visible.character.id === next.character.id;
          let outFrames = returning ? 0 : timing.outFrames * visible.opacity;
          if (wasSwapping && state.swap.outFrames > 0 && frame < state.swap.at + state.swap.outFrames && !returning)
            outFrames = state.swap.at + state.swap.outFrames - frame;
          let inFrames = timing.inFrames * (returning ? 1 - visible.opacity : 1);
          ch = next.character;
          settings = config(ch);
          if (returning) inFrames = Math.max(inFrames, recoveryFrames(ch, outgoing.pose, next));
          // Quantise once. Both completion and activity use stored absolute deadlines.
          const total = Math.min(Math.floor(settings.idle.frames), Math.round(outFrames + inFrames));
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
            state.swap = { at: frame, until: frame + total, outFrames, inFrames, opacity: visible.opacity, outgoing };
        } else if (moodChanged) {
          state.previous = shownMood(ch, state, frame, settings.change);
          state.mood = next.mood;
          if (wasSwapping) {
            state.previous = next.mood;
            delete state.changedAt;
          } else state.changedAt = frame;
          delete state.gesture;
          delete state.gestureAt;
        }
        values = next;
        state.pose = next.pose;
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
        if (characterChanged || (!wasSwapping && (moodChanged || poseChanged))) activate();
        if (!next.swap) delete state.swap;
        if (state.reduced) settle();
        drawFrame();
        schedule();
        notifyChange();
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
        if (!values.gestures) return;
        if (sceneFrame(ch, state, frame).swapping) return;
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
      /**
       * Freeze elapsed frames, including after the player has automatically rested.
       * @returns {void}
       */
      pause() {
        if (destroyed) return;
        paused = true;
        stopLoop();
      },
      /** Hold visibility independently of user pause, without renewing activity or drawing.
       * @param {boolean} held Whether the host is outside the viewport.
       * @returns {void}
       */
      holdVisibility(held) {
        if (destroyed || visibilityHeld === held) return;
        visibilityHeld = held;
        stopLoop();
        schedule();
      },
      /**
       * Resume after pause without catching up; renew activity unless a swap is still running.
       * Calling play while already playing (including automatic rest) is a no-op.
       * @returns {void}
       */
      play() {
        if (destroyed || !paused) return;
        paused = false;
        if (!sceneFrame(ch, state, frame).swapping) activate();
        drawFrame();
        schedule();
        notifyChange();
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
        layer = null;
      },
      /**
       * Read the displayed state; changing the returned object cannot affect the player.
       * Remains readable at the final frozen frame after destroy().
       * @returns {Object} { character: string, mood: string, swapping: boolean }.
       */
      current() {
        const visible = sceneFrame(ch, state, frame);
        return { character: visible.character.id, mood: visible.pose.mood, swapping: visible.swapping };
      },
    };
    drawFrame();
    media.addEventListener('change', preference);
    schedule();
    notifyChange();
    return controller;
  }

  // ---- Format-v1 tracks (internal, E4a) -------------------------------------------------------------
  // Pure functions over a checked character-format v1 description; nothing here draws, reads a clock or
  // touches the DOM. Only the internal adapter switch (ns.internal.useCharacterAdapter with a registered
  // ns.internal.tracks[id]) lets pose() use them; the default player never does.
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
          if (key !== 'mode' && key !== 'keys') problem('unknown_key', `${path}.${key}`, 'Use only mode and keys.');
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
      for (const [group, allowed] of Object.entries(motionDefaults))
        for (const key of Object.keys(motion[group] ?? {}))
          if (!Object.hasOwn(allowed, key))
            problem('unknown_key', `$.motion.${group}.${key}`, `Use one of ${Object.keys(allowed).join(', ')}.`);
      for (const key of Object.keys(motion))
        if (!Object.hasOwn(motionDefaults, key))
          problem('unknown_key', `$.motion.${key}`, `Use one of ${Object.keys(motionDefaults).join(', ')}.`);
      const change = { ...motionDefaults.change, ...motion.change };
      const idle = { ...motionDefaults.idle, ...motion.idle };
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
      // The idle extra plays once from a host-supplied start (the format leaves its timing open); an
      // action in progress wins, and a late start is fitted into the frames left (none left: discarded).
      if (!playing && !changing && idle.extra && state.extraAt != null && frame >= state.extraAt) {
        const extra = own(compiled.gestures, own(compiled.selected, idle.extra));
        if (!extra)
          problem('missing_reference', '$.motion.idle.extra', `Name a declared gesture, not '${idle.extra}'.`);
        const length = fit(state.extraAt, extra.frames, until);
        const u = length > 0 ? (frame - state.extraAt) / length : 1;
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

  // Internal bridge for the provisional adapter: the legacy pose fields, with the v1 tracks of the
  // character registered in ns.internal.tracks[id]. Off unless the adapter switch is on.
  function bridgeRest(ch, p) {
    const arms = ch.arms ? ns.drawing.armAngles(ch, { ...p, t: 0, armJitter: 0 }) : null;
    const rest = {
      'root.lift': p.lift,
      'root.rotate': p.rot,
      'root.scale_x': p.scale * p.sx,
      'root.scale_y': p.scale * p.sy,
    };
    if (arms) {
      rest['arm_l.rotate'] = arms.L;
      rest['arm_r.rotate'] = arms.R;
    }
    return rest;
  }

  function bridgePose(ch, p, channels) {
    const next = { ...p };
    if (Object.hasOwn(channels, 'root.lift')) next.lift = channels['root.lift'];
    if (Object.hasOwn(channels, 'root.rotate')) next.rot = channels['root.rotate'];
    if (p.scale !== 0) {
      if (Object.hasOwn(channels, 'root.scale_x')) next.sx = channels['root.scale_x'] / p.scale;
      if (Object.hasOwn(channels, 'root.scale_y')) next.sy = channels['root.scale_y'] / p.scale;
    }
    if (ch.arms) {
      if (Object.hasOwn(channels, 'arm_l.rotate')) next.armL = channels['arm_l.rotate'];
      if (Object.hasOwn(channels, 'arm_r.rotate')) next.armR = channels['arm_r.rotate'];
    }
    return next;
  }

  ns.motion = {
    pose,
    frame: sceneFrame,
    tracks,
    validate,
    settings: Object.freeze(motionFlags),
    panels: Object.freeze(panelNames),
  };
  ns.mount = mount;
})();
