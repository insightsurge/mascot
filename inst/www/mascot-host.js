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

  function mount(el) {
    if (records.has(el)) return;
    const id = el.dataset.character;
    const description = ns.readCharacter(id, el);
    const canvas = el.querySelector('.mascot-canvas');
    const statusEl = el.querySelector('.mascot-status');
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
    const patch = pending.get(el.id);
    if (patch) {
      pending.delete(el.id);
      const { problem, ...good } = patch;
      if (Object.keys(good).length) apply(el, good);
      if (problem !== undefined) apply(el, { problem });
    }
  }

  function apply(el, patch) {
    const record = records.get(el);
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

    let description;
    let status = record.status;
    let changed = false;
    const enginePatch = {};
    try {
      for (const key of Object.keys(patch)) {
        if (!['character', 'mood', 'status'].includes(key)) throw new Error(`unknown update field "${key}"`);
      }
      if (has(patch, 'character')) {
        const ch = patch.character;
        if (!ch || typeof ch.id !== 'string' || !ch.id || typeof ch.name !== 'string' || !ch.name) {
          throw new Error('character needs an id and name');
        }
        description = record.descriptions.get(ch.id) || JSON.parse(ch.json);
        if (!description || description.id !== ch.id) throw new Error('character id does not match its description');
        enginePatch.character = description;
        changed = ch.id !== record.character;
      }
      if (has(patch, 'mood')) enginePatch.mood = patch.mood;
      else if (record.problem && !changed) enginePatch.mood = record.problemMood;
      if (has(patch, 'status')) {
        const next = patch.status;
        if (
          !next ||
          !['mood', 'custom'].includes(next.mode) ||
          (next.mode === 'custom' && (typeof next.text !== 'string' || !next.text.length))
        ) {
          throw new Error('status needs mode "mood" or mode "custom" with non-empty text');
        }
        status = { mode: next.mode, text: next.mode === 'custom' ? next.text : null };
      }
      // Synchronous engine notifications must not expose a partially committed host patch.
      updating.add(record);
      if (Object.keys(enginePatch).length) record.controller.update(enginePatch);
    } catch (error) {
      warn(error);
      return;
    } finally {
      updating.delete(record);
    }

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
    show(record, record.controller.current());
  }

  function queue(id, patch) {
    const next = { ...pending.get(id) };
    if (!has(patch, 'problem')) delete next.problem;
    if (has(patch, 'character')) {
      next.character = patch.character;
      delete next.mood;
    }
    for (const key of ['mood', 'status', 'problem']) {
      if (has(patch, key)) next[key] = patch[key];
    }
    if (has(patch, 'gesture')) {
      console.warn(`mascot: gesture "${patch.gesture}" for "${id}" was dropped: the mascot was not on the page yet`);
    }
    pending.set(id, next);
  }

  function receive(message) {
    const targets = [...document.querySelectorAll('.mascot')].filter((el) => el.id === message.id && records.has(el));
    if (!targets.length) queue(message.id, message.patch);
    else for (const el of targets) apply(el, message.patch);
  }

  function unmount(el) {
    const record = records.get(el);
    if (!record) return;
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
