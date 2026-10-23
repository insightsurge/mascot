// Offline studio UI. The isolated host shares its parent's Shiny session, never its viewport.
(() => {
  if (window.frameElement?.id === 'live_frame' || document.documentElement.dataset.studioHost === 'true') {
    document.documentElement.dataset.studioHost = 'true';
    window.Shiny = {
      setInputValue: (name, value, options) => window.parent.Shiny.setInputValue(name, value, options),
    };
    document.addEventListener('DOMContentLoaded', () => {
      // Studio-only overlay: reuse the actual displayed frame, including gestures and swaps.
      // The public R listing supplies labels; the engine supplies transformed coordinates.
      const layer = document.createElement('div');
      layer.className = 'pg-anchor-overlay';
      // Only each label's rect is a keyboard stop. Never focus the viewport-sized layer.
      layer.hidden = true;
      layer.setAttribute('aria-label', 'Character anchors');
      document.body.append(layer);
      let listing = { character: '', anchors: [] };
      let enabled = false;
      let latest = null;
      const svgNS = 'http://www.w3.org/2000/svg';
      const svg = document.createElementNS(svgNS, 'svg');
      svg.setAttribute('focusable', 'false');
      svg.setAttribute('aria-label', 'Move anchor labels with arrow keys; Home or Escape resets a label');
      layer.append(svg);
      const pins = new Map();
      let anchorOffset = { x: 0, y: 0 };
      window.parent.mascot ||= {};
      const parentMascot = window.parent.mascot;
      parentMascot.studioAnchorPositions ||= new Map();
      const positions = parentMascot.studioAnchorPositions;
      const saved = () => {
        if (!positions.has(listing.character)) positions.set(listing.character, new Map());
        return positions.get(listing.character);
      };
      const resetLink = () => {
        window.parent.document.getElementById('reset_anchors').hidden = saved().size === 0;
      };
      const clamp = (value, limit) => Math.max(4, Math.min(value, Math.max(4, limit - 4)));
      function movePin(pin, x, y) {
        saved().set(pin.name, { x: clamp(x, innerWidth - pin.width), y: clamp(y, innerHeight - 16) });
        resetLink();
        paintAnchors();
      }
      function wirePin(pin) {
        let drag = null;
        pin.group.addEventListener('pointerdown', (event) => {
          if (event.button !== 0) return;
          event.preventDefault();
          pin.box.blur();
          drag = { x: event.clientX, y: event.clientY, left: pin.left, top: pin.top };
          pin.group.setPointerCapture(event.pointerId);
        });
        pin.group.addEventListener('pointermove', (event) => {
          if (drag) movePin(pin, drag.left + event.clientX - drag.x, drag.top + event.clientY - drag.y);
        });
        const finish = () => {
          drag = null;
        };
        pin.group.addEventListener('pointerup', finish);
        pin.group.addEventListener('pointercancel', finish);
        pin.group.addEventListener('lostpointercapture', finish);
        pin.group.addEventListener('keydown', (event) => {
          const step = event.shiftKey ? 10 : 2;
          const delta = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] }[
            event.key
          ];
          if (delta) movePin(pin, pin.left + delta[0], pin.top + delta[1]);
          else if (['Escape', 'Home'].includes(event.key)) {
            saved().delete(pin.name);
            resetLink();
            paintAnchors();
          } else return;
          event.preventDefault();
          event.stopPropagation();
        });
      }
      function svgPart(tag, attrs, parent) {
        const part = document.createElementNS(svgNS, tag);
        for (const [name, value] of Object.entries(attrs)) part.setAttribute(name, value);
        parent.append(part);
        return part;
      }
      function paintAnchors() {
        layer.hidden = !enabled || !latest || latest.character !== listing.character || latest.canvas.hidden;
        if (layer.hidden) return;
        const rect = latest.canvas.getBoundingClientRect();
        svg.setAttribute('viewBox', `0 0 ${innerWidth} ${innerHeight}`);
        // Uniform top/bottom lanes cannot collide with one another or the canvas.
        // All measurements use this iframe's viewport, including its SVG viewBox.
        const labelHeight = 16;
        const gap = 6;
        const slots = Math.max(1, Math.floor((innerWidth - 16) / 100));
        const width = Math.min(110, (innerWidth - 16 - (slots - 1) * gap) / slots);
        const active = listing.anchors.filter((label) => latest.anchors[label.name]?.available);
        const topCount = Math.ceil(active.length / 2);
        const topRows = Math.ceil(topCount / slots);
        const bottomRows = Math.ceil((active.length - topCount) / slots);
        const topRoom = topRows * (labelHeight + gap) + 12;
        const bottomRoom = bottomRows * (labelHeight + gap) + 12;
        const host = latest.canvas.closest('#helper');
        const maxSize = Math.max(24, Math.min(innerWidth - 16, innerHeight - topRoom - bottomRoom));
        if (host.style.getPropertyValue('--studio-anchor-size') !== `${maxSize}px`) {
          host.style.setProperty('--studio-anchor-size', `${maxSize}px`);
          requestAnimationFrame(paintAnchors);
          return;
        }
        const desiredX = (innerWidth - rect.width) / 2;
        const desiredY = topRoom + Math.max(0, (innerHeight - topRoom - bottomRoom - rect.height) / 2);
        const nextOffset = { x: anchorOffset.x + desiredX - rect.left, y: anchorOffset.y + desiredY - rect.top };
        if (Math.abs(nextOffset.x - anchorOffset.x) > 0.5 || Math.abs(nextOffset.y - anchorOffset.y) > 0.5) {
          anchorOffset = nextOffset;
          host.style.setProperty('--studio-anchor-shift', `${anchorOffset.x}px ${anchorOffset.y}px`);
          requestAnimationFrame(paintAnchors);
          return;
        }
        active.forEach((label, index) => {
          const anchor = latest.anchors[label.name];
          let pin = pins.get(label.name);
          if (!pin) {
            const group = svgPart(
              'g',
              {
                'data-anchor': label.name,
                'aria-label': `${label.name}: ${label.description || label.name}. Drag or use arrow keys; Home or Escape resets.`,
              },
              svg,
            );
            const line = svgPart('line', { class: 'pg-anchor-leader' }, group);
            const dot = svgPart('circle', { class: 'pg-anchor-dot', r: 2.5 }, group);
            const box = svgPart(
              'rect',
              {
                class: 'pg-anchor-label',
                rx: 3,
                height: labelHeight,
                tabindex: 0,
                role: 'button',
                'aria-label': `${label.name}: drag or use arrow keys; Home or Escape resets.`,
              },
              group,
            );
            const text = svgPart('text', { class: 'pg-anchor-text', 'dominant-baseline': 'middle' }, group);
            svgPart('title', {}, group).textContent = `${label.name}: ${label.description || label.name}`;
            pin = { group, line, dot, box, text, name: label.name };
            pins.set(label.name, pin);
            wirePin(pin);
          }
          const top = index < topCount;
          const i = top ? index : index - topCount;
          const laneCount = top ? topCount : active.length - topCount;
          const columns = Math.min(slots, laneCount);
          const defaultX = (innerWidth - (columns * width + (columns - 1) * gap)) / 2 + (i % slots) * (width + gap);
          const defaultY = top
            ? rect.top - 10 - topRows * (labelHeight + gap) + Math.floor(i / slots) * (labelHeight + gap)
            : rect.bottom + 10 + Math.floor(i / slots) * (labelHeight + gap);
          const position = saved().get(pin.name);
          const x = clamp(position?.x ?? defaultX, innerWidth - width);
          const y = clamp(position?.y ?? defaultY, innerHeight - labelHeight);
          pin.left = x;
          pin.top = y;
          pin.box.setAttribute('x', x);
          pin.box.setAttribute('y', y);
          pin.box.setAttribute('width', width);
          pin.text.setAttribute('x', x + 4);
          pin.text.setAttribute('y', y + labelHeight / 2);
          if (pin.width !== width) {
            pin.text.textContent = pin.name;
            let length = pin.name.length;
            while (pin.text.getComputedTextLength() > width - 8 && length > 0)
              pin.text.textContent = `${pin.name.slice(0, --length)}…`;
            pin.width = width;
          }
          const ax = rect.left + (anchor.matrix[4] / 300) * rect.width;
          const ay = rect.top + (anchor.matrix[5] / 300) * rect.height;
          pin.dot.setAttribute('cx', ax);
          pin.dot.setAttribute('cy', ay);
          pin.line.setAttribute('x1', ax);
          pin.line.setAttribute('y1', ay);
          pin.line.setAttribute('x2', x + width / 2);
          pin.line.setAttribute('y2', y + labelHeight / 2);
        });
        for (const [name, pin] of pins)
          pin.group.style.display = active.some((label) => label.name === name) ? '' : 'none';
      }
      window.addEventListener('studio:reset-anchors', () => {
        saved().clear();
        resetLink();
        paintAnchors();
      });
      window.addEventListener('studio:anchors', (event) => {
        enabled = event.detail.enabled;
        document.documentElement.classList.toggle('pg-show-anchors', enabled);
        if (!enabled) {
          anchorOffset = { x: 0, y: 0 };
          document.getElementById('helper')?.style.removeProperty('--studio-anchor-shift');
          document.getElementById('helper')?.style.removeProperty('--studio-anchor-size');
        }
        if (listing.character !== event.detail.listing.character) {
          anchorOffset = { x: 0, y: 0 };
          document.getElementById('helper')?.style.removeProperty('--studio-anchor-shift');
          svg.replaceChildren();
          pins.clear();
        }
        listing = event.detail.listing;
        resetLink();
        paintAnchors();
      });
      const geometry = window.mascot.geometry;
      window.mascot.geometry = {
        ...geometry,
        draw(ctx, compiled, state, ...args) {
          const result = geometry.draw(ctx, compiled, state, ...args);
          if (compiled.source.id && ctx.canvas.closest('#helper')) {
            latest = { canvas: ctx.canvas, character: compiled.source.id, anchors: state.anchors };
            if (enabled) paintAnchors();
          }
          return result;
        },
      };
      new ResizeObserver(paintAnchors).observe(document.body);
      const helper = document.getElementById('helper');
      if (helper) {
        new MutationObserver(paintAnchors).observe(helper, {
          attributes: true,
          subtree: true,
          attributeFilter: ['style', 'hidden', 'data-minimised'],
        });
      }
      document.addEventListener('scroll', paintAnchors, true);

      // Window load follows every DOM-ready listener, including the engine's mount.
      window.addEventListener('load', () => window.mascot.host.reconcile(document.getElementById('helper')), {
        once: true,
      });
      document.addEventListener('keydown', (event) => {
        if (event.target.closest('input, textarea, select, button, [contenteditable=true]')) return;
        window.parent.document.dispatchEvent(
          new KeyboardEvent('keydown', {
            key: event.key,
            ctrlKey: event.ctrlKey,
            metaKey: event.metaKey,
            altKey: event.altKey,
            shiftKey: event.shiftKey,
            bubbles: true,
          }),
        );
      });
      window.addEventListener('shiny:client-message', (event) => {
        window.parent.dispatchEvent(new CustomEvent('shiny:client-message', { detail: event.detail }));
      });
    });
    return;
  }
  if (!window.Shiny) return;
  const $ = window.jQuery;

  const byId = (id) => document.getElementById(id);
  // Avoid feeding unchanged text replacements back into the shell's MutationObserver.
  const setText = (id, value) => {
    const element = byId(id);
    if (element.textContent !== value) element.textContent = value;
  };
  const send = (name, value) => window.Shiny.setInputValue(name, value, { priority: 'event' });
  let selectedFunction = 'mascot_mood';
  let inspectorView = 'controls';
  let hostMode = 'mascot';
  let inspectorExpanded = false;
  let studioReturn = null;
  let moved = [];
  let chipFunction = 'mascot';
  let chipField = 'id';
  let chipArgument = null;
  let chipInput = '';
  const surfaces = [];
  const openers = new Map();
  const phone = () => window.matchMedia('(max-width: 860px)').matches;
  // The visible viewport and the sentence bar's helpers are shared with the other views (inputs.js).
  const { viewportBounds, positionWordTooltip, sizeSentence } = window.mascotStudioInputs;
  const visible = (element) => element && element.getClientRects().length > 0;
  const focusables = (surface) =>
    [...surface.querySelectorAll('button, input, select, textarea, a[href], [tabindex="0"]')].filter(
      (element) => visible(element) && !element.disabled && !element.closest('[inert]'),
    );

  let anchorListing = { character: '', anchors: [] };
  function liveWindow() {
    return byId('live_frame')?.contentWindow;
  }
  function syncHost() {
    const frame = liveWindow();
    if (!frame?.document.documentElement) return;
    frame.document.documentElement.dataset.bsTheme = document.documentElement.dataset.bsTheme || 'light';
    const accent = getComputedStyle(document.documentElement).getPropertyValue('--studio-accent');
    frame.document.documentElement.style.setProperty('--studio-accent', accent);
    frame.dispatchEvent(
      new frame.CustomEvent('studio:anchors', {
        detail: {
          enabled: !byId('show_anchors')?.disabled && byId('show_anchors')?.getAttribute('aria-pressed') === 'true',
          listing: anchorListing,
        },
      }),
    );
  }
  // The normal complete-state messages and real engine events cross the same-origin frame boundary.
  // A drawn demo in the guide loads the engine into this page, and the engine registers its own
  // 'mascot:update' handler. Keep the studio's router in place and hand it the engine's handler, so
  // a demo's id is updated here and every other id goes to the live frame.
  let engineUpdate = null;
  const registerHandler = window.Shiny.addCustomMessageHandler.bind(window.Shiny);
  window.Shiny.addCustomMessageHandler = (type, handler) => {
    if (type === 'mascot:update') engineUpdate = handler;
    else registerHandler(type, handler);
  };
  registerHandler('mascot:update', (message) => {
    if (engineUpdate && typeof message?.id === 'string' && byId(message.id)) engineUpdate(message);
    else liveWindow()?.mascot?.host.receive(message);
  });
  window.Shiny.addCustomMessageHandler('studio:anchors', (listing) => {
    anchorListing = listing;
    const empty = listing.anchors.length === 0;
    byId('show_anchors').disabled = empty;
    byId('no_anchors').hidden = !empty;
    setText('no_anchors', `${listing.name} has no anchors`);
    syncHost();
  });
  window.Shiny.addCustomMessageHandler('studio:task', (busy) => {
    const button = byId('task_run');
    if (button) button.disabled = busy;
  });

  function closeSelects() {
    for (const select of document.querySelectorAll('select')) {
      select.selectize?.close();
      select.selectize?.blur();
    }
  }
  function focusInput(id) {
    const target = byId(id);
    if (!target) return;
    const slider = target.classList.contains('js-range-slider') && target.parentElement.querySelector('.irs-handle');
    if (slider) {
      slider.tabIndex = 0;
      slider.focus();
    } else if (target.selectize) {
      target.selectize.$control_input[0].focus();
      target.selectize.close();
    } else {
      const control = target.matches('input, select, textarea, button')
        ? target
        : target.querySelector('input:checked, input, select, textarea, button');
      (control || target).focus();
    }
    target.closest('.shiny-input-container, .pg-quick-gestures')?.classList.add('pg-topbar-highlight');
  }
  function restoreEditor() {
    for (const item of moved) {
      for (const portal of item.portals) {
        portal.select.close();
        portal.select.blur();
        portal.select.positionDropdown = portal.position;
        portal.select.settings.dropdownParent = portal.dropdownParent;
        portal.parent.append(portal.select.$dropdown[0]);
        portal.select.$dropdown.removeClass('pg-chip-dropdown');
        portal.select.$dropdown.attr('style', portal.style || '');
        portal.select.$dropdown_content.attr('style', portal.contentStyle || '');
      }
      item.marker.replaceWith(item.element);
    }
    moved = [];
    // DOM-ready initialisation also calls this before Shiny installs setInputValue().
    if (chipArgument !== null) send('chip_argument', '');
    for (const chip of document.querySelectorAll('[data-call-arg]')) chip.setAttribute('aria-expanded', 'false');
  }
  function inspectorButton() {
    return byId(phone() ? 'open_inspector' : `inspector_view_${inspectorView}`);
  }
  function syncInspector() {
    const expanded = !byId('inspector_sidebar').hidden;
    for (const button of document.querySelectorAll('[data-inspector-view]')) {
      button.setAttribute('aria-pressed', String(expanded && button.dataset.inspectorView === inspectorView));
    }
    byId('open_inspector').setAttribute('aria-expanded', String(expanded));
  }
  function close(id, returnFocus = true) {
    const surface = byId(id);
    if (!surface || surface.hidden) return false;
    if (id === 'chip_editor') {
      closePopovers(false);
      restoreEditor();
    }
    if (id === 'inspector_sidebar') closeSelects();
    surface.hidden = true;
    if (id === 'inspector_sidebar') syncInspector();
    const index = surfaces.indexOf(id);
    if (index >= 0) surfaces.splice(index, 1);
    const opener = openers.get(id);
    if (id === 'function_flyout') {
      for (const button of document.querySelectorAll('.pg-rail [aria-expanded]'))
        button.setAttribute('aria-expanded', 'false');
    }
    syncModal();
    if (returnFocus) {
      const replacement =
        id === 'chip_editor'
          ? document.querySelector(`[data-call-arg="${chipArgument}"]`)
          : id === 'inspector_sidebar'
            ? inspectorButton()
            : opener;
      (visible(replacement) ? replacement : inspectorButton())?.focus();
    }
    return true;
  }
  function open(id, opener = document.activeElement) {
    const surface = byId(id);
    if (!surface) return;
    openers.set(id, opener);
    surface.hidden = false;
    if (id === 'inspector_sidebar') syncInspector();
    const index = surfaces.indexOf(id);
    if (index >= 0) surfaces.splice(index, 1);
    surfaces.push(id);
    syncModal();
  }
  function syncModal() {
    const search = !byId('studio_search')?.hidden;
    const inspector = !byId('inspector_sidebar')?.hidden && phone();
    const modal = search ? byId('studio_search') : inspector ? byId('inspector_sidebar') : null;
    for (const id of ['studio_centre', 'function_flyout', 'chip_editor', 'code_drawer']) {
      if (byId(id)) byId(id).inert = !!modal;
    }
    document.querySelector('.pg-rail')?.toggleAttribute('inert', !!modal);
    byId('studio_right_rail')?.toggleAttribute('inert', !!modal);
    if (byId('inspector_sidebar')) {
      byId('inspector_sidebar').inert = search;
      byId('inspector_sidebar').setAttribute('role', inspector ? 'dialog' : 'region');
      if (inspector && !byId('inspector_sidebar').contains(document.activeElement) && !search)
        byId('inspector_sidebar').focus();
      if (inspector) byId('inspector_sidebar').setAttribute('aria-modal', 'true');
      else byId('inspector_sidebar').removeAttribute('aria-modal');
    }
  }
  function syncExpansion() {
    const expanded = inspectorExpanded && inspectorView !== 'controls';
    byId('inspector_sidebar').classList.toggle('is-expanded', expanded);
    for (const button of document.querySelectorAll('[data-expand-inspector]')) {
      const label = expanded ? 'Collapse panel' : 'Expand panel';
      button.setAttribute('aria-expanded', String(expanded));
      button.setAttribute('aria-label', label);
      button.title = label;
    }
  }
  function toggleExpansion() {
    if (inspectorView === 'controls') return;
    inspectorExpanded = !inspectorExpanded;
    syncExpansion();
  }
  function tab(name) {
    inspectorView = name;
    syncExpansion();
    for (const button of document.querySelectorAll('[data-inspector-tab]')) {
      const active = button.dataset.inspectorTab === name;
      button.setAttribute('aria-selected', String(active));
      button.tabIndex = active ? 0 : -1;
      byId(`inspector_${button.dataset.inspectorTab}`).hidden = !active;
    }
    syncInspector();
  }
  function showControls() {
    restoreEditor();
    close('chip_editor', false);
    for (const group of document.querySelectorAll('#studio_inspector [data-function]')) {
      group.hidden = group.dataset.function !== selectedFunction;
    }
    for (const button of document.querySelectorAll('.pg-index-link')) {
      button.setAttribute('aria-current', String(button.dataset.value === selectedFunction));
    }
    if (byId('inspector_title')) byId('inspector_title').textContent = `${selectedFunction}()`;
    if (byId('inspector_controls')) byId('inspector_controls').scrollTop = 0;
  }
  function mode(value) {
    const examples = value === 'examples';
    const wasExamples = hostMode === 'examples';
    if (examples && !wasExamples) {
      studioReturn = {
        mode: hostMode,
        fn: selectedFunction,
        view: inspectorView,
        open: !byId('inspector_sidebar').hidden,
        chip: byId('chip_editor').hidden ? null : chipArgument,
        code: !byId('code_drawer').hidden,
      };
      close('chip_editor', false);
      close('code_drawer', false);
      close('function_flyout', false);
    }
    hostMode = value;
    const shell = byId('studio_shell');
    shell.classList.toggle('is-examples', examples);
    for (const id of ['studio_character_bar', 'studio_dock']) byId(id).hidden = examples;
    byId('back_to_studio').hidden = !examples;
    for (const button of document.querySelectorAll('.pg-rail [data-group]'))
      button.setAttribute('aria-disabled', String(examples));
    // Keep the two-option selector and its mounted Shiny binding intact while browsing examples.
    if (!examples) {
      const select = byId('host_mode');
      if (select?.selectize) select.selectize.setValue(value, true);
      else if (select) select.value = value;
      $(select).trigger('change');
    }
    const canvas = byId('studio_canvas');
    canvas.dataset.mode = value;
    for (const part of canvas.querySelectorAll('[data-canvas]')) part.hidden = part.dataset.canvas !== value;
    positionRightRail();
  }
  function enterExamples() {
    mode('examples');
    if (!['mascot_example', 'mascot_examples'].includes(selectedFunction)) selectedFunction = 'mascot_example';
    showControls();
    // Initial ?view=examples runs before Shiny installs its input API.
    if (window.Shiny.setInputValue) send('select_function', selectedFunction);
    close('inspector_sidebar', false);
    byId('back_to_studio').focus();
  }
  function backToStudio() {
    const saved = studioReturn;
    mode(saved?.mode || 'mascot');
    selectedFunction = saved?.fn || 'mascot_mood';
    showControls();
    send('select_function', selectedFunction);
    tab(saved?.view || 'controls');
    if (saved?.open) open('inspector_sidebar');
    else close('inspector_sidebar', false);
    if (saved?.code) open('code_drawer', byId('open_code'));
    const chip = saved?.chip && document.querySelector(`[data-call-arg="${saved.chip}"]`);
    if (chip) chipOpen(chip);
    else byId('all_functions').focus();
  }
  // Reveal the mounted field through Shiny's own conditional panels and Bootstrap tabs.
  // This reads the panel's condition, so exported argument names stay in the R control map.
  function revealField(field) {
    if (!field) return;
    for (let ancestor = field; ancestor && ancestor.id !== 'studio_inspector'; ancestor = ancestor.parentElement) {
      if (ancestor.matches('.shiny-panel-conditional')) {
        const match = ancestor.dataset.displayIf?.match(/^input[.]([a-zA-Z0-9_]+)\s*==\s*['"]([^'"]+)['"]$/);
        const element = match && byId(match[1]);
        const binding = element && $(element).data('shiny-input-binding');
        if (binding) binding.receiveMessage(element, { value: match[2] });
      }
      if (ancestor.classList.contains('tab-pane') && !ancestor.classList.contains('active')) {
        const trigger = document.querySelector(
          `[data-bs-toggle="tab"][data-bs-target="#${ancestor.id}"], [data-bs-toggle="tab"][href="#${ancestor.id}"], [data-bs-toggle="pill"][href="#${ancestor.id}"], [role="tab"][aria-controls="${ancestor.id}"]`,
        );
        if (trigger) window.bootstrap?.Tab?.getOrCreateInstance(trigger).show();
      }
    }
  }
  let argumentFocusObserver;
  function selectFunction(fn, input = '', arg = '', focusArgument = false) {
    argumentFocusObserver?.disconnect();
    for (const trigger of document.querySelectorAll('.pg-index [aria-describedby]')) {
      window.bootstrap?.Tooltip?.getInstance(trigger)?.hide();
    }
    if (['mascot_example', 'mascot_examples'].includes(fn) && hostMode !== 'examples') mode('examples');
    selectedFunction = fn;
    showControls();
    send('select_function', fn);
    if (fn === 'mascot_preview') mode('preview');
    else if (['mascot_example', 'mascot_examples'].includes(fn)) mode('examples');
    else mode('mascot');
    if (byId('function_flyout').dataset.group !== 'all') close('function_flyout', false);
    open('inspector_sidebar');
    tab('controls');
    if (!input && !arg && ['mascot_character', 'mascot_mood'].includes(fn)) {
      input = fn === 'mascot_character' ? 'character' : 'mood';
      arg = fn === 'mascot_character' ? 'id' : 'name';
    }
    const sharedButton = document.querySelector(`[data-function="${fn}"] [data-focus-input]`);
    if (!input && !arg && sharedButton) {
      input = sharedButton.dataset.focusInput;
      arg = sharedButton.closest('.pg-field').dataset.argument;
    }
    let field = document.querySelector(`[data-function="${fn}"] [data-argument="${arg}"]`);
    revealField(focusArgument ? byId(input) || field : field);
    field?.scrollIntoView({ block: 'nearest' });
    closeSelects();
    byId('inspector_sidebar').focus({ preventScroll: true });
    requestAnimationFrame(() => {
      if (byId('inspector_sidebar').hidden || selectedFunction !== fn) return;
      field?.scrollIntoView({ block: 'nearest' });
      if (focusArgument) {
        // Conditional panels update after Shiny receives their controlling input.
        // Wait for the routed control itself to become visible before focusing it.
        const focusArgumentControl = () => {
          if (byId('inspector_sidebar').hidden || selectedFunction !== fn || inspectorView !== 'controls') {
            argumentFocusObserver?.disconnect();
            return;
          }
          if (!field) {
            field = document.querySelector(`[data-function="${fn}"] [data-argument="${arg}"]`);
            revealField(field);
          }
          const target = byId(input);
          const visibleTarget = target?.selectize
            ? target.selectize.$control[0]
            : target?.classList.contains('js-range-slider')
              ? target.parentElement.querySelector('.irs-handle')
              : target;
          if (field && !visible(field)) return;
          if (target?.closest('.shiny-panel-conditional') && !visible(visibleTarget)) return;
          if (visible(visibleTarget) && !target.closest('[inert]')) focusInput(input);
          else {
            const fallback =
              [...(field?.querySelectorAll('input, select, textarea, button, [tabindex]') || [])].find(
                (element) => visible(element) && !element.disabled && !element.closest('.pg-field-head'),
              ) || field;
            if (!fallback) return;
            if (!fallback.matches('button, input, select, textarea')) fallback.tabIndex = -1;
            fallback.focus({ preventScroll: true });
          }
          field?.scrollIntoView({ block: 'nearest' });
          argumentFocusObserver?.disconnect();
        };
        argumentFocusObserver = new MutationObserver(focusArgumentControl);
        argumentFocusObserver.observe(byId('studio_shell'), {
          subtree: true,
          childList: true,
          attributes: true,
          attributeFilter: ['style', 'class', 'hidden'],
        });
        focusArgumentControl();
      }
    });
  }

  function flyout(group, opener) {
    const panel = byId('function_flyout');
    const same = panel.dataset.group === group && !panel.hidden;
    close('function_flyout', false);
    if (same) return;
    panel.dataset.group = group;
    for (const heading of panel.querySelectorAll('.pg-index h2')) {
      const category = heading.dataset.category;
      const show = group === 'all' || category === group || (group === 'wiring' && category === 'preview');
      heading.hidden = !show;
      let next = heading.nextElementSibling;
      while (next && next.tagName !== 'H2') {
        next.hidden = !show;
        next = next.nextElementSibling;
      }
    }
    open('function_flyout', opener);
    opener?.setAttribute('aria-expanded', 'true');
    focusables(panel)[1]?.focus();
  }

  let searchIndex = 0;
  let results = [];
  let searchOptions;
  function searchResults() {
    const query = byId('function_search').value.trim().toLowerCase();
    const list = byId('search_results');
    for (const heading of list.querySelectorAll('.pg-search-group')) heading.remove();
    searchOptions ||= [...list.querySelectorAll('[role="option"]')];
    const options = searchOptions;
    const ranks = new Map();
    results = [];
    for (const option of options) {
      const badges = [...option.querySelectorAll('[data-search-argument]')];
      const matching = badges.filter((badge) => query && badge.dataset.searchArgument.toLowerCase().includes(query));
      for (const badge of badges) badge.hidden = true;
      for (const badge of matching.slice(0, 4)) badge.hidden = false;
      option.querySelector('.pg-search-matches').hidden = !matching.length;
      const more = option.querySelector('.pg-search-more');
      more.hidden = matching.length <= 4;
      more.textContent = matching.length > 4 ? `+${matching.length - 4}` : '';
      const rank = option.dataset.searchFunction.toLowerCase().includes(query)
        ? 0
        : option.dataset.searchTitle.toLowerCase().includes(query)
          ? 1
          : matching.length
            ? 2
            : 3;
      ranks.set(option, rank);
      option.hidden = rank === 3;
      if (!option.hidden) results.push(option);
    }
    results.sort((a, b) => ranks.get(a) - ranks.get(b) || options.indexOf(a) - options.indexOf(b));
    let group;
    for (const option of results) {
      if (group !== option.dataset.searchGroup) {
        group = option.dataset.searchGroup;
        const heading = document.createElement('li');
        heading.className = 'pg-search-group';
        heading.setAttribute('role', 'presentation');
        heading.textContent = group;
        list.append(heading);
      }
      list.append(option);
    }
    searchIndex = 0;
    byId('search_count').textContent = `${results.length} ${results.length === 1 ? 'function' : 'functions'}`;
    searchSelection();
  }
  function searchSelection() {
    for (const option of byId('search_results').querySelectorAll('[role=option]'))
      option.setAttribute('aria-selected', 'false');
    const active = results[searchIndex];
    if (active) {
      active.setAttribute('aria-selected', 'true');
      byId('function_search').setAttribute('aria-activedescendant', active.id);
      active.scrollIntoView({ block: 'nearest' });
    } else byId('function_search').removeAttribute('aria-activedescendant');
  }
  function searchOpen() {
    if (!byId('studio_search')) return;
    if (!byId('studio_search').hidden) {
      byId('function_search').focus();
      return;
    }
    open('studio_search');
    byId('function_search').value = '';
    searchResults();
    byId('function_search').focus();
  }
  function chooseResult(option) {
    close('studio_search', false);
    selectFunction(
      option.dataset.searchFunction,
      option.dataset.searchInput,
      option.dataset.searchArgument,
      !!option.dataset.searchArgument,
    );
  }

  // Move bound containers, never a function panel or a clone of its inputs.
  function moveQuick(id) {
    const input = byId(id);
    if (input?.closest('#studio_character_bar')) return;
    const element = input?.closest('.shiny-input-container');
    if (!element) return;
    const marker = document.createComment('mounted studio input');
    element.before(marker);
    const sliders = [...element.querySelectorAll('input.js-range-slider')].map((slider) => ({
      slider: $(slider).data('ionRangeSlider'),
      value: window.Shiny.shinyapp.$inputValues[slider.id] ?? Number(slider.value),
    }));
    const portals = [...element.querySelectorAll('select')]
      .filter((select) => select.selectize)
      .map((select) => {
        const widget = select.selectize;
        const portal = {
          select: widget,
          parent: widget.$dropdown[0].parentElement,
          position: widget.positionDropdown,
          dropdownParent: widget.settings.dropdownParent,
          style: widget.$dropdown.attr('style'),
          contentStyle: widget.$dropdown_content.attr('style'),
        };
        widget.settings.dropdownParent = 'body';
        widget.$dropdown.appendTo(document.body).addClass('pg-chip-dropdown');
        widget.positionDropdown = () => {
          const rect = widget.$control[0].getBoundingClientRect();
          const bounds = viewportBounds();
          const below = Math.max(0, bounds.bottom - rect.bottom - 8);
          const above = Math.max(0, rect.top - bounds.top - 8);
          const up = below < Math.min(200, widget.$dropdown_content[0].scrollHeight) && above > below;
          widget.$dropdown_content.css('max-height', `${Math.min(200, up ? above : below)}px`);
          const height = widget.$dropdown.outerHeight();
          widget.$dropdown.css({
            position: 'fixed',
            left: `${Math.max(bounds.left + 8, Math.min(rect.left, bounds.right - rect.width - 8))}px`,
            width: `${Math.min(rect.width, bounds.width - 16)}px`,
            top: `${Math.max(bounds.top + 8, Math.min(up ? rect.top - height : rect.bottom, bounds.bottom - height - 8))}px`,
          });
          widget.$dropdown.attr('data-direction', up ? 'up' : 'down');
        };
        return portal;
      });
    moved.push({ element, marker, portals });
    byId('chip_editor_body').append(element);
    // ionRangeSlider measured its original hidden inspector. Refresh only once visible,
    // retaining Shiny's current value rather than the hidden widget's stale geometry.
    requestAnimationFrame(() => {
      for (const item of sliders) {
        if (!item.slider) continue;
        const value = Number(item.value);
        item.slider.update({ from: value >= item.slider.options.min ? value : item.slider.options.from });
      }
    });
  }
  function positionChip() {
    const pop = byId('chip_editor');
    if (pop.hidden) return;
    const rect = document.querySelector(`[data-call-arg="${chipArgument}"]`)?.getBoundingClientRect();
    if (!rect) return;
    const { left, top, right, bottom } = viewportBounds();
    pop.style.maxHeight = `${bottom - top - 16}px`;
    pop.style.maxWidth = `${right - left - 16}px`;
    const width = pop.offsetWidth;
    pop.style.left = `${phone() ? left + 8 : Math.max(left + 8, Math.min(rect.left, right - width - 8))}px`;
    pop.style.top = `${Math.max(top + 8, Math.min(phone() ? bottom - pop.offsetHeight - 8 : rect.top - pop.offsetHeight - 8, bottom - pop.offsetHeight - 8))}px`;
  }
  function chipContext(button) {
    if (!button) return;
    setText('chip_hint', button.dataset.callHint);
    setText('chip_default', button.dataset.callDefault);
    setText('chip_current', button.querySelector('.pg-chip-value').textContent);
    const changed = button.dataset.callChanged === 'true';
    byId('chip_changed').hidden = !changed;
    byId('chip_reset').hidden = !changed || ['character', 'mood', 'gesture'].includes(chipArgument);
    byId('chip_style').hidden = !['size', 'placement', 'theme', 'status', 'bubble', 'click', 'motion'].includes(
      chipArgument,
    );
    for (const option of document.querySelectorAll('[data-chip-style]')) {
      option.setAttribute('aria-pressed', String(option.dataset.chipStyle === button.dataset.callStyle));
    }
  }
  function chipOpen(button) {
    close('chip_editor', false);
    close('inspector_sidebar', false);
    chipArgument = button.dataset.callArg;
    chipInput =
      {
        size: byId('size_unit').querySelector('input:checked')?.value === 'pct' ? 'size_pct' : 'size_px',
        theme: 'theme_mode',
        motion: 'motion_on',
      }[chipArgument] || button.dataset.callInput;
    chipFunction = button.dataset.callFunction;
    chipField =
      {
        character: 'id',
        mood: 'name',
        gesture: 'name',
        status: 'text',
        bubble: 'text',
        placement: 'position',
        theme: 'mode',
        motion: 'others',
        click: chipFunction === 'mascot_popup_menu' ? 'items' : 'label',
      }[chipArgument] || chipArgument;
    byId('chip_editor_body').replaceChildren();
    byId('chip_title').textContent = `${chipArgument} =`;
    for (const overview of document.querySelectorAll('[data-chip-overview]')) {
      overview.hidden = overview.dataset.chipOverview !== chipArgument;
    }
    chipContext(button);
    open('chip_editor', button);
    button.setAttribute('aria-expanded', 'true');
    const controls =
      {
        status: ['status_text'],
        bubble: ['bubble_text'],
        size: ['size_unit', byId('size_unit').querySelector('input:checked')?.value === 'pct' ? 'size_pct' : 'size_px'],
        placement: ['position', 'drag'],
        theme: ['theme_source', 'theme_mode'],
        motion: ['motion_on'],
        click: ['click_type'],
      }[chipArgument] || [];
    for (const id of controls) moveQuick(id);
    if (['character', 'mood', 'gesture'].includes(chipArgument)) {
      const note = document.createElement('span');
      note.textContent = 'Change it in the top bar. ';
      const focus = document.createElement('button');
      focus.type = 'button';
      focus.id = 'chip_topbar';
      focus.className = 'btn btn-sm';
      focus.textContent = 'Focus top-bar control';
      byId('chip_editor_body').append(note, focus);
    }
    closeSelects();
    if (chipArgument === 'id') byId('chip_editor_body').textContent = 'Fixed studio id: "helper".';
    send('chip_argument', chipArgument);
    positionChip();
    // Focus the surface, which leaves selectize closed until the visitor chooses it.
    byId('chip_editor').tabIndex = -1;
    byId('chip_editor').focus({ preventScroll: true });
  }
  let helpObserver = null;
  function argumentHelp(fn, arg) {
    helpObserver?.disconnect();
    closePopovers();
    close('chip_editor', false);
    selectFunction(fn);
    tab('help');
    const reveal = () => {
      if (!byId('function_help').querySelector(`[data-guide-function="${fn}"]`)) return false;
      const field = byId('function_help').querySelector(`[data-argument="${arg}"]`);
      if (!field) return false;
      byId('function_help').dataset.activeArgument = arg;
      byId('inspector_sidebar').focus({ preventScroll: true });
      field.scrollIntoView({ block: 'nearest' });
      return true;
    };
    if (!reveal()) {
      // Shiny idle can precede an asynchronous renderUI replacement. Wait for
      // the requested function, rather than ending on an unrelated idle event.
      helpObserver = new MutationObserver(() => {
        if (
          selectedFunction !== fn ||
          byId('inspector_sidebar').hidden ||
          byId('inspector_tab_help').getAttribute('aria-selected') !== 'true' ||
          reveal()
        )
          helpObserver.disconnect();
      });
      helpObserver.observe(byId('function_help'), { childList: true, subtree: true });
    }
  }

  function closePopovers(returnFocus = true) {
    const pop = document.querySelector('.popover.show');
    if (!pop) return false;
    const trigger = document.querySelector(`[aria-describedby="${pop.id}"]`);
    window.bootstrap?.Popover?.getInstance(trigger)?.hide();
    if (returnFocus) trigger?.focus();
    return true;
  }
  document.addEventListener(
    'keydown',
    (event) => {
      if (
        event.shiftKey &&
        !event.ctrlKey &&
        !event.metaKey &&
        !event.altKey &&
        event.key.toLowerCase() === 'e' &&
        byId('inspector_sidebar').contains(event.target) &&
        // Shift+E types a capital E in a field; the shortcut is for the panel itself (#482). Today every field sits in
        // the Controls tab, so this guard keeps a field added to a reading tab typeable too.
        !event.target.closest('input, textarea, select, [contenteditable]:not([contenteditable="false"])') &&
        // The Controls tab never expands, so the key is left alone there.
        inspectorView !== 'controls'
      ) {
        event.preventDefault();
        toggleExpansion();
        return;
      }
      // The search field is a button in disguise: it opens only when asked (WCAG 2.2 "On Focus"), never on focus.
      if (event.target.id === 'open_search' && (event.key === 'Enter' || event.key === ' ')) {
        event.preventDefault();
        if (byId('studio_search').hidden) searchOpen();
        return;
      }
      if (event.key === 'Escape') {
        // Shiny owns its modal lifecycle; it sits above all studio surfaces.
        if (document.querySelector('.modal.show')) return;
        const select = event.target.closest?.('.shiny-input-container')?.querySelector('select');
        if (select?.selectize?.isOpen) {
          select.selectize.close();
          event.preventDefault();
          event.stopImmediatePropagation();
          return;
        }
        if (closePopovers()) {
          event.preventDefault();
          event.stopImmediatePropagation();
          return;
        }
        const menu = byId('studio_menu');
        if (menu?.open) {
          menu.open = false;
          menu.querySelector('summary').focus();
          event.preventDefault();
          event.stopImmediatePropagation();
          return;
        }
        const id = surfaces.at(-1);
        if (id) {
          if (id === 'inspector_sidebar' && byId(id).classList.contains('is-expanded')) toggleExpansion();
          else close(id);
          event.preventDefault();
          event.stopImmediatePropagation();
        }
        return;
      }
      const activeModal = !byId('studio_search')?.hidden
        ? byId('studio_search')
        : phone() && !byId('inspector_sidebar')?.hidden
          ? byId('inspector_sidebar')
          : null;
      if (event.key === 'Tab' && activeModal) {
        const items = focusables(activeModal);
        const index = items.indexOf(document.activeElement);
        if ((event.shiftKey && index <= 0) || (!event.shiftKey && (index === items.length - 1 || index < 0))) {
          event.preventDefault();
          items[event.shiftKey ? items.length - 1 : 0]?.focus();
        }
      }
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        searchOpen();
        return;
      }
      if (event.target.id === 'function_search' || event.target.closest?.('#search_results')) {
        if (['ArrowDown', 'ArrowUp'].includes(event.key) && results.length) {
          event.preventDefault();
          searchIndex = (searchIndex + (event.key === 'ArrowDown' ? 1 : -1) + results.length) % results.length;
          searchSelection();
          byId('function_search').focus();
        } else if (event.key === 'Enter' && event.target.matches?.('button')) {
          // A badge opens its argument; click it ourselves so synthetic key events behave like real ones.
          event.preventDefault();
          event.target.click();
        } else if (event.key === 'Enter' && results[searchIndex]) {
          event.preventDefault();
          chooseResult(results[searchIndex]);
        }
        return;
      }
      if (event.target.dataset?.inspectorTab && ['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
        event.preventDefault();
        const tabs = [...document.querySelectorAll('[data-inspector-tab]')];
        const i = tabs.indexOf(event.target);
        const index =
          event.key === 'Home' ? 0 : event.key === 'End' ? 2 : (i + (event.key === 'ArrowRight' ? 1 : 2)) % 3;
        tab(tabs[index].dataset.inspectorTab);
        tabs[index].focus();
        return;
      }
      const previewFocused = document.activeElement === byId('live_frame');
      if (
        !previewFocused ||
        !byId('studio_keys')?.checked ||
        activeModal ||
        event.ctrlKey ||
        event.metaKey ||
        event.altKey
      )
        return;
      if (event.key === '/') {
        event.preventDefault();
        searchOpen();
      } else if (['w', 'n'].includes(event.key)) {
        const select = byId('gesture');
        const name = event.key === 'w' ? 'wave' : 'nod';
        if (select.value === name) send('gesture_replay', name);
        else {
          select.value = name;
          $(select).trigger('change');
        }
      } else if (/^[1-5]$/.test(event.key)) {
        const select = byId('mood');
        const value = select.options[Number(event.key) - 1]?.value;
        if (value) {
          if (select.selectize) select.selectize.setValue(value);
          else {
            select.value = value;
            $(select).trigger('change');
          }
        }
      }
    },
    true,
  );

  document.addEventListener('click', (event) => {
    const menu = byId('studio_menu');
    if (menu?.open && !event.target.closest('#studio_menu')) menu.open = false;
    const target = event.target.closest('button, a, #open_search, [data-search-function]');
    if (!target) return;
    if (target.getAttribute('aria-disabled') === 'true') {
      event.preventDefault();
      return;
    }
    const id = target.id;
    if (id === 'more_examples') {
      event.preventDefault();
      byId('studio_menu').open = false;
      enterExamples();
      return;
    }
    if (id === 'back_to_studio') {
      backToStudio();
      return;
    }
    if (target.dataset.expandInspector) {
      toggleExpansion();
      return;
    }
    if (id === 'all_functions') flyout('all', target);
    else if (target.dataset.group) flyout(target.dataset.group, target);
    else if (id === 'open_search') searchOpen();
    else if (id === 'gesture_play') send('gesture_play', 'play');
    else if (id === 'open_inspector' || target.dataset.inspectorView) {
      const name = target.dataset.inspectorView || inspectorView;
      if (!byId('inspector_sidebar').hidden && name === inspectorView) close('inspector_sidebar');
      else {
        closeSelects();
        close('chip_editor', false);
        tab(name);
        open('inspector_sidebar', target);
        byId('inspector_sidebar').focus({ preventScroll: true });
      }
    } else if (id === 'open_code') {
      open('code_drawer', target);
      focusables(byId('code_drawer'))[0]?.focus();
    } else if (id === 'close_search') close('studio_search');
    else if (id === 'close_functions') close('function_flyout');
    else if (id === 'close_inspector') close('inspector_sidebar');
    else if (id === 'close_chip') close('chip_editor');
    else if (id === 'close_code') close('code_drawer');
    else if (id === 'chip_inspector') {
      close('chip_editor', false);
      selectFunction(chipFunction, chipInput, chipField);
    } else if (id === 'chip_help') {
      // The helper's own help page, as Controls and Guide open it. Arguments of mascot() itself
      // and the gesture's name keep their argument-level help.
      if (chipFunction === 'mascot' || chipArgument === 'gesture') {
        argumentHelp(
          chipArgument === 'gesture' ? 'mascot_gesture' : 'mascot',
          chipArgument === 'gesture' ? 'name' : chipArgument,
        );
      } else {
        close('chip_editor', false);
        selectFunction(chipFunction);
        tab('help');
      }
    } else if (target.dataset.callOpen) {
      selectFunction(target.dataset.callOpen);
    } else if (id === 'chip_guide') {
      close('chip_editor', false);
      selectFunction(chipFunction);
      tab('guide');
    } else if (id === 'chip_topbar') {
      close('chip_editor', false);
      focusInput(chipInput);
    } else if (target.closest('[data-chip-overview]')) {
      const content = target.closest('[data-chip-overview]').querySelector('.pg-overview-content');
      const popover = window.bootstrap.Popover.getOrCreateInstance(target, {
        html: true,
        sanitize: false, // Trusted package help, rendered by tools::Rd2HTML().
        content: content.innerHTML,
        container: document.body,
        trigger: 'manual',
        customClass: 'pg-help-popover',
      });
      popover.toggle();
    } else if (id === 'chip_reset') send('chip_reset', chipArgument);
    else if (target.dataset.chipStyle) send('chip_style', { arg: chipArgument, style: target.dataset.chipStyle });
    else if (target.dataset.argumentHelp) argumentHelp(target.dataset.helpFunction, target.dataset.argumentHelp);
    else if (id === 'phone_width') {
      const on = target.getAttribute('aria-pressed') !== 'true';
      target.setAttribute('aria-pressed', String(on));
      document.querySelector('.pg-host')?.classList.toggle('is-phone', on);
    } else if (id === 'reset_anchors') {
      liveWindow()?.dispatchEvent(new Event('studio:reset-anchors'));
    } else if (id === 'show_anchors' && !target.disabled) {
      target.setAttribute('aria-pressed', String(target.getAttribute('aria-pressed') !== 'true'));
      syncHost();
    } else if (target.dataset.focusInput) {
      focusInput(target.dataset.focusInput);
    } else if (target.dataset.inspectorTab) tab(target.dataset.inspectorTab);
    else if (target.dataset.callArg) chipOpen(target);
    else if (target.dataset.searchFunction) chooseResult(target);
  });
  // Buttons with data-event and copy buttons are inputs.js's. The function index and its links open a function
  // here instead of only sending the event.
  window.mascotStudioInputs.on('select_function', (fn) => selectFunction(fn));
  let bubbleTimer = null;
  document.addEventListener('input', (event) => {
    if (event.target.id === 'function_search') searchResults();
    if (event.target.id === 'bubble_text' && !byId('chip_editor').hidden && chipArgument === 'bubble') {
      // One update when typing pauses, not one per keystroke (each restarts the bubble and is announced).
      clearTimeout(bubbleTimer);
      const text = event.target.value;
      bubbleTimer = setTimeout(() => send('chip_bubble', text), 600);
    }
  });
  $(document).on('change', '#size_unit', () => {
    if (byId('chip_editor').hidden || chipArgument !== 'size') return;
    const sizeId = byId('size_unit').querySelector('input:checked').value === 'pct' ? 'size_pct' : 'size_px';
    const item = moved.find((entry) => entry.element.querySelector('#size_px, #size_pct'));
    // A server reset also updates the radio group without changing its unit.
    // Remounting here would restore the pre-reset slider value on the next frame.
    if (item?.element.querySelector(`#${sizeId}`)) return;
    if (item) {
      item.marker.replaceWith(item.element);
      moved.splice(moved.indexOf(item), 1);
    }
    moveQuick(byId('size_unit').querySelector('input:checked').value === 'pct' ? 'size_pct' : 'size_px');
    positionChip();
  });
  $(document).on('change', '#host_mode', () => {
    const value = byId('host_mode').value;
    if (value !== hostMode) mode(value);
  });
  $(document).on('shiny:disconnected shiny:connected', (event) => {
    liveWindow()?.document.dispatchEvent(new Event(event.type));
  });
  document.addEventListener(
    'load',
    (event) => {
      if (event.target.id === 'live_frame') syncHost();
    },
    true,
  );
  new MutationObserver(syncHost).observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['data-bs-theme', 'style'],
  });
  function positionDropdowns() {
    for (const item of moved)
      for (const portal of item.portals) {
        if (portal.select.isOpen) portal.select.positionDropdown();
      }
  }
  document.addEventListener('scroll', positionDropdowns, true);
  // The sentence words' tooltips are placed by inputs.js; the function index button has one too.
  document.addEventListener('pointerover', (event) => positionWordTooltip(event.target.closest('#all_functions')));
  document.addEventListener('pointerdown', (event) => {
    if (event.pointerType !== 'mouse') positionWordTooltip(event.target.closest('#all_functions'));
  });
  document.addEventListener('focusin', (event) => positionWordTooltip(event.target.closest('#all_functions')));
  document.addEventListener('focusout', (event) => {
    event.target.closest?.('.pg-topbar-highlight')?.classList.remove('pg-topbar-highlight');
  });
  let railHome = null;
  function positionRightRail() {
    const rail = byId('studio_right_rail');
    if (!rail) return;
    if (!railHome) {
      railHome = document.createComment('desktop right rail');
      rail.before(railHome);
    }
    const slot = byId(hostMode === 'examples' ? 'examples_phone_tools' : 'studio_phone_tools');
    const destination = phone() ? slot : railHome.parentElement;
    const active = document.activeElement;
    const focused = rail.contains(active);
    if (rail.parentElement !== destination) {
      if (phone()) slot.append(rail);
      else railHome.after(rail);
    }
    if (focused) {
      const target = visible(active) ? active : inspectorButton();
      if (document.activeElement !== target) target.focus({ preventScroll: true });
    }
  }
  function positionSurfaces() {
    positionRightRail();
    const bounds = viewportBounds();
    for (const name of ['left', 'top', 'width', 'height'])
      document.documentElement.style.setProperty(`--studio-viewport-${name}`, `${bounds[name]}px`);
    const menu = byId('studio_menu');
    menu?.querySelector('summary').setAttribute('aria-expanded', String(menu.open));
    if (menu?.open) {
      const body = menu.querySelector('.pg-menu-body');
      const rect = menu.querySelector('summary').getBoundingClientRect();
      body.style.left = `${Math.max(bounds.left + 8, Math.min(rect.right - body.offsetWidth, bounds.right - body.offsetWidth - 8))}px`;
      body.style.top = `${Math.max(bounds.top + 8, Math.min(rect.bottom + 4, bounds.bottom - body.offsetHeight - 8))}px`;
    }
    sizeSentenceWords();
    positionDropdowns();
    positionChip();
    for (const word of document.querySelectorAll('.pg-sentence-word')) positionWordTooltip(word);
    syncModal();
  }
  window.visualViewport?.addEventListener('resize', positionSurfaces);
  window.visualViewport?.addEventListener('scroll', positionSurfaces);
  window.addEventListener('resize', positionSurfaces);
  document.addEventListener(
    'scroll',
    (event) => {
      if (event.target !== byId('studio_centre') && event.target !== document) return;
      const menu = byId('studio_menu');
      if (menu?.open) menu.open = false;
      for (const word of document.querySelectorAll('.is-touch-help')) word.classList.remove('is-touch-help');
    },
    true,
  );

  // Mark changed controls without replacing, cloning or rebinding their mounted inputs.
  const initialValues = new WeakMap();
  function inputValue(input) {
    return input.type === 'checkbox' || input.type === 'radio' ? `${input.value}:${input.checked}` : input.value;
  }
  // Keep irrelevant controls mounted and preserve their values while explaining their state.
  function syncApplicability() {
    const forever = byId('bubble_forever')?.checked === true;
    const seconds = byId('bubble_seconds');
    seconds?.setAttribute('aria-disabled', String(forever));
    const slider = $('#bubble_duration').data('ionRangeSlider');
    if (slider && slider.options.disable !== forever) slider.update({ disable: forever });
    const inline = document.querySelector('#position input:checked')?.value === 'inline';
    const drag = byId('drag');
    if (drag?.selectize) {
      if (inline) drag.selectize.disable();
      else drag.selectize.enable();
    }
    if (drag) drag.disabled = inline;
    if (byId('minimise')) byId('minimise').disabled = inline;
  }
  function markControls() {
    syncApplicability();
    for (const field of document.querySelectorAll('.pg-field')) {
      const input = byId(field.dataset.defaultInput);
      const expression = field.dataset.packageDefault;
      let changed = false;
      if (input && expression && !['none: required', 'empty'].includes(expression)) {
        let current = input.type === 'checkbox' ? String(input.checked).toUpperCase() : input.value;
        let expected = expression.replace(/^"(.*)"$/, '$1');
        if (expected === 'NULL') expected = '';
        if (['follow', 'own'].includes(current)) current = '';
        if (field.dataset.owner === 'mascot' && field.dataset.argument === 'motion' && current === '') current = 'TRUE';
        changed = String(current) !== expected;
      }
      for (const item of field.querySelectorAll('input, select, textarea')) {
        if (initialValues.has(item) && initialValues.get(item) !== inputValue(item)) changed = true;
      }
      const mainArgument = {
        mascot_size: 'size',
        mascot_placement: 'position',
        mascot_status: 'text',
        mascot_bubble: 'text',
        mascot_theme: 'mode',
        mascot_motion_settings: 'others',
      }[field.dataset.owner];
      const chipName =
        field.dataset.owner === 'mascot'
          ? field.dataset.argument
          : field.dataset.argument === mainArgument
            ? {
                mascot_size: 'size',
                mascot_placement: 'placement',
                mascot_status: 'status',
                mascot_bubble: 'bubble',
                mascot_theme: 'theme',
                mascot_motion_settings: 'motion',
              }[field.dataset.owner]
            : null;
      if (chipName) changed = document.querySelector(`[data-call-arg="${chipName}"]`)?.dataset.callChanged === 'true';
      field.classList.toggle('is-changed', changed);
      if (changed) field.title = 'Changed from the package default';
      else field.removeAttribute('title');
    }
    for (const chip of document.querySelectorAll('[data-call-arg]')) {
      if (!byId('chip_editor').hidden && chip.dataset.callArg === chipArgument) {
        chip.setAttribute('aria-expanded', 'true');
        chipContext(chip);
        // The click can switch between action and menu while this editor stays open.
        chipFunction = chip.dataset.callFunction;
        if (chipArgument === 'click') chipInput = chip.dataset.callInput;
        if (chipArgument === 'click') chipField = chipFunction === 'mascot_popup_menu' ? 'items' : 'label';
      }
    }
  }
  const chipValues = new Map();
  const pulseUntil = new Map();
  const pulseTimers = new Map();
  function rememberChips() {
    for (const chip of document.querySelectorAll('[data-call-arg]')) {
      const name = chip.dataset.callArg;
      const value = chip.querySelector('code')?.textContent;
      if (chipValues.has(name) && chipValues.get(name) !== value) pulseUntil.set(name, performance.now() + 600);
      chipValues.set(name, value);
      const remaining = (pulseUntil.get(name) || 0) - performance.now();
      if (remaining <= 0) continue;
      chip.classList.add('pg-chip-pulse');
      clearTimeout(pulseTimers.get(name));
      pulseTimers.set(
        name,
        setTimeout(() => {
          document.querySelector(`[data-call-arg="${name}"]`)?.classList.remove('pg-chip-pulse');
          pulseUntil.delete(name);
        }, remaining),
      );
    }
  }
  function rememberControls() {
    for (const input of document.querySelectorAll('.pg-field input, .pg-field select, .pg-field textarea')) {
      if (!initialValues.has(input)) initialValues.set(input, inputValue(input));
    }
    markControls();
  }
  // Shiny's receiveMessage() also emits jQuery changes for programmatic updates.
  $(document).on('change', markControls);
  // Media-query changes settle after the resize event itself, so measure again on the next frames.
  window.addEventListener('resize', () => {
    sizeSentenceWords();
    requestAnimationFrame(() => requestAnimationFrame(sizeSentenceWords));
  });
  function sizeSentenceWords() {
    const sentence = document.querySelector('.pg-sentence');
    if (sentence)
      byId('studio_dock').style.setProperty(
        '--studio-call-font',
        `${Math.max(12, parseFloat(getComputedStyle(sentence).fontSize))}px`,
      );
    const palette = byId('palette');
    if (palette) {
      for (const option of palette.options) {
        option.title = option.value === 'original' ? palette.dataset.nativePalette || option.title : option.value;
      }
      palette.title = palette.selectedOptions[0]?.title || palette.value;
      setText('palette_id', palette.title);
      setText('palette_prefix', palette.value === 'original' ? 'in' : 'in the');
      setText('palette_suffix', palette.value === 'original' ? ',' : 'palette,');
    }
    sizeSentence();
  }
  window.Shiny.addCustomMessageHandler('studio:palette', (sentence) => {
    const select = byId('palette');
    if (!select) return;
    setText('palette_prefix', sentence.prefix);
    setText('palette_suffix', sentence.suffix);
    select.dataset.nativePalette = sentence.ids[0];
    sizeSentenceWords();
  });
  $(document).on('change', '.pg-sentence select', sizeSentenceWords);
  function initialise() {
    const centre = byId('studio_centre');
    if (!centre) return;
    selectedFunction = centre.dataset.initialFunction || selectedFunction;
    showControls();
    tab('controls');
    if (selectedFunction === 'mascot_preview') mode('preview');
    if (centre.dataset.initialMode === 'examples') enterExamples();
    else if (centre.dataset.initialMode) mode(centre.dataset.initialMode);
    $(document).one('shiny:connected', () => {
      send('initial_function', selectedFunction);
      send('initial_character', centre.dataset.initialCharacter);
      // mascot_studio(fn = ) opens that function on its Guide, as its help promises.
      if (centre.dataset.initialOpen === 'guide') {
        selectFunction(selectedFunction);
        tab('guide');
      }
    });
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const reduced = () => {
      byId('reduced_motion').textContent = media.matches ? 'Reduced motion (OS)' : '';
    };
    reduced();
    media.addEventListener('change', reduced);
    const index = document.querySelector('.pg-index');
    index?.addEventListener('show.bs.tooltip', (event) => {
      const button = event.target.closest('.pg-index-link') ?? event.target.querySelector('.pg-index-link');
      const description = button?.querySelector('span');
      if (!description || description.scrollWidth <= description.clientWidth) {
        event.preventDefault();
        return;
      }
      for (const trigger of index.querySelectorAll('[aria-describedby]')) {
        if (trigger !== event.target) window.bootstrap?.Tooltip?.getInstance(trigger)?.hide();
      }
    });
    new ResizeObserver(positionChip).observe(byId('chip_editor'));
    byId('studio_menu').addEventListener('toggle', positionSurfaces);
    const help = byId('inspector_help');
    function markStickyUsage() {
      const usage = help.querySelector('.pg-help-usage');
      usage?.classList.toggle(
        'is-stuck',
        help.scrollTop > 0 && usage.getBoundingClientRect().top <= help.getBoundingClientRect().top + 5,
      );
    }
    help.addEventListener('scroll', markStickyUsage);
    new MutationObserver(markStickyUsage).observe(help, { childList: true, subtree: true });
    syncExpansion();
    new MutationObserver(syncExpansion).observe(byId('inspector_sidebar'), { childList: true, subtree: true });
    rememberControls();
    rememberChips();
    new MutationObserver(rememberChips).observe(byId('live_call'), {
      childList: true,
      subtree: true,
      characterData: true,
    });
    sizeSentenceWords();
    new MutationObserver(sizeSentenceWords).observe(byId('studio_character_bar'), { childList: true, subtree: true });
    new MutationObserver(rememberControls).observe(byId('studio_shell'), { childList: true, subtree: true });
    positionSurfaces();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialise);
  else initialise();

  function paintSwatches() {
    const frame = liveWindow();
    const el = frame?.document.getElementById('helper');
    const state = el && frame.mascot?.host.state(el);
    const colours = Object.fromEntries(
      Object.entries(state?.colours || {}).map(([key, value]) => [
        key.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase(),
        value,
      ]),
    );
    for (const swatch of document.querySelectorAll('.pg-resolved')) {
      const active = state && swatch.dataset.mode === state.mode;
      swatch.style.background = active ? colours[swatch.dataset.role] || swatch.dataset.default : 'transparent';
      swatch.classList.toggle('is-idle', !active);
      swatch.title = active ? 'In use now' : `Used when the mascot is in ${swatch.dataset.mode} mode`;
    }
  }
  setInterval(paintSwatches, 700);
})();
