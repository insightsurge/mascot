// Inputs that every view of the studio app shares: the colour picker as a Shiny input, copy buttons, and buttons
// or links that send an event. A view loads this file before its own script.
(() => {
  if (!window.Shiny || window.mascotStudioInputs) return;
  const $ = window.jQuery;
  const waitingColours = new Set();
  const receivingColours = new WeakSet();
  const choiceRevisions = new Map();
  const receivingChoices = new WeakSet();
  const initialChoices = new WeakMap();
  $(document).on('shiny:bound', (event) => {
    if (event.bindingType === 'input' && event.target.closest('[data-choice-input]')) {
      initialChoices.set(event.target, event.binding.getValue(event.target));
    }
  });
  // Linked controls share a revision counter. Server replies carry the counter they answer and never count as
  // another user choice, including the change event sent by Shiny's native input bindings.
  $(document).on('shiny:inputchanged', (event) => {
    if (event.el?.matches('.pg-colour')) waitingColours.delete(event.el);
    const control = event.el?.closest('[data-choice-input]');
    if (control || event.el?.id === 'character') flushColours();
    if (!control) return;
    if (receivingChoices.has(event.el)) {
      event.preventDefault();
      return;
    }
    if (initialChoices.has(event.el)) {
      // Binding a drawn control reports its starting value; that report is not another user choice.
      const initial = initialChoices.get(event.el);
      initialChoices.delete(event.el);
      if (event.value === initial) return;
    }
    const group = control.dataset.choiceInput;
    const revision = (choiceRevisions.get(group) || 0) + 1;
    choiceRevisions.set(group, revision);
    window.Shiny.setInputValue(`${group}_revision`, revision);
    window.Shiny.setInputValue(`${event.name}_revision`, revision);
    window.Shiny.forgetLastInputValue(event.name);
  });
  $(document).on('shiny:updateinput', (event) => {
    const { group, revision } = event.message;
    if (!group) return;
    event.preventDefault();
    const el = event.target;
    initialChoices.delete(el);
    const stale = revision < (choiceRevisions.get(group) || 0);
    if (stale && !event.message.options) return;
    // A character's palette options are still needed when its selected value answers an older choice.
    const message = stale ? { ...event.message, value: event.binding.getValue(el) } : event.message;
    receivingChoices.add(el);
    Promise.resolve(event.binding.receiveMessage(el, message)).finally(() => {
      window.Shiny.forgetLastInputValue(el.id);
      receivingChoices.delete(el);
    });
  });
  // A redrawn output can also answer an older choice. Its HTML carries the same stamp as a control update.
  const colourDrawings = new Map();
  $(document).on('shiny:value', (event) => {
    if (typeof event.value?.html !== 'string' || !event.value.html.includes('data-colour-revision')) return;
    const content = document.createElement('template');
    content.innerHTML = event.value.html;
    const choice = content.content.querySelector('[data-choice-revision]');
    if (choice && Number(choice.dataset.choiceRevision) < (choiceRevisions.get(choice.dataset.choiceGroup) || 0)) {
      event.preventDefault();
      return;
    }
    const drawing = content.content.querySelector('[data-colour-revision]');
    if (!drawing) return;
    const revision = Number(drawing.dataset.colourRevision);
    if (revision < (colourDrawings.get(event.name) || 0)) event.preventDefault();
    else colourDrawings.set(event.name, revision);
  });
  // input type="color" as a Shiny input. CSS-variable pickers also set their variable on the page.
  class ColourBinding extends window.Shiny.InputBinding {
    find(scope) {
      return $(scope).find('input.pg-colour');
    }
    getValue(el) {
      const drawing = el.closest('[data-colour-revision]');
      return drawing
        ? {
            value: el.value,
            revision: Number(drawing.dataset.colourRevision),
            edit: Number(el.dataset.colourEdit || 0),
          }
        : el.value;
    }
    setValue(el, value) {
      el.value = value;
    }
    subscribe(el, callback) {
      if (el.dataset.cssVar) document.documentElement.style.setProperty(el.dataset.cssVar, el.value);
      $(el).on('input.pgColour change.pgColour', () => {
        if (el.dataset.cssVar) document.documentElement.style.setProperty(el.dataset.cssVar, el.value);
        if (receivingColours.has(el)) return;
        el.dataset.colourEdit = String(Number(el.dataset.colourEdit || 0) + 1);
        waitingColours.add(el);
        callback(true);
      });
    }
    unsubscribe(el) {
      waitingColours.delete(el);
      $(el).off('.pgColour');
    }
    receiveMessage(el, data) {
      const drawing = el.closest('[data-colour-revision]');
      if (drawing && data.revision !== Number(drawing.dataset.colourRevision)) return;
      if (drawing && data.edit < Number(el.dataset.colourEdit || 0)) return;
      if (typeof data.value === 'string') {
        el.value = data.value;
        receivingColours.add(el);
        try {
          $(el).trigger('change');
        } finally {
          receivingColours.delete(el);
        }
        window.Shiny.forgetLastInputValue(el.id);
      }
    }
    getRatePolicy() {
      return { policy: 'debounce', delay: 250 };
    }
  }
  const colourBinding = new ColourBinding();
  window.Shiny.inputBindings.register(colourBinding, 'mascotStudio.colour');
  // An immediate send cancels Shiny's pending debounce for that input. Send waiting colours before the action's
  // event, so its result comes from the server state that includes those edits.
  const flushColours = () => {
    for (const el of waitingColours) {
      if (el.isConnected) window.Shiny.setInputValue(el.id, colourBinding.getValue(el));
    }
    waitingColours.clear();
  };

  // A role's picker (R/shared-colours.R role_picker()) is marked is-changed while it differs from its listed colour,
  // including after a reset from the server (receiveMessage() triggers a jQuery change).
  // A page may hide the reset button of an unchanged role: if that button has the focus, the role's picker takes it.
  $(document).on('input change', '.pg-role[data-default] > .pg-colour', (event) => {
    const role = event.currentTarget.closest('.pg-role');
    const changed = event.currentTarget.value.toLowerCase() !== role.dataset.default.toLowerCase();
    if (!changed && role.querySelector('.pg-role-reset') === document.activeElement) event.currentTarget.focus();
    role.classList.toggle('is-changed', changed);
  });

  // Copies the text of the element that data-copy names, then says so on the button for a moment. The text may be a
  // little behind the page: a change the visitor just made is applied by the server a moment later, and some changes
  // wait a moment more (a text box is applied when typing pauses). So a click does not copy at once. It sends a ticket
  // (input$copy_ticket) and copies when the server answers that ticket (copy_gate() in R/shared-ui.R), by which time
  // everything sent before the click has been applied and drawn. The button says "Copying" until then, and gives up
  // after a few seconds, for a server that does not answer.
  const copyWaiting = new Map();
  const copyHooks = [];
  let copyTickets = 0;
  window.Shiny.addCustomMessageHandler('studio:copy', ({ ticket }) => copyWaiting.get(ticket)?.());
  const copyViaSelection = (text) => {
    // Selecting the hidden field moves keyboard focus to it; give focus back to where it was (the copy button).
    const focused = document.activeElement;
    const field = document.createElement('textarea');
    field.value = text;
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
    if (focused?.isConnected) focused.focus({ preventScroll: true });
    return ok ? Promise.resolve() : Promise.reject(new Error('selection copy failed'));
  };
  // The clipboard API needs a secure page; a studio opened by a network address falls back to a selection copy, and so
  // does a page whose browser refuses the clipboard API (a studio shown in a frame without clipboard access, such as an
  // IDE's viewer). Where the browser takes the text as a promise, the write starts inside the click and the text arrives
  // with the answer.
  const writeClipboard = (text) => {
    if (!(navigator.clipboard && window.isSecureContext)) return text.then(copyViaSelection);
    if (window.ClipboardItem && navigator.clipboard.write) {
      const blob = text.then((value) => new Blob([value], { type: 'text/plain' }));
      return navigator.clipboard
        .write([new window.ClipboardItem({ 'text/plain': blob })])
        .catch(() => text.then(copyViaSelection));
    }
    return text.then((value) => navigator.clipboard.writeText(value).catch(() => copyViaSelection(value)));
  };
  const copy = (target) => {
    if (target.getAttribute('aria-busy') === 'true') return;
    flushColours();
    for (const hook of copyHooks) hook();
    if (!target.dataset.label) target.dataset.label = target.textContent;
    const label = target.dataset.label;
    const ticket = ++copyTickets;
    let timedOut = false;
    const answered = new Promise((resolve, reject) => {
      copyWaiting.set(ticket, resolve);
      setTimeout(() => {
        timedOut = true;
        reject(new Error('no answer'));
      }, 5000);
    });
    const text = answered.then(() => document.getElementById(target.dataset.copy)?.textContent || '');
    const done = (message) => {
      copyWaiting.delete(ticket);
      target.removeAttribute('aria-busy');
      // The server may have drawn the button again with its output while the copy waited (an example's code): say so
      // on the button that is on the page now.
      const shown = target.isConnected ? target : document.querySelector(`[data-copy="${target.dataset.copy}"]`);
      if (!shown) return;
      // A button drawn again has no remembered label yet: a click during the message must not take it as its label.
      if (!shown.dataset.label) shown.dataset.label = label;
      shown.textContent = message;
      setTimeout(() => {
        shown.textContent = label;
      }, 1500);
    };
    target.setAttribute('aria-busy', 'true');
    target.textContent = 'Copying\u2026';
    window.Shiny.setInputValue('copy_ticket', ticket, { priority: 'event' });
    writeClipboard(text).then(
      () => done('Copied'),
      () => done(timedOut ? 'Copy unavailable' : 'Copy failed'),
    );
  };

  // A button or link with data-event sends data-value (or "click") as input$<data-event>, with any module prefix
  // already in the name. A page can answer an event in the browser instead, with mascotStudioInputs.on().
  const handlers = new Map();
  document.addEventListener('click', (event) => {
    const target = event.target.closest('button, a');
    if (!target || target.getAttribute('aria-disabled') === 'true') return;
    if (target.dataset.event || target.dataset.busyLabel) flushColours();
    if (target.dataset.busyLabel && target.getAttribute('aria-busy') !== 'true') busy(target);
    if (target.dataset.event) {
      if (target.tagName === 'A') event.preventDefault();
      const handler = handlers.get(target.dataset.event);
      const value = target.dataset.busyClick || target.dataset.value || 'click';
      if (handler) handler(target.dataset.value);
      else window.Shiny.setInputValue(target.dataset.event, value, { priority: 'event' });
    } else if (target.dataset.copy) copy(target);
    else if (target.dataset.toggleClass) {
      // A button with data-toggle-class switches that class on the element data-toggle-target names.
      const on = document.getElementById(target.dataset.toggleTarget)?.classList.toggle(target.dataset.toggleClass);
      target.setAttribute('aria-pressed', String(Boolean(on)));
    }
  });

  // A frame says when the page inside it has loaded (data-loaded). The server draws a frame's tag first and the page
  // arrives a moment later, so a frame that is drawn is not yet a frame that is shown. A load event does not reach the
  // window from an element, only the document, and it does not bubble: listen on the document, while capturing.
  document.addEventListener(
    'load',
    (event) => {
      if (event.target.tagName === 'IFRAME') event.target.dataset.loaded = 'true';
    },
    true,
  );

  // A button with data-busy-label says so while the server works on its click: the label, aria-busy and aria-disabled
  // (not disabled, which would move keyboard focus from the button to the page), until the output data-busy-output
  // names shows the result of that click, or an error. Each click sends a number of
  // its own, and the server draws it into the result as data-busy-done (busy_done_mark() in R/shared-check.R), so a
  // result that answers an earlier click or a settings change doesn't count. Shiny's events are no sign of it:
  // shiny:value comes before the value is drawn (asynchronously), and "idle" comes before the values of the same
  // update. An output in a hidden tab sends its result when it is shown again. An error is drawn straight after
  // shiny:error. Shiny also reports a silent validation error (an empty output, no message) for an output in a tab
  // that has just been shown, a moment after it; that one is no answer to a click that came in between, so it is
  // ignored.
  const busyButtons = new Map();
  let clicks = 0;
  const busy = (button) => {
    const output = document.getElementById(button.dataset.busyOutput);
    if (!output) return;
    const click = String(++clicks);
    // The result is shown when it is drawn and the page inside any frame of it has loaded (data-loaded, set above).
    const check = () => {
      if (output.querySelector(`[data-busy-done="${click}"]`) && !output.querySelector('iframe:not([data-loaded])')) {
        done(button);
      }
    };
    const answered = new MutationObserver(check);
    answered.observe(output, { childList: true, subtree: true });
    document.addEventListener('load', check, true);
    busyButtons.set(button, () => {
      answered.disconnect();
      document.removeEventListener('load', check, true);
    });
    button.dataset.busyClick = click;
    button.dataset.idleLabel = button.textContent;
    button.textContent = button.dataset.busyLabel;
    button.setAttribute('aria-busy', 'true');
    button.setAttribute('aria-disabled', 'true');
  };
  const done = (button) => {
    const stop = busyButtons.get(button);
    if (!stop) return;
    stop();
    busyButtons.delete(button);
    delete button.dataset.busyClick;
    button.textContent = button.dataset.idleLabel;
    button.removeAttribute('aria-busy');
    button.removeAttribute('aria-disabled');
  };
  const silentError = (error) => {
    const types = [].concat(error?.type ?? []);
    return types.includes('shiny.silent.error') || !error?.message;
  };
  $(document).on('shiny:error', (event) => {
    if (silentError(event.error)) return;
    const buttons = [...busyButtons.keys()].filter((button) => button.dataset.busyOutput === event.name);
    queueMicrotask(() => buttons.forEach(done));
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

  // The server's note under a field it cannot use yet ({ id, text }; an empty text removes the note).
  window.Shiny.addCustomMessageHandler('studio:field-problem', ({ id, text }) => {
    const field = document.getElementById(id);
    if (!field) return;
    let note = document.getElementById(`${id}_problem`);
    if (!text) {
      field.removeAttribute('aria-invalid');
      field.removeAttribute('aria-describedby');
      note?.remove();
      return;
    }
    if (!note) {
      note = document.createElement('div');
      note.id = `${id}_problem`;
      note.className = 'pg-field-problem';
      note.setAttribute('role', 'status');
      field.after(note);
    }
    note.textContent = text;
    field.setAttribute('aria-invalid', 'true');
    field.setAttribute('aria-describedby', note.id);
  });

  window.mascotStudioInputs = {
    on: (name, handler) => handlers.set(name, handler),
    // Runs just before a copy button sends its ticket: a page that holds a change back itself sends it now.
    beforeCopy: (hook) => copyHooks.push(hook),
    viewportBounds,
    positionWordTooltip,
    sizeSentence,
  };
})();
