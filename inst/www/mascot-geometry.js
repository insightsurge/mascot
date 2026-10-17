/* Character-format v1 shapes, paints and clips. Copyright (c) Harsh Verma; MIT. */
(() => {
  window.mascot = window.mascot || {};
  const ns = window.mascot;
  if (ns.geometry) return;
  const fail = (code, path, message) => {
    const error = new Error(`${path}: ${message}`);
    Object.assign(error, { code, path });
    throw error;
  };
  const finite = (value, path, lower = -4096, upper = 4096) => {
    if (typeof value !== 'number') fail('input_type', path, 'Supply a number.');
    if (!Number.isFinite(value)) fail('non_finite', path, 'Supply a finite number.');
    if (value < lower || value > upper) fail('input_type', path, 'Use a value in the documented range.');
    return value;
  };
  const positive = (value, path) => {
    finite(value, path, 0);
    if (value === 0) fail('input_type', path, 'Use a positive dimension.');
    return value;
  };
  const commands = (text, path = '$.d') => {
    if (typeof text !== 'string') fail('input_type', path, 'Supply path text.');
    const tokenPattern = /[A-Za-z]|[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/g;
    const tokens = text.match(tokenPattern) ?? [];
    if (text.replace(tokenPattern, '').replace(/[\s,]/g, '') || tokens[0] !== 'M') {
      fail('input_type', path, 'Use an absolute M/L/Q/C/Z path starting with M.');
    }
    const sizes = { M: 2, L: 2, Q: 4, C: 6, Z: 0 };
    const result = [];
    let index = 0;
    while (index < tokens.length) {
      const operation = tokens[index++];
      if (!Object.hasOwn(sizes, operation)) fail('capability', path, 'Use an absolute M/L/Q/C/Z path.');
      const count = sizes[operation];
      if (!count) {
        result.push(['Z']);
        continue;
      }
      let first = true;
      if (index >= tokens.length || /^[A-Za-z]$/.test(tokens[index]))
        fail('input_type', path, 'Complete every command.');
      while (index < tokens.length && !/^[A-Za-z]$/.test(tokens[index])) {
        const values = tokens.slice(index, index + count);
        if (values.length !== count || values.some((value) => /^[A-Za-z]$/.test(value))) {
          fail('input_type', path, 'Complete every command.');
        }
        const numbers = values.map((value) => finite(Number(value), path));
        result.push([operation === 'M' && !first ? 'L' : operation, ...numbers]);
        index += count;
        first = false;
      }
    }
    return result;
  };
  const buildPath = (entries) => {
    const path = new Path2D();
    for (const [op, ...args] of entries) {
      if (op === 'M') path.moveTo(...args);
      else if (op === 'L') path.lineTo(...args);
      else if (op === 'Q') path.quadraticCurveTo(...args);
      else if (op === 'C') path.bezierCurveTo(...args);
      else if (op === 'Z') path.closePath();
      else if (op === 'arc') path.arc(...args);
      else if (op === 'ellipse') path.ellipse(...args);
      else if (op === 'rect') path.rect(...args);
      else if (op === 'round_rect') path.roundRect(...args.slice(0, 4), args.slice(4));
    }
    return path;
  };
  const localTransform = (x = 0, y = 0, angle = 0, sx = 1, sy = sx) => [
    Math.cos(angle) * sx,
    Math.sin(angle) * sx,
    -Math.sin(angle) * sy,
    Math.cos(angle) * sy,
    x,
    y,
  ];
  const transformed = (path, matrix) => {
    const result = new Path2D();
    result.addPath(path, new DOMMatrix(matrix));
    return result;
  };
  const transformBox = (box, at = [0, 0], angle = 0, scale = [1, 1]) => {
    const [minX, minY, maxX, maxY] = box;
    const [sx, sy] = Array.isArray(scale) ? scale : [scale, scale];
    const [ax, ay] = at;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    const corners = [
      [minX * sx, minY * sy],
      [maxX * sx, minY * sy],
      [minX * sx, maxY * sy],
      [maxX * sx, maxY * sy],
    ];
    let tMinX = Infinity;
    let tMinY = Infinity;
    let tMaxX = -Infinity;
    let tMaxY = -Infinity;
    for (const [cx, cy] of corners) {
      const tx = ax + cos * cx - sin * cy;
      const ty = ay + sin * cx + cos * cy;
      if (tx < tMinX) tMinX = tx;
      if (ty < tMinY) tMinY = ty;
      if (tx > tMaxX) tMaxX = tx;
      if (ty > tMaxY) tMaxY = ty;
    }
    return [tMinX, tMinY, tMaxX, tMaxY];
  };
  const compile = (item, shapes = {}, path = '$.item') => {
    if (!item || typeof item !== 'object') fail('input_type', path, 'Supply shape data.');
    let style = item;
    let transform = ns.parts.identity();
    if (item.shape === 'ref') {
      const definition = ns.parts.own(shapes, item.use);
      if (!definition) fail('missing_reference', `${path}.use`, 'Name a declared shape.');
      if (definition.shape === 'ref') fail('missing_reference', `${path}.use`, 'A shape cannot reference another ref.');
      const allowed = [
        'shape',
        'use',
        'id',
        'fill',
        'stroke',
        'width',
        'alpha',
        'outline',
        'cap',
        'join',
        'lod',
        'x',
        'y',
        'rotate',
        'scale',
        'note',
        'clip',
      ];
      for (const key of Object.keys(item))
        if (!allowed.includes(key)) fail('unknown_key', `${path}.${key}`, 'Remove this ref override.');
      style = { ...definition };
      for (const key of ['id', 'fill', 'stroke', 'width', 'alpha', 'outline', 'cap', 'join', 'lod', 'clip']) {
        if (Object.hasOwn(item, key)) style[key] = item[key];
      }
      const scale = Array.isArray(item.scale) ? item.scale : [item.scale ?? 1, item.scale ?? 1];
      if (scale.length !== 2) fail('input_type', `${path}.scale`, 'Supply a scalar or two-vector.');
      transform = localTransform(
        finite(item.x ?? 0, `${path}.x`),
        finite(item.y ?? 0, `${path}.y`),
        finite(item.rotate ?? 0, `${path}.rotate`, -Infinity, Infinity),
        ...scale.map((axis) => finite(axis, `${path}.scale`, -16, 16)),
      );
    }
    const x = finite(style.x ?? 0, `${path}.x`);
    const y = finite(style.y ?? 0, `${path}.y`);
    const entries = [];
    let numbers = 0;
    let bounds = [x, y, x, y];
    const shape = style.shape;
    if (shape === 'path') {
      entries.push(...commands(style.d, `${path}.d`));
      numbers = entries.reduce((sum, entry) => sum + entry.length - 1, 0);
      const xs = [];
      const ys = [];
      entries.forEach(([, ...args]) => {
        for (let i = 0; i < args.length; i += 2) {
          xs.push(args[i]);
          ys.push(args[i + 1]);
        }
      });
      if (xs.length) bounds = [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
    } else if (shape === 'circle' || shape === 'arc') {
      const radius = positive(style.r, `${path}.r`);
      entries.push([
        'arc',
        x,
        y,
        radius,
        shape === 'arc' ? finite(style.start, `${path}.start`, -Infinity, Infinity) : 0,
        shape === 'arc' ? finite(style.end, `${path}.end`, -Infinity, Infinity) : 2 * Math.PI,
      ]);
      if (shape === 'arc' && style.closed) entries.push(['Z']);
      numbers = 5;
      bounds = [x - radius, y - radius, x + radius, y + radius];
    } else if (shape === 'ellipse') {
      const rx = positive(style.rx, `${path}.rx`);
      const ry = positive(style.ry, `${path}.ry`);
      const rot = finite(style.rotate ?? 0, `${path}.rotate`, -Infinity, Infinity);
      entries.push(['ellipse', x, y, rx, ry, rot, 0, 2 * Math.PI]);
      numbers = 7;
      const dx = Math.sqrt((rx * Math.cos(rot)) ** 2 + (ry * Math.sin(rot)) ** 2);
      const dy = Math.sqrt((rx * Math.sin(rot)) ** 2 + (ry * Math.cos(rot)) ** 2);
      bounds = [x - dx, y - dy, x + dx, y + dy];
    } else if (shape === 'rect' || shape === 'round_rect') {
      const width = positive(style.w, `${path}.w`);
      const height = positive(style.h, `${path}.h`);
      if (shape === 'rect') entries.push(['rect', x, y, width, height]);
      else {
        const radii = Array.isArray(style.r) ? style.r : [style.r, style.r, style.r, style.r];
        if (radii.length !== 4) fail('input_type', `${path}.r`, 'Supply one or four radii.');
        entries.push(['round_rect', x, y, width, height, ...radii.map((radius) => finite(radius, `${path}.r`, 0))]);
      }
      numbers = shape === 'rect' ? 4 : 8;
      bounds = [x, y, x + width, y + height];
    } else if (shape === 'polyline') {
      if (!Array.isArray(style.points) || style.points.length < 2)
        fail('input_type', `${path}.points`, 'Supply at least two points.');
      style.points.forEach((point, index) => {
        if (!Array.isArray(point) || point.length !== 2)
          fail('input_type', `${path}.points[${index}]`, 'Supply a two-vector.');
        entries.push([index ? 'L' : 'M', ...point.map((axis) => finite(axis, `${path}.points[${index}]`))]);
      });
      numbers = 2 * style.points.length;
      const xs = style.points.map((p) => p[0]);
      const ys = style.points.map((p) => p[1]);
      bounds = [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)];
    } else if (shape === 'polygon' || shape === 'hexagon') {
      const sides = shape === 'hexagon' ? 6 : finite(style.sides, `${path}.sides`, 3, 12);
      if (!Number.isInteger(sides)) fail('input_type', `${path}.sides`, 'Supply an integer.');
      const radius = positive(style.r, `${path}.r`);
      const corner = finite(style.corner ?? 0, `${path}.corner`, 0);
      const angle = finite(style.rotate ?? 0, `${path}.rotate`, -Infinity, Infinity);
      const points = Array.from({ length: sides }, (_, index) => [
        x + radius * Math.sin(angle + (2 * Math.PI * index) / sides),
        y - radius * Math.cos(angle + (2 * Math.PI * index) / sides),
      ]);
      points.forEach((current, index) => {
        if (!corner) entries.push([index ? 'L' : 'M', ...current]);
        else {
          const previous = points[(index + sides - 1) % sides];
          const next = points[(index + 1) % sides];
          const lp = Math.hypot(previous[0] - current[0], previous[1] - current[1]);
          const ln = Math.hypot(next[0] - current[0], next[1] - current[1]);
          const distance = Math.min(corner, lp * 0.45, ln * 0.45);
          entries.push([
            index ? 'L' : 'M',
            current[0] + ((previous[0] - current[0]) * distance) / lp,
            current[1] + ((previous[1] - current[1]) * distance) / lp,
          ]);
          entries.push([
            'Q',
            ...current,
            current[0] + ((next[0] - current[0]) * distance) / ln,
            current[1] + ((next[1] - current[1]) * distance) / ln,
          ]);
        }
      });
      entries.push(['Z']);
      numbers = sides * (corner ? 6 : 2);
      bounds = [x - radius, y - radius, x + radius, y + radius];
    } else fail('capability', `${path}.shape`, 'Use a supported shape.');
    if (shape === 'polyline' || (shape === 'arc' && !style.closed)) {
      if (style.fill || style.outline) fail('input_type', path, 'Open arcs and polylines use a detail stroke only.');
    }
    const geometry = buildPath(entries);
    let box = [...bounds];
    if (style.transform) {
      if (!Array.isArray(style.transform) || style.transform.length !== 3)
        fail('input_type', `${path}.transform`, 'Supply x/y/rotate.');
      const [tx, ty, angle] = style.transform;
      const local = localTransform(
        finite(tx, `${path}.transform[0]`),
        finite(ty, `${path}.transform[1]`),
        finite(angle, `${path}.transform[2]`, -Infinity, Infinity),
      );
      transform = ns.parts.multiply(transform, local);
      box = transformBox(
        box,
        [finite(tx, `${path}.transform[0]`), finite(ty, `${path}.transform[1]`)],
        finite(angle, `${path}.transform[2]`, -Infinity, Infinity),
        [1, 1],
      );
    }
    if (item.shape === 'ref') {
      const scale = Array.isArray(item.scale) ? item.scale : [item.scale ?? 1, item.scale ?? 1];
      box = transformBox(
        box,
        [finite(item.x ?? 0, `${path}.x`), finite(item.y ?? 0, `${path}.y`)],
        finite(item.rotate ?? 0, `${path}.rotate`, -Infinity, Infinity),
        scale.map((axis) => finite(axis, `${path}.scale`, -16, 16)),
      );
    }
    return {
      path: transformed(geometry, transform),
      paint_path: geometry,
      transform,
      style,
      numbers,
      entries,
      bounds,
      box,
    };
  };

  const role = (colours, id, path) => {
    if (!Object.hasOwn(colours, id)) fail('invalid_colour', path, 'Name a declared colour role.');
    return colours[id];
  };
  const alphaColour = (colour, alpha, path) => {
    let channels;
    if (/^#[0-9a-f]{3}([0-9a-f]{3})?$/i.test(colour)) {
      const hex = colour.length === 4 ? [...colour.slice(1)].map((digit) => digit + digit).join('') : colour.slice(1);
      channels = [0, 2, 4].map((offset) => parseInt(hex.slice(offset, offset + 2), 16));
      channels.push(1);
    } else {
      const match = /^(rgb|rgba)\(([^)]+)\)$/.exec(colour);
      if (!match) fail('invalid_colour', path, 'Use a hex, rgb or rgba colour.');
      channels = match[2].split(',').map(Number);
      if (channels.length !== (match[1] === 'rgba' ? 4 : 3))
        fail('invalid_colour', path, 'Complete the colour channels.');
      if (channels.length === 3) channels.push(1);
    }
    channels.forEach((entry, index) => {
      finite(entry, path, 0, index === 3 ? 1 : 255);
    });
    return `rgba(${channels[0]},${channels[1]},${channels[2]},${channels[3] * alpha})`;
  };
  const paint = (ctx, fill, character, colours, path) => {
    if (typeof fill === 'string') return role(colours, fill, path);
    const definition = ns.parts.own(character.paints, fill?.paint);
    if (!definition) fail('missing_reference', path, 'Name a declared paint.');
    let gradient;
    if (definition.type === 'linear') gradient = ctx.createLinearGradient(...definition.from, ...definition.to);
    else if (definition.type === 'radial')
      gradient = ctx.createRadialGradient(
        ...(definition.focus ?? definition.centre),
        definition.r0 ?? 0,
        ...definition.centre,
        definition.r1,
      );
    else fail('capability', path, 'Use a supported paint.');
    let last = -1;
    if (!Array.isArray(definition.stops) || definition.stops.length < 2 || definition.stops.length > 6)
      fail('input_type', path, 'Supply two to six stops.');
    definition.stops.forEach((stop) => {
      const offset = finite(stop[0], path, 0, 1);
      if (offset < last) fail('input_type', path, 'Order paint stops by offset.');
      last = offset;
      gradient.addColorStop(offset, alphaColour(role(colours, stop[1], path), finite(stop[2] ?? 1, path, 0, 1), path));
    });
    return gradient;
  };
  const prepared = new WeakMap();
  const backingBlur = (blur, cssWidth = 300, dpr = 1) => blur * (cssWidth / 300) * dpr;

  const transformPoint = (matrix, x, y) => {
    if (Array.isArray(matrix)) {
      return {
        x: matrix[0] * x + matrix[2] * y + matrix[4],
        y: matrix[1] * x + matrix[3] * y + matrix[5],
      };
    }
    if (matrix.transformPoint) return matrix.transformPoint({ x, y });
    return {
      x: matrix.a * x + matrix.c * y + matrix.e,
      y: matrix.b * x + matrix.d * y + matrix.f,
    };
  };

  const scratchBounds = (bounds, blur, matrix) => {
    const corners = [
      [bounds[0], bounds[1]],
      [bounds[0], bounds[3]],
      [bounds[2], bounds[1]],
      [bounds[2], bounds[3]],
    ];
    const points = matrix ? corners.map(([x, y]) => transformPoint(matrix, x, y)) : corners.map(([x, y]) => ({ x, y }));
    const minX = Math.min(...points.map((p) => p.x));
    const minY = Math.min(...points.map((p) => p.y));
    const maxX = Math.max(...points.map((p) => p.x));
    const maxY = Math.max(...points.map((p) => p.y));
    const left = Math.floor(minX - 3 * blur - 1);
    const top = Math.floor(minY - 3 * blur - 1);
    const width = Math.max(1, Math.ceil(maxX + 3 * blur + 1) - left);
    const height = Math.max(1, Math.ceil(maxY + 3 * blur + 1) - top);
    return { left, top, width, height, bounds: [left, top, left + width, top + height] };
  };

  const setContextTransformOffset = (targetCtx, matrix, dx, dy) => {
    if (Array.isArray(matrix)) {
      targetCtx.setTransform(matrix[0], matrix[1], matrix[2], matrix[3], matrix[4] + dx, matrix[5] + dy);
    } else {
      targetCtx.setTransform(matrix.a, matrix.b, matrix.c, matrix.d, matrix.e + dx, matrix.f + dy);
    }
  };

  let scratch = null;
  const resetScratch = () => {
    scratch = null;
  };
  const getScratch = () => {
    if (!scratch && typeof document !== 'undefined' && document.createElement) {
      scratch = [document.createElement('canvas'), document.createElement('canvas')];
      scratch[0].width = 0;
      scratch[0].height = 0;
      scratch[1].width = 0;
      scratch[1].height = 0;
    }
    return scratch;
  };

  const glowPass = (
    ctx,
    path,
    bounds,
    transform,
    clip,
    colour,
    glow,
    pixelScale,
    type = 'fill',
    style = {},
    ownerOpacity = 1,
  ) => {
    const blur = glow.blur * pixelScale;
    if (blur <= 0) return false;
    const { left, top, width: widthPx, height: heightPx } = scratchBounds(bounds, blur, transform);
    if (widthPx <= 0 || heightPx <= 0) return false;
    const canvases = getScratch();
    if (!canvases) return false;
    const [source, emitted] = canvases;
    const g = source.getContext('2d');
    const e = emitted.getContext('2d');
    if (!g || !e) fail('budget', '$.glow', 'Scratch surface allocation failed.');

    if (source.width !== widthPx) source.width = widthPx;
    if (source.height !== heightPx) source.height = heightPx;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, widthPx, heightPx);

    const neededEmittedWidth = 3 * widthPx;
    if (emitted.width !== neededEmittedWidth) emitted.width = neededEmittedWidth;
    if (emitted.height !== heightPx) emitted.height = heightPx;
    e.setTransform(1, 0, 0, 1, 0, 0);
    e.clearRect(0, 0, neededEmittedWidth, heightPx);

    if (clip) {
      g.save();
      try {
        if (clip.transform) {
          setContextTransformOffset(g, clip.transform, -left, -top);
          g.clip(clip.path);
          setContextTransformOffset(g, transform, -left, -top);
        } else {
          setContextTransformOffset(g, transform, -left, -top);
          if (clip.path) g.clip(clip.path);
        }
      } catch (err) {
        g.restore();
        throw err;
      }
    } else {
      setContextTransformOffset(g, transform, -left, -top);
    }

    g.globalAlpha = style.alpha ?? 1;
    g.fillStyle = '#ffffff';
    g.strokeStyle = '#ffffff';
    g.lineWidth = style.width ?? 2.5;
    g.lineCap = style.cap ?? 'round';
    g.lineJoin = style.join ?? 'round';
    g.shadowBlur = 0;
    g.shadowColor = 'transparent';
    g.shadowOffsetX = 0;
    g.shadowOffsetY = 0;
    g.filter = 'none';
    try {
      if (type === 'fill') g.fill(path);
      else g.stroke(path);
    } finally {
      if (clip) g.restore();
    }

    e.globalAlpha = glow.alpha ?? 1;
    e.shadowColor = colour;
    e.shadowBlur = blur;
    e.shadowOffsetX = 2 * widthPx;
    e.shadowOffsetY = 0;
    e.filter = 'none';
    e.drawImage(source, 0, 0);

    ctx.save();
    try {
      ctx.setTransform(1, 0, 0, 1, left, top);
      ctx.globalAlpha *= ownerOpacity;
      ctx.drawImage(emitted, 2 * widthPx, 0, widthPx, heightPx, 0, 0, widthPx, heightPx);
    } finally {
      ctx.restore();
    }
    return true;
  };

  const combineCounts = (target, source) => {
    if (!source) return target;
    for (const [key, value] of Object.entries(source)) {
      if (key === 'active_parts' || key === 'active_part_ids') continue;
      if (key === 'blur_design_units') {
        target[key] = Math.max(target[key] ?? 0, value);
      } else if (typeof value === 'number') {
        target[key] = (target[key] ?? 0) + value;
      }
    }
    let set = target._active_parts;
    if (!set) {
      set = new Set(target.active_part_ids ?? []);
      target._active_parts = set;
    }
    if (source._active_parts) {
      for (const id of source._active_parts) set.add(id);
    } else if (source.active_part_ids) {
      for (const id of source.active_part_ids) set.add(id);
    }
    if (set.size === 0 && (typeof target.active_parts === 'number' || typeof source.active_parts === 'number')) {
      target.active_parts = (target.active_parts ?? 0) + (source.active_parts ?? 0);
    } else {
      target.active_parts = set.size;
    }
    target.active_part_ids = [...set];
    return target;
  };

  const draw = (ctx, compiled, state, colours, options = {}) => {
    const character = compiled.source;
    const initial = ctx.getTransform();
    const base = [initial.a, initial.b, initial.c, initial.d, initial.e, initial.f];
    const pixelScale =
      options.pixel_scale ??
      (options.css_width ? (options.css_width / 300) * (options.dpr ?? 1) : Math.hypot(initial.a, initial.b));
    const activeParts = new Set();
    const counts = {
      active_parts: 0,
      active_part_ids: [],
      painted_items: 0,
      paint_passes: 0,
      path_numbers: 0,
      clip_applications: 0,
      gradient_uses: 0,
      glow_emitters: 0,
      blur_design_units: 0,
    };
    let data = prepared.get(compiled);
    if (!data) {
      const partDefs = new Map();
      if (Array.isArray(character.parts)) {
        for (const part of character.parts) {
          partDefs.set(part.id, part);
        }
      }
      if (Array.isArray(compiled.parts)) {
        for (const part of compiled.parts) {
          const charPart = partDefs.get(part.id);
          if (charPart) {
            partDefs.set(part.id, {
              ...part,
              glow: part.glow ?? charPart.glow,
              parent: part.parent ?? charPart.parent,
              path: part.path ?? charPart.path,
            });
          } else {
            partDefs.set(part.id, part);
          }
        }
      }
      data = {
        items: new Map(),
        partDefs,
      };
      prepared.set(compiled, data);
    }
    const partDefs = data.partDefs;
    const addActivePart = (id) => {
      let current = id;
      while (current && current !== 'root') {
        activeParts.add(current);
        const def = partDefs.get(current);
        current = def ? (def.parent ?? 'root') : null;
      }
    };
    const local = (partId, index) => {
      const owner = state.parts[partId];
      const key = `${partId}.${owner.variant}[${index}]`;
      const item = owner.items[index];
      if (data.items.get(key)?.item !== item)
        data.items.set(key, { item, geometry: compile(item, character.shapes, `${owner.path}.items[${index}]`) });
      return data.items.get(key).geometry;
    };
    const target = (reference) => {
      const [partId, itemId] = reference.split('.');
      const owner = state.parts[partId];
      if (!owner) fail('missing_reference', '$.clip', 'Name a declared target part.');
      const index = owner.items.findIndex((item) => item.id === itemId);
      if (index < 0) fail('missing_reference', '$.clip', 'The target geometry must exist in the active variant.');
      return { partId, owner, geometry: local(partId, index) };
    };
    const outline = {
      ...(character.outline ?? {}),
      ...character.outline?.lod?.[state.band],
      ...character.lod?.[state.band]?.outline,
    };
    const band = state.band ?? 'full';
    const lod = character.lod?.[band] ?? {};
    const glowEnabled = lod.glow ?? band !== 'micro';
    const hasItemOverrides = Boolean(
      (state.item_overrides && Object.keys(state.item_overrides).length > 0) ||
        (options.items && Object.keys(options.items).length > 0),
    );
    for (const id of state.layers) {
      const owner = state.parts[id];
      if (!owner.available || !owner.opacity) continue;
      const partDef = partDefs.get(id);
      const glowDef = glowEnabled && partDef?.glow ? partDef.glow : null;
      let glowAlpha = 1;
      let glowActive = false;
      let glowBlur = 0;
      let glowColour = null;
      if (glowDef) {
        glowBlur = finite(glowDef.blur, `${partDef.path ?? '$.part'}.glow.blur`, 0);
        glowAlpha = finite(glowDef.alpha ?? 1, `${partDef.path ?? '$.part'}.glow.alpha`, 0, 1);
        if (glowBlur > 0 && glowAlpha > 0) {
          glowColour = role(colours, glowDef.colour, `${partDef.path ?? '$.part'}.glow.colour`);
          glowActive = true;
        }
      }
      const items = owner.items;
      for (let index = 0; index < items.length; index++) {
        const item = items[index];
        if ((item.lod && !item.lod.includes(band)) || state.hidden.includes(`${id}.${item.id}`)) continue;
        const isEmitter = glowActive && item.id === glowDef.item;
        const geometry = local(id, index);
        let itemOverride = null;
        if (hasItemOverrides) {
          const itemKey = `${id}.${item.id}`;
          itemOverride = state.item_overrides?.[itemKey] ?? options.items?.[itemKey] ?? null;
        }
        const style = itemOverride ? { ...geometry.style, ...itemOverride } : geometry.style;
        const alpha = finite(style.alpha ?? 1, '$.item.alpha', 0, 1) * owner.opacity;
        // Outlines go under the fill, as in the drawings they come from: only their outer half shows, a slim line
        // with the second (light) line outside it. A detail stroke stays on top of the fill.
        const under = [];
        if (style.outline) {
          if ((outline.second?.width ?? 0) > 0) under.push(outline.second);
          if ((outline.width ?? 0) > 0) under.push(outline);
        }
        const over = [];
        if (style.stroke && (style.width ?? 2.5) > 0)
          over.push({ width: style.width ?? 2.5, colour: style.stroke, cap: style.cap, join: style.join });
        const strokes = [...under, ...over];
        const hasPaint = (style.fill || strokes.length > 0) && alpha > 0;
        if (!hasPaint && !isEmitter) continue;

        let clip = null;
        if (style.clip) {
          clip = target(style.clip);
          const m = clip.owner.matrix;
          const complete = ns.parts.multiply(m, clip.geometry.transform);
          if (Math.abs(complete[0] * complete[3] - complete[1] * complete[2]) < 1e-12) continue;
          counts.clip_applications += 1;
          counts.path_numbers += clip.geometry.numbers;
          addActivePart(clip.partId);
        }
        const itemTransform = ns.parts.multiply(ns.parts.multiply(base, owner.matrix), geometry.transform);

        if (isEmitter) {
          let emittedGlow = false;
          const strokeWidth = strokes[0]?.width ?? style.width ?? 2.5;
          const cap = strokes[0]?.cap ?? style.cap ?? 'round';
          const join = strokes[0]?.join ?? style.join ?? 'round';
          const itemAlpha = finite(style.alpha ?? 1, '$.item.alpha', 0, 1);
          const clipArg = clip
            ? { path: clip.geometry.path, transform: ns.parts.multiply(base, clip.owner.matrix) }
            : null;

          if (style.fill || (!style.fill && !strokes.length)) {
            if (
              glowPass(
                ctx,
                geometry.paint_path,
                geometry.bounds,
                itemTransform,
                clipArg,
                glowColour,
                { ...glowDef, alpha: glowAlpha, blur: glowBlur },
                pixelScale,
                'fill',
                { width: strokeWidth, cap, join, alpha: itemAlpha },
                owner.opacity,
              )
            ) {
              counts.paint_passes += 1;
              emittedGlow = true;
            }
          }
          if (strokes.length > 0) {
            const halfWidth = strokeWidth / 2;
            const strokeBounds = [
              geometry.bounds[0] - halfWidth,
              geometry.bounds[1] - halfWidth,
              geometry.bounds[2] + halfWidth,
              geometry.bounds[3] + halfWidth,
            ];
            if (
              glowPass(
                ctx,
                geometry.paint_path,
                strokeBounds,
                itemTransform,
                clipArg,
                glowColour,
                { ...glowDef, alpha: glowAlpha, blur: glowBlur },
                pixelScale,
                'stroke',
                { width: strokeWidth, cap, join, alpha: itemAlpha },
                owner.opacity,
              )
            ) {
              counts.paint_passes += 1;
              emittedGlow = true;
            }
          }
          if (emittedGlow) {
            counts.glow_emitters += 1;
            counts.blur_design_units = Math.max(counts.blur_design_units, glowBlur);
          }
        }

        if (hasPaint) {
          ctx.save();
          try {
            if (clip) {
              ctx.setTransform(...ns.parts.multiply(base, clip.owner.matrix));
              ctx.clip(clip.geometry.path);
            }
            ctx.setTransform(...itemTransform);
            ctx.globalAlpha *= alpha;
            ctx.miterLimit = 10;
            const strokeAll = (list) => {
              for (const stroke of list) {
                ctx.lineWidth = finite(stroke.width, '$.item.width', 0);
                ctx.strokeStyle = role(colours, stroke.colour, '$.item.stroke');
                ctx.lineCap = stroke.cap ?? 'round';
                ctx.lineJoin = stroke.join ?? 'round';
                ctx.stroke(geometry.paint_path);
                counts.paint_passes += 1;
              }
            };
            strokeAll(under);
            if (style.fill) {
              ctx.fillStyle = paint(ctx, style.fill, character, colours, '$.item.fill');
              ctx.fill(geometry.paint_path);
              counts.paint_passes += 1;
              if (typeof style.fill === 'object') counts.gradient_uses += 1;
            }
            strokeAll(over);
          } finally {
            ctx.restore();
          }
        }
        counts.painted_items += 1;
        counts.path_numbers += geometry.numbers;
        addActivePart(id);
      }
    }
    counts.active_parts = activeParts.size;
    counts.active_part_ids = [...activeParts];
    counts._active_parts = activeParts;
    return counts;
  };
  // E5b policy caps per detail band: the metrics this engine counts, mirroring inst/format/policy-v1.json (a test
  // compares them).
  const bandCaps = Object.freeze({
    full: Object.freeze({
      active_parts: 64,
      painted_items: 160,
      paint_passes: 320,
      path_numbers: 1500,
      clip_applications: 12,
      gradient_uses: 16,
      glow_emitters: 8,
      blur_design_units: 16,
      inflated_glow_area_ratio: 1.0,
    }),
    small: Object.freeze({
      active_parts: 40,
      painted_items: 90,
      paint_passes: 180,
      path_numbers: 900,
      clip_applications: 6,
      gradient_uses: 8,
      glow_emitters: 4,
      blur_design_units: 10,
      inflated_glow_area_ratio: 0.5,
    }),
    micro: Object.freeze({
      active_parts: 16,
      painted_items: 30,
      paint_passes: 60,
      path_numbers: 300,
      clip_applications: 2,
      gradient_uses: 2,
      glow_emitters: 0,
      blur_design_units: 0,
      inflated_glow_area_ratio: 0,
    }),
  });

  const workItem = (item, shapes = {}, outline = null) => {
    const geometry = compile(item, shapes);
    const style = geometry.style;
    const result = {
      active_parts: 0,
      painted_items: 0,
      paint_passes: 0,
      path_numbers: 0,
      clip_applications: 0,
      gradient_uses: 0,
      glow_emitters: 0,
      blur_design_units: 0,
      inflated_glow_area_ratio: 0,
    };
    if (style.alpha !== undefined && style.alpha !== null && style.alpha <= 0) {
      return result;
    }
    const fill = style.fill !== undefined && style.fill !== null;
    const stroke =
      style.stroke !== undefined &&
      style.stroke !== null &&
      (style.width === undefined || style.width === null || style.width > 0);
    const primary =
      style.outline === true && outline?.width !== undefined && outline.width !== null && outline.width > 0;
    const second =
      style.outline === true &&
      outline?.second?.width !== undefined &&
      outline.second.width !== null &&
      outline.second.width > 0;
    const passes = (fill ? 1 : 0) + (stroke ? 1 : 0) + (primary ? 1 : 0) + (second ? 1 : 0);
    if (passes === 0) {
      return result;
    }
    result.painted_items = 1;
    result.paint_passes = passes;
    result.path_numbers = geometry.numbers;
    result.gradient_uses = fill && typeof style.fill === 'object' && style.fill !== null ? 1 : 0;
    return result;
  };

  const workBox = (item, shapes = {}, outline = null) => {
    const geometry = compile(item, shapes);
    const style = geometry.style;
    const widths = [0];
    if (style.stroke !== undefined && style.stroke !== null) {
      widths.push(style.width ?? 2.5);
    }
    if (style.outline === true && outline) {
      if (outline.width !== undefined && outline.width !== null) widths.push(outline.width);
      if (outline.second?.width !== undefined && outline.second.width !== null) widths.push(outline.second.width);
    }
    let width = Math.max(...widths);
    if (item.shape === 'ref' && item.scale !== undefined) {
      const s = Array.isArray(item.scale) ? item.scale : [item.scale, item.scale];
      width *= Math.max(Math.abs(s[0]), Math.abs(s[1]));
    }
    const miter = style.join === 'miter' || (style.outline === true && outline?.join === 'miter');
    const pad = width * (miter ? 5 : 0.5);
    const b = geometry.box;
    return [b[0] - pad, b[1] - pad, b[2] + pad, b[3] + pad];
  };

  // Compares a work bound (mascot.runtime's bound() for a character) with the band's caps; throws budget at $ naming the
  // metric and the limit, before anything is painted.
  const checkWork = (work, band) => {
    if (!Object.hasOwn(bandCaps, band)) fail('input_type', '$.band', "Use 'full', 'small' or 'micro'.");
    for (const [metric, limit] of Object.entries(bandCaps[band])) {
      if (work[metric] > limit)
        fail('budget', '$', `the ${band} band paints too much (${metric} ${work[metric]} > ${limit}); reduce it`);
    }
    return work;
  };

  ns.geometry = Object.freeze({
    bandCaps,
    checkWork,
    workItem,
    workBox,
    commands,
    compile,
    paint,
    alphaColour,
    backingBlur,
    scratchBounds,
    glowPass,
    resetScratch,
    combineCounts,
    addCounts: combineCounts,
    draw,
  });
})();
