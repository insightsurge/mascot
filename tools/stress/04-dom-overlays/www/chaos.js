document.addEventListener('DOMContentLoaded', () => {
  const noise = document.getElementById('noise');
  new MutationObserver(() => {
    for (const child of noise.children) {
      if (!child.hasAttribute('data-rewritten')) child.setAttribute('data-rewritten', 'true');
    }
  }).observe(noise, { childList: true, subtree: true, attributes: true });
  const binding = new Shiny.InputBinding();
  Object.assign(binding, {
    find: (scope) => $(scope).find('.stress-input'),
    getValue: (el) => el.value,
    subscribe: (el, callback) => $(el).on('change.stress', () => callback(false)),
    unsubscribe: (el) => $(el).off('.stress'),
  });
  Shiny.inputBindings.register(binding, 'stress.input');
  document.getElementById('chaos').addEventListener('click', () => {
    for (let i = 0; i < 200; i++) {
      const copy = noise.firstElementChild.cloneNode(true);
      copy.removeAttribute('data-rewritten');
      noise.append(copy);
      window.dispatchEvent(new Event('resize'));
    }
    const helper = document.getElementById('helper');
    helper.append(helper.querySelector('canvas').cloneNode(true));
    document.getElementById('moved').append(helper);
    const input = document.getElementById('custom');
    input.value = '200';
    $(input).trigger('change');
    window.stressMutationsDone = true;
  });
});
