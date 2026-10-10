/**
 * mascot: entry point (window.mascot).
 *
 * Drawing is deterministic: a frame is a pure function of the character, the pose and a frame number. The
 * engine never reads the clock and never calls Math.random(). Load mascot-draw.js too (in either order).
 * Immutable descriptions are checked once for drawing structure and names; failures are cached too.
 * The colour guard is shared with the player, so malformed overrides fail before a state change.
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

  const checked = new WeakMap();

  // Shared by description colours and controller overrides: only the forms draw() understands.
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

  // Check the blocks every drawing branch dereferences, including branches absent in the default pose.
  // This runs once per immutable description, never on each frame; no canvas or dry raster draw is needed.
  function structure(ch) {
    const errors = [];
    const record = (value, field) => {
      if (!value || typeof value !== 'object' || Array.isArray(value)) {
        errors.push(`${field}: expected an object`);
        return false;
      }
      return true;
    };
    const numbers = (value, fields, at) => {
      for (const field of fields)
        if (!Number.isFinite(value[field])) errors.push(`${at}.${field}: expected a finite number`);
    };
    const minimum = (value, fields, at, limit = 0) => {
      for (const field of fields)
        if (value[field] !== undefined && value[field] < limit)
          errors.push(`${at}.${field}: expected at least ${limit}`);
    };
    const array = (value, at, item) => {
      if (!Array.isArray(value)) errors.push(`${at}: expected an array`);
      else for (const [i, v] of value.entries()) item(v, `${at}[${i}]`);
    };
    const radius = (value, at) => {
      const values = Array.isArray(value) ? value : [value];
      if (!values.length || values.length > 4 || values.some((v) => !Number.isFinite(v) || v < 0))
        errors.push(`${at}: expected a non-negative radius or one to four radii`);
    };
    const rect = (value, at) => {
      if (!record(value, at)) return;
      numbers(value, ['x', 'y', 'w', 'h'], at);
      radius(value.r, `${at}.r`);
    };
    const parts = (value, at) =>
      array(value, at, (part, field) => {
        if (!record(part, field)) return;
        const required = { hexagon: ['r', 'corner'], circle: ['x', 'y', 'r'], rect: ['x', 'y', 'w', 'h'] };
        if (Object.hasOwn(required, part.shape)) numbers(part, required[part.shape], field);
        if (part.shape === 'circle') minimum(part, ['r'], field);
        if (part.shape === 'roundRect') rect(part, field);
        if (part.shape === 'path' && typeof part.d !== 'string') errors.push(`${field}.d: expected path text`);
      });
    for (const field of ['eyes', 'mouth'])
      if (record(ch.face[field], `face.${field}`))
        numbers(ch.face[field], field === 'eyes' ? ['y', 'spacing'] : ['y'], `face.${field}`);
    if (ch.face.blush !== undefined && record(ch.face.blush, 'face.blush'))
      numbers(ch.face.blush, ['x', 'y', 'rx', 'ry', 'alpha', 'strongAlpha'], 'face.blush');
    if (ch.face.blush && typeof ch.face.blush === 'object') minimum(ch.face.blush, ['rx', 'ry'], 'face.blush');
    for (const field of ['style', 'outline']) if (ch.face[field] !== undefined) record(ch.face[field], `face.${field}`);
    if (ch.face.style && typeof ch.face.style === 'object')
      for (const [name, value] of Object.entries(ch.face.style)) {
        if (!record(value, `face.style.${name}`)) continue;
        minimum(value, ['r', 'pr'], `face.style.${name}`);
        minimum(value, ['ew', 'eh'], `face.style.${name}`, 1);
        for (const [key, v] of Object.entries(value)) {
          if (name === 'lashes' && ['two', 'three'].includes(key))
            array(v, `face.style.${name}.${key}`, (n, at) => {
              if (!Number.isFinite(n)) errors.push(`${at}: expected a finite number`);
            });
          else if (!Number.isFinite(v)) errors.push(`face.style.${name}.${key}: expected a finite number`);
        }
      }
    parts(ch.body, 'body');
    for (const field of ['anchors', 'accessories', 'arms', 'feet', 'shadow', 'pose', 'motion'])
      if (ch[field] !== undefined) record(ch[field], field);
    if (ch.anchors && typeof ch.anchors === 'object')
      for (const [name, value] of Object.entries(ch.anchors))
        if (record(value, `anchors.${name}`)) numbers(value, ['x', 'y'], `anchors.${name}`);
    if (ch.shadow && typeof ch.shadow === 'object') {
      numbers(ch.shadow, ['rx', 'ry', 'alpha'], 'shadow');
      minimum(ch.shadow, ['rx', 'ry'], 'shadow');
    }
    if (ch.arms && typeof ch.arms === 'object') {
      numbers(ch.arms, ['length', 'width'], 'arms');
      minimum(ch.arms, ['width'], 'arms');
      if (record(ch.arms.paw, 'arms.paw')) {
        numbers(ch.arms.paw, ['offset', 'r'], 'arms.paw');
        minimum(ch.arms.paw, ['r'], 'arms.paw');
      }
      if (record(ch.arms.presets, 'arms.presets'))
        for (const [name, value] of Object.entries(ch.arms.presets))
          if (record(value, `arms.presets.${name}`)) numbers(value, ['L', 'R'], `arms.presets.${name}`);
      record(ch.anchors?.shoulders, 'anchors.shoulders');
    }
    if (ch.feet && typeof ch.feet === 'object') {
      array(ch.feet.stand, 'feet.stand', rect);
      if (record(ch.feet.tuck, 'feet.tuck')) {
        numbers(ch.feet.tuck, ['x', 'y', 'rotate'], 'feet.tuck');
        rect(ch.feet.tuck.rect, 'feet.tuck.rect');
      }
    }
    if (ch.accessories && typeof ch.accessories === 'object')
      for (const [name, value] of Object.entries(ch.accessories)) {
        const at = `accessories.${name}`;
        if (!record(value, at)) continue;
        parts(value.parts, `${at}.parts`);
        if (value.colours !== undefined && record(value.colours, `${at}.colours`))
          for (const [role, colour] of Object.entries(value.colours))
            if (!ns.validColour(colour)) errors.push(`${at}.colours.${role}: invalid colour '${String(colour)}'`);
      }
    for (const [name, value] of Object.entries(ch.moods)) record(value, `moods.${name}`);
    if (ch.motion && typeof ch.motion === 'object') {
      for (const field of ['change', 'idle', 'gestures'])
        if (ch.motion[field] !== undefined) record(ch.motion[field], `motion.${field}`);
      if (ch.motion.gestures && typeof ch.motion.gestures === 'object')
        for (const [name, value] of Object.entries(ch.motion.gestures)) {
          const at = `motion.gestures.${name}`;
          if (!record(value, at)) continue;
          if (value.timeline !== undefined) {
            array(value.timeline, `${at}.timeline`, (point, field) => {
              if (record(point, field)) {
                numbers(point, ['at'], field);
                record(point.pose, `${field}.pose`);
              }
            });
            if (Array.isArray(value.timeline) && !value.timeline.length)
              errors.push(`${at}.timeline: expected at least one keyframe`);
          }
        }
    }
    for (const [role, value] of Object.entries(ch.colours))
      if (!ns.validColour(value)) errors.push(`colours.${role}: invalid colour '${String(value)}'`);
    return errors;
  }

  /** Browser draw-structure/name guard. Cache successes and failures for immutable descriptions. */
  ns.validateCharacter = (ch) => {
    if (!ch || typeof ch !== 'object' || Array.isArray(ch))
      return ['character: draw() needs a character description object'];
    if (!checked.has(ch)) checked.set(ch, validateDescription(ch));
    const errors = checked.get(ch);
    return errors.length ? [...errors] : ns.motion ? ns.motion.validate(ch) : [];
  };

  function validateDescription(ch) {
    if (!ch || typeof ch !== 'object' || Array.isArray(ch))
      return ['character: draw() needs a character description object'];
    const errors = [];
    for (const field of ['id', 'name', 'centreHeight', 'colours', 'body', 'face', 'moods']) {
      if (!Object.hasOwn(ch, field)) errors.push(`${field} is missing`);
    }
    if (errors.length) return errors;
    for (const field of ['id', 'name'])
      if (typeof ch[field] !== 'string' || !ch[field].trim()) errors.push(`${field}: expected a non-empty string`);
    for (const field of ['colours', 'face', 'moods'])
      if (!ch[field] || typeof ch[field] !== 'object' || Array.isArray(ch[field]))
        errors.push(`${field}: expected an object`);
    if (!Array.isArray(ch.body)) errors.push('body: expected an array');
    if (!Number.isFinite(ch.centreHeight)) errors.push('centreHeight: expected a finite number');
    if (errors.length) return errors;
    errors.push(...structure(ch));
    if (errors.length) return errors;
    if (!Object.keys(ch.moods).length) errors.push('moods: expected at least one mood');
    if (ns.motion) errors.push(...ns.motion.validate(ch));
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
        if (part.shape === 'rect' && part.fill === undefined) errors.push(`${at}.fill is missing`);
        for (const key of ['fill', 'stroke']) if (part[key] !== undefined) role(part[key], `${at}.${key}`);
        if (part.shape === 'path') {
          try {
            ns.drawing.svgPath(ns.drawing.pathGuard, part.d);
          } catch (e) {
            errors.push(`${at}.d: ${e.message}`);
          }
        }
      });
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
        ns.drawing.resolvePose(ch, field === 'pose' ? {} : { mood: field.slice('moods.'.length) }, 0);
      } catch (e) {
        errors.push(e.message.replace('mascot: ', ''));
      }
    }
    return errors;
  }

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
