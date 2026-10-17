// The studio's browser helpers: a Shiny input for the browser's own colour picker, buttons
// that report a click to the server, copy buttons, and swatches showing the colours in use.
(() => {
  if (!window.Shiny) return;
  const $ = window.jQuery;

  // input type="color" as a Shiny input. CSS-variable pickers also set their variable on the page.
  class ColourBinding extends window.Shiny.InputBinding {
    find(scope) {
      return $(scope).find('input.pg-colour');
    }
    getValue(el) {
      return el.value;
    }
    setValue(el, value) {
      el.value = value;
    }
    subscribe(el, callback) {
      if (el.dataset.cssVar) document.documentElement.style.setProperty(el.dataset.cssVar, el.value);
      $(el).on('input.pgColour change.pgColour', () => {
        if (el.dataset.cssVar) document.documentElement.style.setProperty(el.dataset.cssVar, el.value);
        callback(true);
      });
    }
    unsubscribe(el) {
      $(el).off('.pgColour');
    }
    receiveMessage(el, data) {
      if (typeof data.value === 'string') {
        el.value = data.value;
        $(el).trigger('change');
      }
    }
    getRatePolicy() {
      return { policy: 'debounce', delay: 250 };
    }
  }
  window.Shiny.inputBindings.register(new ColourBinding(), 'mascotStudio.colour');

  let selectedFunction = 'mascot_mood';
  // The canvas shows the live mascot, or the page mascot_preview() returns while that function is selected.
  // Hiding (not removing) keeps the mascot and its state as they were.
  function showCanvas() {
    const canvas = document.getElementById('studio_canvas');
    if (!canvas) return;
    const mode = selectedFunction === 'mascot_preview' ? 'preview' : 'mascot';
    canvas.dataset.mode = mode;
    for (const part of canvas.querySelectorAll('[data-canvas]')) part.hidden = part.dataset.canvas !== mode;
  }
  function showControls() {
    showCanvas();
    const inspector = document.getElementById('studio_inspector');
    if (!inspector) return;
    for (const group of inspector.querySelectorAll('[data-function]')) {
      const selected = group.dataset.function === selectedFunction;
      if (!selected && group.contains(document.activeElement)) {
        document.querySelector(`.pg-index-link[data-value="${selectedFunction}"]`)?.focus();
      }
      group.hidden = !selected;
    }
    (inspector.closest('.sidebar-content') || inspector).scrollTop = 0;
    for (const button of document.querySelectorAll('.pg-index-link')) {
      button.setAttribute('aria-current', String(button.dataset.value === selectedFunction));
    }
  }

  function initialise() {
    for (const el of document.querySelectorAll('input.pg-colour[data-css-var]')) {
      document.documentElement.style.setProperty(el.dataset.cssVar, el.value);
    }
    const centre = document.getElementById('studio_centre');
    selectedFunction = centre?.dataset.initialFunction || selectedFunction;
    showControls();
    $(document).one('shiny:connected', () => {
      if (centre) {
        window.Shiny.setInputValue('initial_function', selectedFunction);
        window.Shiny.setInputValue('initial_character', centre.dataset.initialCharacter);
      }
    });
    const index = document.querySelector('.pg-index');
    index?.addEventListener('show.bs.tooltip', (event) => {
      const button = event.target.closest('.pg-index-link') ?? event.target.querySelector('.pg-index-link');
      const description = button?.querySelector('span');
      if (!description || description.scrollWidth <= description.clientWidth) {
        event.preventDefault();
        return;
      }
      for (const trigger of index.querySelectorAll('[aria-describedby]')) {
        if (trigger !== event.target) window.bootstrap.Tooltip.getInstance(trigger)?.hide();
      }
    });
    const dock = document.getElementById('studio_dock');
    const header = document.getElementById('code_tray_header');
    const headerToggle = document.getElementById('code_tray_toggle');
    const trayBody = document.getElementById('code_tray_body');
    const card = document.getElementById('studio_panels_card');
    const saved = (() => {
      try {
        return JSON.parse(sessionStorage.getItem('mascot-studio-tray') || 'null');
      } catch {
        return null;
      }
    })();
    let open = saved?.open ?? !window.matchMedia('(max-width: 575.98px)').matches;
    function saveTray() {
      try {
        sessionStorage.setItem('mascot-studio-tray', JSON.stringify({ open, height: preferred }));
      } catch {
        /* Storage can be unavailable; the controls still work. */
      }
    }
    function syncDock() {
      if (!dock) return;
      if (!open && (trayBody?.contains(document.activeElement) || document.activeElement?.id === 'dock_grip')) {
        headerToggle?.focus();
      }
      dock.classList.toggle('is-closed', !open);
      if (trayBody) {
        trayBody.inert = !open;
        trayBody.setAttribute('aria-hidden', String(!open));
      }
      headerToggle?.setAttribute('aria-expanded', String(open));
      headerToggle?.setAttribute('aria-label', `${open ? 'Collapse' : 'Expand'} Code tray`);
    }
    function toggleTray() {
      if (open && card?.dataset.fullScreen === 'true') document.querySelector('.bslib-full-screen-exit')?.click();
      open = !open;
      syncDock();
      saveTray();
    }
    header?.addEventListener('click', toggleTray);
    function placementControls() {
      const inline = document.querySelector('#position input:checked')?.value === 'inline';
      const minimise = document.getElementById('minimise');
      const drag = document.getElementById('drag');
      if (minimise) minimise.disabled = inline;
      if (drag) {
        drag.disabled = inline;
        const selectize = $(drag)[0]?.selectize;
        if (selectize) {
          if (inline) selectize.disable();
          else selectize.enable();
        }
      }
    }
    $(document).on('shiny:inputchanged', (event) => {
      if (event.name === 'position') setTimeout(placementControls, 0);
      if (event.name === 'bubble_forever') setTimeout(durationControl, 0);
    });
    function durationControl() {
      const disabled = document.getElementById('bubble_forever')?.checked === true;
      const slider = $('#bubble_duration').data('ionRangeSlider');
      slider?.update({ disable: disabled });
      document.getElementById('bubble_seconds')?.setAttribute('aria-disabled', String(disabled));
    }
    placementControls();
    durationControl();
    window.Shiny.addCustomMessageHandler('studio:task', (busy) => {
      const button = document.getElementById('task_run');
      if (button) button.disabled = busy;
    });
    const grip = document.getElementById('dock_grip');
    let height = Number.isFinite(saved?.height) ? saved.height : 33;
    // The height the visitor chose. A crowded canvas (the mascot_preview() page) lowers the height shown, not this.
    let preferred = height;
    let drag = null;
    function resize(value, chosen = true) {
      if (!centre || !grip || !centre.clientHeight) return;
      const dockStyle = getComputedStyle(dock);
      const borders = parseFloat(dockStyle.borderTopWidth) + parseFloat(dockStyle.borderBottomWidth);
      dock.style.setProperty('--pg-dock-header-height', `${header.offsetHeight + borders}px`);
      const canvas = document.getElementById('studio_canvas');
      const style = getComputedStyle(canvas);
      // Include the reserved bubble region, character, status and caption in the canvas floor.
      // The preview page grows to fill the canvas, so only its own minimum height counts.
      const contentHeight = [...canvas.children].reduce((total, child) => {
        if (child.hidden) return total;
        const childStyle = getComputedStyle(child);
        const own = child.dataset.canvas === 'preview' ? parseFloat(childStyle.minHeight) : child.offsetHeight;
        return total + own + parseFloat(childStyle.marginTop) + parseFloat(childStyle.marginBottom);
      }, parseFloat(style.paddingTop) + parseFloat(style.paddingBottom));
      const canvasHeight = Math.max(parseFloat(style.minHeight), contentHeight);
      const toolbarHeight = centre.querySelector('.pg-toolbar').offsetHeight;
      const maximum = Math.max(
        0,
        Math.min(80, ((centre.clientHeight - toolbarHeight - canvasHeight) / centre.clientHeight) * 100),
      );
      const minimum = Math.min(25, maximum);
      height = Math.max(minimum, Math.min(maximum, value));
      if (chosen) preferred = height;
      centre.style.setProperty('--pg-dock-height', `${(height / 100) * centre.clientHeight}px`);
      grip.setAttribute('aria-valuemin', String(Math.round(minimum)));
      grip.setAttribute('aria-valuemax', String(Math.round(maximum)));
      grip.setAttribute('aria-valuenow', String(Math.round(height)));
    }
    syncDock();
    resize(height, false);
    if (centre) {
      const observer = new ResizeObserver(() => resize(preferred, false));
      observer.observe(centre);
      observer.observe(centre.querySelector('.pg-toolbar'));
      observer.observe(header);
      for (const child of document.getElementById('studio_canvas').children) observer.observe(child);
    }
    grip?.addEventListener('pointerdown', (event) => {
      if (event.button !== 0) return;
      open = true;
      syncDock();
      document.body.classList.add('is-resizing');
      drag = { y: event.clientY, height };
      grip.setPointerCapture(event.pointerId);
      event.preventDefault();
    });
    grip?.addEventListener('pointermove', (event) => {
      if (drag) resize(drag.height + ((drag.y - event.clientY) / centre.clientHeight) * 100);
    });
    function stopResize(event) {
      if (grip.hasPointerCapture(event.pointerId)) grip.releasePointerCapture(event.pointerId);
      drag = null;
      document.body.classList.remove('is-resizing');
      saveTray();
    }
    grip?.addEventListener('pointerup', stopResize);
    grip?.addEventListener('pointercancel', stopResize);
    grip?.addEventListener('dblclick', () => {
      resize(33);
      saveTray();
    });
    grip?.addEventListener('keydown', (event) => {
      if (!['ArrowUp', 'ArrowDown', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      open = true;
      syncDock();
      resize(event.key === 'Home' ? 25 : event.key === 'End' ? 80 : height + (event.key === 'ArrowUp' ? 5 : -5));
      saveTray();
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialise);
  else initialise();

  function closeOpenPopovers() {
    let closed = false;
    for (const trigger of document.querySelectorAll(
      'bslib-popover > button, [data-bs-toggle="popover"], [aria-describedby^="popover"]',
    )) {
      const inst = window.bootstrap?.Popover?.getInstance(trigger);
      if (inst) {
        inst.hide();
        closed = true;
      }
    }
    for (const popover of document.querySelectorAll('.popover.show')) {
      const trigger = document.querySelector(`[aria-describedby="${popover.id}"]`);
      const inst = trigger && window.bootstrap?.Popover?.getInstance(trigger);
      if (inst) {
        inst.hide();
      } else {
        popover.classList.remove('show');
        popover.remove();
      }
      closed = true;
    }
    return closed;
  }

  function closeOpenTooltips() {
    for (const trigger of document.querySelectorAll('[data-bs-toggle="tooltip"], .pg-index [aria-describedby]')) {
      window.bootstrap?.Tooltip?.getInstance(trigger)?.hide();
    }
    for (const tooltip of document.querySelectorAll('.tooltip.show')) {
      const trigger = document.querySelector(`[aria-describedby="${tooltip.id}"]`);
      const inst = trigger && window.bootstrap?.Tooltip?.getInstance(trigger);
      if (inst) {
        inst.hide();
      } else {
        tooltip.classList.remove('show');
        tooltip.remove();
      }
    }
  }

  // Restore the opener after Shiny's modal cleanup, for either dismissal path.
  let guideOpener = null;
  $(document).on('show.bs.modal', (event) => {
    if (!event.target.classList.contains('pg-guide-modal')) return;
    closeOpenPopovers();
    closeOpenTooltips();
  });
  $(document).on('hidden.bs.modal', (event) => {
    if (!event.target.classList.contains('pg-guide-modal')) return;
    const opener = guideOpener;
    guideOpener = null;
    setTimeout(() => {
      if (opener?.isConnected && opener.getClientRects().length) opener.focus();
    }, 0);
  });

  // Use Shiny's modal lifecycle for both dismissal paths. Capture Escape before
  // Bootstrap or Shiny's modal wrapper consumes it, then let removeModal() hide
  // the modal and perform Shiny's normal unbinding and backdrop cleanup.
  document.addEventListener(
    'keydown',
    (event) => {
      if (event.key !== 'Escape') return;
      if (document.querySelector('.pg-guide-modal.show')) {
        event.preventDefault();
        event.stopPropagation();
        window.Shiny.setInputValue('close_guide', 'escape', { priority: 'event' });
        return;
      }
      if (document.querySelectorAll('.popover.show').length > 0) {
        event.preventDefault();
        event.stopPropagation();
        closeOpenPopovers();
      }
    },
    true,
  );

  // Buttons update the same mounted inputs as the inspector.
  document.addEventListener('click', (event) => {
    if (!event.target.closest('.popover') && !event.target.closest('bslib-popover, [data-bs-toggle="popover"]')) {
      closeOpenPopovers();
    }
    const target = event.target.closest('[data-event]');
    if (target) {
      if (target.tagName === 'A') event.preventDefault();
      if (target.dataset.event === 'open_guide') {
        closeOpenPopovers();
        closeOpenTooltips();
        guideOpener = target;
      }
      if (target.dataset.event === 'select_function') {
        selectedFunction = target.dataset.value;
        showControls();
        // Choosing a function opens the controls again if they were collapsed.
        const layout = document.getElementById('inspector_sidebar')?.closest('.bslib-sidebar-layout');
        if (layout) window.bslib?.Sidebar?.getInstance(layout)?.toggle('open');
      }
      window.Shiny.setInputValue(target.dataset.event, target.dataset.value ?? 'click', { priority: 'event' });
      return;
    }
    const copy = event.target.closest('[data-copy]');
    if (copy && navigator.clipboard) {
      const source = document.getElementById(copy.dataset.copy);
      navigator.clipboard.writeText(source ? source.innerText : '').then(
        () => {
          copy.textContent = 'Copied';
          setTimeout(() => {
            copy.textContent = 'Copy';
          }, 1500);
        },
        () => {
          copy.textContent = 'Copy failed';
        },
      );
    }
  });

  // Paints each picker's round swatch with the colour the mascot uses now, read from its state.
  function paintSwatches() {
    const el = document.getElementById('helper');
    const state = el && window.mascot?.host?.state ? window.mascot.host.state(el) : null;
    // Match the public role spelling from mascot_colour_roles(), including multiword keys.
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
