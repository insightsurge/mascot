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
  const compile = (character) => {
    if (!character || !Array.isArray(character.parts)) problem('input_type', '$.parts', 'Supply a part array.');
    if (character.format_version !== 1) problem('version', '$.format_version', 'Use character format 1.');
    // Never retain mutable caller-owned templates. This stage is not the R checker.
    const source = JSON.parse(JSON.stringify(character));
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
      const accessory = source.accessories?.[id];
      if (!accessory) problem('missing_reference', `$.wear[${index}]`, 'Name a declared accessory.');
      if (slots.has(accessory.slot)) problem('input_type', `$.wear[${index}]`, 'Wear only one accessory in each slot.');
      slots.add(accessory.slot);
      const anchor = source.anchors?.[accessory.anchor];
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
      const parent = part.attachment ? source.anchors[part.attachment.id].part : part.parent;
      if (parent !== 'root') {
        if (!byId.has(parent)) problem('missing_reference', `${part.path}.parent`, 'Name a declared parent part.');
        visit(byId.get(parent));
      }
      marks.set(part.id, 2);
      ordered.push(part.id);
    };
    parts.forEach(visit);
    return freeze({ source, parts, order: ordered });
  };

  const frame = (compiled, channels = {}, band = 'full', host = {}) => {
    if (!['full', 'small', 'micro'].includes(band)) problem('input_type', '$.band', 'Choose a detail band.');
    const { source } = compiled;
    const rootMatrix = root(source.ground.centre_height, channels, host);
    const records = new Map(compiled.parts.map((part) => [part.id, part]));
    const states = Object.create(null);
    const anchors = Object.create(null);
    const lod = source.lod?.[band] ?? {};
    const hidden = new Set(lod.hide ?? []);
    const anchorState = (id) => {
      if (anchors[id]) return anchors[id];
      const definition = source.anchors[id];
      if (!definition) problem('missing_reference', `$.anchors.${id}`, 'Name a declared anchor.');
      const owner = states[definition.part];
      if (!owner) problem('missing_reference', `$.anchors.${id}.part`, 'Resolve the owning part first.');
      const local = { ...definition, ...definition.variants?.[owner.variant] };
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
        parent = { ...anchor, opacity: states[source.anchors[part.attachment.id].part].opacity };
        if (part.attachment.lod && !part.attachment.lod.includes(band)) parent.available = false;
      }
      const transform = child(parent.matrix, part, channels);
      const opacity =
        parent.opacity * number(value(channels, `${id}.opacity`, part.opacity ?? 1), `${part.path}.opacity`, 0, 1);
      const visible = value(channels, `${id}.visible`, part.visible ?? true);
      if (typeof visible !== 'boolean') problem('invalid_channel', `${part.path}.visible`, 'Supply a boolean.');
      let variant = value(channels, `${id}.variant`, 'default');
      if (part.switch && value(channels, part.switch.channel, 0) > part.switch.above) variant = part.switch.variant;
      variant = lod.variants?.[id] ?? variant;
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
    return { root: rootMatrix, parts: states, anchors, layers, band, hidden: [...hidden] };
  };

  ns.parts = Object.freeze({ identity, multiply, point, root, child, compile, frame });
})();
