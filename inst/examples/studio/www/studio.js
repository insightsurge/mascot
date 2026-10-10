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

  // Mood cards are the one input for mascot_mood(name), including updates from the server.
  function setMood(el, value) {
    el.dataset.value = value;
    for (const button of el.querySelectorAll('[data-event="try_mood"]')) {
      button.setAttribute('aria-pressed', String(button.dataset.value === value));
    }
  }
  class MoodBinding extends window.Shiny.InputBinding {
    find(scope) {
      return $(scope).find('.pg-mood-input');
    }
    getValue(el) {
      return el.dataset.value;
    }
    subscribe(el, callback) {
      $(el).on('change.pgMood', () => callback(false));
    }
    unsubscribe(el) {
      $(el).off('.pgMood');
    }
    receiveMessage(el, data) {
      if (typeof data.value === 'string') {
        setMood(el, data.value);
        $(el).trigger('change');
      }
    }
  }
  window.Shiny.inputBindings.register(new MoodBinding(), 'mascotStudio.mood');

  let selectedFunction = 'mascot_mood';
  let showAll = false;
  function showControls(selectionChanged = false) {
    const inspector = document.getElementById('studio_inspector');
    if (!inspector) return;
    inspector.classList.toggle('is-show-all', showAll);
    for (const group of inspector.querySelectorAll('[data-function]')) {
      const selected = group.dataset.function === selectedFunction;
      if ((!showAll || selectionChanged) && !selected && group.contains(document.activeElement)) {
        document.querySelector(`.pg-index-link[data-value="${selectedFunction}"]`)?.focus();
      }
      group.hidden = !showAll && !selected;
      if (!showAll || selectionChanged) group.open = selected;
    }
    for (const button of document.querySelectorAll('.pg-index-link')) {
      button.setAttribute('aria-current', String(button.dataset.value === selectedFunction));
    }
  }

  function initialise() {
    for (const el of document.querySelectorAll('input.pg-colour[data-css-var]')) {
      document.documentElement.style.setProperty(el.dataset.cssVar, el.value);
    }
    showControls();
    $(document).on('shiny:inputchanged', (event) => {
      if (event.name === 'show_all_controls') {
        showAll = event.value === true;
        showControls(true);
      }
    });
    const centre = document.getElementById('studio_centre');
    const expand = document.getElementById('guide_expand');
    const dock = document.getElementById('studio_dock');
    const dockTabs = dock?.querySelector(':scope > .tabbable > .nav');
    function placeMiniCard() {
      if (centre && dock && dockTabs) {
        centre.style.setProperty('--pg-mini-top', `${dock.offsetTop + dockTabs.offsetHeight + 12}px`);
      }
    }
    const layoutObserver = new ResizeObserver(placeMiniCard);
    if (centre) layoutObserver.observe(centre);
    if (dockTabs) layoutObserver.observe(dockTabs);
    expand?.addEventListener('click', () => {
      const expanded = centre.classList.toggle('is-expanded');
      expand.setAttribute('aria-expanded', String(expanded));
      expand.textContent = expanded ? 'Restore canvas' : 'Expand guide';
      placeMiniCard();
      document.querySelector('#code_tabs a[data-value="Guide"]')?.click();
    });
    const grip = document.getElementById('dock_grip');
    let height = 42;
    let drag = null;
    function resize(value) {
      height = Math.max(25, Math.min(80, value));
      centre.style.setProperty('--pg-dock-height', `${height}%`);
      grip.setAttribute('aria-valuenow', String(Math.round(height)));
    }
    grip?.addEventListener('pointerdown', (event) => {
      if (event.button !== 0) return;
      drag = { y: event.clientY, height };
      grip.setPointerCapture(event.pointerId);
      event.preventDefault();
    });
    grip?.addEventListener('pointermove', (event) => {
      if (drag) resize(drag.height + ((drag.y - event.clientY) / centre.clientHeight) * 100);
    });
    grip?.addEventListener('pointerup', () => {
      drag = null;
    });
    grip?.addEventListener('pointercancel', () => {
      drag = null;
    });
    grip?.addEventListener('keydown', (event) => {
      if (!['ArrowUp', 'ArrowDown', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      resize(event.key === 'Home' ? 25 : event.key === 'End' ? 80 : height + (event.key === 'ArrowUp' ? 5 : -5));
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialise);
  else initialise();

  // Buttons update the same mounted inputs as the inspector.
  document.addEventListener('click', (event) => {
    if (!showAll && event.target.closest('.pg-inspector-function > summary')) {
      event.preventDefault();
      return;
    }
    const target = event.target.closest('[data-event]');
    if (target) {
      if (target.dataset.event === 'select_function') {
        selectedFunction = target.dataset.value;
        showControls(true);
      }
      if (target.dataset.event === 'try_mood') {
        const mood = document.getElementById('mood');
        setMood(mood, target.dataset.value);
        $(mood).trigger('change');
        return;
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

  // A selected function starts at the top. Placement shortcuts retain their keyboard focus.
  $(document).on('shiny:value', (event) => {
    if (event.name === 'guide') {
      const body = document.querySelector('#studio_dock > .tabbable > .tab-content');
      if (body) body.scrollTop = 0;
    }
    if (event.name === 'placement_map') {
      const focused = document.activeElement?.closest('#placement_map [data-value]')?.dataset.value;
      if (!focused) return;
      setTimeout(() => {
        document.querySelector(`#placement_map [data-value="${focused}"]`)?.focus();
      }, 0);
    }
  });

  // Paints each picker's round swatch with the colour the mascot uses now, read from its state.
  function paintSwatches() {
    const el = document.getElementById('helper');
    const state = el && window.mascot?.host?.state ? window.mascot.host.state(el) : null;
    for (const swatch of document.querySelectorAll('.pg-resolved')) {
      const active = state && swatch.dataset.mode === state.mode;
      swatch.style.background = active ? state.colours[swatch.dataset.role] || swatch.dataset.default : 'transparent';
      swatch.classList.toggle('is-idle', !active);
      swatch.title = active ? 'In use now' : `Used when the mascot is in ${swatch.dataset.mode} mode`;
    }
  }
  setInterval(paintSwatches, 700);
})();
