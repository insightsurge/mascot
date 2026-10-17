/**
 * Page host for mascot: one record and controller per element, with an idempotent lifecycle.
 * A Shiny input binding mounts for its initial value/subscribe and destroys on unsubscribe; static pages mount at DOM ready.
 * Shiny messages use versioned, generation-bound complete state settled by R.
 * A connection-local ledger retains consumed gestures and bubble dismissal through DOM replacement.
 * Browser-only/custom hosts retain the legacy { id, patch } path and its bounded early queue.
 * In Shiny development mode, updates waiting 2 s for "x" while "<namespace>-x" is mounted, or for "<namespace>-x" while
 * "x" is mounted, warn once with the likely namespace fix.
 * Patches are atomic: prepare descriptions/status, ask the engine to validate, then commit host state.
 * Desired character/mood live in data-character/data-mood; data-shown-* and status follow the shown frame.
 * Custom status persists across swaps. Development problems temporarily cover it and use a worried mood;
 * the next good patch clears the problem and restores the earlier mood unless it chooses another.
 * The host owns canvas dimensions (CSS size times pixel ratio), the 300-unit transform and accessible text.
 * Size patches are { size: pixels|percentage, small_screen: pixels|percentage|'auto'|null }; every size draws in full.
 * 'auto' leaves the phone size to the CSS rule for floating mascots; null keeps one size at every width.
 * Placement patches are { floating: boolean, position: corner, minimise: boolean, drag: false|'snap'|'free' };
 * neither patch remounts the engine. A floating mascot with drag follows a pointer pressed on its canvas or its
 * restore button while minimised (pointer capture; a few pixels of movement before a press becomes a drag, so a
 * click still opens the menu or restores). On release
 * "snap" moves to the nearest corner (animated unless motion is reduced), which becomes its position; "free" keeps
 * the dropped point, kept 1rem inside the window on resize, and takes the nearest corner only to orient the bubble
 * and menu. Each drop sets the namespaced id + '_position' (the corner, or { x, y }) with priority 'event'.
 * A placement patch replaces any dragged position.
 * Theme patches are { light, dark, mode, css, brand }; empty maps are null, mode null selects the host default
 * (auto follows the page; no signal means light). Maps use description role names. Brand retains primary/secondary
 * colours for the incoming character's brand leaders. A theme replaces overrides, and survives character swaps.
 * Auto follows source data-bs-theme, then Quarto's body class; CSS reads the original source context.
 * Missing/invalid CSS uses the character colour and warns; contrast below 3:1 warns without changing the colour.
 * One theme observer exists while auto is used; the shared scheme listener serves auto and floating bubbles.
 * CSS chooses the narrow-screen size. One ResizeObserver per element refreshes its backing canvas;
 * zero sizes retain the last usable drawing. Shared viewport/density, intersection and notification observers are
 * reference-counted; unrelated DOM mutations are ignored, relevant ones coalesce into one animation frame, and
 * off-screen mascots pause drawing until they return to the viewport.
 * Floating elements move to body; a source marker preserves tab visibility, inherited text/theme and Shiny teardown.
 * Inline bubbles are clamped to viewport edges without changing their reserved height.
 * Floating bubbles point towards the page centre. Native buttons minimise/restore; messages pause while minimised.
 * Motion patches carry reduced (null|true), independent boolean switches and messages (panel names).
 * data-* attributes carry the same settings on static pages; reduced motion always wins.
 * Minimise/restore use transform and opacity for 240 ms, with no page layout movement.
 * Motion changes update the live controller; swaps reapply retained settings alongside the theme.
 * CSS suppresses bubble and restore-control movement too. No per-element global listeners are added by this host.
 * Click patches are { type: 'none' } | { type: 'action', label, tooltip, disabled } |
 * { type: 'menu', items: {id: label}, direction, label: string|null, tooltip: boolean }; a new click replaces the old one whole.
 * Clicks are Shiny-only. Without one the canvas is an image and no keyboard stop. With one, a native button wraps
 * the canvas (hidden from assistive technology inside it), named by the action's label or the menu's label (else
 * "<character>, menu"); mood changes never rename it. Every activation of that button (pointer, Enter, Space or an
 * assistive technology's click; a held key counts once) sets the namespaced id + '_click' to a count since mounting,
 * with priority 'event'; the count survives click changes. A disabled action (aria-disabled) sends nothing.
 * Drags, outside clicks, Escape, minimise/restore and server updates never count.
 * Menu choices set id + '_menu' with priority 'event'. Labels always use textContent. Opening and closing count as
 * activations; navigation stays within the focused menu. No global keyboard listeners for menus.
 * A shared outside-pointer listener exists only while a menu is open; teardown removes it when unused.
 * A tooltip (for an action, or a menu with a label and tooltip: true) shows the label on hover (not touch) and
 * keyboard focus, stays while the pointer is over the mascot or the tooltip, and Escape dismisses it without
 * moving focus (a shared document listener exists only while a tooltip shows). It hides while a menu or bubble shows,
 * while minimised and during a drag.
 * Panels (#233): the bubble, the menu and the tooltip share one look (.mascot-panel). The menu and the tooltip also
 * share placement: anchored to the painted character (sampled when shown), a requested side with fallbacks (the
 * opposite side, then "auto"), inside the window or an inline mascot's clipping container, refitted on resize/scroll.
 * Open menus pause bubble timers. The mascot looks towards what it shows: an open menu's side as finally chosen
 * (after any fallback), otherwise its bubble's side (above inline and bottom-corner mascots, below top-corner ones).
 * The gaze is a held look/lookY pose, so it is instant and never animated; closing clears only those fields,
 * preserving the mood. Only pupils move, so eyes without visible pupils keep their look.
 * Action controls use a separate strip: hover/focus reveals it, touch keeps it available, open menus hide it.
 * Restore stays reachable while minimised. Placement focus falls back to the visible menu toggle or image.
 * host.{mount,unmount,receive,state} exposes lifecycle and plain snapshots for integration tests.
 * A character with format_version 1 is drawn and moved by mascot.runtime (mascot-player.js) through mascot.mount(); the
 * host drives both players alike. For it the status of the shown mood and the accessible label come from the character's
 * moods, the held look goes to face.look_x and face.look_y (flipped back by the runtime from the shown frame's
 * root.flip; never sent to a faceless or no-gaze character), the detail band follows the canvas width with no switch, a
 * swap without a mood follows the character's fallback chain, and the restore control is named with the shown status.
 * The legacy Tessa path is unchanged.
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.host) return;

  const records = new WeakMap();
  const pending = new Map();
  const playedGestures = new Map();
  // Connection-local action/dismissal ledger survives DOM removal. Complete
  // state revisions are generation-local; action watermarks never reset.
  const ledgers = new Map();
  const safeCounter = (x) => Number.isSafeInteger(x) && x >= 0;
  const sameValue = (a, b) => {
    if (a === b) return true;
    if (!a || !b || typeof a !== 'object' || typeof b !== 'object' || Array.isArray(a) !== Array.isArray(b))
      return false;
    const keys = Object.keys(a);
    return keys.length === Object.keys(b).length && keys.every((key) => has(b, key) && sameValue(a[key], b[key]));
  };
  const queueLimit = 20;
  const warnedIds = new Set();
  const namespaceDelay = 2000;
  let mountSerial = 0;
  const known = new Map();
  const updating = new WeakSet();
  const live = new Set();
  let disconnected = false;
  const disconnectStatus = 'Connection lost. Reload the page to continue.';
  const sources = new WeakMap();
  const corners = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  const drags = [false, 'snap', 'free'];
  const motionFlags = ns.motion.settings;
  const panelNames = ns.motion.panels;
  const defaultMotion = () => ({
    reduced: null,
    ...Object.fromEntries(motionFlags.map((key) => [key, true])),
    messages: [...panelNames],
  });
  let motionMedia = null;
  function finishInterfaceMotion() {
    if (!motionMedia?.matches) return;
    for (const record of live) {
      record.snapAnimation?.finish();
      record.placementAnimation?.finish();
      record.panelExits.forEach((movement) => {
        movement.finish();
      });
      for (const panel of [record.bubbleEl, record.menuEl, record.tooltipEl]) {
        panel?.getAnimations().forEach((movement) => {
          movement.finish();
        });
      }
    }
  }
  // CSS pixels a press must move before it becomes a drag, so a click still opens the menu.
  const dragThreshold = 4;
  let densityMedia = null;
  const openMenus = new Set();
  let schemeMedia = null;
  let modeMutation = null;
  const colourContext = document.createElement('canvas').getContext('2d');
  let notificationMutation = null;
  let notificationResize = null;
  let notificationPanel = null;
  let viewportObserver = null;
  let pageFrame = null;
  const has = (object, key) => Object.hasOwn(object, key);
  const label = (mood) => mood.charAt(0).toUpperCase() + mood.slice(1);
  const warn = (error) => console.warn(`mascot: ${String(error.message || error).replace(/^mascot: /, '')}`);
  // I1: a character with format_version 1 is drawn and moved by mascot.runtime; the legacy Tessa path is untouched.
  const isFormat = (description) => ns.runtime?.isFormat(description) === true;
  // The detail bands follow the canvas width for a format-v1 character.
  const bandsApply = (description) => isFormat(description);
  // The engine owns the vocabulary: a pure pose (legacy) or the runtime's checks (format v1) validate without changing
  // a controller. request is {}, { mood } or { gesture }.
  function engineValidate(description, request) {
    if (isFormat(description)) ns.runtime.validate(description, request);
    else ns.motion.pose(description, { ...request, reduced: true }, 0);
  }
  // E5b, internal: the untransformed CSS width of a canvas in px (a transform does not change it). 0 means not laid out
  // (display: none, a hidden tab): such a width decides no band.
  const cssWidth = (canvas) => {
    const value = getComputedStyle(canvas).width;
    return value.endsWith('px') ? parseFloat(value) : 0;
  };
  // E5b, internal: one diagnostic per band and canvas, through the host's warn() route.
  function reportBand(record, band, error) {
    record.reportedBands ??= new Set();
    if (record.reportedBands.has(band)) return;
    record.reportedBands.add(band);
    warn(error);
  }

  function show(record, snapshot) {
    if (updating.has(record)) return;
    record.el.dataset.shownCharacter = snapshot.character;
    record.el.dataset.shownMood = snapshot.mood;
    record.el.dataset.swapping = String(snapshot.swapping);
    const shownStatus = disconnected
      ? disconnectStatus
      : record.problem ||
        (record.status.mode === 'mood'
          ? record.descriptions.get(snapshot.character)?.moods[snapshot.mood]?.status || label(snapshot.mood)
          : record.status.text);
    const accessibleLabel = `${record.names.get(snapshot.character)}, ${shownStatus}`;
    record.canvas.setAttribute('aria-label', accessibleLabel);
    if (record.button) {
      const name = record.click.label || `${record.names.get(snapshot.character)}, menu`;
      if (record.button.getAttribute('aria-label') !== name) record.button.setAttribute('aria-label', name);
    }
    if (record.restoreButton) {
      const description = record.descriptions.get(snapshot.character);
      // A format-v1 name never carries a raw mood id: it names the character and the shown status.
      record.restoreButton.setAttribute(
        'aria-label',
        `Restore ${record.names.get(snapshot.character)}, ${isFormat(description) ? shownStatus : snapshot.mood}`,
      );
      const colours = record.palettes.get(snapshot.character) || description.colours;
      const fallback = Object.values(colours)[0];
      // The brand leaders name a format-v1 character's main and accent colour; the legacy roles stay as they were.
      const leaders = isFormat(description) ? description.brand : undefined;
      const main = (leaders && colours[leaders.primary]) || colours.body;
      const accent = (leaders && colours[leaders.secondary]) || colours.rim;
      setProperty(record.el, '--_mascot-restore-bg', main || fallback);
      setProperty(record.el, '--_mascot-restore-fg', colours.outline || fallback);
      setProperty(record.el, '--_mascot-restore-glow', accent || main || fallback);
    }
    const text = shownStatus;
    if (record.statusEl.textContent !== text) record.statusEl.textContent = text;
    for (const id of record.descriptions.keys())
      if (id !== record.character && id !== snapshot.character) {
        record.descriptions.delete(id);
        record.names.delete(id);
        record.palettes.delete(id);
      }
  }

  function setDisconnected(value) {
    if (disconnected === value) return;
    disconnected = value;
    for (const record of live) {
      record.el.toggleAttribute('data-disconnected', value);
      if (value) {
        forceConnectionMood(record);
      } else {
        record.controller.update({ mood: record.mood, reduced: true, swap: false });
      }
      show(record, record.controller.current());
    }
  }

  function disconnectMood(record) {
    const description = record.descriptions.get(record.character);
    return ns.runtime.swapMood(description, 'worried', description);
  }

  function forceConnectionMood(record) {
    // Turning gestures off clears an already running gesture, even when worried is already the current mood.
    record.controller.update({ mood: disconnectMood(record), gestures: false, reduced: true, swap: false });
    if (record.motion.gestures) record.controller.update({ gestures: true });
  }

  const disconnectedHandler = () => setDisconnected(true);
  const connectedHandler = () => setDisconnected(false);
  document.addEventListener('shiny:disconnected', disconnectedHandler);
  document.addEventListener('shiny:connected', connectedHandler);
  if (typeof window.jQuery === 'function') {
    window.jQuery(document).on('shiny:disconnected.mascot-host', disconnectedHandler);
    window.jQuery(document).on('shiny:connected.mascot-host', connectedHandler);
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
      record.hidden ||
      record.menuOpen ||
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
    if (record.bubble && record.ledger && !record.installing && record.ledger.bubble_watermark) {
      record.ledger.dismissed_bubble_revision = record.ledger.bubble_watermark;
      record.ledger.bubble = null;
      publish(record, 'mounted');
    }
    stopTimer(record);
    record.bubble = null;
    const focused = record.bubbleEl.contains(document.activeElement);
    hidePanel(record, record.bubbleEl, 'bubble');
    delete record.bubbleEl.dataset.text;
    if (focused) record.el.focus();
    record.bubbleText.textContent = '';
    record.bubbleEl.querySelector('.mascot-bubble-close')?.remove();
    record.hover = false;
    refreshGaze(record);
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
    if (record.menuOpen) closeMenu(record, record.menuEl.contains(document.activeElement));
    hideTooltip(record);
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
    syncMotion(record);
    el.hidden = false;
    refreshGaze(record);
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
        if (event.key === 'Escape' && !record.menuOpen && el.contains(document.activeElement) && record.bubble) {
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
    if (description) engineValidate(description, { gesture: name });
  }

  const emptyTheme = () => ({ light: null, dark: null, mode: null, css: null, brand: null });
  const themeMode = (theme) => theme.mode ?? 'auto';

  function themeMap(value, field, css = false) {
    if (value === null) return null;
    if (!value || typeof value !== 'object' || Array.isArray(value))
      throw new Error(`theme.${field} needs a map or null`);
    for (const [role, colour] of Object.entries(value)) {
      if (['light', 'dark', 'default'].includes(role))
        throw new Error(`theme.${field}: reserved colour role "${role}"`);
      if (css ? typeof colour !== 'string' || !/^--[A-Za-z_][A-Za-z0-9_-]*$/.test(colour) : !ns.validColour(colour))
        throw new Error(`theme.${field}.${role}: invalid ${css ? 'CSS variable' : 'colour'} "${colour}"`);
    }
    return { ...value };
  }

  function validateTheme(value) {
    const fields = ['light', 'dark', 'mode', 'css', 'brand'];
    if (
      !value ||
      typeof value !== 'object' ||
      Array.isArray(value) ||
      Object.keys(value).length !== fields.length ||
      Object.keys(value).some((key) => !fields.includes(key))
    )
      throw new Error('theme needs light, dark, mode, css and brand fields');
    if (value.mode !== null && !['light', 'dark', 'auto'].includes(value.mode))
      throw new Error('theme.mode needs light, dark, auto or null');
    const result = {
      light: themeMap(value.light, 'light'),
      dark: themeMap(value.dark, 'dark'),
      mode: value.mode,
      css: themeMap(value.css, 'css', true),
      brand: themeMap(value.brand, 'brand'),
    };
    if (
      result.brand &&
      (Object.keys(result.brand).length !== 2 ||
        Object.keys(result.brand).some((key) => !['primary', 'secondary'].includes(key)))
    )
      throw new Error('theme.brand needs primary and secondary colours');
    return result;
  }

  function pageMode(source) {
    for (let el = source; el; el = el.parentElement) {
      if (['light', 'dark'].includes(el.dataset.bsTheme)) return el.dataset.bsTheme;
    }
    if (document.body.classList.contains('quarto-dark')) return 'dark';
    if (document.body.classList.contains('quarto-light')) return 'light';
    return 'light';
  }

  function browserColour(value) {
    if (
      !value ||
      /^(inherit|initial|unset|revert|revert-layer|currentcolor)$/i.test(value) ||
      !CSS.supports('color', value)
    )
      return null;
    // Canvas normalises named colours and alpha hex without adding DOM nodes or drawing pixels.
    colourContext.fillStyle = value;
    const colour = colourContext.fillStyle;
    return ns.validColour(colour) ? colour : null;
  }

  function colourChannels(colour) {
    if (colour.startsWith('#')) {
      const hex = colour.length === 4 ? [...colour.slice(1)].map((x) => x + x).join('') : colour.slice(1);
      return [0, 2, 4].map((at) => parseInt(hex.slice(at, at + 2), 16) / 255).concat(1);
    }
    const values = colour
      .slice(colour.indexOf('(') + 1, -1)
      .split(',')
      .map(Number);
    return values
      .slice(0, 3)
      .map((x) => x / 255)
      .concat(values[3] ?? 1);
  }

  function colourContrast(colour, background) {
    const fg = colourChannels(colour),
      bg = colourChannels(background);
    const luminance = (channels) =>
      channels
        .slice(0, 3)
        .reduce(
          (sum, x, i) => sum + (x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4) * [0.2126, 0.7152, 0.0722][i],
          0,
        );
    const values = [luminance(fg.slice(0, 3).map((x, i) => x * fg[3] + bg[i] * (1 - fg[3]))), luminance(bg)];
    return (Math.max(...values) + 0.05) / (Math.min(...values) + 0.05);
  }

  // HSL shifts retain the leader's hue and alpha. Description amounts are calibrated from original colours.
  function shadeColour(colour, rule) {
    const [r, g, b, alpha] = colourChannels(colour);
    const max = Math.max(r, g, b),
      min = Math.min(r, g, b),
      delta = max - min;
    const light = (max + min) / 2;
    const saturation = delta === 0 ? 0 : delta / (1 - Math.abs(2 * light - 1));
    let hue = 0;
    if (delta !== 0) {
      if (max === r) hue = ((g - b) / delta + 6) % 6;
      else if (max === g) hue = (b - r) / delta + 2;
      else hue = (r - g) / delta + 4;
    }
    const clamp = (x) => Math.min(1, Math.max(0, x));
    const l = clamp(light + rule.amount),
      sat = delta === 0 ? 0 : clamp(saturation + (rule.saturation || 0));
    const chroma = (1 - Math.abs(2 * l - 1)) * sat;
    const x = chroma * (1 - Math.abs((hue % 2) - 1)),
      m = l - chroma / 2;
    const channels = [
      [chroma, x, 0],
      [x, chroma, 0],
      [0, chroma, x],
      [0, x, chroma],
      [x, 0, chroma],
      [chroma, 0, x],
    ][Math.floor(hue)];
    const rgb = channels.map((value) => Math.round((value + m) * 255));
    return alpha === 1
      ? `#${rgb.map((value) => value.toString(16).padStart(2, '0')).join('')}`
      : `rgba(${rgb.join(',')},${alpha})`;
  }

  function resolveTheme(theme, description, source, strict = false) {
    const mode = themeMode(theme) === 'auto' ? pageMode(source) : themeMode(theme);
    const overrides = {};
    const warnings = [];
    if (!description) return { overrides, mode, warnings };
    if (strict && !theme.brand) {
      for (const field of ['light', 'dark', 'css'])
        for (const role of Object.keys(theme[field] || {}))
          if (!has(description.colours, role))
            throw new Error(
              `theme.${field}: unknown colour role "${role}"; valid roles: ${Object.keys(description.colours).join(', ')}`,
            );
    }
    const selected = theme.brand ? {} : theme[mode] || {};
    if (theme.brand) {
      for (const [slot, role] of Object.entries(description.brand || {})) {
        if (!has(theme.brand, slot) || !has(description.colours, role))
          throw new Error(`invalid brand leader "${slot}"`);
        selected[role] = theme.brand[slot];
      }
    }
    for (const role of Object.keys(description.colours)) overrides[role] = has(selected, role) ? selected[role] : null;
    if (source && theme.css) {
      const style = getComputedStyle(source);
      const background =
        browserColour(
          style.getPropertyValue('--bs-body-bg').trim() || style.getPropertyValue('--_mascot-panel-bg').trim(),
        ) || (mode === 'dark' ? '#212529' : '#ffffff');
      for (const [role, variable] of Object.entries(theme.css)) {
        if (!has(description.colours, role)) continue;
        const colour = browserColour(style.getPropertyValue(variable).trim());
        overrides[role] = colour;
        if (!colour)
          warnings.push(
            `CSS variable "${variable}" for role "${role}" is missing or invalid; the character colour is kept`,
          );
        else if (colourContrast(colour, background) < 3)
          warnings.push(
            `CSS colour "${colour}" for role "${role}" in ${mode} mode has contrast below 3:1 against ${background}; the colour is kept`,
          );
      }
    }
    // Only supplied or filled leaders participate. Resolve recursively so data order is irrelevant.
    const visiting = new Set();
    const fill = (role) => {
      if (overrides[role] !== null) return overrides[role];
      const rule = description.follows?.[role];
      if (!rule || has(theme.css || {}, role)) return null;
      if (visiting.has(role)) throw new Error(`cyclic colour follow rule "${role}"`);
      visiting.add(role);
      for (const leader of rule.from) {
        if (!has(overrides, leader)) throw new Error(`unknown colour leader "${leader}"`);
        const colour = fill(leader);
        if (colour !== null) {
          overrides[role] = rule.shade ? shadeColour(colour, rule) : colour;
          break;
        }
      }
      visiting.delete(role);
      return overrides[role];
    };
    for (const role of Object.keys(overrides)) fill(role);
    return { overrides, mode, warnings };
  }

  function commitPalette(record, description, resolved) {
    record.colours = resolved.overrides;
    record.mode = resolved.mode;
    record.palettes.set(
      description.id,
      Object.fromEntries(
        Object.entries(description.colours).map(([role, colour]) => [role, resolved.overrides[role] ?? colour]),
      ),
    );
    for (const message of resolved.warnings) {
      if (!record.themeWarnings.has(message)) {
        record.themeWarnings.add(message);
        warn(message);
      }
    }
  }

  function refreshTheme(record) {
    const description = record.descriptions.get(record.character);
    const resolved = resolveTheme(record.theme, description, record.anchor || record.el);
    if (JSON.stringify(resolved.overrides) !== JSON.stringify(record.colours)) {
      record.controller.update({ colours: resolved.overrides });
      commitPalette(record, description, resolved);
      show(record, record.controller.current());
    } else commitPalette(record, description, resolved);
  }

  function watchModes() {
    if (live.size && !motionMedia) {
      motionMedia = window.matchMedia('(prefers-reduced-motion: reduce)');
      motionMedia.addEventListener('change', finishInterfaceMotion);
    } else if (!live.size && motionMedia) {
      motionMedia.removeEventListener('change', finishInterfaceMotion);
      motionMedia = null;
    }
    const auto = [...live].some((record) => themeMode(record.theme) === 'auto');
    if (auto && !modeMutation) {
      modeMutation = new MutationObserver(schedulePageRefresh);
      for (const el of [document.documentElement, document.body])
        modeMutation.observe(el, { attributes: true, attributeFilter: ['class', 'data-bs-theme'] });
    } else if (!auto) {
      modeMutation?.disconnect();
      modeMutation = null;
    }
    const scheme = auto || [...live].some((record) => record.placement.floating);
    if (scheme && !schemeMedia) {
      schemeMedia = window.matchMedia('(prefers-color-scheme: dark)');
      schemeMedia.addEventListener('change', refreshPage);
    } else if (!scheme) {
      schemeMedia?.removeEventListener('change', refreshPage);
      schemeMedia = null;
    }
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
      Object.keys(next).length !== 2 ||
      Object.keys(next).some((key) => !['size', 'small_screen'].includes(key))
    )
      throw new Error('size needs size and small_screen fields');
    validateSizeValue(next.size);
    if (next.small_screen !== null && next.small_screen !== 'auto') validateSizeValue(next.small_screen);
    return { ...next };
  }

  function validatePlacement(next) {
    if (
      !next ||
      typeof next !== 'object' ||
      Array.isArray(next) ||
      Object.keys(next).length !== 4 ||
      Object.keys(next).some((key) => !['floating', 'position', 'minimise', 'drag'].includes(key)) ||
      typeof next.floating !== 'boolean' ||
      typeof next.minimise !== 'boolean' ||
      !corners.includes(next.position) ||
      !drags.includes(next.drag)
    )
      throw new Error('placement needs floating, position, minimise and drag (false, "snap" or "free") fields');
    if (!next.floating && (next.position !== 'bottom-right' || next.minimise || next.drag !== false))
      throw new Error('position, minimise and drag only work with floating');
    return { ...next };
  }

  function sizeAttribute(value) {
    if (value === 'auto') return 'auto';
    return typeof value === 'string' && value.endsWith('%') ? value : Number(value);
  }

  function sizeCSS(value, floating) {
    return typeof value === 'number' ? `${value}px` : floating ? `${value.slice(0, -1)}vw` : value;
  }

  function setProperty(el, key, value) {
    if (el.style.getPropertyValue(key) !== value) {
      el.style.setProperty(key, value);
    }
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

  const stylingHooks = [
    'panel-bg',
    'panel-color',
    'panel-border',
    'restore-bg',
    'restore-fg',
    'restore-glow',
    'z-index',
  ];

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
      bg: style.getPropertyValue('--bs-body-bg') || style.getPropertyValue('--_mascot-panel-bg'),
      text: style.getPropertyValue('--bs-body-color') || style.getPropertyValue('--_mascot-panel-color'),
      border: style.getPropertyValue('--bs-border-color') || style.getPropertyValue('--_mascot-panel-border'),
    };
    // Keep inherited hooks from the original container without writing the public properties.
    for (const hook of stylingHooks) values[hook] = style.getPropertyValue(`--mascot-${hook}`);
    for (const [key, value] of Object.entries(values)) setProperty(el, `--_mascot-source-${key}`, value);
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
      for (const key of ['font', 'color', 'bg', 'text', 'border', ...stylingHooks])
        el.style.removeProperty(`--_mascot-source-${key}`);
      if (teardown) el.classList.remove('shiny-bound-input');
      else syncBinding(record);
    }
    if (focused && document.activeElement !== focused && !teardown) focused.focus();
  }

  // A picture is no keyboard stop, so focus that must stay in the mascot lands on its (programmatically focusable) box.
  function focusTarget(record) {
    if (record.minimised) return record.restoreButton;
    return record.button || record.el;
  }

  function refreshActions(record) {
    record.actions.hidden = record.minimiseButton.hidden || record.menuOpen;
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
    el.dataset.floating = String(placement.floating);
    el.dataset.position = placement.position;
    el.dataset.minimise = String(placement.minimise);
    el.dataset.drag = String(placement.drag);
    const point = record.dragState?.point || record.dropped;
    if (placement.floating && point) placeAt(record, point);
    else unplace(record);
    el.style.setProperty('--_mascot-size-default', sizeCSS(size.size, placement.floating));
    if (size.small_screen === null || size.small_screen === 'auto') {
      el.style.removeProperty('--_mascot-size-small');
    } else {
      el.style.setProperty('--_mascot-size-small', sizeCSS(size.small_screen, placement.floating));
    }
    record.minimiseButton.hidden = !placement.floating || !placement.minimise || record.minimised;
    record.restoreButton.hidden = !record.minimised;
    record.canvas.hidden = record.minimised;
    if (record.button) record.button.hidden = record.minimised;
    record.bubbleEl.parentElement.hidden = record.minimised;
    el.dataset.minimised = String(record.minimised);
    refreshActions(record);
    if (focusedControl?.hidden) {
      focusTarget(record).focus();
    }
  }

  // Floating mascots sit 1rem inside the window, like the CSS corners.
  function edgeOffset() {
    return parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
  }

  // Keep a point (the mascot's top-left) inside the window; an oversized mascot keeps its top-left edge visible.
  function clampPoint(record, point) {
    const rect = record.el.getBoundingClientRect();
    const edge = edgeOffset();
    const width = document.documentElement.clientWidth,
      height = document.documentElement.clientHeight;
    return {
      x: Math.max(edge, Math.min(point.x, width - rect.width - edge)),
      y: Math.max(edge, Math.min(point.y, height - rect.height - edge)),
    };
  }

  // The corner whose quarter of the window holds the mascot's centre.
  function nearestCorner(rect) {
    const vertical = rect.top + rect.height / 2 < document.documentElement.clientHeight / 2 ? 'top' : 'bottom';
    const horizontal = rect.left + rect.width / 2 < document.documentElement.clientWidth / 2 ? 'left' : 'right';
    return `${vertical}-${horizontal}`;
  }

  function placeAt(record, point) {
    const { x, y } = clampPoint(record, point);
    setProperty(record.el, '--_mascot-drag-left', `${x}px`);
    setProperty(record.el, '--_mascot-drag-top', `${y}px`);
    record.el.dataset.placed = 'true';
  }

  function unplace(record) {
    delete record.el.dataset.placed;
    record.el.style.removeProperty('--_mascot-drag-left');
    record.el.style.removeProperty('--_mascot-drag-top');
  }

  function reducedMotion(record) {
    return record.motion.reduced === true || window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  }

  // The side of the canvas the mascot looks towards: an open menu's chosen side, else its shown bubble's side.
  function gazeSide(record) {
    if (record.menuOpen) return record.menuSide;
    if (!record.bubble) return null;
    return record.placement.floating && record.placement.position.startsWith('top') ? 'bottom' : 'top';
  }

  // The held look with no side: only the look fields clear, whatever the mood.
  function clearedGaze(description) {
    if (!isFormat(description)) return { look: null, lookY: null };
    return ns.runtime.compile(description).gaze ? { 'face.look_x': null, 'face.look_y': null } : {};
  }

  // A held pose rather than motion, so it applies at once with or without reduced motion. A mirrored pose (flip)
  // mirrors the pupils too, so the horizontal look is flipped back to point at the same side of the page.
  function gazePose(record, side) {
    const description = record.descriptions.get(record.character);
    if (isFormat(description)) {
      // Held look goes to face.look_x and face.look_y in page terms; a faceless or no-gaze character gets no gaze
      // channels. The runtime flips the horizontal look back from the root flip of the frame it shows (contract 3.16).
      if (!ns.runtime.compile(description).gaze) return {};
      return {
        'face.look_x': side === 'left' ? -1 : side === 'right' ? 1 : null,
        'face.look_y': side === 'top' ? -1 : side === 'bottom' ? 1 : null,
      };
    }
    const flip = Math.sign(ns.drawing.resolvePose(description, { mood: record.mood }).flip) || 1;
    return {
      look: side === 'left' ? -flip : side === 'right' ? flip : null,
      lookY: side === 'top' ? -1 : side === 'bottom' ? 1 : null,
    };
  }

  function refreshGaze(record) {
    if (!record.controller) return;
    const side = gazeSide(record);
    const pose = gazePose(record, side);
    const key = JSON.stringify(pose);
    record.gazeSide = side;
    if (key === record.gaze) return;
    record.controller.update({ pose });
    record.gaze = key;
  }

  function draggable(record) {
    return record.placement.floating && record.placement.drag !== false;
  }

  // Abandon a gesture without dropping: a placement update or unmount replaces it.
  function cancelDrag(record) {
    record.snapAnimation?.cancel();
    record.snapAnimation = null;
    const gesture = record.dragState;
    if (!gesture) return;
    record.dragState = null;
    delete record.el.dataset.dragging;
    if (gesture.moved) record.suppressClick = true;
    if (gesture.target.hasPointerCapture(gesture.pointerId)) gesture.target.releasePointerCapture(gesture.pointerId);
  }

  function drop(record) {
    const gesture = record.dragState;
    record.dragState = null;
    delete record.el.dataset.dragging;
    if (!gesture.moved) return;
    // The click that ends a drag must not open the menu or restore; a touch drag may send no click at all.
    record.suppressClick = true;
    window.setTimeout(() => {
      record.suppressClick = false;
    }, 0);
    const first = record.el.getBoundingClientRect();
    const position = nearestCorner(first);
    const free = record.placement.drag === 'free';
    if (free) {
      const point = clampPoint(record, gesture.point);
      record.dropped = { x: Math.round(point.x), y: Math.round(point.y) };
    } else record.dropped = null;
    record.placement = { ...record.placement, position };
    layout(record);
    watchNotifications();
    measure(record);
    refreshGaze(record);
    if (!free && record.motion.others && !reducedMotion(record)) {
      const last = record.el.getBoundingClientRect();
      record.snapAnimation = record.el.animate(
        [{ transform: `translate(${first.left - last.left}px, ${first.top - last.top}px)` }, { transform: 'none' }],
        { duration: 200, easing: 'ease-out' },
      );
      record.snapAnimation.onfinish = () => {
        record.snapAnimation = null;
      };
    }
    window.Shiny?.setInputValue?.(`${record.el.id}_position`, free ? { ...record.dropped } : position, {
      priority: 'event',
    });
  }

  function listenDrag(record) {
    const { el } = record;
    const handlers = {
      pointerdown(event) {
        const target = record.minimised ? record.restoreButton : record.canvas;
        // A new press starts afresh, even when dragging was switched off: a cancelled touch drag may never have sent
        // the click that clears this, and the next real click must not be lost.
        if (!record.dragState && event.button === 0 && target.contains(event.target)) record.suppressClick = false;
        if (!draggable(record) || record.dragState || event.button !== 0 || !target.contains(event.target)) return;
        record.snapAnimation?.finish();
        const rect = el.getBoundingClientRect();
        record.dragState = {
          target,
          pointerId: event.pointerId,
          x: event.clientX,
          y: event.clientY,
          left: rect.left,
          top: rect.top,
          moved: false,
          point: null,
        };
        // Synthetic events (tests) have no active pointer to capture; the drag still follows their moves.
        if (event.isTrusted) target.setPointerCapture(event.pointerId);
      },
      pointermove(event) {
        const gesture = record.dragState;
        if (!gesture || event.pointerId !== gesture.pointerId) return;
        const dx = event.clientX - gesture.x,
          dy = event.clientY - gesture.y;
        if (!gesture.moved && Math.hypot(dx, dy) < dragThreshold) return;
        if (!gesture.moved) {
          gesture.moved = true;
          el.dataset.dragging = 'true';
          hideTooltip(record);
        }
        event.preventDefault();
        gesture.point = { x: gesture.left + dx, y: gesture.top + dy };
        placeAt(record, gesture.point);
      },
      pointerup(event) {
        if (record.dragState?.pointerId === event.pointerId) drop(record);
      },
      pointercancel(event) {
        if (record.dragState?.pointerId === event.pointerId) drop(record);
      },
      lostpointercapture(event) {
        if (record.dragState?.pointerId === event.pointerId) drop(record);
      },
      // Capture phase, so the menu's own click handler on the same element never sees a drag's click.
      click(event) {
        if (!record.suppressClick) return;
        record.suppressClick = false;
        event.preventDefault();
        event.stopPropagation();
      },
    };
    record.dragHandlers = handlers;
    for (const [name, handler] of Object.entries(handlers)) el.addEventListener(name, handler, name === 'click');
  }

  function unlistenDrag(record) {
    if (!record.dragHandlers) return;
    cancelDrag(record);
    for (const [name, handler] of Object.entries(record.dragHandlers))
      record.el.removeEventListener(name, handler, name === 'click');
    record.dragHandlers = null;
    unplace(record);
  }

  function minimise(record, value, focus = true) {
    if (value === record.minimised) return;
    if (value && (!record.placement.floating || !record.placement.minimise)) return;
    if (value) {
      closeMenu(record);
      hideTooltip(record);
    }
    record.placementAnimation?.cancel();
    record.placementCopy?.remove();
    record.placementCopy = null;
    const source = (value ? record.canvas : record.restoreButton).getBoundingClientRect();
    const moving = source.width > 0 && !reducedMotion(record) && record.motion[value ? 'minimising' : 'restoring'];
    let copy = null;
    if (moving && value) {
      copy = document.createElement('canvas');
      copy.width = record.canvas.width;
      copy.height = record.canvas.height;
      copy.getContext('2d').drawImage(record.canvas, 0, 0);
      copy.className = 'mascot-motion-copy';
      copy.setAttribute('aria-hidden', 'true');
      for (const [key, n] of Object.entries({
        left: source.left,
        top: source.top,
        width: source.width,
        height: source.height,
      }))
        copy.style[key] = `${n}px`;
      record.el.append(copy);
      record.placementCopy = copy;
    }
    stopTimer(record);
    record.minimised = value;
    window.Shiny?.setInputValue?.(`${record.el.id}_minimised`, value, { priority: 'event' });
    layout(record);
    if (!value) {
      measure(record);
      record.controller.redraw();
      resumeTimer(record);
    }
    if (moving) {
      const target = (value ? record.restoreButton : record.canvas).getBoundingClientRect();
      const dx =
        (value ? target.left - source.left : source.left - target.left) +
        (value ? target.width - source.width : source.width - target.width) / 2;
      const dy =
        (value ? target.top - source.top : source.top - target.top) +
        (value ? target.height - source.height : source.height - target.height) / 2;
      const scale = value ? target.width / source.width : source.width / target.width;
      const small = { transform: `translate(${dx}px, ${dy}px) scale(${scale})`, opacity: 0 };
      const full = { transform: 'none', opacity: 1 };
      const movement = (copy || record.canvas).animate(value ? [full, small] : [small, full], {
        duration: 240,
        easing: 'ease-out',
      });
      record.placementAnimation = movement;
      const cleanup = () => {
        copy?.remove();
        if (record.placementAnimation === movement) {
          record.placementAnimation = null;
          record.placementCopy = null;
        }
        if (!value) {
          measure(record);
          record.controller.redraw();
        }
      };
      movement.onfinish = cleanup;
      movement.oncancel = cleanup;
    }
    if (focus) (value ? record.restoreButton : record.minimiseButton).focus();
    record.focus = record.el.contains(document.activeElement);
  }

  // Sample once when a panel shows, not on scroll or each animation frame. Canvas artwork
  // has transparent margins; anchoring to its box leaves a visible gap above the character.
  function inkBox(record) {
    const canvas = record.canvas;
    const { data } = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
    let firstY = canvas.height;
    let lastY = -1;
    let firstX = canvas.width;
    let lastX = -1;
    for (let y = 0; y < canvas.height; y++) {
      for (let x = 0; x < canvas.width; x++) {
        if (data[(y * canvas.width + x) * 4 + 3] === 0) continue;
        firstY = Math.min(firstY, y);
        lastY = Math.max(lastY, y);
        firstX = Math.min(firstX, x);
        lastX = Math.max(lastX, x);
      }
    }
    return lastY < 0
      ? { top: 0, bottom: 1, left: 0, right: 1 }
      : {
          top: firstY / canvas.height,
          bottom: (lastY + 1) / canvas.height,
          left: firstX / canvas.width,
          right: (lastX + 1) / canvas.width,
        };
  }

  // The shared panel placement (#233): put a shown panel on the requested side of the painted character, falling back
  // to the opposite side and then to "auto", inside the room the page gives. Sets --_mascot-<name>-top, -left and
  // -max-height/-max-width on the mascot, the chosen side as the panel's data-side and its tail offset; returns the side.
  function placePanel(record, panel, requested, name, capEm = Infinity) {
    const margin = 16;
    const notification =
      record.placement.floating && record.placement.position === 'bottom-right'
        ? parseFloat(record.el.style.getPropertyValue('--_mascot-notification-offset')) || 0
        : 0;
    const bounds = record.placement.floating ? clipBounds(document.body) : clipBounds(record.el);
    const ceiling = bounds.top;
    const floor = Math.min(bounds.bottom, document.documentElement.clientHeight - notification - margin);
    // Constrain width before measuring, so a tooltip's wrapped height determines the side and available height.
    setProperty(record.el, `--_mascot-${name}-max-width`, `${Math.max(0, bounds.right - bounds.left)}px`);
    const gap = 8;
    const canvas = record.canvas.getBoundingClientRect();
    const ink = record.ink || { top: 0, bottom: 1, left: 0, right: 1 };
    const anchorTop = canvas.top + ink.top * canvas.height;
    const anchorBottom = canvas.top + ink.bottom * canvas.height;
    const anchorLeft = canvas.left + ink.left * canvas.width;
    const anchorRight = canvas.left + ink.right * canvas.width;
    const anchorWidth = anchorRight - anchorLeft;
    const anchorCenterX = (anchorLeft + anchorRight) / 2;
    const anchorCenterY = (anchorTop + anchorBottom) / 2;

    const style = getComputedStyle(panel);
    const wantedHeight = Math.min(
      panel.scrollHeight + parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth),
      capEm * parseFloat(style.fontSize),
    );
    const wantedWidth = panel.scrollWidth + parseFloat(style.borderLeftWidth) + parseFloat(style.borderRightWidth);

    const spaceAbove = Math.max(0, anchorTop - gap - ceiling);
    const spaceBelow = Math.max(0, floor - anchorBottom - gap);
    const spaceLeft = Math.max(0, anchorLeft - gap - bounds.left);
    const spaceRight = Math.max(0, bounds.right - anchorRight - gap);

    const hasRoomTop = spaceAbove >= wantedHeight;
    const hasRoomBottom = spaceBelow >= wantedHeight;
    const hasRoomLeft = spaceLeft >= wantedWidth;
    const hasRoomRight = spaceRight >= wantedWidth;

    const resolveAuto = () => {
      if (hasRoomTop) return 'top';
      if (hasRoomBottom) return 'bottom';
      const pageCenter = document.documentElement.clientWidth / 2;
      const towardsCenter = anchorCenterX < pageCenter ? 'right' : 'left';
      const awayFromCenter = towardsCenter === 'right' ? 'left' : 'right';
      const hasRoomTowards = towardsCenter === 'right' ? hasRoomRight : hasRoomLeft;
      const hasRoomAway = awayFromCenter === 'right' ? hasRoomRight : hasRoomLeft;
      if (hasRoomTowards) return towardsCenter;
      if (hasRoomAway) return awayFromCenter;
      return spaceAbove >= spaceBelow ? 'top' : 'bottom';
    };

    let chosen = requested;
    if (requested === 'top') {
      if (!hasRoomTop) chosen = hasRoomBottom ? 'bottom' : resolveAuto();
    } else if (requested === 'bottom') {
      if (!hasRoomBottom) chosen = hasRoomTop ? 'top' : resolveAuto();
    } else if (requested === 'left') {
      if (!hasRoomLeft) chosen = hasRoomRight ? 'right' : resolveAuto();
    } else if (requested === 'right') {
      if (!hasRoomRight) chosen = hasRoomLeft ? 'left' : resolveAuto();
    } else {
      chosen = resolveAuto();
    }

    const availableHeight =
      chosen === 'top' ? spaceAbove : chosen === 'bottom' ? spaceBelow : Math.max(24, floor - ceiling);
    setProperty(record.el, `--_mascot-${name}-max-height`, `${Math.max(24, availableHeight)}px`);

    const rect = panel.getBoundingClientRect();
    let top;
    let left;

    if (chosen === 'top') {
      top = Math.max(ceiling, Math.min(anchorTop - gap - rect.height, floor - rect.height));
      const naturalLeft = anchorLeft + (anchorWidth - rect.width) / 2;
      left = Math.max(bounds.left, Math.min(naturalLeft, bounds.right - rect.width));
    } else if (chosen === 'bottom') {
      top = Math.max(ceiling, Math.min(anchorBottom + gap, floor - rect.height));
      const naturalLeft = anchorLeft + (anchorWidth - rect.width) / 2;
      left = Math.max(bounds.left, Math.min(naturalLeft, bounds.right - rect.width));
    } else if (chosen === 'left') {
      left = Math.max(bounds.left, Math.min(anchorLeft - gap - rect.width, bounds.right - rect.width));
      top = Math.max(ceiling, Math.min(anchorCenterY - rect.height / 2, floor - rect.height));
    } else {
      left = Math.max(bounds.left, Math.min(anchorRight + gap, bounds.right - rect.width));
      top = Math.max(ceiling, Math.min(anchorCenterY - rect.height / 2, floor - rect.height));
    }

    const hostRect = record.el.getBoundingClientRect();
    setProperty(record.el, `--_mascot-${name}-top`, `${top - hostRect.top}px`);
    setProperty(record.el, `--_mascot-${name}-left`, `${left - hostRect.left}px`);
    // The tail points at the character's centre, kept off the panel's rounded corners.
    const vertical = chosen === 'top' || chosen === 'bottom';
    const length = vertical ? rect.width : rect.height;
    const offset = vertical ? anchorCenterX - left : anchorCenterY - top;
    setProperty(panel, '--_mascot-panel-tail', `${Math.max(12, Math.min(offset, length - 12))}px`);
    panel.dataset.side = chosen;
    return chosen;
  }

  function measureMenu(record) {
    if (!record.menuEl || !record.menuOpen) return;
    record.menuSide = placePanel(record, record.menuEl, record.click.direction || 'auto', 'menu', 18);
    refreshGaze(record);
  }

  function measureTooltip(record) {
    if (record.tooltipShown) placePanel(record, record.tooltipEl, 'auto', 'tooltip');
  }

  // Overlay room: the viewport, narrowed by ancestors that clip overflow (such as a bslib card).
  function clipBounds(el) {
    const viewport = 16,
      inset = 8;
    let left = viewport,
      right = document.documentElement.clientWidth - viewport,
      top = viewport,
      bottom = document.documentElement.clientHeight - viewport;
    for (let node = el.parentElement; node && node !== document.body; node = node.parentElement) {
      const style = getComputedStyle(node);
      const rect = node.getBoundingClientRect();
      if (style.overflowX !== 'visible') {
        left = Math.max(left, rect.left + node.clientLeft + inset);
        right = Math.min(right, rect.left + node.clientLeft + node.clientWidth - inset);
      }
      if (style.overflowY !== 'visible') {
        top = Math.max(top, rect.top + node.clientTop + inset);
        bottom = Math.min(bottom, rect.top + node.clientTop + node.clientHeight - inset);
      }
    }
    return { left, right: Math.max(left, right), top, bottom: Math.max(top, bottom) };
  }

  function measure(record) {
    record.measures += 1;
    // A free drop stays inside the window when the window or the mascot changes size.
    if (record.dropped && record.placement.floating && !record.dragState) placeAt(record, record.dropped);
    const size = record.placementAnimation
      ? parseFloat(getComputedStyle(record.canvas).width) || record.canvas.clientWidth
      : record.canvas.getBoundingClientRect().width;
    const visibility = getComputedStyle(record.canvas).visibility;
    const hidden =
      !(size > 0) || visibility === 'hidden' || visibility === 'collapse' || record.el.dataset.sourceHidden === 'true';
    if (hidden !== record.hidden) {
      record.hidden = hidden;
      if (hidden) stopTimer(record);
      else resumeTimer(record);
    }
    if (record.minimised || hidden) return;
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
      // Subtract only a shift that is applied: page CSS may turn the transform off (mascot_preview() does), and
      // subtracting an unapplied shift would grow it on every measure, an endless loop through the page observer.
      // The variable, not the computed matrix, gives the exact value; a rounded matrix would never settle either.
      const applied = getComputedStyle(region).transform !== 'none';
      const shift = applied ? parseFloat(record.el.style.getPropertyValue('--_mascot-bubble-shift')) || 0 : 0;
      const natural = rect.left - shift;
      const bounds = clipBounds(record.el);
      const left = Math.max(bounds.left, Math.min(natural, bounds.right - rect.width));
      setProperty(record.el, '--_mascot-bubble-shift', `${left - natural}px`);
    }
    measureMenu(record);
    measureTooltip(record);
    // E5b, internal only: the band follows the untransformed CSS width (not the transformed rectangle). setBand() is
    // atomic: a band over budget throws before anything changes, so the old band stays, measuring goes on, and the
    // refusal is reported once per band. It never throws out of measure(). The public default never gets here.
    // setBand() reports whether it drew: a band that is already set draws nothing, so the redraw below still runs.
    // A width of 0 decides nothing, so the band waits for the first real width.
    let drawn = false;
    const width = cssWidth(record.canvas);
    if (record.controller && width > 0 && bandsApply(record.descriptions.get(record.character))) {
      const band = ns.parts.bandFor(width);
      if (band !== record.band) {
        try {
          drawn = record.controller.setBand(band);
          record.band = band;
        } catch (error) {
          reportBand(record, band, error);
        }
      }
    }
    record.renderedSize = size;
    // A successful band change has already drawn the current frame on the resized canvas: draw once, not twice.
    if (resized && !drawn) record.controller.redraw();
  }

  function refreshViewport() {
    for (const record of live) {
      syncSource(record);
      refreshTheme(record);
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
        if (record.el.style.getPropertyValue('--_mascot-notification-offset') !== value) {
          record.el.style.setProperty('--_mascot-notification-offset', value);
        }
        measureMenu(record);
      }
    }
  }

  function cancelPageRefresh() {
    if (pageFrame !== null) {
      window.cancelAnimationFrame(pageFrame);
      pageFrame = null;
    }
  }

  function schedulePageRefresh() {
    if (!live.size || pageFrame !== null) return;
    pageFrame = window.requestAnimationFrame(() => {
      pageFrame = null;
      refreshPage();
    });
  }

  function affectsMascot(node) {
    if (!(node instanceof Element)) return false;
    for (const record of live) {
      if (node.contains(record.el) || (record.anchor && node.contains(record.anchor))) return true;
    }
    return false;
  }

  function hasStyleNode(nodes) {
    for (const node of nodes) {
      if (!(node instanceof Element)) continue;
      if (node.tagName === 'STYLE' || node.tagName === 'LINK' || node.querySelector?.('style, link[rel="stylesheet"]'))
        return true;
    }
    return false;
  }

  function externalMutation(m, after) {
    if (m.type !== 'attributes') return true;
    if (m.oldValue === after) return false;
    if (m.attributeName !== 'style' || !records.has(m.target)) return true;
    // Compare each transition, not only the final style: application writes in the same
    // task as host writes must survive. Only private host properties are ignored.
    const publicStyle = (text) => {
      const style = document.createElement('span').style;
      style.cssText = text || '';
      for (const key of [...style]) if (key.startsWith('--_mascot-')) style.removeProperty(key);
      return style.cssText;
    };
    return publicStyle(m.oldValue) !== publicStyle(after);
  }

  function relevantMutation(m) {
    for (const record of live) {
      if (record.anchor && !record.anchor.isConnected) return true;
    }
    const panel = document.getElementById('shiny-notification-panel');
    if (panel !== notificationPanel) return true;
    if (panel && (m.target === panel || panel.contains(m.target))) return true;
    if (m.type === 'attributes' && affectsMascot(m.target)) return true;
    // A sibling's layout can move an inline bubble without resizing its mascot.
    // Ignore mutations inside mascot UI; its own writes must not schedule another frame.
    if (
      ![...live].some((record) => record.el.contains(m.target)) &&
      [...live].some((record) => !record.placement.floating && record.bubble && !record.hidden)
    )
      return true;
    if (m.type === 'attributes') return false;
    if (m.target instanceof Element && m.target.tagName === 'STYLE') return true;
    if (document.head && (m.target === document.head || document.head.contains(m.target))) return true;
    return (
      hasStyleNode(m.addedNodes) ||
      hasStyleNode(m.removedNodes) ||
      [...m.addedNodes, ...m.removedNodes].some(affectsMascot)
    );
  }

  function refreshPage() {
    cancelPageRefresh();
    for (const record of live) {
      if (record.anchor && !record.anchor.isConnected) unmount(record.el);
      else {
        syncSource(record);
        refreshTheme(record);
        measure(record);
      }
    }
    refreshNotifications();
  }

  function watchNotifications() {
    // A shared page observer also catches inline messages moving near a viewport edge.
    const needed = live.size > 0;
    if (!needed) {
      cancelPageRefresh();
      notificationMutation?.disconnect();
      notificationResize?.disconnect();
      notificationMutation = notificationResize = notificationPanel = null;
      return;
    }
    if (!notificationMutation) {
      notificationMutation = new MutationObserver((mutations) => {
        // MutationRecord has the old value only. Walk backwards to recover each new
        // value even when application and host writes share the same delivery batch.
        const values = new Map();
        let relevant = false;
        for (let i = mutations.length - 1; i >= 0; i--) {
          const m = mutations[i];
          let after;
          if (m.type === 'attributes') {
            if (!values.has(m.target)) values.set(m.target, new Map());
            const attrs = values.get(m.target);
            after = attrs.has(m.attributeName) ? attrs.get(m.attributeName) : m.target.getAttribute(m.attributeName);
            attrs.set(m.attributeName, m.oldValue);
          }
          if (externalMutation(m, after) && relevantMutation(m)) relevant = true;
        }
        if (relevant) schedulePageRefresh();
      });
      notificationMutation.observe(document.documentElement, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['class', 'style', 'hidden', 'data-bs-theme'],
        attributeOldValue: true,
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

  function watchViewport() {
    if (!live.size) {
      viewportObserver?.disconnect();
      viewportObserver = null;
      return;
    }
    if (!viewportObserver && typeof window.IntersectionObserver === 'function') {
      viewportObserver = new window.IntersectionObserver((entries) => {
        for (const entry of entries) {
          const target = records.get(entry.target);
          if (!target) continue;
          const offscreen = !entry.isIntersecting && entry.intersectionRatio === 0;
          if (offscreen === target.offscreen) continue;
          target.offscreen = offscreen;
          target.controller.holdVisibility(offscreen);
        }
      });
    }
  }

  function watch(record) {
    record.resize = new ResizeObserver(() => measure(record));
    record.resize.observe(record.el);
    live.add(record);
    if (live.size === 1) {
      window.addEventListener('resize', refreshViewport);
      densityChanged();
    }
    watchViewport();
    viewportObserver?.observe(record.el);
    watchNotifications();
    watchModes();
  }

  function unwatch(record) {
    record.resize?.disconnect();
    viewportObserver?.unobserve(record.el);
    const registered = live.delete(record);
    if (registered && !live.size) {
      window.removeEventListener('resize', refreshViewport);
      densityMedia?.removeEventListener('change', densityChanged);
      densityMedia = null;
    }
    watchViewport();
    watchNotifications();
    watchModes();
  }

  const menuDirections = ['auto', 'top', 'bottom', 'left', 'right'];
  const openTooltips = new Set();
  // How long a tooltip waits before hiding when the pointer leaves, so it can cross to the tooltip (WCAG 1.4.13).
  const tooltipGrace = 150;

  function validateMenuItems(items) {
    if (
      !items ||
      typeof items !== 'object' ||
      Array.isArray(items) ||
      !Object.keys(items).length ||
      Object.entries(items).some(
        ([id, text]) => !id.length || /\s/.test(id) || typeof text !== 'string' || !text.length,
      )
    )
      throw new Error('click menu items need non-empty ids without whitespace and plain-text labels');
    return { ...items };
  }

  function validateClick(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('click needs an object');
    const fields = {
      none: ['type'],
      action: ['type', 'label', 'tooltip', 'disabled'],
      menu: ['type', 'items', 'direction', 'label', 'tooltip'],
    };
    const keys = fields[value.type];
    if (!keys) throw new Error('click type must be none, action or menu');
    if (Object.keys(value).length !== keys.length || Object.keys(value).some((key) => !keys.includes(key)))
      throw new Error(`a ${value.type} click needs exactly ${keys.join(', ')}`);
    if (value.type === 'none') return { type: 'none' };
    const label = (text) => typeof text === 'string' && /\S/.test(text);
    if (value.type === 'action') {
      if (!label(value.label) || typeof value.tooltip !== 'boolean' || typeof value.disabled !== 'boolean')
        throw new Error('a click action needs a non-empty label and tooltip and disabled flags');
      return { type: 'action', label: value.label, tooltip: value.tooltip, disabled: value.disabled };
    }
    if (!menuDirections.includes(value.direction))
      throw new Error('click menu direction must be auto, top, bottom, left or right');
    if (value.label !== null && !label(value.label)) throw new Error('click menu label must be non-empty text or null');
    if (typeof value.tooltip !== 'boolean') throw new Error('click menu tooltip must be a boolean');
    return {
      type: 'menu',
      items: validateMenuItems(value.items),
      direction: value.direction,
      label: value.label,
      tooltip: value.tooltip,
    };
  }

  function measureOpenMenus() {
    for (const record of openMenus) measureMenu(record);
    for (const record of openTooltips) measureTooltip(record);
  }

  function outsideMenu(event) {
    for (const record of [...openMenus])
      if (!record.menuEl.contains(event.target) && !record.button.contains(event.target)) closeMenu(record);
  }

  // One shared scroll listener while any menu or tooltip shows.
  let scrollWatched = false;
  function watchScroll() {
    const needed = openMenus.size > 0 || openTooltips.size > 0;
    if (needed === scrollWatched) return;
    scrollWatched = needed;
    if (needed) window.addEventListener('scroll', measureOpenMenus, true);
    else window.removeEventListener('scroll', measureOpenMenus, true);
  }

  function closeMenu(record, focus = false, clearPose = true) {
    if (!record.menuOpen) return;
    record.menuOpen = false;
    hidePanel(record, record.menuEl, 'menu');
    record.button.setAttribute('aria-expanded', 'false');
    openMenus.delete(record);
    if (!openMenus.size) document.removeEventListener('pointerdown', outsideMenu, true);
    watchScroll();
    refreshActions(record);
    record.menuSide = null;
    if (clearPose) refreshGaze(record);
    if (focus) record.button.focus();
    resumeTimer(record);
  }

  function openMenu(record, keyboard) {
    if (record.minimised || !record.menuEl) return;
    for (const other of [...openMenus]) if (other !== record) closeMenu(other);
    clearBubble(record);
    hideTooltip(record);
    record.menuOpen = true;
    const actionFocused = record.actions.contains(document.activeElement);
    refreshActions(record);
    syncMotion(record);
    record.menuEl.hidden = false;
    record.ink = inkBox(record);
    measureMenu(record);
    record.button.setAttribute('aria-expanded', 'true');
    stopTimer(record);
    if (!openMenus.size) document.addEventListener('pointerdown', outsideMenu, true);
    openMenus.add(record);
    watchScroll();
    if (keyboard) record.menuEl.querySelector('button').focus();
    else if (actionFocused) record.button.focus();
  }

  // Escape dismisses every shown tooltip, wherever the focus is; the listener exists only while one shows.
  function escapeTooltips(event) {
    if (event.key !== 'Escape') return;
    for (const record of [...openTooltips]) {
      record.tooltipDismissed = true;
      hideTooltip(record);
    }
  }

  function showTooltip(record) {
    window.clearTimeout(record.tooltipTimer);
    record.tooltipTimer = null;
    if (
      !record.tooltipEl ||
      record.tooltipShown ||
      record.tooltipDismissed ||
      record.minimised ||
      record.menuOpen ||
      record.bubble ||
      record.dragState?.moved
    )
      return;
    record.tooltipShown = true;
    syncMotion(record);
    record.tooltipEl.hidden = false;
    record.ink = inkBox(record);
    measureTooltip(record);
    if (!openTooltips.size) document.addEventListener('keydown', escapeTooltips, true);
    openTooltips.add(record);
    watchScroll();
  }

  function hideTooltip(record) {
    window.clearTimeout(record.tooltipTimer);
    record.tooltipTimer = null;
    if (!record.tooltipShown) return;
    record.tooltipShown = false;
    hidePanel(record, record.tooltipEl, 'tooltip');
    openTooltips.delete(record);
    if (!openTooltips.size) document.removeEventListener('keydown', escapeTooltips, true);
    watchScroll();
  }

  // The tooltip stays while the pointer is over the mascot's button or the tooltip, or the button has keyboard focus.
  function settleTooltip(record) {
    if (record.tooltipHover || record.button?.matches(':focus-visible')) showTooltip(record);
    else if (record.tooltipShown && record.tooltipTimer === null)
      record.tooltipTimer = window.setTimeout(() => hideTooltip(record), tooltipGrace);
  }

  function activate(record, keyboard) {
    if (record.click.disabled) return;
    record.clicks += 1;
    window.Shiny.setInputValue(`${record.el.id}_click`, record.clicks, { priority: 'event' });
    if (record.click.type === 'menu') {
      if (record.menuOpen) closeMenu(record, keyboard);
      else openMenu(record, keyboard);
    } else {
      // The app's answer (a panel, a dialog) takes over; the tooltip returns on the next hover or focus.
      record.tooltipDismissed = true;
      hideTooltip(record);
    }
  }

  function removeClick(record, clearPose = true) {
    closeMenu(record, false, clearPose);
    hideTooltip(record);
    if (!record.button) return;
    const focused = record.el.contains(document.activeElement) && record.button.contains(document.activeElement);
    const inMenu = record.menuEl?.contains(document.activeElement);
    if (focused || inMenu) record.el.focus();
    for (const [name, handler] of Object.entries(record.buttonHandlers)) record.el.removeEventListener(name, handler);
    record.button.replaceWith(record.canvas);
    record.canvas.removeAttribute('aria-hidden');
    record.menuEl?.remove();
    record.tooltipEl?.remove();
    record.button = record.menuEl = record.tooltipEl = record.buttonHandlers = null;
    record.tooltipHover = record.tooltipDismissed = false;
  }

  function replaceClick(record, value, clearPose = true) {
    const focused =
      Boolean(record.button) &&
      (record.button === document.activeElement || Boolean(record.menuEl?.contains(document.activeElement)));
    removeClick(record, clearPose);
    record.click = value;
    if (value.type === 'none' || !window.Shiny?.setInputValue) return;
    const menuClick = value.type === 'menu';
    const button = document.createElement('button');
    button.type = 'button';
    button.className = menuClick ? 'mascot-button mascot-menu-toggle' : 'mascot-button';
    button.hidden = record.minimised;
    if (value.disabled) button.setAttribute('aria-disabled', 'true');
    let menu = null;
    if (menuClick) {
      button.setAttribute('aria-haspopup', 'menu');
      button.setAttribute('aria-expanded', 'false');
      button.setAttribute('aria-controls', `${record.el.id}_popup_menu`);
      menu = document.createElement('div');
      menu.id = `${record.el.id}_popup_menu`;
      menu.className = 'mascot-panel mascot-menu';
      menu.setAttribute('role', 'menu');
      menu.setAttribute('aria-label', 'Mascot choices');
      menu.hidden = true;
      for (const [id, text] of Object.entries(value.items)) {
        const item = document.createElement('button');
        item.type = 'button';
        item.setAttribute('role', 'menuitem');
        item.tabIndex = -1;
        item.dataset.itemId = id;
        item.textContent = text;
        menu.append(item);
      }
    }
    let tooltip = null;
    if (
      (value.type === 'action' && value.tooltip) ||
      (value.type === 'menu' && value.tooltip && Boolean(value.label))
    ) {
      tooltip = document.createElement('div');
      tooltip.className = 'mascot-panel mascot-tooltip';
      tooltip.id = `${record.el.id}_tooltip`;
      tooltip.setAttribute('role', 'tooltip');
      // The button's name already says this; hidden from assistive technology so it is not read twice.
      tooltip.setAttribute('aria-hidden', 'true');
      tooltip.textContent = value.label;
      tooltip.hidden = true;
    }
    record.canvas.before(button);
    button.append(record.canvas);
    record.canvas.setAttribute('aria-hidden', 'true');
    if (menu) record.el.append(menu);
    if (tooltip) record.el.append(tooltip);
    record.button = button;
    record.menuEl = menu;
    record.tooltipEl = tooltip;
    const onTooltip = (target) => Boolean(target) && (button.contains(target) || Boolean(tooltip?.contains(target)));
    record.buttonHandlers = {
      click(event) {
        if (button.contains(event.target)) {
          // A keyboard or assistive-technology click has no pointer detail; it moves focus into an opened menu.
          activate(record, event.detail === 0);
          return;
        }
        const item = menu && event.target.closest('[role="menuitem"]');
        if (!item || !menu.contains(item)) return;
        const id = item.dataset.itemId;
        closeMenu(record, true);
        window.Shiny.setInputValue(`${record.el.id}_menu`, id, { priority: 'event' });
      },
      keydown(event) {
        const activating = ['Enter', ' '].includes(event.key);
        // A held key activates once: its repeats reach neither the button nor a menu item that took focus on opening.
        if (activating && event.repeat && (button.contains(event.target) || Boolean(menu?.contains(event.target)))) {
          event.preventDefault();
          return;
        }
        if (event.target === button && activating) {
          // Like a native button: shortcuts with Ctrl, Alt or Meta belong to the browser or the app.
          if (event.ctrlKey || event.altKey || event.metaKey) return;
          // Handled here, not by the button's own click, so a key press counts once.
          event.preventDefault();
          activate(record, true);
          return;
        }
        if (!record.menuOpen) return;
        if (event.key === 'Escape') {
          event.preventDefault();
          event.stopPropagation();
          closeMenu(record, true);
        } else if (event.target === button && ['ArrowDown', 'ArrowUp'].includes(event.key)) {
          // A menu opened by pointer keeps focus on the toggle; the arrows move into it.
          event.preventDefault();
          const items = menu.querySelectorAll('button');
          items[event.key === 'ArrowDown' ? 0 : items.length - 1].focus();
        } else if (menu.contains(event.target)) {
          const items = [...menu.querySelectorAll('button')];
          const index = items.indexOf(document.activeElement);
          let next;
          if (event.key === 'ArrowDown') next = (index + 1) % items.length;
          if (event.key === 'ArrowUp') next = (index + items.length - 1) % items.length;
          if (event.key === 'Home') next = 0;
          if (event.key === 'End') next = items.length - 1;
          if (next !== undefined) {
            event.preventDefault();
            items[next].focus();
          }
        }
      },
      focusin(event) {
        if (event.target === button) settleTooltip(record);
      },
      focusout(event) {
        if (!record.el.contains(event.relatedTarget)) closeMenu(record);
        if (event.target === button) {
          record.tooltipDismissed = false;
          settleTooltip(record);
        }
      },
      pointerover(event) {
        if (event.pointerType === 'touch' || !onTooltip(event.target) || onTooltip(event.relatedTarget)) return;
        record.tooltipHover = true;
        settleTooltip(record);
      },
      pointerout(event) {
        if (!onTooltip(event.target) || onTooltip(event.relatedTarget)) return;
        record.tooltipHover = false;
        if (!button.matches(':focus-visible')) record.tooltipDismissed = false;
        settleTooltip(record);
      },
    };
    for (const [name, handler] of Object.entries(record.buttonHandlers)) record.el.addEventListener(name, handler);
    show(record, record.controller.current());
    if (focused && !record.minimised) button.focus();
  }

  function validateMotion(value) {
    const keys = ['reduced', ...motionFlags, 'messages'];
    if (
      !value ||
      typeof value !== 'object' ||
      Array.isArray(value) ||
      Object.keys(value).length !== keys.length ||
      keys.some((key) => !has(value, key)) ||
      (value.reduced !== null && value.reduced !== true) ||
      motionFlags.some((key) => typeof value[key] !== 'boolean') ||
      !Array.isArray(value.messages) ||
      value.messages.some((name) => !panelNames.includes(name))
    )
      throw new Error(
        'motion needs reduced null or true, boolean switches and messages naming bubble, tooltip or menu',
      );
    return { ...value, messages: [...value.messages] };
  }

  function syncMotion(record) {
    record.el.dataset.reduced = record.motion.reduced === true ? 'true' : 'auto';
    for (const key of motionFlags) {
      record.el.dataset[key === 'mood_change' ? 'moodChange' : key] = String(record.motion[key]);
    }
    record.el.dataset.messages = record.motion.messages.join(',');
    for (const [name, panel] of [
      ['bubble', record.bubbleEl],
      ['menu', record.menuEl],
      ['tooltip', record.tooltipEl],
    ]) {
      if (!panel) continue;
      panel.dataset.motion = String(record.motion.messages.includes(name));
      if (reducedMotion(record) || !record.motion.messages.includes(name))
        panel.getAnimations().forEach((movement) => {
          movement.finish();
        });
    }
    if (reducedMotion(record) || !record.motion.others) record.snapAnimation?.finish();
    for (const movement of record.panelExits) {
      if (reducedMotion(record) || !record.motion.messages.includes(movement.effect.target.dataset.panel))
        movement.finish();
    }
    if (reducedMotion(record) || !record.motion[record.minimised ? 'minimising' : 'restoring'])
      record.placementAnimation?.finish();
  }

  // Hiding is logical immediately; a non-interactive copy supplies only the short exit fade.
  function hidePanel(record, panel, name) {
    if (!panel.hidden && !reducedMotion(record) && record.motion.messages.includes(name)) {
      const copy = panel.cloneNode(true);
      copy.removeAttribute('id');
      for (const node of copy.querySelectorAll('[id]')) node.removeAttribute('id');
      copy.inert = true;
      copy.setAttribute('aria-hidden', 'true');
      copy.dataset.panel = name;
      copy.classList.add('mascot-motion-copy');
      const rect = panel.getBoundingClientRect();
      for (const [key, value] of Object.entries({
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
      }))
        copy.style[key] = `${value}px`;
      record.el.append(copy);
      const movement = copy.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 150, easing: 'ease-out' });
      const remove = () => {
        copy.remove();
        record.panelExits.delete(movement);
      };
      movement.onfinish = remove;
      movement.oncancel = remove;
      record.panelExits.add(movement);
    }
    panel.hidden = true;
  }

  function mount(el) {
    if (records.has(el)) return true;
    const authoritative = ledgers.get(el.id);
    if (authoritative?.live) {
      warn(`duplicate live mascot id "${el.id}"; the first binding remains authoritative`);
      return false;
    }
    if (!Number.isSafeInteger(mountSerial + 1)) throw new Error('mascot mount generation exhausted');
    const id = el.dataset.character;
    // Rebinding the same DOM may follow an accepted character swap: its live
    // data-character then names the last checked content, not the original UI
    // script. Keep only that referenced descriptor per retained id.
    const local = el.querySelector(`script[data-mascot-character="${id}"]`);
    const cached = known.get(el.id);
    const description = local || cached?.id !== id ? ns.readCharacter(id, el) : cached;
    const canvas = el.querySelector('.mascot-canvas');
    const statusEl = el.querySelector('.mascot-status');
    const bubbleEl = el.querySelector('.mascot-bubble');
    const size = 160; // A usable backing size until a hidden element can be measured.
    const sizeConfig = validateSize({
      size: has(el.dataset, 'size') ? sizeAttribute(el.dataset.size) : 160,
      small_screen: has(el.dataset, 'smallScreen') ? sizeAttribute(el.dataset.smallScreen) : null,
    });
    const placement = validatePlacement({
      floating: el.dataset.floating === 'true',
      position: el.dataset.position || 'bottom-right',
      minimise: el.dataset.minimise === 'true',
      drag: ['snap', 'free'].includes(el.dataset.drag) ? el.dataset.drag : false,
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
    const actions = document.createElement('div');
    actions.className = 'mascot-actions';
    const minimiseButton = button('mascot-minimise', 'Minimise mascot');
    actions.append(minimiseButton);
    el.append(actions);
    const record = {
      el,
      canvas,
      statusEl,
      controller: null,
      size: sizeConfig,
      placement,
      click: validateClick(JSON.parse(el.querySelector('script[data-mascot-click]')?.textContent || '{"type":"none"}')),
      menuOpen: false,
      menuSide: null,
      ink: null,
      gaze: JSON.stringify(clearedGaze(description)),
      gazeSide: null,
      clicks: 0,
      button: null,
      buttonHandlers: null,
      menuEl: null,
      tooltipEl: null,
      tooltipShown: false,
      tooltipHover: false,
      tooltipDismissed: false,
      tooltipTimer: null,
      motion: validateMotion({
        reduced: !has(el.dataset, 'reduced') || el.dataset.reduced === 'auto' ? null : el.dataset.reduced === 'true',
        ...Object.fromEntries(
          motionFlags.map((key) => {
            const name = key === 'mood_change' ? 'moodChange' : key;
            return [
              key,
              !has(el.dataset, name)
                ? el.dataset.others !== 'false'
                : el.dataset[name] === 'true'
                  ? true
                  : el.dataset[name] === 'false'
                    ? false
                    : null,
            ];
          }),
        ),
        messages: has(el.dataset, 'messages')
          ? el.dataset.messages.split(',').filter(Boolean)
          : el.dataset.others === 'false'
            ? []
            : [...panelNames],
      }),
      theme: validateTheme(
        JSON.parse(el.querySelector('script[data-mascot-theme]')?.textContent || JSON.stringify(emptyTheme())),
      ),
      mode: null,
      colours: {},
      palettes: new Map(),
      themeWarnings: new Set(),
      minimised: false,
      hidden: true,
      offscreen: false,
      measures: 0,
      revision: 0,
      fields: new Map(),
      mountSerial: ++mountSerial,
      renderedSize: null,
      resize: null,
      anchor: null,
      binding: null,
      actions,
      minimiseButton,
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
      dragHandlers: null,
      dragState: null,
      dropped: null,
      suppressClick: false,
      snapAnimation: null,
      placementAnimation: null,
      placementCopy: null,
      panelExits: new Set(),
    };
    const previousLedger = ledgers.get(el.id);
    record.ledger = {
      generation: record.mountSerial,
      mount_token: el.dataset.mountToken || '',
      lifecycle: 'ready',
      applied_revision: 0,
      gesture_watermark: previousLedger?.gesture_watermark || 0,
      bubble_watermark: previousLedger?.bubble_watermark || 0,
      dismissed_bubble_revision: previousLedger?.dismissed_bubble_revision || 0,
      bubble: previousLedger?.bubble || null,
      live: true,
      record,
    };
    ledgers.set(el.id, record.ledger);
    // A Shiny baseline is installed only after R resolves ownership. In
    // particular a dismissed UI bubble must not flash during remount.
    if (window.Shiny?.InputBinding) {
      record.bubble = null;
      record.bubbleEl.hidden = true;
    }
    records.set(el, record);
    try {
      layout(record);
      const resolved = resolveTheme(record.theme, description, record.anchor || el, true);
      commitPalette(record, description, resolved);
      // E5b, internal only: mount at the band the canvas measures, so a small mascot never draws a full-band frame.
      // A band over budget mounts at full with one warning. A width not laid out yet (0) mounts at full and leaves
      // record.band undefined, so the first real measure decides.
      let band = null;
      if (bandsApply(description)) {
        const width = cssWidth(canvas);
        band = 'full';
        if (width > 0) {
          const measured = ns.parts.bandFor(width);
          try {
            ns.checkCharacter(description, measured);
            band = measured;
          } catch (error) {
            reportBand(record, measured, error);
          }
        }
      }
      record.controller = ns.mount(canvas, description, {
        x: 150,
        baseY: 270,
        mood: el.dataset.mood,
        colours: record.colours,
        ...record.motion,
        ...(band ? { band } : {}),
        onChange: (snapshot) => show(record, snapshot),
      });
      if (disconnected) {
        el.setAttribute('data-disconnected', '');
        forceConnectionMood(record);
        show(record, record.controller.current());
      }
      if (band && cssWidth(canvas) > 0) record.band = band;
      listenBubble(record);
      listenDrag(record);
      replaceClick(record, record.click);
      syncMotion(record);
      record.handlers.clickPlacement = (event) => {
        if (!record.actions.hidden && event.target.closest('.mascot-minimise') === record.minimiseButton)
          minimise(record, true);
        if (event.target.closest('.mascot-restore') === record.restoreButton) minimise(record, false);
      };
      el.addEventListener('click', record.handlers.clickPlacement);
      watch(record);
      measure(record);
      refreshGaze(record);
    } catch (error) {
      unwatch(record);
      unlistenDrag(record);
      removeClick(record);
      if (record.handlers) {
        for (const [name, handler] of Object.entries(record.handlers))
          el.removeEventListener(name === 'clickPlacement' ? 'click' : name, handler);
      }
      record.controller?.destroy();
      portal(record, false, true);
      record.actions.remove();
      record.restoreButton.remove();
      records.delete(el);
      record.ledger.live = false;
      record.ledger.record = null;
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
      for (const { patch: next } of waiting.patches) {
        try {
          const prepared = prepare(next, current, descriptions);
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
      if (Object.keys(good).length) apply(el, good, true);
      record.revision = waiting.revision || 0;
      for (const key of Object.keys(patch)) record.fields.set(key, record.revision);
      if (problem !== undefined) apply(el, { problem });
      if (waiting.gestureRevision && has(good, 'gesture')) playedGestures.set(el.id, waiting.gestureRevision);
    }
  }

  function apply(el, patch, allowThemeDrop = false) {
    const record = records.get(el);
    let prepared;
    try {
      prepared = prepare(
        patch,
        record.descriptions.get(record.character),
        record.descriptions,
        record.theme,
        record.anchor || el,
        !allowThemeDrop,
        record.motion,
      );
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
      return true;
    }

    const enginePatch = { ...prepared.enginePatch };
    if (prepared.click && record.menuOpen)
      enginePatch.pose = clearedGaze(prepared.description || record.descriptions.get(record.character));
    try {
      if (!has(patch, 'mood') && record.problem && !prepared.changed) enginePatch.mood = record.problemMood;
      // A format-v1 swap without a mood follows the contract's fallback chain; the legacy player starts at the first mood.
      if (
        prepared.changed &&
        !has(enginePatch, 'mood') &&
        isFormat(prepared.description) &&
        isFormat(record.descriptions.get(record.character))
      )
        enginePatch.mood = ns.runtime.swapMood(
          record.descriptions.get(record.character),
          record.problem ? record.problemMood : record.mood,
          prepared.description,
        );
      // Synchronous engine notifications must not expose a partially committed host patch.
      updating.add(record);
      // Establish initial queued state before its gesture, without a mood transition or swap.
      const initial = allowThemeDrop && (prepared.changed || has(enginePatch, 'mood'));
      if (initial) Object.assign(enginePatch, { reduced: true, swap: false });
      if (Object.keys(enginePatch).length) record.controller.update(enginePatch);
      if (initial) record.controller.update(prepared.motion || record.motion);
    } catch (error) {
      warn(error);
      return;
    } finally {
      updating.delete(record);
    }
    if (enginePatch.pose) record.gaze = JSON.stringify(enginePatch.pose);

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
    if (prepared.click) replaceClick(record, prepared.click, false);
    if (prepared.motion) {
      record.motion = prepared.motion;
      syncMotion(record);
    }
    if (prepared.theme) {
      record.theme = prepared.theme;
      record.themeWarnings.clear();
    }
    if (prepared.resolved) commitPalette(record, record.descriptions.get(record.character), prepared.resolved);
    watchModes();
    el.dataset.character = record.character;
    el.dataset.mood = record.mood;
    el.dataset.status = status.mode;
    known.set(el.id, record.descriptions.get(record.character));
    show(record, record.controller.current());
    if (prepared.size) record.size = prepared.size;
    if (prepared.placement) {
      cancelDrag(record);
      record.dropped = null;
      record.placement = prepared.placement;
    }
    if (record.minimised && (!record.placement.floating || !record.placement.minimise)) {
      const focused = record.el.contains(document.activeElement);
      minimise(record, false, false);
      if (focused) focusTarget(record).focus();
    }
    if (prepared.size || prepared.placement) {
      layout(record);
      measure(record);
      watchNotifications();
      watchModes();
      refreshTheme(record);
    }
    if (has(patch, 'bubble')) replaceBubble(record, prepared.bubble);
    refreshGaze(record);
    syncMotion(record);
    if (has(patch, 'gesture')) {
      if (!record.motion.gestures) {
        if (window.Shiny?.inDevMode?.()) {
          const message = `Gesture '${patch.gesture}' skipped: gestures are switched off in mascot_motion_settings()`;
          window.dispatchEvent(
            new CustomEvent('shiny:client-message', {
              detail: { headline: 'mascot', message, status: 'warning' },
            }),
          );
        }
      } else record.controller.gesture(patch.gesture);
    }
    if (disconnected) {
      forceConnectionMood(record);
      show(record, record.controller.current());
    }
    return true;
  }

  // Use the same pure preflight for mounted and queued patches; never merge a partial bad patch.
  function prepare(
    patch,
    current,
    descriptions = new Map(current ? [[current.id, current]] : []),
    theme = emptyTheme(),
    source = null,
    strictTheme = true,
    motion = defaultMotion(),
  ) {
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) throw new Error('update needs an object');
    for (const key of Object.keys(patch)) {
      if (
        ![
          'character',
          'mood',
          'status',
          'bubble',
          'gesture',
          'size',
          'placement',
          'theme',
          'motion',
          'click',
          'problem',
        ].includes(key)
      )
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
      const supplied = typeof ch.json === 'string' ? JSON.parse(ch.json) : null;
      const cached = descriptions.get(ch.id);
      if (cached && supplied && !sameValue(cached, supplied))
        throw new Error('same character id has different content');
      description = cached || supplied;
      if (!description) throw new Error('character content cache miss');
      if (!description || description.id !== ch.id) throw new Error('character id does not match its description');
      engineValidate(description, {});
      enginePatch.character = description;
      changed = ch.id !== current?.id;
    }
    const candidate = description || current;
    if (has(patch, 'mood')) {
      if (typeof patch.mood !== 'string' || !patch.mood.length) throw new Error('mood needs a non-empty name');
      if (candidate) engineValidate(candidate, { mood: patch.mood });
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
    const click = has(patch, 'click') ? validateClick(patch.click) : undefined;
    const bubble = has(patch, 'bubble') ? validateBubble(patch.bubble) : undefined;
    if (has(patch, 'gesture')) validateGesture(candidate, patch.gesture);
    const size = has(patch, 'size') ? validateSize(patch.size) : undefined;
    const placement = has(patch, 'placement') ? validatePlacement(patch.placement) : undefined;
    const nextMotion = has(patch, 'motion') ? validateMotion(patch.motion) : undefined;
    if (nextMotion || changed) Object.assign(enginePatch, nextMotion || motion);
    const nextTheme = has(patch, 'theme') ? validateTheme(patch.theme) : undefined;
    const resolved =
      nextTheme || changed
        ? resolveTheme(nextTheme || theme, candidate, source, Boolean(nextTheme) && strictTheme)
        : undefined;
    if (resolved && candidate) enginePatch.colours = resolved.overrides;
    return {
      description,
      changed,
      enginePatch,
      status,
      bubble,
      click,
      size,
      placement,
      theme: nextTheme,
      motion: nextMotion,
      resolved,
    };
  }

  function mergeQueued(next, patch) {
    if (!has(patch, 'problem')) delete next.problem;
    if (has(patch, 'character')) {
      next.character = patch.character;
      delete next.mood;
    }
    for (const key of [
      'mood',
      'status',
      'bubble',
      'size',
      'placement',
      'theme',
      'motion',
      'click',
      'gesture',
      'problem',
    ]) {
      if (has(patch, key)) next[key] = patch[key];
    }
  }

  function queue(id, patch, revision) {
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
    const patches = [...(waiting?.patches || []), { patch }];
    // Bound the queue for an id that never appears (removed or mistyped). Past the limit keep the newest patches and
    // report revision 0 on mount, so the server re-sends its complete retained state.
    const stale = Boolean(waiting?.stale) || patches.length > queueLimit;
    pending.set(id, {
      patches: patches.slice(-queueLimit),
      stale,
      revision: stale ? 0 : revision || waiting?.revision || 0,
      gestureRevision: waiting?.gestureRevision || 0,
      description: prepared.description || current,
    });
    suggestNamespace(id);
    return true;
  }

  // Development mode only: a missing ns() in a module UI sends updates to "helper" while the page has "first-helper".
  // Late mascots are normal (renderUI after a login), so warn only when such a namespaced id is on the page.
  function suggestNamespace(id) {
    if (warnedIds.has(id) || !window.Shiny?.inDevMode?.()) return;
    setTimeout(() => {
      if (!pending.has(id) || warnedIds.has(id)) return;
      const ids = [...live].map((record) => record.el.id);
      // A module UI without ns(): the server updates "first-helper" while the page has "helper".
      const bare = ids.find((other) => id.endsWith(`-${other}`));
      // An update from outside the module: the server updates "helper" while the page has "first-helper".
      const namespaced = ids.find((other) => other.endsWith(`-${id}`));
      if (!bare && !namespaced) return;
      warnedIds.add(id);
      const message = bare
        ? `no mascot "${id}" is on the page, but "${bare}" is; in a module UI use mascot(id = ns("${bare}"))`
        : `no mascot "${id}" is on the page, but "${namespaced}" is; update it from inside its module, ` +
          `where update_mascot("${id}") adds the namespace`;
      warn(message);
      window.dispatchEvent(
        new CustomEvent('shiny:client-message', { detail: { headline: 'mascot', message, status: 'warning' } }),
      );
    }, namespaceDelay);
  }

  function receive(message) {
    if (!message || typeof message !== 'object' || typeof message.id !== 'string') {
      warn('update envelope needs an id');
      return;
    }
    if (has(message, 'version')) return receiveState(message);
    // The compatibility patch route belongs to custom hosts. Typed Shiny
    // bindings accept versioned state/diagnostic envelopes only.
    if (window.Shiny?.InputBinding) return;
    const targets = [...document.querySelectorAll('.mascot')].filter((el) => el.id === message.id && records.has(el));
    if (!message.patch || typeof message.patch !== 'object' || Array.isArray(message.patch)) {
      if (!targets.length) queue(message.id, message.patch, message.revision);
      else for (const el of targets) apply(el, message.patch);
      return;
    }
    const patch = { ...message.patch };
    // A retained gesture is an event, not state. Replacements must not play it again.
    if (has(patch, 'gesture') && message.gestureRevision) {
      if ((playedGestures.get(message.id) || 0) >= message.gestureRevision) delete patch.gesture;
    }
    const deliver = (next) => {
      if (!targets.length) {
        if (queue(message.id, next, message.revision) && has(next, 'gesture') && message.gestureRevision)
          pending.get(message.id).gestureRevision = message.gestureRevision;
      } else
        for (const el of targets) {
          const record = records.get(el);
          const value = { ...next };
          if (message.replay) {
            for (const key of Object.keys(value)) {
              if ((record.fields.get(key) || 0) >= (message.fields?.[key] || message.revision)) delete value[key];
            }
          }
          if (!Object.keys(value).length) continue;
          const previousProblem = record.problem;
          if (apply(el, value, Boolean(message.replay))) {
            if (message.replay && previousProblem && !has(value, 'problem')) apply(el, { problem: previousProblem });
            if (message.revision) {
              for (const key of Object.keys(value)) record.fields.set(key, message.fields?.[key] || message.revision);
              if (!message.replay && !has(value, 'problem')) record.fields.set('problem', message.revision);
              if (has(value, 'character') && !has(value, 'mood')) record.fields.set('mood', message.revision);
            }
            if (has(value, 'gesture') && message.gestureRevision)
              playedGestures.set(message.id, message.gestureRevision);
          }
        }
    };
    // The retained problem covers the last good state; ordinary patches remain atomic.
    if (message.replay && has(patch, 'problem')) {
      const { problem, ...good } = patch;
      if (Object.keys(good).length) deliver(good);
      deliver({ problem });
    } else deliver(patch);
    for (const el of targets) records.get(el).revision = Math.max(message.revision || 0, records.get(el).revision);
  }

  function unmount(el) {
    const record = records.get(el);
    if (!record) return;
    // Terminal notice is emitted while the binding/ledger still exist, before
    // Shiny tears down the element. The explicit event route is repeatable.
    stopTimer(record);
    record.ledger.bubble = record.bubble ? { ...record.bubble } : null;
    record.ledger.live = false;
    publish(record, 'unmounted');
    record.ledger.record = null;
    removeClick(record);
    unwatch(record);
    unlistenDrag(record);
    for (const [name, handler] of Object.entries(record.handlers))
      el.removeEventListener(name === 'clickPlacement' ? 'click' : name, handler);
    record.actions.remove();
    record.restoreButton.remove();
    record.placementAnimation?.cancel();
    record.placementCopy?.remove();
    record.panelExits.forEach((movement) => {
      movement.effect.target.remove();
      movement.cancel();
    });
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
      motion: { ...record.motion },
      click: JSON.parse(JSON.stringify(record.click)),
      menuOpen: record.menuOpen,
      tooltip: record.tooltipShown,
      gaze: record.gazeSide,
      clicks: record.clicks,
      theme: JSON.parse(JSON.stringify(record.theme)),
      mode: record.mode,
      colours: { ...record.colours },
      minimised: record.minimised,
      dropped: record.dropped ? { ...record.dropped } : null,
      dragging: Boolean(record.dragState?.moved),
      renderedSize: record.renderedSize,
      band: record.band ?? null,
      bubble: record.bubble ? { ...record.bubble, remaining: remaining(record) } : null,
      hidden: record.hidden,
      offscreen: record.offscreen,
      measures: record.measures,
      revision: record.revision,
      snapshot: snapshot(record),
      current: record.controller ? record.controller.current() : null,
    };
  }

  function snapshot(record, lifecycle = record.ledger.lifecycle) {
    const ledger = record.ledger;
    return {
      version: 1,
      generation: ledger.generation,
      mount_token: ledger.mount_token,
      lifecycle,
      applied_revision: ledger.applied_revision,
      gesture_watermark: ledger.gesture_watermark,
      bubble_watermark: ledger.bubble_watermark,
      dismissed_bubble_revision: ledger.dismissed_bubble_revision,
    };
  }

  function publish(record, lifecycle) {
    record.ledger.lifecycle = lifecycle;
    if (record.ledger.mount_token)
      window.Shiny?.setInputValue?.(`${record.el.id}:mascot.state`, snapshot(record), { priority: 'event' });
  }

  function receiveState(message) {
    const ledger = ledgers.get(message.id),
      record = ledger?.record;
    if (
      message.version !== 1 ||
      !record ||
      !ledger.live ||
      message.generation !== ledger.generation ||
      !safeCounter(message.revision)
    )
      return;
    if (message.kind === 'template-needed' || message.kind === 'template-rejected') {
      if (
        message.mount_token !== ledger.mount_token ||
        ledger.applied_revision !== 0 ||
        typeof message.problem !== 'string' ||
        !message.problem.length
      )
        return;
      if (message.kind === 'template-needed' && record.recoverySent) return;
      if (message.kind === 'template-needed') {
        record.recoverySent = true;
        try {
          const script = record.el.querySelector('script[data-mascot-baseline]');
          const baseline = JSON.parse(script.textContent);
          const character = record.el.querySelector(`script[data-mascot-character="${baseline.character.id}"]`);
          baseline.character.json = character.textContent;
          window.Shiny?.setInputValue?.(
            `${record.el.id}:mascot.state`,
            { ...snapshot(record, 'ready'), baseline },
            { priority: 'event' },
          );
          return;
        } catch (error) {
          warn(`cannot recover mascot UI baseline: ${error.message}`);
        }
      }
      apply(record.el, { problem: message.problem });
      warn(message.problem);
      return;
    }
    if (message.kind === 'diagnostic') {
      if (message.revision >= ledger.applied_revision && typeof message.problem === 'string' && message.problem.length)
        apply(record.el, { problem: message.problem });
      return;
    }
    // Unknown additive kinds are optional extensions, not state candidates.
    if (message.kind != null && message.kind !== 'state') return;
    if (message.revision <= ledger.applied_revision) return;
    try {
      if (
        !safeCounter(message.bubble_revision) ||
        !safeCounter(message.gesture_watermark) ||
        message.gesture_watermark > message.revision ||
        typeof message.restore !== 'boolean'
      )
        throw new Error('invalid complete-state counters');
      if (message.problem != null && (typeof message.problem !== 'string' || !message.problem.length))
        throw new Error('invalid development diagnostic');
      const fields = ['character', 'mood', 'status', 'bubble', 'size', 'placement', 'theme', 'motion', 'click'];
      if (
        !message.state ||
        Object.keys(message.state).length !== fields.length ||
        fields.some((key) => !has(message.state, key))
      )
        throw new Error('incomplete state');
      const gesture = message.gesture;
      if (
        gesture !== null &&
        (!gesture ||
          Object.keys(gesture).some((key) => !['name', 'revision'].includes(key)) ||
          !safeCounter(gesture.revision) ||
          gesture.revision === 0 ||
          gesture.revision > message.revision)
      )
        throw new Error('invalid gesture revision');
      const whole = { ...message.state };
      if (gesture) whole.gesture = gesture.name;
      // Pure preflight of the entire state against ONE incoming character.
      const checkedState = prepare(
        whole,
        record.descriptions.get(record.character),
        record.descriptions,
        record.theme,
        record.anchor || record.el,
        true,
        record.motion,
      );
      if (checkedState.description.name !== whole.character.name)
        throw new Error('character display name disagrees with content');
      const patch = {};
      for (const field of fields) {
        const previous = record.completeState?.[field] ?? record[field];
        const unchanged =
          field === 'character'
            ? record.character === message.state.character.id
            : field === 'status'
              ? record.status.mode === message.state.status.mode &&
                (record.status.mode === 'mood' || record.status.text === message.state.status.text)
              : sameValue(message.state[field], previous);
        if (field !== 'bubble' && !unchanged) patch[field] = message.state[field];
      }
      // Keep timer/visibility locally even when an acknowledgement was lost.
      const newBubble = message.bubble_revision > ledger.bubble_watermark;
      if (newBubble) patch.bubble = message.state.bubble;
      else if (ledger.applied_revision === 0) {
        patch.bubble =
          ledger.dismissed_bubble_revision >= message.bubble_revision || !ledger.bubble
            ? { clear: true }
            : {
                text: ledger.bubble.text,
                html: ledger.bubble.html,
                closable: ledger.bubble.closable,
                duration: ledger.bubble.remaining,
              };
      }
      // Consume before scheduling, even if motion/swap policy discards it.
      ledger.gesture_watermark = Math.max(ledger.gesture_watermark, message.gesture_watermark);
      if (gesture && gesture.revision > ledger.gesture_watermark) {
        ledger.gesture_watermark = gesture.revision;
        patch.gesture = gesture.name;
      }
      record.installing = true;
      try {
        if (!apply(record.el, patch, message.restore || ledger.applied_revision === 0))
          throw new Error('complete-state installation failed');
      } finally {
        record.installing = false;
      }
      if (message.problem) apply(record.el, { problem: message.problem });
      record.completeState = message.state;
      ledger.applied_revision = message.revision;
      record.revision = message.revision;
      ledger.bubble_watermark = Math.max(ledger.bubble_watermark, message.bubble_revision);
      ledger.bubble = record.bubble ? { ...record.bubble, remaining: remaining(record) } : null;
      publish(record, 'mounted');
    } catch (error) {
      warn(`complete-state invariant failure: ${error.message}`);
      publish(record, 'error');
    }
  }

  ns.host = {
    mount,
    unmount,
    receive,
    state,
    reconcile: (el) => {
      const record = records.get(el);
      if (record) publish(record, 'reconcile');
    },
  };
  if (window.Shiny?.InputBinding) {
    class MascotBinding extends window.Shiny.InputBinding {
      find(scope) {
        return window.jQuery(scope).find('.mascot, .mascot-source');
      }
      getType() {
        return 'mascot.state';
      }
      getId(el) {
        const record = sources.get(el) || records.get(el),
          id = record?.el.id || el.id;
        const authoritative = ledgers.get(id);
        if (authoritative?.live && record !== authoritative.record) {
          warn(`duplicate live mascot id "${id}"; the first binding remains authoritative`);
          return null;
        }
        return id || null;
      }
      getValue(el) {
        // Shiny bindInputs reads the initial value before subscribe.
        if (!sources.has(el)) mount(el);
        const record = sources.get(el) || records.get(el);
        return record ? snapshot(record) : null;
      }
      subscribe(el) {
        if (!mount(el)) return;
        const record = records.get(el);
        record.binding = this;
        syncBinding(record);
        publish(record, 'ready');
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
