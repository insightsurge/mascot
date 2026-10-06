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

  const checked = new WeakSet();

  /** Thin browser guard; R owns types and numeric ranges. Descriptions are immutable after first use. */
  ns.validateCharacter = (ch) => {
    if (!ch || typeof ch !== 'object') return ['character: draw() needs a character description object'];
    const errors = ns.motion ? ns.motion.validate(ch) : [];
    if (checked.has(ch)) return errors;
    for (const field of ['id', 'name', 'centreHeight', 'colours', 'body', 'face', 'moods', 'small']) {
      if (!Object.hasOwn(ch, field)) errors.push(`${field} is missing`);
    }
    if (errors.length) return errors;
    for (const field of ['eyes', 'mouth']) if (!Object.hasOwn(ch.face, field)) errors.push(`face.${field} is missing`);
    const role = (name, field) => {
      if (!Object.hasOwn(ch.colours, name)) errors.push(`${field}: colour role '${name}' is not in colours`);
    };
    for (const name of ['body', 'outline', 'feature', 'eyeWhite', 'shine', 'teeth', 'eyelid', 'tongue']) {
      if (!Object.hasOwn(ch.colours, name)) errors.push(`colours.${name} is missing`);
    }
    const parts = (items, field) =>
      items.forEach((part, i) => {
        const at = `${field}[${i}]`;
        if (!ns.drawing.names.shape.includes(part.shape)) errors.push(`${at}.shape: unknown shape '${part.shape}'`);
        if (part.shape === 'rect' && part.stroke !== undefined) errors.push(`${at}.stroke: rect is fill-only`);
        for (const key of ['fill', 'stroke']) if (part[key] !== undefined) role(part[key], `${at}.${key}`);
        if (part.shape === 'path') {
          try {
            ns.drawing.svgPath(ns.drawing.pathGuard, part.d);
          } catch (e) {
            errors.push(`${at}.d: ${e.message}`);
          }
        }
      });
    for (const name of ch.small.hide || []) {
      if (!ns.drawing.names.hide.includes(name)) errors.push(`small.hide: unknown name '${name}'`);
    }
    for (const field of ['faceScale', 'minLineWidth', 'hide']) {
      if (!Object.hasOwn(ch.small, field)) errors.push(`small.${field} is missing`);
    }
    for (const [group, fields] of Object.entries(ch.face.style || {})) {
      if (!Object.hasOwn(ns.drawing.faceStyle, group)) {
        errors.push(`face.style.${group}: unknown group '${group}'`);
        continue;
      }
      for (const key of Object.keys(fields))
        if (!Object.hasOwn(ns.drawing.faceStyle[group], key))
          errors.push(`face.style.${group}.${key}: unknown field '${key}'`);
    }
    for (const [key, value] of Object.entries(ch.face.outline || {})) {
      const choices = key === 'join' ? ['miter', 'round', 'bevel'] : ['butt', 'round', 'square'];
      if (!['leftCap', 'rightCap', 'join'].includes(key) || !choices.includes(value))
        errors.push(`face.outline.${key}: unknown name '${value}'`);
    }
    for (const [field, roles] of [
      ['shadow', ['shadow']],
      ['arms', ['limb', 'sleeve']],
      ['feet', ['limb']],
    ]) {
      if (ch[field]) for (const name of roles) role(name, field);
    }
    if (ch.face.blush) for (const name of ['blush', 'blushStrong']) role(name, 'face.blush');
    if (Object.hasOwn(ch.anchors || {}, 'sweat')) role('sweat', 'anchors.sweat');
    if (Object.hasOwn(ch.anchors || {}, 'sparkle'))
      for (const name of ['sparkle', 'sparkleOutline']) role(name, 'anchors.sparkle');
    parts(ch.body, 'body');
    for (const name of Object.keys(ch.anchors || {})) {
      if (!ns.drawing.names.anchor.includes(name)) errors.push(`anchors.${name}: unknown anchor '${name}'`);
    }
    if (ch.arms) {
      for (const field of ['presets', 'paw'])
        if (!Object.hasOwn(ch.arms, field)) errors.push(`arms.${field} is missing`);
      if (!Object.hasOwn(ch.anchors || {}, 'shoulders')) errors.push('anchors.shoulders is missing for arms');
    }
    for (const [name, item] of Object.entries(ch.accessories || {})) {
      const at = `accessories.${name}`;
      if (!Object.hasOwn(item, 'parts')) {
        errors.push(`${at}.parts is missing`);
        continue;
      }
      if (!Object.hasOwn(item, 'slot')) errors.push(`${at}.slot is missing`);
      if (!ns.drawing.names.anchor.includes(item.anchor || 'hair'))
        errors.push(`${at}.anchor: unknown anchor '${item.anchor}'`);
      for (const key of Object.keys(item.colours || {})) role(key, `${at}.colours`);
      parts(item.parts, `${at}.parts`);
      try {
        ns.drawing.guardPose(ch, { accessory: name }, at);
      } catch (e) {
        errors.push(e.message.replace('mascot: ', ''));
      }
    }
    for (const [field, pose] of [
      ['pose', ch.pose || {}],
      ...Object.entries(ch.moods).map(([name, pose]) => [`moods.${name}`, pose]),
    ]) {
      try {
        ns.drawing.guardPose(ch, pose, field);
      } catch (e) {
        errors.push(e.message.replace('mascot: ', ''));
      }
    }
    if (!errors.length) checked.add(ch);
    return errors;
  };

  /** draw(ctx, character, { x, baseY, pose, frame, colours }): one deterministic frame. */
  ns.draw = (ctx, character, { x = 0, baseY = 0, pose = {}, frame = 0, colours } = {}) => {
    const errors = ns.validateCharacter(character);
    if (errors.length) throw new Error(`mascot: ${errors[0]}`);
    const p = ns.drawing.resolvePose(character, pose, frame);
    for (const role of Object.keys(colours || {})) {
      if (!Object.hasOwn(character.colours, role)) throw new Error(`mascot: colours: unknown role '${role}'`);
    }
    ns.drawing.character(ctx, character, x, baseY, p, { ...character.colours, ...colours });
  };
})();
