/**
 * Page host for mascot: one record and controller per element, with an idempotent lifecycle.
 * A Shiny input binding mounts for its initial value/subscribe and destroys on unsubscribe; static pages mount at DOM ready.
 * Custom messages carry { id, patch }; late state merges by id, including the latest one-off gesture.
 * At most 20 patches wait per id; beyond that the newest are kept and the server re-sends its retained state on mount.
 * In Shiny development mode, updates waiting 2 s for "x" while "<namespace>-x" is mounted, or for "<namespace>-x" while
 * "x" is mounted, warn once with the likely namespace fix.
 * Patches are atomic: prepare descriptions/status, ask the engine to validate, then commit host state.
 * Desired character/mood live in data-character/data-mood; data-shown-* and status follow the shown frame.
 * Custom status persists across swaps. Development problems temporarily cover it and use a worried mood;
 * the next good patch clears the problem and restores the earlier mood unless it chooses another.
 * The host owns canvas dimensions (CSS size times pixel ratio), the 300-unit transform and accessible text.
 * Size patches are { size: pixels|percentage, small_screen: pixels|percentage|null }; every size draws in full.
 * Placement patches are { floating: boolean, position: corner, minimise: boolean }; neither patch remounts the engine.
 * Theme patches are { light, dark, mode, css, brand }; empty maps are null, mode null selects the host default
 * (auto follows the page; no signal means light). Maps use description role names. Brand retains primary/secondary
 * colours for the incoming character's brand leaders. A theme replaces overrides, and survives character swaps.
 * Auto follows source data-bs-theme, then Quarto's body class; CSS reads the original source context.
 * Missing/invalid CSS uses the character colour and warns; contrast below 3:1 warns without changing the colour.
 * One theme observer exists while auto is used; the shared scheme listener serves auto and floating bubbles.
 * CSS chooses the narrow-screen size. One ResizeObserver per element refreshes its backing canvas;
 * zero sizes retain the last usable drawing. Shared viewport/density and notification observers are reference-counted.
 * Floating elements move to body; a source marker preserves tab visibility, inherited text/theme and Shiny teardown.
 * Inline bubbles are clamped to viewport edges without changing their reserved height.
 * Floating bubbles point towards the page centre. Native buttons minimise/restore; messages pause while minimised.
 * Motion patches are { reduced: null|true, swap: boolean }; null follows the visitor, true stops motion.
 * data-reduced="auto"|"true" and data-swap="true"|"false" carry the same settings on static pages.
 * Motion changes update the live controller; swaps reapply retained settings alongside the theme.
 * CSS suppresses bubble and restore-control movement too. No per-element global listeners are added by this host.
 * Popup menu patches are { items: {id: label}|null }; replacement closes the menu.
 * Menus are Shiny-only. An active menu wraps the canvas in a native button; otherwise it stays an image.
 * Choices set the already namespaced id + '_menu' with priority 'event'. Labels always use textContent.
 * Enter/Space operate the focused toggle; navigation stays within the focused menu. No global keyboard listeners.
 * A shared outside-pointer listener exists only while a menu is open; teardown removes it when unused.
 * Open menus hold lookY=-1 and pause bubble timers; closing clears only lookY, preserving the mood.
 * Menus prefer above the canvas (below top corners), fitting/flipping to actual viewport space on resize/scroll.
 * Action controls use a separate strip: hover/focus reveals it, touch keeps it available, open menus hide it.
 * Restore stays reachable while minimised. Placement focus falls back to the visible menu toggle or image.
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
  const playedGestures = new Map();
  const queueLimit = 20;
  const warnedIds = new Set();
  const namespaceDelay = 2000;
  let mountSerial = 0;
  const known = new Map();
  const updating = new WeakSet();
  const live = new Set();
  const sources = new WeakMap();
  const corners = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  let densityMedia = null;
  const openMenus = new Set();
  let schemeMedia = null;
  let modeMutation = null;
  const colourContext = document.createElement('canvas').getContext('2d');
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
    const accessibleLabel = `${record.names.get(snapshot.character)}, ${snapshot.mood}`;
    record.canvas.setAttribute('aria-label', accessibleLabel);
    record.menuButton?.setAttribute('aria-label', `${accessibleLabel}, menu`);
    if (record.restoreButton) {
      record.restoreButton.setAttribute(
        'aria-label',
        `Restore ${record.names.get(snapshot.character)}, ${snapshot.mood}`,
      );
      const colours = record.palettes.get(snapshot.character) || record.descriptions.get(snapshot.character).colours;
      const fallback = Object.values(colours)[0];
      setProperty(record.el, '--mascot-button-bg', colours.body || fallback);
      setProperty(record.el, '--mascot-button-fg', colours.outline || fallback);
      setProperty(record.el, '--mascot-button-glow', colours.rim || colours.body || fallback);
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
    // The engine owns the vocabulary. Its pure pose path validates without changing a controller.
    if (description) ns.motion.pose(description, { gesture: name, reduced: true }, 0);
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
          style.getPropertyValue('--bs-body-bg').trim() || style.getPropertyValue('--mascot-bubble-bg').trim(),
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
    const auto = [...live].some((record) => themeMode(record.theme) === 'auto');
    if (auto && !modeMutation) {
      modeMutation = new MutationObserver(refreshPage);
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
    if (next.small_screen !== null) validateSizeValue(next.small_screen);
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

  function focusTarget(record) {
    if (record.minimised) return record.restoreButton;
    return record.menuButton || record.canvas;
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
    el.style.setProperty('--mascot-size-default', sizeCSS(size.size, placement.floating));
    el.style.setProperty('--mascot-size-small', sizeCSS(size.small_screen ?? size.size, placement.floating));
    record.minimiseButton.hidden = !placement.floating || !placement.minimise || record.minimised;
    record.restoreButton.hidden = !record.minimised;
    record.canvas.hidden = record.minimised;
    if (record.menuButton) record.menuButton.hidden = record.minimised;
    record.bubbleEl.parentElement.hidden = record.minimised;
    el.dataset.minimised = String(record.minimised);
    refreshActions(record);
    if (focusedControl?.hidden) {
      focusTarget(record).focus();
    }
  }

  function minimise(record, value, focus = true) {
    if (value === record.minimised) return;
    if (value && (!record.placement.floating || !record.placement.minimise)) return;
    if (value) closeMenu(record);
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

  function measureMenu(record) {
    if (!record.menuEl || !record.menuOpen) return;
    const menu = record.menuEl;
    const margin = 16;
    const notification =
      record.placement.floating && record.placement.position === 'bottom-right'
        ? parseFloat(record.el.style.getPropertyValue('--mascot-notification-offset')) || 0
        : 0;
    const height = document.documentElement.clientHeight - notification;
    const canvas = record.canvas.getBoundingClientRect();
    const anchorBottom = record.placement.floating ? record.el.getBoundingClientRect().bottom : canvas.bottom;
    const style = getComputedStyle(menu);
    const wanted = Math.min(
      menu.scrollHeight + parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth),
      18 * parseFloat(style.fontSize),
    );
    const above = Math.max(0, Math.min(height - 2 * margin, canvas.top - margin));
    const below = Math.max(0, Math.min(height - 2 * margin, height - margin - anchorBottom));
    let downward = record.placement.floating && record.placement.position.startsWith('top');
    const preferred = downward ? below : above;
    const alternative = downward ? above : below;
    if (wanted > preferred && alternative > preferred) downward = !downward;
    // Even a canvas taller than the viewport must not make the menu unreachable.
    const available = Math.max(24, downward ? below : above);
    setProperty(record.el, '--mascot-menu-max-height', `${available}px`);
    const rect = menu.getBoundingClientRect();
    const top = Math.max(
      margin,
      Math.min(downward ? anchorBottom : canvas.top - rect.height, height - margin - rect.height),
    );
    setProperty(record.el, '--mascot-menu-top', `${top - record.el.getBoundingClientRect().top}px`);
    const shift = parseFloat(record.el.style.getPropertyValue('--mascot-menu-shift')) || 0;
    const natural = rect.left - shift;
    const bounds = record.placement.floating ? clipBounds(document.body) : clipBounds(record.el);
    const left = Math.max(bounds.left, Math.min(natural, bounds.right - rect.width));
    setProperty(record.el, '--mascot-menu-shift', `${left - natural}px`);
  }

  // Horizontal room for an inline overlay: the viewport, narrowed by any ancestor that clips overflow (a bslib card).
  function clipBounds(el) {
    const viewport = 16,
      inset = 8;
    let left = viewport,
      right = document.documentElement.clientWidth - viewport;
    for (let node = el.parentElement; node && node !== document.body; node = node.parentElement) {
      if (getComputedStyle(node).overflowX === 'visible') continue;
      const rect = node.getBoundingClientRect();
      left = Math.max(left, rect.left + node.clientLeft + inset);
      right = Math.min(right, rect.left + node.clientLeft + node.clientWidth - inset);
    }
    return { left, right: Math.max(left, right) };
  }

  function measure(record) {
    const size = record.canvas.getBoundingClientRect().width;
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
      const shift = parseFloat(record.el.style.getPropertyValue('--mascot-bubble-shift')) || 0;
      const natural = rect.left - shift;
      const bounds = clipBounds(record.el);
      const left = Math.max(bounds.left, Math.min(natural, bounds.right - rect.width));
      setProperty(record.el, '--mascot-bubble-shift', `${left - natural}px`);
    }
    measureMenu(record);
    record.renderedSize = size;
    if (resized) record.controller.redraw();
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
        if (record.el.style.getPropertyValue('--mascot-notification-offset') !== value)
          record.el.style.setProperty('--mascot-notification-offset', value);
        measureMenu(record);
      }
    }
  }

  function refreshPage() {
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
      densityChanged();
    }
    watchNotifications();
    watchModes();
  }

  function unwatch(record) {
    record.resize?.disconnect();
    const registered = live.delete(record);
    if (registered && !live.size) {
      window.removeEventListener('resize', refreshViewport);
      densityMedia?.removeEventListener('change', densityChanged);
      densityMedia = null;
    }
    watchNotifications();
    watchModes();
  }

  function validateMenu(value) {
    if (
      !value ||
      typeof value !== 'object' ||
      Array.isArray(value) ||
      Object.keys(value).length !== 1 ||
      !has(value, 'items')
    )
      throw new Error('popup_menu needs only an items field');
    if (
      value.items !== null &&
      (!value.items ||
        typeof value.items !== 'object' ||
        Array.isArray(value.items) ||
        !Object.keys(value.items).length ||
        Object.entries(value.items).some(
          ([id, text]) => !id.length || /\s/.test(id) || typeof text !== 'string' || !text.length,
        ))
    )
      throw new Error('popup_menu items need non-empty ids without whitespace and plain-text labels');
    return { items: value.items === null ? null : { ...value.items } };
  }

  function measureOpenMenus() {
    for (const record of openMenus) measureMenu(record);
  }

  function outsideMenu(event) {
    for (const record of [...openMenus])
      if (!record.menuEl.contains(event.target) && !record.menuButton.contains(event.target)) closeMenu(record);
  }

  function closeMenu(record, focus = false, clearPose = true) {
    if (!record.menuOpen) return;
    record.menuOpen = false;
    record.menuEl.hidden = true;
    record.menuButton.setAttribute('aria-expanded', 'false');
    openMenus.delete(record);
    if (!openMenus.size) {
      document.removeEventListener('pointerdown', outsideMenu, true);
      window.removeEventListener('scroll', measureOpenMenus, true);
    }
    refreshActions(record);
    if (clearPose) record.controller.update({ pose: { lookY: null } });
    if (focus) record.menuButton.focus();
    resumeTimer(record);
  }

  function openMenu(record, keyboard) {
    if (record.minimised || !record.menuEl) return;
    for (const other of [...openMenus]) if (other !== record) closeMenu(other);
    record.controller.update({ pose: { lookY: -1 } });
    record.menuOpen = true;
    const actionFocused = record.actions.contains(document.activeElement);
    refreshActions(record);
    record.menuEl.hidden = false;
    measureMenu(record);
    record.menuButton.setAttribute('aria-expanded', 'true');
    stopTimer(record);
    if (!openMenus.size) {
      document.addEventListener('pointerdown', outsideMenu, true);
      window.addEventListener('scroll', measureOpenMenus, true);
    }
    openMenus.add(record);
    if (keyboard) record.menuEl.querySelector('button').focus();
    else if (actionFocused) record.menuButton.focus();
  }

  function removeMenu(record, clearPose = true) {
    closeMenu(record, false, clearPose);
    if (!record.menuButton) return;
    const focused = record.menuButton === document.activeElement || record.menuEl.contains(document.activeElement);
    if (focused) record.el.focus();
    for (const [name, handler] of Object.entries(record.menuHandlers)) record.el.removeEventListener(name, handler);
    record.menuButton.replaceWith(record.canvas);
    record.canvas.removeAttribute('aria-hidden');
    record.canvas.setAttribute('tabindex', '0');
    record.menuEl.remove();
    record.menuButton = record.menuEl = record.menuHandlers = null;
    if (focused) focusTarget(record).focus();
  }

  function replaceMenu(record, value, clearPose = true) {
    const focused = record.menuButton === document.activeElement || record.menuEl?.contains(document.activeElement);
    removeMenu(record, clearPose);
    record.menu = value;
    if (!value.items || !window.Shiny?.setInputValue) return;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'mascot-menu-toggle';
    button.hidden = record.minimised;
    button.setAttribute('aria-haspopup', 'menu');
    button.setAttribute('aria-expanded', 'false');
    button.setAttribute('aria-controls', `${record.el.id}_popup_menu`);
    const menu = document.createElement('div');
    menu.id = `${record.el.id}_popup_menu`;
    menu.className = 'mascot-menu';
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
    record.canvas.before(button);
    button.append(record.canvas);
    record.canvas.setAttribute('aria-hidden', 'true');
    record.canvas.setAttribute('tabindex', '-1');
    record.el.append(menu);
    record.menuButton = button;
    record.menuEl = menu;
    record.menuHandlers = {
      click(event) {
        if (button.contains(event.target)) {
          if (record.menuOpen) closeMenu(record);
          else openMenu(record, false);
        } else {
          const item = event.target.closest('[role="menuitem"]');
          if (!item || !menu.contains(item)) return;
          const id = item.dataset.itemId;
          closeMenu(record, true);
          window.Shiny.setInputValue(`${record.el.id}_menu`, id, { priority: 'event' });
        }
      },
      keydown(event) {
        if (event.target === button && ['Enter', ' '].includes(event.key)) {
          event.preventDefault();
          if (record.menuOpen) closeMenu(record, true);
          else openMenu(record, true);
          return;
        }
        if (!record.menuOpen) return;
        if (event.key === 'Escape') {
          event.preventDefault();
          event.stopPropagation();
          closeMenu(record, true);
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
      focusout(event) {
        if (!record.el.contains(event.relatedTarget)) closeMenu(record);
      },
    };
    for (const [name, handler] of Object.entries(record.menuHandlers)) record.el.addEventListener(name, handler);
    show(record, record.controller.current());
    if (focused && !record.minimised) button.focus();
  }

  function validateMotion(value) {
    if (
      !value ||
      typeof value !== 'object' ||
      Array.isArray(value) ||
      Object.keys(value).length !== 2 ||
      !has(value, 'reduced') ||
      !has(value, 'swap') ||
      (value.reduced !== null && value.reduced !== true) ||
      typeof value.swap !== 'boolean'
    )
      throw new Error('motion needs reduced null or true and swap true or false');
    return { reduced: value.reduced, swap: value.swap };
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
      menu: validateMenu(
        JSON.parse(el.querySelector('script[data-mascot-popup-menu]')?.textContent || '{"items":null}'),
      ),
      menuOpen: false,
      menuButton: null,
      menuEl: null,
      menuHandlers: null,
      motion: validateMotion({
        reduced: !has(el.dataset, 'reduced') || el.dataset.reduced === 'auto' ? null : el.dataset.reduced === 'true',
        swap:
          !has(el.dataset, 'swap') || el.dataset.swap === 'true' ? true : el.dataset.swap === 'false' ? false : null,
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
    };
    records.set(el, record);
    try {
      layout(record);
      const resolved = resolveTheme(record.theme, description, record.anchor || el, true);
      commitPalette(record, description, resolved);
      record.controller = ns.mount(canvas, description, {
        x: 150,
        baseY: 270,
        mood: el.dataset.mood,
        colours: record.colours,
        ...record.motion,
        onChange: (snapshot) => show(record, snapshot),
      });
      listenBubble(record);
      replaceMenu(record, record.menu);
      record.handlers.clickPlacement = (event) => {
        if (!record.actions.hidden && event.target.closest('.mascot-minimise') === record.minimiseButton)
          minimise(record, true);
        if (event.target.closest('.mascot-restore') === record.restoreButton) minimise(record, false);
      };
      el.addEventListener('click', record.handlers.clickPlacement);
      watch(record);
      measure(record);
    } catch (error) {
      unwatch(record);
      removeMenu(record);
      if (record.handlers) {
        for (const [name, handler] of Object.entries(record.handlers))
          el.removeEventListener(name === 'clickPlacement' ? 'click' : name, handler);
      }
      record.controller?.destroy();
      portal(record, false, true);
      record.actions.remove();
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
    if (prepared.menu && record.menuOpen) enginePatch.pose = { lookY: null };
    try {
      if (!has(patch, 'mood') && record.problem && !prepared.changed) enginePatch.mood = record.problemMood;
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
    if (prepared.menu) replaceMenu(record, prepared.menu, false);
    if (prepared.motion) {
      record.motion = prepared.motion;
      el.dataset.reduced = record.motion.reduced === true ? 'true' : 'auto';
      el.dataset.swap = String(record.motion.swap);
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
    if (prepared.placement) record.placement = prepared.placement;
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
    if (has(patch, 'gesture')) record.controller.gesture(patch.gesture);
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
    motion = { reduced: null, swap: true },
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
          'popup_menu',
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
    const menu = has(patch, 'popup_menu') ? validateMenu(patch.popup_menu) : undefined;
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
      menu,
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
      'popup_menu',
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
          `where updateMascot("${id}") adds the namespace`;
      warn(message);
      window.dispatchEvent(
        new CustomEvent('shiny:client-message', { detail: { headline: 'mascot', message, status: 'warning' } }),
      );
    }, namespaceDelay);
  }

  function receive(message) {
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
    removeMenu(record);
    stopTimer(record);
    unwatch(record);
    for (const [name, handler] of Object.entries(record.handlers))
      el.removeEventListener(name === 'clickPlacement' ? 'click' : name, handler);
    record.actions.remove();
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
      motion: { ...record.motion },
      popup_menu: JSON.parse(JSON.stringify(record.menu)),
      menuOpen: record.menuOpen,
      theme: JSON.parse(JSON.stringify(record.theme)),
      mode: record.mode,
      colours: { ...record.colours },
      minimised: record.minimised,
      renderedSize: record.renderedSize,
      bubble: record.bubble ? { ...record.bubble, remaining: remaining(record) } : null,
      hidden: record.hidden,
      revision: record.revision,
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
      getValue(el) {
        // Shiny bindInputs reads the initial value before subscribe.
        if (!sources.has(el)) mount(el);
        const record = sources.get(el) || records.get(el);
        return record ? { mount: record.mountSerial, revision: record.revision } : null;
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
