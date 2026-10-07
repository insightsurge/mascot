/**
 * Page host for mascot: one record and controller per element, with an idempotent lifecycle.
 * A Shiny input binding mounts on subscribe and destroys on unsubscribe; static pages mount at DOM ready.
 * Custom messages carry { id, patch }; late state merges by id, while late gestures are dropped.
 * Patches are atomic: prepare descriptions/status, ask the engine to validate, then commit host state.
 * Desired character/mood live in data-character/data-mood; data-shown-* and status follow the shown frame.
 * Custom status persists across swaps. Development problems temporarily cover it and use a worried mood;
 * the next good patch clears the problem and restores the earlier mood unless it chooses another.
 * The host owns canvas dimensions (CSS size times pixel ratio), the 300-unit transform and accessible text.
 * Size patches are { size: pixels|percentage, small_screen: pixels|percentage|null, simplify_when_small: boolean }.
 * Placement patches are { floating: boolean, position: corner, minimise: boolean }; neither patch remounts the engine.
 * CSS chooses the narrow-screen size. One ResizeObserver per element refreshes its backing canvas and detail pose;
 * zero sizes retain the last usable drawing. Shared viewport/density and notification observers are reference-counted.
 * Floating elements move to body; a source marker preserves tab visibility, inherited text/theme and Shiny teardown.
 * Inline bubbles are clamped to viewport edges without changing their reserved height.
 * Floating bubbles point towards the page centre. Native buttons minimise/restore; messages pause while minimised.
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
  const live = new Set();
  const sources = new WeakMap();
  const corners = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  let densityMedia = null;
  let schemeMedia = null;
  let notificationMutation = null;
  let notificationResize = null;
  let notificationPanel = null;
  const has = (object, key) => Object.hasOwn(object, key);
  const label = (mood) => mood.charAt(0).toUpperCase() + mood.slice(1);
  const warn = (error) => console.warn(`mascot: ${String(error.message || error).replace(/^mascot: /, '')}`);

  function show(record, snapshot) {
    if (updating.has(record)) return;
    record.el.dataset.shownCharacter = snapshot.character;
    record.el.dataset.shownMood = snapshot.mood;
    record.el.dataset.swapping = String(snapshot.swapping);
    record.canvas.setAttribute('aria-label', `${record.names.get(snapshot.character)}, ${snapshot.mood}`);
    if (record.restoreButton) {
      record.restoreButton.setAttribute(
        'aria-label',
        `Restore ${record.names.get(snapshot.character)}, ${snapshot.mood}`,
      );
      const colours = record.descriptions.get(snapshot.character).colours;
      const fallback = Object.values(colours)[0];
      record.el.style.setProperty('--mascot-button-bg', colours.body || fallback);
      record.el.style.setProperty('--mascot-button-fg', colours.outline || fallback);
      record.el.style.setProperty('--mascot-button-glow', colours.rim || colours.body || fallback);
    }
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
    if (
      !record.bubble ||
      record.bubble.remaining === null ||
      record.hover ||
      record.focus ||
      record.minimised ||
      record.timer !== null
    )
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

  function validateSizeValue(value) {
    if (typeof value === 'number' && Number.isFinite(value) && value >= 24) return;
    if (typeof value === 'string' && /^(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)%$/.test(value)) {
      const number = Number(value.slice(0, -1));
      if (Number.isFinite(number) && number > 0) return;
    }
    throw new Error('size needs finite pixels at least 24 or a positive percentage');
  }

  function validateSize(next) {
    if (
      !next ||
      typeof next !== 'object' ||
      Array.isArray(next) ||
      Object.keys(next).length !== 3 ||
      Object.keys(next).some((key) => !['size', 'small_screen', 'simplify_when_small'].includes(key))
    )
      throw new Error('size needs size, small_screen and simplify_when_small fields');
    validateSizeValue(next.size);
    if (next.small_screen !== null) validateSizeValue(next.small_screen);
    if (typeof next.simplify_when_small !== 'boolean') throw new Error('simplify_when_small needs a flag');
    return { ...next };
  }

  function validatePlacement(next) {
    if (
      !next ||
      typeof next !== 'object' ||
      Array.isArray(next) ||
      Object.keys(next).length !== 3 ||
      Object.keys(next).some((key) => !['floating', 'position', 'minimise'].includes(key)) ||
      typeof next.floating !== 'boolean' ||
      typeof next.minimise !== 'boolean' ||
      !corners.includes(next.position)
    )
      throw new Error('placement needs floating, position and minimise fields');
    if (!next.floating && (next.position !== 'bottom-right' || next.minimise))
      throw new Error('position and minimise only work with floating');
    return { ...next };
  }

  function sizeAttribute(value) {
    return typeof value === 'string' && value.endsWith('%') ? value : Number(value);
  }

  function sizeCSS(value, floating) {
    return typeof value === 'number' ? `${value}px` : floating ? `${value.slice(0, -1)}vw` : value;
  }

  function setProperty(el, key, value) {
    if (el.style.getPropertyValue(key) !== value) el.style.setProperty(key, value);
  }

  // Shiny registers after subscribe returns. Transfer its bound marker in the next microtask,
  // so unbindAll(originalContainer) still finds and unsubscribes a floating descendant.
  function syncBinding(record) {
    if (!record.binding) return;
    queueMicrotask(() => {
      if (records.get(record.el) !== record) return;
      const bound = record.anchor || record.el;
      window.jQuery(bound).data('shiny-input-binding', record.binding).addClass('shiny-bound-input');
      if (record.anchor) record.el.classList.remove('shiny-bound-input');
    });
  }

  function syncSource(record) {
    const { anchor, el } = record;
    if (!anchor) return;
    if (el.dataset.bsTheme !== anchor.dataset.bsTheme) {
      if (el.dataset.bsTheme) anchor.dataset.bsTheme = el.dataset.bsTheme;
      else delete anchor.dataset.bsTheme;
    }
    const visible = anchor.getClientRects().length > 0 && getComputedStyle(anchor).visibility !== 'hidden';
    el.dataset.sourceHidden = String(!visible);
    const style = getComputedStyle(anchor);
    const values = {
      font: style.font,
      color: style.color,
      bg: style.getPropertyValue('--bs-body-bg') || style.getPropertyValue('--mascot-bubble-bg'),
      text: style.getPropertyValue('--bs-body-color') || style.getPropertyValue('--mascot-bubble-color'),
      border: style.getPropertyValue('--bs-border-color') || style.getPropertyValue('--mascot-bubble-border'),
    };
    for (const [key, value] of Object.entries(values)) setProperty(el, `--mascot-source-${key}`, value);
  }

  function portal(record, floating, teardown = false) {
    const { el } = record;
    const focused = el.contains(document.activeElement) ? document.activeElement : null;
    if (floating && !record.anchor) {
      const anchor = document.createElement('span');
      anchor.className = 'mascot-source';
      anchor.setAttribute('aria-hidden', 'true');
      el.before(anchor);
      record.anchor = anchor;
      sources.set(anchor, record);
      el.setAttribute('data-shiny-no-bind-input', '');
      document.body.append(el);
      syncSource(record);
      syncBinding(record);
    } else if (!floating && record.anchor) {
      const anchor = record.anchor;
      anchor.replaceWith(el);
      sources.delete(anchor);
      record.anchor = null;
      el.removeAttribute('data-shiny-no-bind-input');
      delete el.dataset.sourceHidden;
      for (const key of ['font', 'color', 'bg', 'text', 'border']) el.style.removeProperty(`--mascot-source-${key}`);
      if (teardown) el.classList.remove('shiny-bound-input');
      else syncBinding(record);
    }
    if (focused && document.activeElement !== focused && !teardown) focused.focus();
  }

  function layout(record) {
    const { el, size, placement } = record;
    portal(record, placement.floating);
    const focusedControl = [record.minimiseButton, record.restoreButton].includes(document.activeElement)
      ? document.activeElement
      : null;
    el.dataset.size = String(size.size);
    if (size.small_screen === null) delete el.dataset.smallScreen;
    else el.dataset.smallScreen = String(size.small_screen);
    el.dataset.simplifyWhenSmall = String(size.simplify_when_small);
    el.dataset.floating = String(placement.floating);
    el.dataset.position = placement.position;
    el.dataset.minimise = String(placement.minimise);
    el.style.setProperty('--mascot-size-default', sizeCSS(size.size, placement.floating));
    el.style.setProperty('--mascot-size-small', sizeCSS(size.small_screen ?? size.size, placement.floating));
    record.minimiseButton.hidden = !placement.floating || !placement.minimise || record.minimised;
    record.restoreButton.hidden = !record.minimised;
    record.canvas.hidden = record.minimised;
    record.bubbleEl.parentElement.hidden = record.minimised;
    el.dataset.minimised = String(record.minimised);
    if (focusedControl?.hidden) {
      (record.minimised
        ? record.restoreButton
        : record.minimiseButton.hidden
          ? record.canvas
          : record.minimiseButton
      ).focus();
    }
  }

  function minimise(record, value, focus = true) {
    if (value === record.minimised) return;
    if (value && (!record.placement.floating || !record.placement.minimise)) return;
    stopTimer(record);
    record.minimised = value;
    layout(record);
    if (focus) (value ? record.restoreButton : record.minimiseButton).focus();
    record.focus = record.el.contains(document.activeElement);
    if (!value) {
      measure(record);
      resumeTimer(record);
    }
  }

  function measure(record) {
    if (record.minimised) return;
    const size = record.canvas.getBoundingClientRect().width;
    if (!(size > 0)) return;
    const pixels = Math.max(1, Math.round(size * (window.devicePixelRatio || 1)));
    const resized = record.canvas.width !== pixels || record.canvas.height !== pixels;
    if (resized) {
      record.canvas.width = record.canvas.height = pixels;
      const k = pixels / 300;
      record.canvas.getContext('2d').setTransform(k, 0, 0, k, 0, 0);
    }
    // Translate only the message region: the canvas/status retain their reserved inline positions.
    if (!record.placement.floating) {
      const region = record.bubbleEl.parentElement;
      const rect = region.getBoundingClientRect();
      const shift = parseFloat(record.el.style.getPropertyValue('--mascot-bubble-shift')) || 0;
      const natural = rect.left - shift;
      const margin = 16;
      const left = Math.max(margin, Math.min(natural, document.documentElement.clientWidth - margin - rect.width));
      setProperty(record.el, '--mascot-bubble-shift', `${left - natural}px`);
    }
    record.renderedSize = size;
    const detail = record.size.simplify_when_small && size < 72 ? 'simple' : 'full';
    if (detail !== record.detail) {
      record.detail = detail;
      record.controller.update({ pose: { detail } });
    }
    if (resized) record.controller.redraw();
  }

  function refreshViewport() {
    for (const record of live) {
      syncSource(record);
      measure(record);
    }
    refreshNotifications();
  }

  function densityChanged() {
    densityMedia?.removeEventListener('change', densityChanged);
    densityMedia = window.matchMedia(`(resolution: ${window.devicePixelRatio || 1}dppx)`);
    densityMedia.addEventListener('change', densityChanged);
    refreshViewport();
  }

  function refreshNotifications() {
    if (!notificationResize) return;
    const panel = document.getElementById('shiny-notification-panel');
    if (panel !== notificationPanel) {
      notificationResize.disconnect();
      notificationPanel = panel;
      if (panel) notificationResize.observe(panel);
    }
    const rect = panel?.getBoundingClientRect();
    const shown =
      panel?.getClientRects().length &&
      getComputedStyle(panel).visibility !== 'hidden' &&
      [...panel.children].some(
        (child) => child.getClientRects().length && getComputedStyle(child).visibility !== 'hidden',
      );
    const offset = shown ? Math.max(0, window.innerHeight - rect.top) : 0;
    for (const record of live) {
      if (record.placement.floating && record.placement.position === 'bottom-right') {
        const value = `${offset}px`;
        if (record.el.style.getPropertyValue('--mascot-notification-offset') !== value)
          record.el.style.setProperty('--mascot-notification-offset', value);
      }
    }
  }

  function refreshPage() {
    for (const record of live) {
      if (record.anchor && !record.anchor.isConnected) unmount(record.el);
      else {
        syncSource(record);
        measure(record);
      }
    }
    refreshNotifications();
  }

  function watchNotifications() {
    // A shared page observer also catches inline messages moving near a viewport edge.
    const needed = live.size > 0;
    if (!needed) {
      notificationMutation?.disconnect();
      notificationResize?.disconnect();
      notificationMutation = notificationResize = notificationPanel = null;
      return;
    }
    if (!notificationMutation) {
      notificationMutation = new MutationObserver(refreshPage);
      notificationMutation.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class', 'style', 'hidden', 'data-bs-theme'],
      });
    }
    const needsPanel = [...live].some(
      (record) => record.placement.floating && record.placement.position === 'bottom-right',
    );
    if (!needsPanel) {
      notificationResize?.disconnect();
      notificationResize = notificationPanel = null;
      return;
    }
    if (!notificationResize) notificationResize = new ResizeObserver(refreshNotifications);
    refreshNotifications();
  }

  function watch(record) {
    record.resize = new ResizeObserver(() => measure(record));
    record.resize.observe(record.el);
    live.add(record);
    if (live.size === 1) {
      window.addEventListener('resize', refreshViewport);
      schemeMedia = window.matchMedia('(prefers-color-scheme: dark)');
      schemeMedia.addEventListener('change', refreshPage);
      densityChanged();
    }
    watchNotifications();
  }

  function unwatch(record) {
    record.resize?.disconnect();
    const registered = live.delete(record);
    if (registered && !live.size) {
      window.removeEventListener('resize', refreshViewport);
      densityMedia?.removeEventListener('change', densityChanged);
      densityMedia = null;
      schemeMedia?.removeEventListener('change', refreshPage);
      schemeMedia = null;
    }
    watchNotifications();
  }

  function mount(el) {
    if (records.has(el)) return;
    const id = el.dataset.character;
    const description = ns.readCharacter(id, el);
    const canvas = el.querySelector('.mascot-canvas');
    const statusEl = el.querySelector('.mascot-status');
    const bubbleEl = el.querySelector('.mascot-bubble');
    const size = 160; // A usable backing size until a hidden element can be measured.
    const sizeConfig = validateSize({
      size: has(el.dataset, 'size') ? sizeAttribute(el.dataset.size) : 160,
      small_screen: has(el.dataset, 'smallScreen') ? sizeAttribute(el.dataset.smallScreen) : null,
      simplify_when_small: el.dataset.simplifyWhenSmall !== 'false',
    });
    const placement = validatePlacement({
      floating: el.dataset.floating === 'true',
      position: el.dataset.position || 'bottom-right',
      minimise: el.dataset.minimise === 'true',
    });
    const button = (className, label) => {
      el.querySelector(`.${className}`)?.remove();
      const value = document.createElement('button');
      value.className = className;
      value.type = 'button';
      value.setAttribute('aria-label', label);
      value.textContent = className === 'mascot-minimise' ? '\u2212' : '\u25cf';
      value.hidden = true;
      el.append(value);
      return value;
    };
    canvas.width = canvas.height = Math.round(size * (window.devicePixelRatio || 1));
    const k = canvas.width / 300;
    canvas.getContext('2d').setTransform(k, 0, 0, k, 0, 0);
    const record = {
      el,
      canvas,
      statusEl,
      controller: null,
      size: sizeConfig,
      placement,
      minimised: false,
      detail: 'full',
      renderedSize: null,
      resize: null,
      anchor: null,
      binding: null,
      minimiseButton: button('mascot-minimise', 'Minimise mascot'),
      restoreButton: button('mascot-restore', 'Restore mascot'),
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
      layout(record);
      record.controller = ns.mount(canvas, description, {
        x: 150,
        baseY: 270,
        mood: el.dataset.mood,
        reduced: null,
        onChange: (snapshot) => show(record, snapshot),
      });
      listenBubble(record);
      record.handlers.clickPlacement = (event) => {
        if (event.target.closest('.mascot-minimise') === record.minimiseButton) minimise(record, true);
        if (event.target.closest('.mascot-restore') === record.restoreButton) minimise(record, false);
      };
      el.addEventListener('click', record.handlers.clickPlacement);
      watch(record);
      measure(record);
    } catch (error) {
      unwatch(record);
      if (record.handlers) {
        for (const [name, handler] of Object.entries(record.handlers))
          el.removeEventListener(name === 'clickPlacement' ? 'click' : name, handler);
      }
      record.controller?.destroy();
      portal(record, false, true);
      record.minimiseButton.remove();
      record.restoreButton.remove();
      records.delete(el);
      throw error;
    }
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
    if (prepared.size) record.size = prepared.size;
    if (prepared.placement) record.placement = prepared.placement;
    if (record.minimised && (!record.placement.floating || !record.placement.minimise)) {
      const focused = record.el.contains(document.activeElement);
      minimise(record, false, false);
      if (focused) record.canvas.focus();
    }
    if (prepared.size || prepared.placement) {
      layout(record);
      measure(record);
      watchNotifications();
    }
    if (has(patch, 'bubble')) replaceBubble(record, prepared.bubble);
    if (has(patch, 'gesture')) record.controller.gesture(patch.gesture);
  }

  // Use the same pure preflight for mounted and queued patches; never merge a partial bad patch.
  function prepare(patch, current, descriptions = new Map(current ? [[current.id, current]] : [])) {
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) throw new Error('update needs an object');
    for (const key of Object.keys(patch)) {
      if (!['character', 'mood', 'status', 'bubble', 'gesture', 'size', 'placement', 'problem'].includes(key))
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
    const size = has(patch, 'size') ? validateSize(patch.size) : undefined;
    const placement = has(patch, 'placement') ? validatePlacement(patch.placement) : undefined;
    return { description, changed, enginePatch, status, bubble, size, placement };
  }

  function mergeQueued(next, patch) {
    if (!has(patch, 'problem')) delete next.problem;
    if (has(patch, 'character')) {
      next.character = patch.character;
      delete next.mood;
    }
    for (const key of ['mood', 'status', 'bubble', 'size', 'placement', 'problem']) {
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
    unwatch(record);
    for (const [name, handler] of Object.entries(record.handlers))
      el.removeEventListener(name === 'clickPlacement' ? 'click' : name, handler);
    record.minimiseButton.remove();
    record.restoreButton.remove();
    record.controller.destroy();
    portal(record, false, true);
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
      size: { ...record.size },
      placement: { ...record.placement },
      minimised: record.minimised,
      renderedSize: record.renderedSize,
      detail: record.detail,
      bubble: record.bubble ? { ...record.bubble, remaining: remaining(record) } : null,
      current: record.controller.current(),
    };
  }

  ns.host = { mount, unmount, receive, state };
  if (window.Shiny?.InputBinding) {
    class MascotBinding extends window.Shiny.InputBinding {
      find(scope) {
        return window.jQuery(scope).find('.mascot, .mascot-source');
      }
      getId(el) {
        return sources.get(el)?.el.id || el.id || null;
      }
      getValue() {
        return null;
      }
      subscribe(el) {
        mount(el);
        const record = records.get(el);
        record.binding = this;
        syncBinding(record);
      }
      unsubscribe(el) {
        unmount(sources.get(el)?.el || el);
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
