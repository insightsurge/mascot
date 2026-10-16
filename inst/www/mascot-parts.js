/* Character-format v1 part transforms. Copyright (c) Harsh Verma; MIT. */
(() => {
  window.mascot = window.mascot || {};
  const ns = window.mascot;
  if (ns.parts) return;

  const identity = () => [1, 0, 0, 1, 0, 0];
  const problem = (code, path, message) => {
    const error = new Error(`${path}: ${message}`);
    Object.assign(error, { code, path });
    throw error;
  };
  const number = (value, path, low = -Infinity, high = Infinity) => {
    if (typeof value !== 'number') problem('input_type', path, 'Supply a number.');
    if (!Number.isFinite(value)) problem('non_finite', path, 'Use a finite number.');
    if (value < low || value > high) problem('input_type', path, 'Use a value in the documented range.');
    return value;
  };
  const matrix = (value, path = '$.matrix') => {
    if (!Array.isArray(value) || value.length !== 6) problem('input_type', path, 'Supply six matrix entries.');
    value.forEach((entry, index) => {
      number(entry, `${path}[${index}]`);
    });
    return value;
  };
  const multiply = (left, right) => {
    matrix(left);
    matrix(right);
    const [a, b, c, d, e, f] = left;
    const [g, h, i, j, k, l] = right;
    return [a * g + c * h, b * g + d * h, a * i + c * j, b * i + d * j, a * k + c * l + e, b * k + d * l + f];
  };
  const point = (transform, position) => {
    matrix(transform);
    if (!Array.isArray(position) || position.length !== 2) problem('input_type', '$.point', 'Supply a two-vector.');
    const [x, y] = position.map((entry, index) => number(entry, `$.point[${index}]`));
    return [transform[0] * x + transform[2] * y + transform[4], transform[1] * x + transform[3] * y + transform[5]];
  };
  const translation = (x, y) => [1, 0, 0, 1, x, y];
  const rotation = (angle) => [Math.cos(angle), Math.sin(angle), -Math.sin(angle), Math.cos(angle), 0, 0];
  const scaling = (x, y) => [x, 0, 0, y, 0, 0];
  const determinant = (transform) => transform[0] * transform[3] - transform[1] * transform[2];
  const collapsed = (transform) => Math.abs(determinant(transform)) < 1e-12;
  const value = (channels, key, fallback) => (Object.hasOwn(channels, key) ? channels[key] : fallback);
  // Data-named keys (part, anchor, accessory, variant ids) may equal Object.prototype names such as
  // `constructor`; read only the object's own properties.
  const own = (object, key) => (object != null && Object.hasOwn(object, key) ? object[key] : undefined);
  const vector = (entries, fallback, path) => {
    const result = entries ?? fallback;
    if (!Array.isArray(result) || result.length !== 2) problem('input_type', path, 'Supply a two-vector.');
    return result.map((entry, index) => number(entry, `${path}[${index}]`, -4096, 4096));
  };
  const scale = (entry, path) => {
    const result = Array.isArray(entry) ? entry : [entry ?? 1, entry ?? 1];
    if (result.length !== 2) problem('input_type', path, 'Supply a scalar or two-vector.');
    return result.map((axis, index) => number(axis, `${path}[${index}]`, -16, 16));
  };

  const root = (height, channels = {}, host = {}) => {
    number(height, '$.ground.centre_height', 0, 4096);
    const x = number(host.x ?? 150, '$.host.x');
    const y = number(host.base_y ?? 270, '$.host.base_y');
    const lift = number(value(channels, 'root.lift', 0), '$.channels.root.lift', -4096, 4096);
    const angle = number(value(channels, 'root.rotate', 0), '$.channels.root.rotate');
    const sx = number(value(channels, 'root.scale_x', 1), '$.channels.root.scale_x', -16, 16);
    const sy = number(value(channels, 'root.scale_y', 1), '$.channels.root.scale_y', -16, 16);
    const flip = value(channels, 'root.flip', 1);
    if (flip !== 1 && flip !== -1) problem('invalid_channel', '$.channels.root.flip', 'Choose 1 or -1.');
    return multiply(
      multiply(
        multiply(multiply(translation(x, y - lift), scaling(flip * sx, sy)), translation(0, -height)),
        rotation(angle),
      ),
      translation(0, height),
    );
  };

  // Consume the local translation before filtering inherited orientation. QR has
  // positive diagonal; reflection is defined as the inherited x-axis reflection.
  const child = (parent, part, channels = {}) => {
    matrix(parent);
    const path = part.path ?? `$.parts.${part.id}`;
    const at = vector(part.at, [0, 0], `${path}.at`);
    const offset = ['x', 'y'].map((axis) =>
      number(value(channels, `${part.id}.${axis}`, 0), `${path}.${axis}`, -4096, 4096),
    );
    const pivot = point(parent, [at[0] + offset[0], at[1] + offset[1]]);
    if (collapsed(parent)) return [0, 0, 0, 0, ...pivot];
    let [a, b, c, d] = parent;
    const reflection = determinant(parent) < 0 ? -1 : 1;
    if (part.keep_upright) {
      const first = Math.hypot(a, b);
      const second = Math.abs(determinant(parent)) / first;
      [a, b, c, d] = [first * (part.no_flip ? 1 : reflection), 0, 0, second];
    } else if (part.no_flip) {
      a *= reflection;
      b *= reflection;
    }
    const resting = scale(part.scale, `${path}.scale`);
    const sx = number(value(channels, `${part.id}.scale_x`, resting[0]), `${path}.scale_x`, -16, 16);
    const sy = number(value(channels, `${part.id}.scale_y`, resting[1]), `${path}.scale_y`, -16, 16);
    const angle = number(value(channels, `${part.id}.rotate`, part.rotate ?? 0), `${path}.rotate`);
    return multiply(multiply([a, b, c, d, ...pivot], rotation(angle)), scaling(sx, sy));
  };
  const freeze = (object) => {
    if (object && typeof object === 'object') {
      Object.values(object).forEach(freeze);
      Object.freeze(object);
    }
    return object;
  };
  const channelVocabulary = (source, byId) => {
    const rules = Object.create(null);
    const add = (name, type, base, lower = -Infinity, upper = Infinity, choices = null) => {
      rules[name] = { type, base, lower, upper, choices };
    };
    add('root.lift', 'number', 0, -4096, 4096);
    add('root.rotate', 'number', 0);
    add('root.scale_x', 'number', 1, -16, 16);
    add('root.scale_y', 'number', 1, -16, 16);
    add('root.flip', 'choice', 1, -Infinity, Infinity, [1, -1]);

    for (const [id, part] of byId.entries()) {
      const restingScale = Array.isArray(part.scale) ? part.scale : [part.scale ?? 1, part.scale ?? 1];
      add(`${id}.x`, 'number', 0, -4096, 4096);
      add(`${id}.y`, 'number', 0, -4096, 4096);
      add(`${id}.rotate`, 'number', part.rotate ?? 0);
      add(`${id}.scale_x`, 'number', restingScale[0], -16, 16);
      add(`${id}.scale_y`, 'number', restingScale[1], -16, 16);
      add(`${id}.opacity`, 'number', part.opacity ?? 1, 0, 1);
      add(`${id}.visible`, 'boolean', part.visible ?? true);
      const variantChoices = ['default', ...Object.keys(part.variants ?? {})];
      add(`${id}.variant`, 'choice', 'default', -Infinity, Infinity, variantChoices);
    }

    if (source.face) {
      add('face.look_x', 'number', 0, -1, 1);
      add('face.look_y', 'number', 0, -1, 1);
      add('face.blink', 'number', 0, 0, 1);
      add('face.lid', 'number', 0, 0, 1);
      add('face.open', 'number', 1, 0, 1);
      const kit = source.face.kit_definition ?? (ns.faces?.readKit ? ns.faces.readKit(source.face.kit) : null) ?? {};
      const eyeChoices = Object.keys(kit.eye_styles ?? {});
      const mouthChoices = Object.keys(kit.mouth_styles ?? {});
      const browChoices = Object.keys(kit.brow_styles ?? {});
      add(
        'face.eyes',
        'eyes',
        kit.defaults?.eyes ?? 'open',
        -Infinity,
        Infinity,
        eyeChoices.length ? eyeChoices : null,
      );
      add(
        'face.mouth',
        'choice',
        kit.defaults?.mouth ?? 'smile',
        -Infinity,
        Infinity,
        mouthChoices.length ? mouthChoices : null,
      );
      add(
        'face.brows',
        'choice',
        kit.defaults?.brows ?? 'none',
        -Infinity,
        Infinity,
        browChoices.length ? browChoices : null,
      );
      add('face.blush', 'blush', kit.defaults?.blush ?? 0);
    }

    for (const [id] of Object.entries(source.effects ?? {})) {
      const kitEffect = source.face?.kit_definition?.effects?.[id];
      const isProgress = kitEffect?.mode === 'progress' || id === 'sweat';
      add(`effects.${id}`, isProgress ? 'number' : 'boolean', isProgress ? 0 : false, 0, 1);
    }
    return rules;
  };

  const validateChannelValue = (val, rule, path) => {
    let valid = false;
    switch (rule.type) {
      case 'number':
        valid = typeof val === 'number' && Number.isFinite(val) && val >= rule.lower && val <= rule.upper;
        break;
      case 'boolean':
        valid = typeof val === 'boolean';
        break;
      case 'choice':
        valid =
          (typeof val === 'string' || typeof val === 'number') &&
          (!rule.choices || rule.choices.includes(val) || rule.choices.includes(String(val)));
        break;
      case 'eyes':
        if (typeof val === 'string') {
          valid = !rule.choices || rule.choices.includes(val);
        } else if (Array.isArray(val) && (val.length === 1 || val.length === 2)) {
          valid = val.every((v) => typeof v === 'string' && (!rule.choices || rule.choices.includes(v)));
        }
        break;
      case 'blush':
        valid = val === 'strong' || (typeof val === 'number' && Number.isFinite(val) && val >= 0 && val <= 1);
        break;
    }
    if (!valid) {
      problem('invalid_channel', path, "Use the channel's declared type, range and membership.");
    }
  };

  const applyChannels = (base, channels, path, rules) => {
    const result = { ...base };
    for (const [target, val] of Object.entries(channels ?? {})) {
      const rule = rules[target];
      if (!rule) {
        problem('missing_reference', `${path}.${target}`, 'Name a declared channel target.');
      }
      validateChannelValue(val, rule, `${path}.${target}`);
      result[target] = val;
    }
    return result;
  };

  const swapMood = (outgoingCharacter, outgoingTargetMood, incomingCharacter) => {
    if (!outgoingCharacter || !outgoingTargetMood) return 'idle';
    if (incomingCharacter?.moods && Object.hasOwn(incomingCharacter.moods, outgoingTargetMood)) {
      return outgoingTargetMood;
    }
    let cursor = outgoingTargetMood;
    const seen = new Set();
    while (cursor && !seen.has(cursor)) {
      seen.add(cursor);
      const moodDef = outgoingCharacter.moods?.[cursor];
      if (!moodDef) break;
      const fallback = moodDef.fallback;
      if (!fallback) break;
      if (incomingCharacter?.moods && Object.hasOwn(incomingCharacter.moods, fallback)) {
        return fallback;
      }
      cursor = fallback;
    }
    return 'idle';
  };

  const sweatProgress = (u, effect = {}) => {
    const progress = number(u ?? 0, '$.sweat.u', 0, 1);
    if (progress <= 0) return { x: 0, y: 0, opacity: 0, visible: false };
    const sway = effect.sway ?? 2;
    const swayRate = effect.sway_rate ?? 12;
    const travel = effect.travel ?? 26;
    const fadeAt = effect.fade_at ?? 0.9;
    const x = sway * Math.sin(progress * swayRate);
    const y = progress * travel;
    const opacity = progress <= fadeAt ? 1 : (1 - progress) / (1 - fadeAt);
    return { x, y, opacity, visible: opacity > 0 };
  };

  const sparklePulse = (t, effect = {}, options = {}) => {
    if (options.reduced) {
      const hasReducedItems = Array.isArray(effect.reduced_items) && effect.reduced_items.length > 0;
      return { scale: 1, reduced: true, items: 'reduced', visible: hasReducedItems };
    }
    const amplitude = number(effect.amplitude ?? 0.18, '$.sparkle.amplitude', 0, 0.5);
    const rate = number(effect.rate ?? 9, '$.sparkle.rate', Number.MIN_VALUE, 30);
    const deadline = options.activity_deadline ?? 150;
    const frame = options.frame ?? t * 30;
    const elapsed = Math.min(frame, deadline) / 30;
    const scale = 1 + amplitude * Math.sin(rate * elapsed);
    return { scale, reduced: false, visible: true };
  };

  const resolveChannels = (compiled, mood, options = {}) => {
    const moodId = mood ?? 'idle';
    const base = options.reduced
      ? (compiled.reducedBases?.[moodId] ?? compiled.moodBases?.[moodId] ?? compiled.resting ?? {})
      : (compiled.moodBases?.[moodId] ?? compiled.resting ?? {});
    const channels = { ...base };
    if (options.pose) {
      Object.assign(channels, options.pose);
    }
    if (options.overrides) {
      Object.assign(channels, options.overrides);
    }
    return channels;
  };

  const resolveColours = (compiled, mood, colours = {}, options = {}) => {
    const moodId = mood ?? 'idle';
    const recolourMap = options.reduced
      ? (compiled.reducedRecolour?.[moodId] ?? compiled.recolour?.[moodId] ?? {})
      : (compiled.recolour?.[moodId] ?? {});
    const result = { ...colours };
    const userOverrides = options.userOverrides;
    for (const [role, dest] of Object.entries(recolourMap)) {
      if (userOverrides && Object.hasOwn(userOverrides, role)) {
        result[role] = userOverrides[role];
      } else if (Object.hasOwn(colours, dest)) {
        result[role] = colours[dest];
      }
    }
    return result;
  };

  const resolveItems = (compiled, mood, options = {}) => {
    const moodId = mood ?? 'idle';
    return options.reduced
      ? (compiled.reducedItems?.[moodId] ?? compiled.items?.[moodId] ?? {})
      : (compiled.items?.[moodId] ?? {});
  };

  // E5b detail bands. The host passes the band from the canvas's untransformed CSS width, compared unrounded:
  // full from 128 px, small from 48 px, micro below 48 px. Micro never inherits small.
  const bands = ['full', 'small', 'micro'];
  const bandFor = (width) => {
    if (typeof width !== 'number' || !Number.isFinite(width) || width < 0)
      problem('input_type', '$.width', 'Use a finite CSS width in pixels.');
    return width >= 128 ? 'full' : width >= 48 ? 'small' : 'micro';
  };
  const plainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
  const bandOverrideKeys = ['hide', 'outline', 'face', 'glow', 'variants', 'note'];
  const faceFlagKeys = ['scale', 'lashes', 'brows', 'iris'];
  // Rejects unknown band names and keys, and micro glow, at compile time: policy wins, nothing is dropped silently.
  const checkBands = (source) => {
    if (source.lod !== undefined) {
      if (!plainObject(source.lod)) problem('input_type', '$.lod', 'Use an object of band overrides.');
      for (const [band, override] of Object.entries(source.lod)) {
        const path = `$.lod.${band}`;
        // full is the file as written, not an authored override (R rejects lod.full the same way).
        if (!['small', 'micro'].includes(band)) problem('unknown_key', path, 'Author lod.small or lod.micro only.');
        if (!plainObject(override)) problem('input_type', path, 'Use an object of band overrides.');
        for (const key of Object.keys(override)) {
          if (!bandOverrideKeys.includes(key))
            problem('unknown_key', `${path}.${key}`, 'Use hide, outline, face, glow, variants or note.');
        }
        if (override.glow !== undefined && typeof override.glow !== 'boolean')
          problem('input_type', `${path}.glow`, 'Use true or false.');
        // Drawing-budget diagnostics use code budget and root path $ (contract); the message names the band and key.
        if (band === 'micro' && override.glow === true)
          problem(
            'budget',
            '$',
            'band micro: lod.micro.glow is true, but micro has no glow emitters or blur; remove lod.micro.glow or set it to false',
          );
        if (override.face !== undefined) {
          if (!plainObject(override.face)) problem('input_type', `${path}.face`, 'Use an object of face flags.');
          for (const key of Object.keys(override.face)) {
            if (!faceFlagKeys.includes(key))
              problem('unknown_key', `${path}.face.${key}`, 'Use scale, lashes, brows or iris.');
          }
        }
      }
    }
    (source.parts ?? []).forEach((part, index) => {
      if (part.lod === undefined) return;
      if (!Array.isArray(part.lod)) problem('input_type', `$.parts[${index}].lod`, 'Use a list of bands.');
      part.lod.forEach((band, at) => {
        if (!bands.includes(band))
          problem('unknown_key', `$.parts[${index}].lod[${at}]`, 'Use the full, small or micro band.');
      });
    });
  };

  const compile = (character) => {
    if (!character || !Array.isArray(character.parts)) problem('input_type', '$.parts', 'Supply a part array.');
    if (character.format_version !== 1) problem('version', '$.format_version', 'Use character format 1.');
    // Never retain mutable caller-owned templates. This stage is not the R checker.
    const source = JSON.parse(JSON.stringify(character));
    checkBands(source);
    const parts = [];
    const byId = new Map();
    const insert = (part, path, attachment = null) => {
      if (
        typeof part.id !== 'string' ||
        !/^[a-z][a-z0-9_]*$/.test(part.id) ||
        ['root', 'face', 'effects'].includes(part.id)
      ) {
        problem('input_type', `${path}.id`, 'Use a non-reserved part id.');
      }
      if (byId.has(part.id)) problem('input_type', `${path}.id`, 'Keep part ids unique.');
      const record = { ...part, path, attachment, index: parts.length, parent: part.parent ?? 'root' };
      parts.push(record);
      byId.set(part.id, record);
    };
    source.parts.forEach((part, index) => {
      insert(part, `$.parts[${index}]`);
    });
    const slots = new Set();
    const worn = new Set();
    for (const [index, id] of (source.wear ?? []).entries()) {
      if (worn.has(id)) problem('input_type', `$.wear[${index}]`, 'Wear each accessory once.');
      worn.add(id);
      const accessory = own(source.accessories, id);
      if (!accessory) problem('missing_reference', `$.wear[${index}]`, 'Name a declared accessory.');
      if (slots.has(accessory.slot)) problem('input_type', `$.wear[${index}]`, 'Wear only one accessory in each slot.');
      slots.add(accessory.slot);
      const anchor = own(source.anchors, accessory.anchor);
      if (!anchor) problem('missing_reference', `$.accessories.${id}.anchor`, 'Name a declared anchor.');
      const prefix = `wear_${id}_`;
      const local = new Set(accessory.parts.map((part) => part.id));
      accessory.parts.forEach((part, partIndex) => {
        const parent = part.parent ?? 'root';
        if (parent !== 'root' && !local.has(parent)) {
          problem(
            'missing_reference',
            `$.accessories.${id}.parts[${partIndex}].parent`,
            'Name a local accessory part.',
          );
        }
        insert(
          { ...part, id: prefix + part.id, parent: parent === 'root' ? 'root' : prefix + parent },
          `$.accessories.${id}.parts[${partIndex}]`,
          parent === 'root' ? { id: accessory.anchor, lod: accessory.lod } : null,
        );
      });
    }
    for (const [id, anchor] of Object.entries(source.anchors ?? {})) {
      if (!byId.has(anchor.part)) problem('missing_reference', `$.anchors.${id}.part`, 'Name a declared part.');
    }
    const ordered = [];
    const marks = new Map();
    const visit = (part) => {
      if (marks.get(part.id) === 1)
        problem('missing_reference', `${part.path}.parent`, 'Remove the part/anchor dependency cycle.');
      if (marks.get(part.id) === 2) return;
      marks.set(part.id, 1);
      const parent = part.attachment ? own(source.anchors, part.attachment.id).part : part.parent;
      if (parent !== 'root') {
        if (!byId.has(parent)) problem('missing_reference', `${part.path}.parent`, 'Name a declared parent part.');
        visit(byId.get(parent));
      }
      marks.set(part.id, 2);
      ordered.push(part.id);
    };
    parts.forEach(visit);

    const rules = channelVocabulary(source, byId);
    const resting = Object.fromEntries(Object.entries(rules).map(([k, r]) => [k, r.base]));

    for (const [poseId, poseChannels] of Object.entries(source.poses ?? {})) {
      applyChannels(resting, poseChannels, `$.poses.${poseId}`, rules);
    }

    for (const part of parts) {
      if (part.switch) {
        const sw = part.switch;
        const swPath = `${part.path}.switch`;
        if (typeof sw.channel !== 'string' || !rules[sw.channel] || rules[sw.channel].type !== 'number') {
          problem('invalid_channel', `${swPath}.channel`, 'Use a declared numeric threshold channel.');
        }
        number(sw.above, `${swPath}.above`);
        if (typeof sw.variant !== 'string' || !part.variants || !Object.hasOwn(part.variants, sw.variant)) {
          problem('missing_reference', `${swPath}.variant`, 'Select a declared variant.');
        }
      }
    }

    const coreMoods = ['idle', 'thinking', 'happy', 'worried', 'celebrating'];
    const moodBases = Object.create(null);
    const reducedBases = Object.create(null);
    const recolourMaps = Object.create(null);
    const reducedRecolourMaps = Object.create(null);
    const itemOverrides = Object.create(null);
    const reducedItemOverrides = Object.create(null);

    if (source.moods) {
      for (const core of coreMoods) {
        if (!Object.hasOwn(source.moods, core)) {
          problem('missing_reference', `$.moods.${core}`, 'Supply every core mood.');
        }
      }

      for (const [id, mood] of Object.entries(source.moods)) {
        const path = `$.moods.${id}`;
        if (!mood.description || typeof mood.description !== 'string') {
          problem('input_type', `${path}.description`, 'Supply nonempty mood metadata after defaults.');
        }
        if (!mood.status || typeof mood.status !== 'string') {
          problem('input_type', `${path}.status`, 'Supply nonempty mood metadata after defaults.');
        }
        if (coreMoods.includes(id) && mood.fallback !== undefined && mood.fallback !== null) {
          problem('input_type', `${path}.fallback`, 'Core moods have no fallback.');
        }
        let cursor = id;
        const seen = new Set();
        while (!coreMoods.includes(cursor)) {
          if (seen.has(cursor)) {
            problem('missing_reference', `${path}.fallback`, 'Remove the cyclic mood fallback chain.');
          }
          seen.add(cursor);
          const nextId = source.moods[cursor]?.fallback;
          if (!nextId || !Object.hasOwn(source.moods, nextId)) {
            problem(
              'missing_reference',
              `$.moods.${cursor}.fallback`,
              'End the fallback chain at a declared core mood.',
            );
          }
          cursor = nextId;
        }

        let base = { ...resting };
        if (mood.pose) {
          if (!own(source.poses, mood.pose)) {
            problem('missing_reference', `${path}.pose`, 'Name a declared pose.');
          }
          base = applyChannels(base, source.poses[mood.pose], `$.poses.${mood.pose}`, rules);
        }

        const moodBase = applyChannels(base, mood.channels, `${path}.channels`, rules);
        if (mood.face) {
          for (const [key, val] of Object.entries(mood.face)) {
            const target = `face.${key}`;
            const rule = rules[target];
            if (!rule) problem('missing_reference', `${path}.face.${key}`, 'Name a declared channel target.');
            validateChannelValue(val, rule, `${path}.face.${key}`);
            moodBase[target] = val;
          }
        }
        if (mood.effects) {
          for (const [key, val] of Object.entries(mood.effects)) {
            const target = `effects.${key}`;
            const rule = rules[target];
            if (!rule) problem('missing_reference', `${path}.effects.${key}`, 'Name a declared channel target.');
            validateChannelValue(val, rule, `${path}.effects.${key}`);
            moodBase[target] = val;
          }
        }
        moodBases[id] = moodBase;

        let redBase = { ...moodBase };
        if (mood.reduced) {
          if (mood.reduced.channels) {
            redBase = applyChannels(redBase, mood.reduced.channels, `${path}.reduced.channels`, rules);
          }
          if (mood.reduced.face) {
            for (const [key, val] of Object.entries(mood.reduced.face)) {
              const target = `face.${key}`;
              const rule = rules[target];
              if (!rule) problem('missing_reference', `${path}.reduced.face.${key}`, 'Name a declared channel target.');
              validateChannelValue(val, rule, `${path}.reduced.face.${key}`);
              redBase[target] = val;
            }
          }
          if (mood.reduced.effects) {
            for (const [key, val] of Object.entries(mood.reduced.effects)) {
              const target = `effects.${key}`;
              const rule = rules[target];
              if (!rule)
                problem('missing_reference', `${path}.reduced.effects.${key}`, 'Name a declared channel target.');
              validateChannelValue(val, rule, `${path}.reduced.effects.${key}`);
              redBase[target] = val;
            }
          }
        }
        reducedBases[id] = redBase;

        const validateRecolour = (recolourObj, recolourPath) => {
          const mapping = Object.create(null);
          if (!recolourObj) return mapping;
          for (const [role, dest] of Object.entries(recolourObj)) {
            if (source.colours) {
              if (!Object.hasOwn(source.colours, role) || !Object.hasOwn(source.colours, dest)) {
                problem('invalid_colour', `${recolourPath}.${role}`, 'Redirect between declared colour roles.');
              }
            }
            let cur = role;
            const visited = new Set();
            while (cur && Object.hasOwn(recolourObj, cur)) {
              if (visited.has(cur)) {
                problem('invalid_colour', `${recolourPath}.${role}`, 'Remove the recolour cycle.');
              }
              visited.add(cur);
              cur = recolourObj[cur];
            }
            mapping[role] = cur;
          }
          return mapping;
        };

        recolourMaps[id] = validateRecolour(mood.recolour, `${path}.recolour`);
        const redRecolour = { ...mood.recolour, ...(mood.reduced?.recolour ?? {}) };
        reducedRecolourMaps[id] = validateRecolour(redRecolour, `${path}.reduced.recolour`);

        const validateItems = (itemsObj, itemsPath) => {
          const overrides = Object.create(null);
          if (!itemsObj) return overrides;
          for (const [target, spec] of Object.entries(itemsObj)) {
            const partsPair = target.split('.');
            if (partsPair.length !== 2) {
              problem('missing_reference', `${itemsPath}.${target}`, 'Name a declared item as part.item.');
            }
            const [partId, itemId] = partsPair;
            const part = byId.get(partId);
            if (!part) {
              problem('missing_reference', `${itemsPath}.${target}`, 'Name a declared item.');
            }
            const allItems = [...(part.items ?? [])];
            for (const vList of Object.values(part.variants ?? {})) {
              allItems.push(...vList);
            }
            if (!allItems.some((it) => it.id === itemId)) {
              problem('missing_reference', `${itemsPath}.${target}`, 'Name a declared item.');
            }
            for (const field of ['fill', 'stroke']) {
              if (typeof spec[field] === 'string' && source.colours) {
                const colourRole = spec[field];
                const paints = source.paints ?? {};
                if (!Object.hasOwn(source.colours, colourRole) && !Object.hasOwn(paints, colourRole)) {
                  problem('invalid_colour', `${itemsPath}.${target}.${field}`, 'Use a declared colour role or paint.');
                }
              }
            }
            if (spec.alpha !== undefined) {
              number(spec.alpha, `${itemsPath}.${target}.alpha`, 0, 1);
            }
            overrides[target] = spec;
          }
          return overrides;
        };

        itemOverrides[id] = validateItems(mood.items, `${path}.items`);
        const redItems = { ...mood.items, ...(mood.reduced?.items ?? {}) };
        reducedItemOverrides[id] = validateItems(redItems, `${path}.reduced.items`);
      }
    }

    return freeze({
      source,
      parts,
      order: ordered,
      rules,
      resting,
      moodBases,
      reducedBases,
      recolour: recolourMaps,
      reducedRecolour: reducedRecolourMaps,
      items: itemOverrides,
      reducedItems: reducedItemOverrides,
    });
  };

  const frame = (compiled, channels = {}, band = 'full', host = {}, options = {}) => {
    if (!['full', 'small', 'micro'].includes(band)) problem('input_type', '$.band', 'Choose a detail band.');
    const { source } = compiled;
    const actualOptions =
      options.mood !== undefined || options.items !== undefined || options.userOverrides !== undefined
        ? options
        : host.mood !== undefined || host.items !== undefined || host.userOverrides !== undefined
          ? host
          : options;
    const actualHost =
      host.x !== undefined || host.base_y !== undefined ? host : options.x !== undefined ? options : host;
    const activeChannels =
      Object.keys(channels).length === 0 && actualOptions.mood
        ? resolveChannels(compiled, actualOptions.mood, actualOptions)
        : channels;
    const rootMatrix = root(source.ground.centre_height, activeChannels, actualHost);
    const records = new Map(compiled.parts.map((part) => [part.id, part]));
    const states = Object.create(null);
    const anchors = Object.create(null);
    const lod = source.lod?.[band] ?? {};
    const hidden = new Set(lod.hide ?? []);
    const resolvedOverrides =
      actualOptions.items ?? (actualOptions.mood ? resolveItems(compiled, actualOptions.mood, actualOptions) : null);
    const itemOverridesMap = resolvedOverrides && Object.keys(resolvedOverrides).length > 0 ? resolvedOverrides : null;
    const anchorState = (id) => {
      if (anchors[id]) return anchors[id];
      const definition = own(source.anchors, id);
      if (!definition) problem('missing_reference', `$.anchors.${id}`, 'Name a declared anchor.');
      const owner = states[definition.part];
      if (!owner) problem('missing_reference', `$.anchors.${id}.part`, 'Resolve the owning part first.');
      const local = { ...definition, ...own(definition.variants, owner.variant) };
      const at = vector(local.at, [0, 0], `$.anchors.${id}.at`);
      const angle = number(local.rotate ?? 0, `$.anchors.${id}.rotate`);
      const size = number(local.scale ?? 1, `$.anchors.${id}.scale`, Number.MIN_VALUE, 16);
      const transform = multiply(
        multiply(multiply(owner.matrix, translation(...at)), rotation(angle)),
        scaling(size, size),
      );
      anchors[id] = {
        matrix: transform,
        available: owner.available && !collapsed(transform),
        side: definition.side,
      };
      return anchors[id];
    };
    for (const id of compiled.order) {
      const part = records.get(id);
      let parent =
        part.parent === 'root'
          ? { matrix: rootMatrix, available: !collapsed(rootMatrix), opacity: 1 }
          : states[part.parent];
      if (part.attachment) {
        const anchor = anchorState(part.attachment.id);
        parent = { ...anchor, opacity: states[own(source.anchors, part.attachment.id).part].opacity };
        if (part.attachment.lod && !part.attachment.lod.includes(band)) parent.available = false;
      }
      const transform = child(parent.matrix, part, activeChannels);
      const opacity =
        parent.opacity *
        number(value(activeChannels, `${id}.opacity`, part.opacity ?? 1), `${part.path}.opacity`, 0, 1);
      const visible = value(activeChannels, `${id}.visible`, part.visible ?? true);
      if (typeof visible !== 'boolean') problem('invalid_channel', `${part.path}.visible`, 'Supply a boolean.');
      let variant = value(activeChannels, `${id}.variant`, 'default');
      if (part.switch && value(activeChannels, part.switch.channel, 0) > part.switch.above)
        variant = part.switch.variant;
      variant = own(lod.variants, id) ?? variant;
      if (variant !== 'default' && !Object.hasOwn(part.variants ?? {}, variant)) {
        problem('missing_reference', `${part.path}.variants.${variant}`, 'Select a declared variant.');
      }
      const items = variant === 'default' ? (part.items ?? []) : part.variants[variant];
      states[id] = {
        matrix: transform,
        opacity,
        variant,
        items,
        available:
          parent.available &&
          visible &&
          !hidden.has(id) &&
          (!part.lod || part.lod.includes(band)) &&
          !collapsed(transform),
        layer: number(part.layer ?? 0, `${part.path}.layer`),
        index: part.index,
        path: part.path,
      };
    }
    Object.keys(source.anchors ?? {}).forEach(anchorState);
    const layers = Object.keys(states).sort(
      (left, right) => states[left].layer - states[right].layer || states[left].index - states[right].index,
    );
    const result = {
      root: rootMatrix,
      parts: states,
      anchors,
      layers,
      band,
      hidden: [...hidden],
    };
    if (itemOverridesMap) {
      result.item_overrides = itemOverridesMap;
    }
    return result;
  };

  ns.parts = Object.freeze({
    identity,
    own,
    multiply,
    point,
    root,
    child,
    compile,
    bandFor,
    frame,
    resolveChannels,
    resolveColours,
    resolveItems,
    swapMood,
    sweatProgress,
    sparklePulse,
  });
})();
