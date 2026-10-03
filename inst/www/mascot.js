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
   * readCharacter(id, doc): the character description that the page carries in
   * <script type="application/json" data-mascot-character="id">, parsed. doc defaults to document.
   */
  ns.readCharacter = (id, doc) => {
    const el = (doc || document).querySelector(`script[type="application/json"][data-mascot-character="${id}"]`);
    if (!el) throw new Error(`mascot: no description of the character '${id}' on this page`);
    return JSON.parse(el.textContent);
  };

  /**
   * draw(ctx, character, x, baseY, pose, frame): draws one frame of a character with its feet on baseY.
   * character: a parsed description (inst/characters/<id>.json). pose: optional fields, including `mood`, which
   * applies the character's own pose for that mood first. frame: a whole number (default 0).
   */
  ns.draw = (ctx, character, x, baseY, pose, frame) => {
    if (!character || typeof character !== 'object' || !character.colours) {
      throw new Error('mascot: draw() needs a character description');
    }
    const given = pose || {};
    let mood = {};
    if (given.mood !== undefined) {
      if (!character.moods || !Object.hasOwn(character.moods, given.mood)) {
        throw new Error(`mascot: the character '${character.id}' has no mood '${given.mood}'`);
      }
      mood = character.moods[given.mood];
    }
    const t = (frame || 0) / ns.fps;
    const p = Object.assign({}, ns.drawing.defaultPose, character.pose || {}, mood, given, { t });
    ns.drawing.character(ctx, character, x, baseY, p);
  };
})();
