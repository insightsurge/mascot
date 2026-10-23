/**
 * mascot: entry point (window.mascot).
 *
 * The small helpers every other engine file shares: the frame rate, reading a character description from the page and
 * the colour guard. Drawing is deterministic: a frame is a pure function of the character, its state and a frame
 * number. The engine never reads the clock to draw and never calls Math.random().
 *
 * window.mascot.version is the version of the R package this engine belongs to: R gives this file's script tag a
 * data-mascot-version attribute. A page that loads a second engine of another version keeps the first one and says so
 * once in the console. Where a page drops the script's attributes, the host takes the version from the first mascot it
 * mounts, which carries the same attribute.
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  const version = document.currentScript?.dataset.mascotVersion ?? null;
  if (ns.readCharacter) {
    if (version !== null && typeof ns.version === 'string' && version !== ns.version)
      console.warn(
        `mascot: this page loads engine version ${version} after version ${ns.version}; ` +
          `version ${ns.version} stays in use. Load one version of mascot per page.`,
      );
    return;
  }

  /** The package version of this engine, or null when the page loaded the file without it. */
  ns.version = version;

  /** Frames per second: converts animation-frame timestamps into the frame numbers the player draws. */
  ns.fps = 30;

  /**
   * characterScript(id, scope): the <script type="application/json" data-mascot-character="id"> element that holds a
   * character description, or null. A custom character's block sits inside its mascot element; a built-in character's
   * block sits once in the page head, outside every mascot. With a mascot element as scope, its own block wins, then
   * the page's copy; a block inside another mascot is never used. scope defaults to document, which searches the whole
   * page.
   */
  ns.characterScript = (id, scope) => {
    const selector = `script[type="application/json"][data-mascot-character="${id}"]`;
    const own = (scope || document).querySelector(selector);
    if (own || !scope || scope === document) return own;
    return Array.from(document.querySelectorAll(selector)).find((el) => !el.closest('.mascot')) || null;
  };

  /** readCharacter(id, scope): the character description characterScript(id, scope) finds, parsed. */
  ns.readCharacter = (id, scope) => {
    const el = ns.characterScript(id, scope);
    if (!el) throw new Error(`mascot: no description of the character '${id}' on this page`);
    return JSON.parse(el.textContent);
  };

  // The colour forms the engine accepts, for theme colours and colour overrides alike: #RGB, #RRGGBB, rgb() and
  // rgba() with channels in range. The host and the player use it to refuse a malformed colour before any change.
  ns.validColour = (value) => {
    if (typeof value !== 'string') return false;
    if (/^#(?:[0-9a-f]{3}|[0-9a-f]{6})$/i.test(value)) return true;
    const match = /^(rgb|rgba)\((.*)\)$/i.exec(value);
    if (!match) return false;
    const channels = match[2].split(',').map((channel) => channel.trim());
    if (channels.length !== (match[1].toLowerCase() === 'rgb' ? 3 : 4)) return false;
    return channels.every((channel, i) => {
      const number = Number(channel);
      return (
        /^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?$/i.test(channel) &&
        Number.isFinite(number) &&
        number >= 0 &&
        number <= (i === 3 ? 1 : 255)
      );
    });
  };
})();
