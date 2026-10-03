/**
 * mascot: entry point (window.mascot).
 *
 * Drawing is deterministic: a frame is a pure function of the character, the pose and a frame number. The
 * engine never reads the clock and never calls Math.random(). Load mascot-draw.js too (in either order).
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.draw) return;

  /** Frames per second: converts a frame number into the seconds the drawing code uses. */
  ns.fps = 30;

  /**
   * draw(ctx, character, x, baseY, pose, frame): draws one frame of a character with its feet on baseY.
   * character: 'tessa' for now. frame: a whole number (default 0).
   */
  ns.draw = (ctx, character, x, baseY, pose, frame) => {
    const characters = ns.drawing ? ns.drawing.characters : {};
    if (!Object.hasOwn(characters, character)) {
      throw new Error(`mascot: unknown character '${character}'`);
    }
    const t = (frame || 0) / ns.fps;
    characters[character](ctx, x, baseY, Object.assign({}, pose || {}, { t }));
  };
})();
