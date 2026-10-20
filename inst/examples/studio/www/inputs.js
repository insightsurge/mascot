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

  // A role's picker (R/shared-colours.R role_picker()) is marked is-changed while it differs from its listed colour,
  // including after a reset from the server (receiveMessage() triggers a jQuery change).
  $(document).on('input change', '.pg-role[data-default] > .pg-colour', (event) => {
    const role = event.currentTarget.closest('.pg-role');
    role.classList.toggle('is-changed', event.currentTarget.value.toLowerCase() !== role.dataset.default.toLowerCase());
  });

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
  // The visible part of the page: the visual viewport when the phone keyboard or zoom changes it.
  const viewportBounds = () => {
    const viewport = window.visualViewport;
    const left = viewport?.offsetLeft || 0;
    const top = viewport?.offsetTop || 0;
    const width = viewport?.width || innerWidth;
    const height = viewport?.height || innerHeight;
    return { left, top, width, height, right: left + width, bottom: top + height };
  };

  // The sentence bar (R/shared-layout.R): each word's tooltip stays inside the visible viewport, and touch shows it.
  const positionWordTooltip = (word) => {
    const tooltip = word?.querySelector('.pg-word-tooltip');
    if (!tooltip) return;
    const rect = word.getBoundingClientRect();
    const { left, top, right, bottom } = viewportBounds();
    tooltip.style.left = `${Math.max(left + 8, Math.min(rect.left, right - tooltip.offsetWidth - 8))}px`;
    tooltip.style.top = `${Math.max(top + 8, Math.min(rect.bottom + 8, bottom - tooltip.offsetHeight - 8))}px`;
  };
  document.addEventListener('pointerover', (event) => positionWordTooltip(event.target.closest('.pg-sentence-word')));
  document.addEventListener('pointerdown', (event) => {
    if (event.pointerType === 'mouse') return;
    const word = event.target.closest('.pg-sentence-word');
    for (const item of document.querySelectorAll('.pg-sentence-word'))
      item.classList.toggle('is-touch-help', item === word);
    positionWordTooltip(word);
  });
  document.addEventListener('focusin', (event) => positionWordTooltip(event.target.closest('.pg-sentence-word')));

  // Each sentence select is as wide as its chosen word, and "in a"/"in an" follows the mood.
  const sizeSentence = () => {
    const article = document.getElementById('mood_article');
    const moodLabel = document.getElementById('mood')?.selectedOptions[0]?.textContent || '';
    const wanted = /^[aeiou]/i.test(moodLabel) ? 'in an' : 'in a';
    if (article && article.textContent !== wanted) article.textContent = wanted;
    for (const select of document.querySelectorAll('.pg-sentence select')) {
      const measure = document.createElement('span');
      measure.textContent = select.selectedOptions[0]?.textContent || '';
      measure.style.font = getComputedStyle(select).font;
      measure.style.position = 'absolute';
      measure.style.visibility = 'hidden';
      document.body.append(measure);
      // Native sentence selects have no arrow and only 2px padding on either side.
      const width = `${Math.ceil(measure.getBoundingClientRect().width) + 4}px`;
      measure.remove();
      if (select.style.width !== width) select.style.width = width;
    }
  };

  // A page marked data-sentence="auto" sizes its sentence here; the studio sizes its own with more of its words.
  const startSentence = () => {
    const page = document.querySelector('[data-sentence="auto"]');
    if (!page) return;
    sizeSentence();
    $(document).on('change', '.pg-sentence select', sizeSentence);
    window.addEventListener('resize', () => requestAnimationFrame(sizeSentence));
    new MutationObserver(sizeSentence).observe(page.querySelector('.pg-sentence'), { childList: true, subtree: true });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', startSentence);
  else startSentence();

  window.mascotStudioInputs = {
    on: (name, handler) => handlers.set(name, handler),
    viewportBounds,
    positionWordTooltip,
    sizeSentence,
  };
})();
