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
    const shape = style.shape;
    if (shape === 'path') {
      entries.push(...commands(style.d, `${path}.d`));
      numbers = entries.reduce((sum, entry) => sum + entry.length - 1, 0);
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
    } else if (shape === 'ellipse') {
      entries.push([
        'ellipse',
        x,
        y,
        positive(style.rx, `${path}.rx`),
        positive(style.ry, `${path}.ry`),
        finite(style.rotate ?? 0, `${path}.rotate`, -Infinity, Infinity),
        0,
        2 * Math.PI,
      ]);
      numbers = 7;
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
    } else if (shape === 'polyline') {
      if (!Array.isArray(style.points) || style.points.length < 2)
        fail('input_type', `${path}.points`, 'Supply at least two points.');
      style.points.forEach((point, index) => {
        if (!Array.isArray(point) || point.length !== 2)
          fail('input_type', `${path}.points[${index}]`, 'Supply a two-vector.');
        entries.push([index ? 'L' : 'M', ...point.map((axis) => finite(axis, `${path}.points[${index}]`))]);
      });
      numbers = 2 * style.points.length;
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
    } else fail('capability', `${path}.shape`, 'Use a supported shape.');
    if (shape === 'polyline' || (shape === 'arc' && !style.closed)) {
      if (style.fill || style.outline) fail('input_type', path, 'Open arcs and polylines use a detail stroke only.');
    }
    const geometry = buildPath(entries);
    if (style.transform) {
      if (!Array.isArray(style.transform) || style.transform.length !== 3)
        fail('input_type', `${path}.transform`, 'Supply x/y/rotate.');
      const [x, y, angle] = style.transform;
      const local = localTransform(
        finite(x, `${path}.transform[0]`),
        finite(y, `${path}.transform[1]`),
        finite(angle, `${path}.transform[2]`, -Infinity, Infinity),
      );
      transform = ns.parts.multiply(transform, local);
    }
    return { path: transformed(geometry, transform), paint_path: geometry, transform, style, numbers, entries };
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
      const match = /^rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)$/.exec(colour);
      if (!match) fail('invalid_colour', path, 'Use a hex or rgba colour.');
      channels = match.slice(1).map(Number);
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
  const draw = (ctx, compiled, state, colours) => {
    const character = compiled.source;
    const initial = ctx.getTransform();
    const base = [initial.a, initial.b, initial.c, initial.d, initial.e, initial.f];
    const counts = { painted_items: 0, paint_passes: 0, path_numbers: 0, clip_applications: 0, gradient_uses: 0 };
    let cache = prepared.get(compiled);
    if (!cache) {
      cache = new Map();
      prepared.set(compiled, cache);
    }
    const local = (partId, index) => {
      const owner = state.parts[partId];
      const key = `${partId}.${owner.variant}[${index}]`;
      const item = owner.items[index];
      if (cache.get(key)?.item !== item)
        cache.set(key, { item, geometry: compile(item, character.shapes, `${owner.path}.items[${index}]`) });
      return cache.get(key).geometry;
    };
    const target = (reference) => {
      const [partId, itemId] = reference.split('.');
      const owner = state.parts[partId];
      if (!owner) fail('missing_reference', '$.clip', 'Name a declared target part.');
      const index = owner.items.findIndex((item) => item.id === itemId);
      if (index < 0) fail('missing_reference', '$.clip', 'The target geometry must exist in the active variant.');
      return { owner, geometry: local(partId, index) };
    };
    const outline = {
      ...(character.outline ?? {}),
      ...character.outline?.lod?.[state.band],
      ...character.lod?.[state.band]?.outline,
    };
    for (const id of state.layers) {
      const owner = state.parts[id];
      if (!owner.available || !owner.opacity) continue;
      owner.items.forEach((item, index) => {
        if ((item.lod && !item.lod.includes(state.band)) || state.hidden.includes(`${id}.${item.id}`)) return;
        const geometry = local(id, index);
        const style = geometry.style;
        const alpha = finite(style.alpha ?? 1, '$.item.alpha', 0, 1) * owner.opacity;
        const strokes = [];
        if (style.outline) {
          if ((outline.second?.width ?? 0) > 0) strokes.push(outline.second);
          if ((outline.width ?? 0) > 0) strokes.push(outline);
        }
        if (style.stroke && (style.width ?? 2.5) > 0)
          strokes.push({ width: style.width ?? 2.5, colour: style.stroke, cap: style.cap, join: style.join });
        if (!alpha || (!style.fill && !strokes.length)) return;
        ctx.save();
        try {
          if (style.clip) {
            const clip = target(style.clip);
            const m = clip.owner.matrix;
            const complete = ns.parts.multiply(m, clip.geometry.transform);
            if (Math.abs(complete[0] * complete[3] - complete[1] * complete[2]) < 1e-12) return;
            ctx.setTransform(...ns.parts.multiply(base, m));
            ctx.clip(clip.geometry.path);
            counts.clip_applications += 1;
            counts.path_numbers += clip.geometry.numbers;
          }
          ctx.setTransform(...ns.parts.multiply(ns.parts.multiply(base, owner.matrix), geometry.transform));
          ctx.globalAlpha *= alpha;
          ctx.miterLimit = 10;
          if (style.fill) {
            ctx.fillStyle = paint(ctx, style.fill, character, colours, '$.item.fill');
            ctx.fill(geometry.paint_path);
            counts.paint_passes += 1;
            if (typeof style.fill === 'object') counts.gradient_uses += 1;
          }
          for (const stroke of strokes) {
            ctx.lineWidth = finite(stroke.width, '$.item.width', 0);
            ctx.strokeStyle = role(colours, stroke.colour, '$.item.stroke');
            ctx.lineCap = stroke.cap ?? 'round';
            ctx.lineJoin = stroke.join ?? 'round';
            ctx.stroke(geometry.paint_path);
            counts.paint_passes += 1;
          }
          counts.painted_items += 1;
          counts.path_numbers += geometry.numbers;
        } finally {
          ctx.restore();
        }
      });
    }
    return counts;
  };
  ns.geometry = Object.freeze({ commands, compile, paint, draw });
})();
