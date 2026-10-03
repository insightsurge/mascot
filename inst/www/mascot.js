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

  const record = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const HEX = /^#(?:[\da-f]{3}|[\da-f]{6})$/i;
  const SHAPES = ['hexagon', 'path', 'circle', 'roundRect', 'rect'];
  const EYES = ['open', 'wide', 'happy', 'blink', 'wink', 'focused', 'worried'];
  const MOUTHS = ['smile', 'smirk', 'proud', 'flat', 'grit', 'determined', 'o', 'grin'];
  const BROWS = ['none', 'neutral', 'raised', 'determined', 'angry', 'frown', 'worried', 'sad'];

  /** Checks the provisional description without changing it; every message names a field. */
  ns.validateCharacter = (ch) => {
    const errors = [];
    const object = (value, field) => {
      if (record(value)) return true;
      errors.push(`${field} must be an object`);
      return false;
    };
    const number = (value, field, min = -Infinity) => {
      if (!Number.isFinite(value) || value < min) {
        errors.push(`${field} must be a finite number${min === -Infinity ? '' : ` >= ${min}`}`);
      }
    };
    const numbers = (value, field, keys, min = -Infinity) => {
      if (object(value, field)) for (const key of keys) number(value[key], `${field}.${key}`, min);
    };
    const choice = (value, field, choices) => {
      if (!choices.includes(value)) errors.push(`${field} '${value}' is not one of ${choices.join(', ')}`);
    };
    const detail = (value, field) => {
      if (value.detail !== undefined) choice(value.detail, `${field}.detail`, ['full', 'simple']);
    };
    const boolean = (value, field) => {
      if (typeof value !== 'boolean') errors.push(`${field} must be a boolean`);
    };
    if (!record(ch)) return ['character: draw() needs a character description object'];
    const c = record(ch.colours) ? ch.colours : {};
    object(ch.colours, 'colours');
    const role = (name) => {
      if (!Object.hasOwn(c, name)) errors.push(`colours.${name} is missing`);
    };
    for (const name of ['body', 'outline', 'feature', 'eyeWhite', 'shine', 'teeth', 'eyelid', 'tongue']) role(name);
    for (const [name, value] of Object.entries(c)) {
      if (typeof value !== 'string' || !HEX.test(value))
        errors.push(`colours.${name} must be a #RGB or #RRGGBB colour`);
    }
    number(ch.centreHeight, 'centreHeight', 0);

    const radius = (value, field) => {
      if (Array.isArray(value)) {
        if (!value.length || value.length > 4) errors.push(`${field} must have 1 to 4 radii`);
        value.forEach((r, i) => {
          number(r, `${field}[${i}]`, 0);
        });
      } else number(value, field, 0);
    };
    const rectangle = (value, field) => {
      if (!object(value, field)) return;
      numbers(value, field, ['x', 'y']);
      numbers(value, field, ['w', 'h'], 0);
      radius(value.r, `${field}.r`);
      detail(value, field);
    };
    const parts = (value, field) => {
      if (!Array.isArray(value)) {
        errors.push(`${field} must be an array of parts`);
        return;
      }
      value.forEach((part, i) => {
        const at = `${field}[${i}]`;
        if (!object(part, at)) return;
        choice(part.shape, `${at}.shape`, SHAPES);
        detail(part, at);
        if (part.shape === 'hexagon') numbers(part, at, ['r', 'corner'], 0);
        if (part.shape === 'circle') {
          numbers(part, at, ['x', 'y']);
          number(part.r, `${at}.r`, 0);
        }
        if (part.shape === 'roundRect') rectangle(part, at);
        if (part.shape === 'rect') {
          numbers(part, at, ['x', 'y']);
          numbers(part, at, ['w', 'h'], 0);
          if (!part.fill) errors.push(`${at}.fill is missing`);
        }
        if (part.shape === 'path') {
          if (typeof part.d !== 'string' || !part.d.trim()) errors.push(`${at}.d must be a non-empty path`);
          else {
            const noop = () => {};
            try {
              ns.drawing.svgPath(
                {
                  beginPath: noop,
                  closePath: noop,
                  moveTo: noop,
                  lineTo: noop,
                  quadraticCurveTo: noop,
                  bezierCurveTo: noop,
                },
                part.d,
              );
            } catch (e) {
              errors.push(`${at}.d: ${e.message}`);
            }
          }
        }
        for (const key of ['fill', 'stroke']) {
          if (part[key] !== undefined) {
            if (typeof part[key] !== 'string') errors.push(`${at}.${key} must name a colour role`);
            else role(part[key]);
          }
        }
        if (part.alpha !== undefined) {
          number(part.alpha, `${at}.alpha`, 0);
          if (part.alpha > 1) errors.push(`${at}.alpha must be <= 1`);
        }
        if (part.lineWidth !== undefined) number(part.lineWidth, `${at}.lineWidth`, 0);
        if (part.round !== undefined) boolean(part.round, `${at}.round`);
      });
    };
    parts(ch.body, 'body');
    if (Array.isArray(ch.body) && !ch.body.length) errors.push('body must contain at least one part');
    if (object(ch.face, 'face')) {
      numbers(ch.face.eyes, 'face.eyes', ['y', 'spacing']);
      if (ch.face.eyes?.spacing < 0) errors.push('face.eyes.spacing must be >= 0');
      numbers(ch.face.mouth, 'face.mouth', ['y']);
      if (ch.face.lashes !== undefined) boolean(ch.face.lashes, 'face.lashes');
      if (ch.face.blush !== undefined && object(ch.face.blush, 'face.blush')) {
        numbers(ch.face.blush, 'face.blush', ['x', 'y']);
        numbers(ch.face.blush, 'face.blush', ['rx', 'ry', 'alpha', 'strongAlpha'], 0);
        for (const key of ['alpha', 'strongAlpha']) {
          if (ch.face.blush[key] > 1) errors.push(`face.blush.${key} must be <= 1`);
        }
        role('blush');
        role('blushStrong');
      }
      if (ch.face.style !== undefined && object(ch.face.style, 'face.style')) {
        for (const [group, style] of Object.entries(ch.face.style)) {
          const field = `face.style.${group}`;
          const defaults = ns.drawing.faceStyle[group];
          if (!Object.hasOwn(ns.drawing.faceStyle, group)) {
            errors.push(`${field} is not a face style group`);
            continue;
          }
          if (!object(style, field)) continue;
          for (const [key, value] of Object.entries(style)) {
            const at = `${field}.${key}`;
            if (!Object.hasOwn(defaults, key)) errors.push(`${at} is not a face style field`);
            else if (Array.isArray(defaults[key])) {
              if (!Array.isArray(value)) errors.push(`${at} must be an array of angles`);
              else
                value.forEach((v, i) => {
                  number(v, `${at}[${i}]`);
                });
            } else {
              const positive = [
                'ew',
                'eh',
                'pr',
                'r',
                'lineWidth',
                'neutralLineWidth',
                'length',
                'lashW',
                'lashH',
              ].includes(key);
              number(value, at, positive ? Number.MIN_VALUE : -Infinity);
              if (['ew', 'eh'].includes(key) && value <= 1) errors.push(`${at} must be > 1 for the eye clip`);
            }
          }
        }
      }
    }
    if (ch.anchors !== undefined && object(ch.anchors, 'anchors')) {
      for (const [name, at] of Object.entries(ch.anchors)) {
        const field = `anchors.${name}`;
        if (!object(at, field)) continue;
        numbers(at, field, ['x', 'y']);
        if (at.rotate !== undefined) number(at.rotate, `${field}.rotate`);
        if (at.scale !== undefined) number(at.scale, `${field}.scale`, Number.MIN_VALUE);
        detail(at, field);
      }
    }
    if (ch.shadow !== undefined && object(ch.shadow, 'shadow')) {
      numbers(ch.shadow, 'shadow', ['rx', 'ry', 'alpha'], 0);
      if (ch.shadow.alpha > 1) errors.push('shadow.alpha must be <= 1');
      detail(ch.shadow, 'shadow');
      role('shadow');
    }
    if (ch.feet !== undefined && object(ch.feet, 'feet')) {
      number(ch.feet.lineWidth, 'feet.lineWidth', 0);
      if (!Array.isArray(ch.feet.stand)) errors.push('feet.stand must be an array');
      else
        ch.feet.stand.forEach((ft, i) => {
          rectangle(ft, `feet.stand[${i}]`);
        });
      if (object(ch.feet.tuck, 'feet.tuck')) {
        numbers(ch.feet.tuck, 'feet.tuck', ['x', 'y', 'rotate']);
        rectangle(ch.feet.tuck.rect, 'feet.tuck.rect');
        detail(ch.feet.tuck, 'feet.tuck');
      }
      detail(ch.feet, 'feet');
      role('limb');
    }
    if (ch.arms !== undefined && object(ch.arms, 'arms')) {
      numbers(ch.arms, 'arms', ['length', 'width'], Number.MIN_VALUE);
      numbers(ch.arms.paw, 'arms.paw', ['offset', 'r'], 0);
      numbers(ch.anchors?.shoulders, 'anchors.shoulders', ['x', 'y']);
      if (object(ch.arms.presets, 'arms.presets')) {
        if (!Object.hasOwn(ch.arms.presets, 'idle')) errors.push('arms.presets.idle is missing');
        for (const [name, preset] of Object.entries(ch.arms.presets))
          numbers(preset, `arms.presets.${name}`, ['L', 'R']);
      }
      detail(ch.arms, 'arms');
      role('limb');
      role('sleeve');
    }
    if (ch.anchors?.sweat) role('sweat');
    if (ch.anchors?.sparkle) {
      role('sparkle');
      role('sparkleOutline');
    }
    if (ch.accessories !== undefined && object(ch.accessories, 'accessories')) {
      if (!ch.anchors?.head) errors.push('anchors.head is missing for accessories');
      for (const [name, value] of Object.entries(ch.accessories)) parts(value, `accessories.${name}`);
    }
    const pose = (p, field) => {
      if (!object(p, field)) return;
      for (const [key, choices] of Object.entries({
        eyes: EYES,
        mouth: MOUTHS,
        brows: BROWS,
        detail: ['full', 'simple'],
        feet: ['auto', 'tuck', 'stand'],
      })) {
        if (p[key] !== undefined && !(key === 'brows' && p[key] === null)) choice(p[key], `${field}.${key}`, choices);
      }
      for (const key of ['scale', 'sx', 'sy', 'lift', 'rot', 'flip', 'look', 'lookY', 'blink', 'armJitter', 't']) {
        if (p[key] !== undefined) number(p[key], `${field}.${key}`);
      }
      for (const key of ['armL', 'armR'])
        if (p[key] !== undefined && p[key] !== null) number(p[key], `${field}.${key}`);
      for (const key of ['shadow', 'sparkle']) if (p[key] !== undefined) boolean(p[key], `${field}.${key}`);
      if (p.blush !== undefined && ![true, false, 'strong'].includes(p.blush))
        errors.push(`${field}.blush must be a boolean or 'strong'`);
      if (p.sweat !== undefined && typeof p.sweat !== 'boolean') number(p.sweat, `${field}.sweat`);
      if (
        ch.arms !== undefined &&
        p.arms !== undefined &&
        (!record(ch.arms?.presets) || !Object.hasOwn(ch.arms.presets, p.arms))
      ) {
        errors.push(`${field}.arms '${p.arms}' is not an arm preset`);
      }
      if (
        ch.accessories !== undefined &&
        p.accessory !== undefined &&
        p.accessory !== 'none' &&
        (!record(ch.accessories) || !Object.hasOwn(ch.accessories, p.accessory))
      ) {
        errors.push(`${field}.accessory '${p.accessory}' is not an accessory`);
      }
    };
    if (ch.pose !== undefined) pose(ch.pose, 'pose');
    if (object(ch.moods, 'moods')) for (const [name, value] of Object.entries(ch.moods)) pose(value, `moods.${name}`);
    return errors;
  };

  /**
   * draw(ctx, character, x, baseY, pose, frame, colours): draws one frame with its feet on baseY.
   * character: a parsed description (inst/characters/<id>.json). pose: optional fields, including `mood`, which
   * applies the character's own pose for that mood first. frame: a whole number (default 0).
   * colours: optional role overrides for this draw only; neither object is changed.
   */
  ns.draw = (ctx, character, x, baseY, pose, frame, colours) => {
    const errors = ns.validateCharacter(character);
    if (errors.length) throw new Error(`mascot: ${errors[0]}`);
    const given = pose || {};
    const p = ns.drawing.resolvePose(character, given, frame || 0);
    if (!['full', 'simple'].includes(p.detail))
      throw new Error(`mascot: pose.detail '${p.detail}' is not full or simple`);
    let palette = character.colours;
    if (colours !== undefined) {
      if (!record(colours)) throw new Error('mascot: colours override must be an object');
      for (const [role, value] of Object.entries(colours)) {
        if (typeof value !== 'string' || !HEX.test(value))
          throw new Error(`mascot: colours.${role} must be a #RGB or #RRGGBB colour`);
      }
      palette = { ...palette, ...colours };
    }
    ns.drawing.character(ctx, character, x, baseY, p, palette);
  };
})();
