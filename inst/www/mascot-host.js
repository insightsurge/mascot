/**
 * Page host for mascot: one record and controller per element, with an idempotent lifecycle.
 * A Shiny input binding mounts on subscribe and destroys on unsubscribe; static pages mount at DOM ready.
 * Custom messages carry { id, patch }; late state merges by id, while late gestures are dropped.
 * Patches are atomic: prepare descriptions/status, ask the engine to validate, then commit host state.
 * Desired character/mood live in data-character/data-mood; data-shown-* and status follow the shown frame.
 * Custom status persists across swaps. Development problems temporarily cover it and use a worried mood;
 * the next good patch clears the problem and restores the earlier mood unless it chooses another.
 * The host owns canvas dimensions (CSS size times pixel ratio), the 300-unit transform and accessible text.
 * Motion follows the visitor's preference. No per-element global listeners are added by this host.
 * host.{mount,unmount,receive,state} exposes lifecycle and plain snapshots for integration tests.
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.host) return;

  const records = new WeakMap();
  const pending = new Map();
  const known = new Map();
  const updating = new WeakSet();
  const has = (object, key) => Object.hasOwn(object, key);
  const label = (mood) => mood.charAt(0).toUpperCase() + mood.slice(1);
  const warn = (error) => console.warn(`mascot: ${String(error.message || error).replace(/^mascot: /, '')}`);

  function show(record, snapshot) {
    if (updating.has(record)) return;
    record.el.dataset.shownCharacter = snapshot.character;
    record.el.dataset.shownMood = snapshot.mood;
    record.el.dataset.swapping = String(snapshot.swapping);
    record.canvas.setAttribute('aria-label', `${record.names.get(snapshot.character)}, ${snapshot.mood}`);
    const text = record.problem || (record.status.mode === 'mood' ? label(snapshot.mood) : record.status.text);
    if (record.statusEl.textContent !== text) record.statusEl.textContent = text;
  }

  // Bubble time is independent of the deterministic drawing engine, in seconds.
  function remaining(record) {
    if (!record.bubble || record.bubble.remaining === null) return null;
    return Math.max(
      0,
      record.bubble.remaining - (record.started === null ? 0 : (window.performance.now() - record.started) / 1000),
    );
  }

  function stopTimer(record) {
    if (record.bubble) record.bubble.remaining = remaining(record);
    if (record.timer !== null) window.clearTimeout(record.timer);
    record.timer = null;
    record.started = null;
  }

  function resumeTimer(record) {
    if (!record.bubble || record.bubble.remaining === null || record.hover || record.focus || record.timer !== null)
      return;
    if (record.bubble.remaining <= 0) {
      clearBubble(record);
      return;
    }
    record.started = window.performance.now();
    // Large finite durations need chunks: browsers otherwise overflow a signed 32-bit delay.
    record.timer = window.setTimeout(
      () => {
        stopTimer(record);
        resumeTimer(record);
      },
      Math.min(record.bubble.remaining * 1000, 2147483647),
    );
  }

  function clearBubble(record) {
    stopTimer(record);
    record.bubble = null;
    const focused = record.bubbleEl.contains(document.activeElement);
    record.bubbleEl.hidden = true;
    delete record.bubbleEl.dataset.text;
    if (focused) record.el.focus();
    record.bubbleText.textContent = '';
    record.bubbleEl.querySelector('.mascot-bubble-close')?.remove();
    record.hover = false;
  }

  function validateBubble(next) {
    if (!next || typeof next !== 'object' || Array.isArray(next)) throw new Error('bubble needs an object');
    const keys = next.clear === true ? ['clear'] : ['text', 'html', 'closable', 'duration'];
    if (Object.keys(next).some((key) => !keys.includes(key))) throw new Error('unknown bubble field');
    if (next.clear === true) return null;
    if (
      typeof next.text !== 'string' ||
      !next.text.length ||
      typeof next.html !== 'boolean' ||
      typeof next.closable !== 'boolean' ||
      !(
        next.duration === null ||
        (typeof next.duration === 'number' && Number.isFinite(next.duration) && next.duration > 0)
      )
    )
      throw new Error('bubble needs non-empty text, html and closable flags, and a positive duration or null');
    return { text: next.text, html: next.html, closable: next.closable, remaining: next.duration };
  }

  function replaceBubble(record, next) {
    if (!next) {
      clearBubble(record);
      return;
    }
    stopTimer(record);
    record.bubble = next;
    const el = record.bubbleEl;
    el.dataset.text = next.text;
    el.dataset.html = String(next.html);
    el.dataset.closable = String(next.closable);
    if (next.remaining === null) delete el.dataset.duration;
    else el.dataset.duration = String(next.remaining);
    // Move focus before removing any focused link or close button.
    if (el.contains(document.activeElement)) record.el.focus();
    if (next.html) record.bubbleText.innerHTML = next.text;
    else record.bubbleText.textContent = next.text;
    el.querySelector('.mascot-bubble-close')?.remove();
    if (next.closable) {
      const button = document.createElement('button');
      button.className = 'mascot-bubble-close';
      button.type = 'button';
      button.setAttribute('aria-label', 'Close message');
      button.textContent = '\u00d7';
      el.append(button);
    }
    el.hidden = false;
    resumeTimer(record);
  }

  function listenBubble(record) {
    const el = record.el;
    const bubble = record.bubbleEl;
    const handlers = {
      pointerover(event) {
        if (!bubble.contains(event.target) || bubble.contains(event.relatedTarget)) return;
        record.hover = true;
        stopTimer(record);
      },
      pointerout(event) {
        if (!bubble.contains(event.target) || bubble.contains(event.relatedTarget)) return;
        record.hover = false;
        resumeTimer(record);
      },
      focusin() {
        record.focus = true;
        stopTimer(record);
      },
      focusout(event) {
        record.focus = el.contains(event.relatedTarget);
        if (!record.focus) resumeTimer(record);
      },
      keydown(event) {
        if (event.key === 'Escape' && el.contains(document.activeElement) && record.bubble) {
          clearBubble(record);
          event.preventDefault();
          event.stopPropagation();
        }
      },
      click(event) {
        if (event.target.closest('.mascot-bubble-close') && bubble.contains(event.target)) clearBubble(record);
      },
    };
    record.handlers = handlers;
    for (const [name, handler] of Object.entries(handlers)) el.addEventListener(name, handler);
  }

  function validateGesture(description, name) {
    if (typeof name !== 'string' || !name.length) throw new Error('gesture needs a non-empty name');
    // The engine owns the vocabulary. Its pure pose path validates without changing a controller.
    if (description) ns.motion.pose(description, { gesture: name, reduced: true }, 0);
  }

  function mount(el) {
    if (records.has(el)) return;
    const id = el.dataset.character;
    const description = ns.readCharacter(id, el);
    const canvas = el.querySelector('.mascot-canvas');
    const statusEl = el.querySelector('.mascot-status');
    const bubbleEl = el.querySelector('.mascot-bubble');
    const size = parseFloat(getComputedStyle(el).getPropertyValue('--mascot-size')) || 160;
    canvas.width = canvas.height = Math.round(size * (window.devicePixelRatio || 1));
    const k = canvas.width / 300;
    canvas.getContext('2d').setTransform(k, 0, 0, k, 0, 0);
    const record = {
      el,
      canvas,
      statusEl,
      controller: null,
      names: new Map([[id, description.name]]),
      descriptions: new Map([[id, description]]),
      character: id,
      mood: el.dataset.mood,
      status: { mode: el.dataset.status, text: el.dataset.status === 'custom' ? statusEl.textContent : null },
      problem: null,
      problemMood: null,
      bubbleEl,
      bubbleText: bubbleEl.querySelector('.mascot-bubble-text'),
      bubble: bubbleEl.hidden
        ? null
        : validateBubble({
            text: bubbleEl.dataset.text,
            html: bubbleEl.dataset.html === 'true',
            closable: bubbleEl.dataset.closable === 'true',
            duration: has(bubbleEl.dataset, 'duration') ? Number(bubbleEl.dataset.duration) : null,
          }),
      timer: null,
      started: null,
      hover: bubbleEl.matches(':hover'),
      focus: el.contains(document.activeElement),
      handlers: null,
    };
    records.set(el, record);
    try {
      record.controller = ns.mount(canvas, description, {
        x: 150,
        baseY: 270,
        mood: el.dataset.mood,
        reduced: null,
        onChange: (snapshot) => show(record, snapshot),
      });
    } catch (error) {
      records.delete(el);
      throw error;
    }
    listenBubble(record);
    resumeTimer(record);
    known.set(el.id, description);
    const waiting = pending.get(el.id);
    if (waiting) {
      pending.delete(el.id);
      let current = description;
      const descriptions = new Map(record.descriptions);
      const patch = {};
      // Preserve whole patches until this target's mood vocabulary is known.
      for (const { patch: next, warnedGesture } of waiting.patches) {
        try {
          const prepared = prepare(next, current, descriptions);
          if (has(next, 'gesture') && !warnedGesture) warnGesture(el.id, next.gesture);
          mergeQueued(patch, next);
          if (prepared.description) {
            current = prepared.description;
            descriptions.set(current.id, current);
          }
        } catch (error) {
          warn(error);
        }
      }
      const { problem, ...good } = patch;
      if (Object.keys(good).length) apply(el, good);
      if (problem !== undefined) apply(el, { problem });
    }
  }

  function apply(el, patch) {
    const record = records.get(el);
    let prepared;
    try {
      prepared = prepare(patch, record.descriptions.get(record.character), record.descriptions);
    } catch (error) {
      warn(error);
      return;
    }
    if (has(patch, 'problem')) {
      if (!record.problem) record.problemMood = record.mood;
      record.problem = patch.problem;
      const shown = record.controller.current();
      if (has(record.descriptions.get(shown.character).moods, 'worried')) {
        record.controller.update({ mood: 'worried' });
      }
      show(record, record.controller.current());
      // Shiny listens on window (shiny.js 1.14.0), so dispatch there: a non-bubbling event on document never arrives.
      if (window.Shiny) {
        window.dispatchEvent(
          new CustomEvent('shiny:client-message', {
            detail: { headline: 'mascot', message: patch.problem, status: 'warning' },
          }),
        );
      }
      return;
    }

    const enginePatch = { ...prepared.enginePatch };
    try {
      if (!has(patch, 'mood') && record.problem && !prepared.changed) enginePatch.mood = record.problemMood;
      // Synchronous engine notifications must not expose a partially committed host patch.
      updating.add(record);
      if (Object.keys(enginePatch).length) record.controller.update(enginePatch);
    } catch (error) {
      warn(error);
      return;
    } finally {
      updating.delete(record);
    }

    const { description, changed } = prepared;
    const status = prepared.status || record.status;
    record.problem = null;
    record.problemMood = null;
    if (description) {
      record.character = description.id;
      record.names.set(description.id, patch.character.name);
      record.descriptions.set(description.id, description);
    }
    if (has(enginePatch, 'mood')) record.mood = enginePatch.mood;
    else if (changed) record.mood = Object.keys(description.moods)[0];
    record.status = status;
    el.dataset.character = record.character;
    el.dataset.mood = record.mood;
    el.dataset.status = status.mode;
    known.set(el.id, record.descriptions.get(record.character));
    show(record, record.controller.current());
    if (has(patch, 'bubble')) replaceBubble(record, prepared.bubble);
    if (has(patch, 'gesture')) record.controller.gesture(patch.gesture);
  }

  // Use the same pure preflight for mounted and queued patches; never merge a partial bad patch.
  function prepare(patch, current, descriptions = new Map(current ? [[current.id, current]] : [])) {
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) throw new Error('update needs an object');
    for (const key of Object.keys(patch)) {
      if (!['character', 'mood', 'status', 'bubble', 'gesture', 'problem'].includes(key))
        throw new Error(`unknown update field "${key}"`);
    }
    if (has(patch, 'problem')) {
      if (Object.keys(patch).length !== 1 || typeof patch.problem !== 'string' || !patch.problem.length)
        throw new Error('problem needs non-empty text and no other fields');
      return { enginePatch: {} };
    }
    let description;
    let changed = false;
    const enginePatch = {};
    if (has(patch, 'character')) {
      const ch = patch.character;
      if (!ch || typeof ch.id !== 'string' || !ch.id || typeof ch.name !== 'string' || !ch.name)
        throw new Error('character needs an id and name');
      description = descriptions.get(ch.id) || JSON.parse(ch.json);
      if (!description || description.id !== ch.id) throw new Error('character id does not match its description');
      ns.motion.pose(description, { reduced: true }, 0);
      enginePatch.character = description;
      changed = ch.id !== current?.id;
    }
    const candidate = changed ? description : current;
    if (has(patch, 'mood')) {
      if (typeof patch.mood !== 'string' || !patch.mood.length) throw new Error('mood needs a non-empty name');
      if (candidate) ns.motion.pose(candidate, { mood: patch.mood, reduced: true }, 0);
      enginePatch.mood = patch.mood;
    }
    let status;
    if (has(patch, 'status')) {
      const next = patch.status;
      if (
        !next ||
        !['mood', 'custom'].includes(next.mode) ||
        (next.mode === 'custom' && (typeof next.text !== 'string' || !next.text.length))
      )
        throw new Error('status needs mode "mood" or mode "custom" with non-empty text');
      status = { mode: next.mode, text: next.mode === 'custom' ? next.text : null };
    }
    const bubble = has(patch, 'bubble') ? validateBubble(patch.bubble) : undefined;
    if (has(patch, 'gesture')) validateGesture(candidate, patch.gesture);
    return { description, changed, enginePatch, status, bubble };
  }

  function mergeQueued(next, patch) {
    if (!has(patch, 'problem')) delete next.problem;
    if (has(patch, 'character')) {
      next.character = patch.character;
      delete next.mood;
    }
    for (const key of ['mood', 'status', 'bubble', 'problem']) {
      if (has(patch, key)) next[key] = patch[key];
    }
  }

  function queue(id, patch) {
    const waiting = pending.get(id);
    const current = waiting?.description || known.get(id);
    let prepared;
    try {
      // Without a target character, validate shape now and vocabulary at mount.
      prepared = prepare(patch, current);
    } catch (error) {
      warn(error);
      return;
    }
    const warnedGesture = has(patch, 'gesture') && Boolean(current || prepared.description);
    if (warnedGesture) warnGesture(id, patch.gesture);
    pending.set(id, {
      patches: [...(waiting?.patches || []), { patch, warnedGesture }],
      description: prepared.description || current,
    });
  }

  function warnGesture(id, name) {
    console.warn(`mascot: gesture "${name}" for "${id}" was dropped: the mascot was not on the page yet`);
  }

  function receive(message) {
    const targets = [...document.querySelectorAll('.mascot')].filter((el) => el.id === message.id && records.has(el));
    if (!targets.length) queue(message.id, message.patch);
    else for (const el of targets) apply(el, message.patch);
  }

  function unmount(el) {
    const record = records.get(el);
    if (!record) return;
    stopTimer(record);
    for (const [name, handler] of Object.entries(record.handlers)) el.removeEventListener(name, handler);
    record.controller.destroy();
    records.delete(el);
  }

  function state(el) {
    const record = records.get(el);
    if (!record) return null;
    return {
      character: record.character,
      mood: record.mood,
      status: { ...record.status },
      problem: record.problem,
      bubble: record.bubble ? { ...record.bubble, remaining: remaining(record) } : null,
      current: record.controller.current(),
    };
  }

  ns.host = { mount, unmount, receive, state };
  if (window.Shiny?.InputBinding) {
    class MascotBinding extends window.Shiny.InputBinding {
      find(scope) {
        return window.jQuery(scope).find('.mascot');
      }
      getId(el) {
        return el.id || null;
      }
      getValue() {
        return null;
      }
      subscribe(el) {
        mount(el);
      }
      unsubscribe(el) {
        unmount(el);
      }
    }
    window.Shiny.inputBindings.register(new MascotBinding(), 'mascot.mascot');
    window.Shiny.addCustomMessageHandler('mascot:update', (message) => receive(message));
  } else {
    const mountAll = () => document.querySelectorAll('.mascot').forEach(mount);
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mountAll, { once: true });
    else mountAll();
  }
})();
