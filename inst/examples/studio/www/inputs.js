// Inputs that every view of the studio app shares: the colour picker as a Shiny input, copy buttons, and buttons
// or links that send an event. A view loads this file before its own script.
(() => {
  if (!window.Shiny || window.mascotStudioInputs) return;
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

  // Copies the text of the element that data-copy names, then says so on the button for a moment.
  const copy = (target) => {
    const source = document.getElementById(target.dataset.copy)?.textContent || '';
    if (!target.dataset.label) target.dataset.label = target.textContent;
    const label = target.dataset.label;
    const done = (ok) => {
      target.textContent = ok ? 'Copied' : 'Copy failed';
      setTimeout(() => {
        target.textContent = label;
      }, 1500);
    };
    // The clipboard API needs a secure page; a studio opened by a network address falls back to a selection copy.
    const fallback = () => {
      const field = document.createElement('textarea');
      field.value = source;
      field.setAttribute('readonly', '');
      field.style.position = 'fixed';
      field.style.opacity = '0';
      document.body.append(field);
      field.select();
      let ok = false;
      try {
        ok = document.execCommand('copy');
      } catch {
        ok = false;
      }
      field.remove();
      done(ok);
    };
    if (navigator.clipboard && window.isSecureContext)
      navigator.clipboard.writeText(source).then(() => done(true), fallback);
    else fallback();
  };

  // A button or link with data-event sends data-value (or "click") as input$<data-event>, with any module prefix
  // already in the name. A page can answer an event in the browser instead, with mascotStudioInputs.on().
  const handlers = new Map();
  document.addEventListener('click', (event) => {
    const target = event.target.closest('button, a');
    if (!target || target.getAttribute('aria-disabled') === 'true') return;
    if (target.dataset.event) {
      if (target.tagName === 'A') event.preventDefault();
      const handler = handlers.get(target.dataset.event);
      if (handler) handler(target.dataset.value);
      else window.Shiny.setInputValue(target.dataset.event, target.dataset.value || 'click', { priority: 'event' });
    } else if (target.dataset.copy) copy(target);
  });
  window.mascotStudioInputs = {
    on: (name, handler) => handlers.set(name, handler),
  };
})();
