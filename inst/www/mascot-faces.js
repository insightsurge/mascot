/* Character-format v1 face-kit operations. Copyright (c) Harsh Verma; MIT. */
(() => {
  window.mascot = window.mascot || {};
  const ns = window.mascot;
  if (ns.faces) return;
  const prepared = new WeakMap();
  const own = (object, key) => (object != null && Object.hasOwn(object, key) ? object[key] : undefined);
  const fail = (code, path, message) => {
    const error = new Error(`${path}: ${message}`);
    Object.assign(error, { code, path });
    throw error;
  };
  const number = (value, path, low = -4096, high = 4096) => {
    if (typeof value !== 'number' || !Number.isFinite(value) || value < low || value > high)
      fail('input_type', path, 'Supply a finite number in the documented range.');
    return value;
  };
  const positive = (value, path) => number(value, path, Number.MIN_VALUE);
  const freeze = (value) => {
    if (value && typeof value === 'object') {
      Object.values(value).forEach(freeze);
      Object.freeze(value);
    }
    return value;
  };
  const tune = (base, override, path) => {
    if (typeof base === 'number') return number(override, path, -Infinity, Infinity);
    if (!base || !override || typeof base !== 'object' || typeof override !== 'object')
      fail('input_type', path, 'Tune existing numeric leaves only.');
    if (Array.isArray(base) !== Array.isArray(override) || (Array.isArray(base) && base.length !== override.length))
      fail('input_type', path, 'Retain the numeric array length.');
    for (const key of Object.keys(override)) {
      const at = Array.isArray(base) ? `${path}[${key}]` : `${path}.${key}`;
      if (!Object.hasOwn(base, key)) fail('unknown_key', at, 'Tune an existing numeric leaf.');
      base[key] = tune(base[key], override[key], at);
    }
    return base;
  };
  const readKit = (id, doc = document) => {
    if (typeof id !== 'string' || !/^[a-z][a-z0-9_]*$/.test(id)) fail('input_type', '$.face.kit', 'Supply a kit id.');
    const element = doc.querySelector(`script[type="application/json"][data-mascot-kit="${id}"]`);
    if (!element) fail('missing_reference', '$.face.kit_definition', `Embed the '${id}' kit data.`);
    return JSON.parse(element.textContent);
  };

  // Paths are compiled from the closed grammar, with conservative control-point
  // bounds for the small backing-pixel glow surface. No full-page glow bitmap.
  const replay = (target, entries) => {
    target.beginPath?.();
    for (const [command, ...args] of entries) {
      if (command === 'M') target.moveTo(...args);
      else if (command === 'L') target.lineTo(...args);
      else if (command === 'Q') target.quadraticCurveTo(...args);
      else if (command === 'C') target.bezierCurveTo(...args);
      else if (command === 'Z') target.closePath();
      else if (command === 'ellipse') target.ellipse(...args);
      else if (command === 'arc') target.arc(...args);
      else if (command === 'mirror_arc') {
        const [x, y, r, start, end] = args;
        target.arc(x, y, r, Math.PI - start, Math.PI - end, true);
      } else if (command === 'rect') target.rect(...args);
    }
  };
  const operation = (entries, style) => {
    const path = new Path2D();
    replay(path, entries);
    const points = [];
    let numbers = 0;
    for (const [command, ...args] of entries) {
      numbers += args.length;
      if (command === 'ellipse' || command === 'arc' || command === 'mirror_arc') {
        const [x, y, rx] = args;
        const ry = command === 'ellipse' ? args[3] : rx;
        points.push([x - rx, y - ry], [x + rx, y + ry]);
      } else if (command === 'rect') points.push(args.slice(0, 2), [args[0] + args[2], args[1] + args[3]]);
      else for (let index = 0; index < args.length; index += 2) points.push(args.slice(index, index + 2));
    }
    const bounds = points.length
      ? [
          Math.min(...points.map((p) => p[0])),
          Math.min(...points.map((p) => p[1])),
          Math.max(...points.map((p) => p[0])),
          Math.max(...points.map((p) => p[1])),
        ]
      : [0, 0, 0, 0];
    return { path, style, bounds, numbers };
  };
  const ellipse = (x, y, rx, ry, style) => operation([['ellipse', x, y, rx, ry, 0, 0, 7]], style);
  const circle = (x, y, r, style) => operation([['arc', x, y, r, 0, 7]], style);
  const mapped = (commands, x, y, sx = 1, sy = 1) =>
    commands.map(([command, ...values]) => [
      command,
      ...values.map((value, index) => (index % 2 ? y + value * sy : x + value * sx)),
    ]);
  const segment = (ops, at = [0, 0], clip = null) => ({ ops, at, clip });
  const emptyCounts = () => ({
    painted_items: 0,
    paint_passes: 0,
    path_numbers: 0,
    clip_applications: 0,
    gradient_uses: 0,
    glow_emitters: 0,
  });
  const addCounts = (left, right) => {
    ns.geometry.combineCounts(left, right);
  };

  // This is the renderer for already checked/resolved data, not a second full
  // character checker. Recheck tuning constraints and dispatch boundaries here.
  const compile = (character) => {
    if (!ns.parts || !ns.geometry) fail('capability', '$', 'Load parts and geometry before faces.');
    const source = JSON.parse(JSON.stringify(character));
    if (!source.face) {
      if (Object.keys(source.effects ?? {}).length)
        fail('missing_reference', '$.effects', 'Faceless characters cannot map kit effects.');
      const result = freeze({ source });
      prepared.set(result, { effects: new Map() });
      return result;
    }
    const face = source.face;
    const kit = face.kit_definition;
    if (!kit || kit.id !== face.kit)
      fail('missing_reference', '$.face.kit_definition', 'Embed a matching complete kit.');
    const groups = { eyes: 'eye_styles', brows: 'brow_styles', mouth: 'mouth_styles' };
    for (const [group, field] of Object.entries(groups)) {
      for (const [name, style] of Object.entries(face.styles?.[group] ?? {})) kit[field][name] = style;
      if (face.tune?.[group]) tune(kit[field], face.tune[group], `$.face.tune.${group}`);
      if (!own(kit[field], kit.defaults[group]))
        fail('missing_reference', `$.face.kit_definition.defaults.${group}`, 'Name a declared style.');
    }
    for (const group of Object.keys(face.tune ?? {}))
      if (!Object.hasOwn(groups, group)) fail('unknown_key', `$.face.tune.${group}`, 'Tune eyes, brows or mouth.');
    if (!own(kit.eye_styles, 'closed') || !own(kit.brow_styles, 'none') || kit.brow_styles.none.width !== 0)
      fail('missing_reference', '$.face.kit_definition', 'Declare closed eyes and an empty none brow.');
    const data = { eyes: new Map(), brows: new Map(), mouths: new Map(), effects: new Map(), raster: null };
    for (const [id, style] of Object.entries(kit.eye_styles)) {
      const path = `$.face.kit_definition.eye_styles.${id}`;
      if (!['eye_ellipse', 'eye_arc', 'eye_path', 'eye_dots'].includes(style.op))
        fail('capability', path, 'Use a closed eye operation.');
      if (style.op === 'eye_ellipse') {
        positive(style.rx, `${path}.rx`);
        positive(style.ry, `${path}.ry`);
        number(style.pupil.r, `${path}.pupil.r`, 0, Math.min(style.rx, style.ry));
        number(style.lid ?? 0, `${path}.lid`, 0, 1);
        number(style.slant ?? 0, `${path}.slant`, -style.ry, style.ry);
        for (const glint of style.pupil.glints ?? []) number(glint.r, `${path}.pupil.glints.r`, 0, 1);
      } else if (style.op === 'eye_arc') {
        positive(style.r, `${path}.r`);
        number(style.start, `${path}.start`);
        number(style.end, `${path}.end`);
      } else if (style.op === 'eye_dots') positive(style.r, `${path}.r`);
      if (style.width !== undefined) number(style.width, `${path}.width`, 0);
      if (style.lashes) {
        number(style.lashes.length ?? 7, `${path}.lashes.length`, 0);
        number(style.lashes.width ?? 3, `${path}.lashes.width`, 0);
        for (const value of style.lashes.radii ?? []) positive(value, `${path}.lashes.radii`);
      }
      for (const edge of [style.outline, style.lid_edge]) if (edge) number(edge.width, `${path}.width`, 0);
      data.eyes.set(id, { style, commands: style.d ? ns.geometry.commands(style.d) : null, last: [null, null] });
    }
    for (const [id, style] of Object.entries(kit.brow_styles)) {
      const path = `$.face.kit_definition.brow_styles.${id}`;
      if (style.op !== 'brow_path') fail('capability', `${path}.op`, 'Use brow_path.');
      number(style.width ?? 3.5, `${path}.width`, 0);
      data.brows.set(id, { style, commands: ns.geometry.commands(style.d, `${path}.d`), paths: [null, null] });
    }
    for (const [id, style] of Object.entries(kit.mouth_styles)) {
      const path = `$.face.kit_definition.mouth_styles.${id}`;
      if (style.op !== 'mouth_path') fail('capability', `${path}.op`, 'Use mouth_path.');
      (style.box ?? [20, 12]).forEach((value, index) => {
        positive(value, `${path}.box[${index}]`);
      });
      const commands = style.items.map((item, index) => {
        const itemPath = `${path}.items[${index}]`;
        if (
          !['path', 'ellipse', 'polyline'].includes(item.shape) ||
          item.clip ||
          item.transform ||
          item.scale !== undefined
        )
          fail('capability', itemPath, 'Use normalised path, ellipse or polyline items.');
        number(item.width ?? 2.5, `${itemPath}.width`, 0);
        if (item.shape === 'ellipse') {
          positive(item.rx, `${itemPath}.rx`);
          positive(item.ry, `${itemPath}.ry`);
        }
        return item.shape === 'path'
          ? ns.geometry.commands(item.d, `${itemPath}.d`)
          : item.shape === 'polyline'
            ? item.points.map((point, index) => [index ? 'L' : 'M', ...point])
            : null;
      });
      data.mouths.set(id, { style, commands, last: null });
    }
    for (const [id, definition] of Object.entries(source.effects ?? {})) {
      const effect = own(kit.effects, id);
      if (!effect) fail('missing_reference', `$.effects.${id}`, 'Name a declared kit effect.');
      if (!own(source.anchors, definition.anchor))
        fail('missing_reference', `$.effects.${id}.anchor`, 'Name a declared anchor.');
      const modes = { sweat_drop: ['progress', 'track'], sparkle_star: ['pulse', 'track'] };
      if (!own(modes, effect.op)?.includes(effect.mode))
        fail('capability', `$.effects.${id}`, 'Use a valid operation/mode pair.');
      if (effect.mode === 'progress' && effect.reduced_items !== undefined)
        fail(
          'input_type',
          `$.effects.${id}.reduced_items`,
          'Progress effects retain their static geometry under reduction.',
        );
      if (effect.mode !== 'track' && (effect.frames !== undefined || effect.tracks !== undefined))
        fail('input_type', `$.effects.${id}`, 'Only track effects have frames and tracks.');
      // The effect's own settings live in the kit definition; errors point there, as in R.
      const kitPath = `$.face.kit_definition.effects.${id}`;
      // fade_at is below 1, as in R: a drop that fades from 1 never shows its fade.
      if (effect.mode === 'progress' && number(effect.fade_at ?? 0.9, `${kitPath}.fade_at`, 0, 1) >= 1)
        fail('input_type', `${kitPath}.fade_at`, 'Use a value of at least 0 and below 1.');
      if (effect.mode === 'pulse') {
        number(effect.amplitude ?? 0.18, `${kitPath}.amplitude`, 0, 0.5);
        number(effect.rate ?? 9, `${kitPath}.rate`, Number.MIN_VALUE, 30);
      }
      for (const list of ['items', 'reduced_items'])
        (effect[list] ?? []).forEach((item, index) => {
          if (item.clip)
            fail(
              'capability',
              `${kitPath}.${list}[${index}].clip`,
              'Kit effects cannot bind item clips: remove the clip from this effect item.',
            );
        });
      const compiled = ns.parts.compile({
        format_version: 1,
        ground: { centre_height: 0 },
        shapes: source.shapes,
        paints: source.paints,
        outline: source.outline,
        parts: [{ id: 'glyph', items: effect.items, variants: { reduced: effect.reduced_items ?? [] } }],
      });
      data.effects.set(id, { definition, effect, compiled });
    }
    const result = freeze({ source });
    prepared.set(result, data);
    return result;
  };

  const palette = (face, colours) => {
    const result = { ...colours };
    for (const [name, role] of Object.entries(face.colours ?? {})) {
      if (!Object.hasOwn(colours, role))
        fail('invalid_colour', `$.face.colours.${name}`, 'Name a declared colour role.');
      result[name] = colours[role];
    }
    return result;
  };
  const paintStyle = (ctx, fill, source, colours, original) =>
    fill?.direct ? ns.geometry.paint(ctx, fill.role, source, original) : ns.geometry.paint(ctx, fill, source, colours);
  const lashes = (style, face, sign, x, y) => {
    const lash = style.lashes;
    if (!lash || face.eyes?.lashes === false) return [];
    const [rx, ry] = lash.radii ?? (style.op === 'eye_ellipse' ? [style.rx, style.ry] : [style.r, style.r]);
    const at = lash.at ?? [0, 0];
    return lash.angles.map((angle) => {
      const dx = Math.cos(angle),
        dy = Math.sin(angle);
      const start = [x + sign * (at[0] + rx * dx), y + at[1] + ry * dy];
      return operation(
        [
          ['M', ...start],
          ['L', start[0] + sign * (lash.length ?? 7) * dx, start[1] + (lash.length ?? 7) * dy],
        ],
        { stroke: 'feature', width: lash.width ?? 3, cap: 'round', join: 'round' },
      );
    });
  };
  const eye = (entry, face, index, controls, flags) => {
    const sign = index ? 1 : -1;
    const style = entry.style;
    const iris = face.eyes?.iris && flags.iris !== false;
    const key = JSON.stringify([controls.look_x, controls.look_y, controls.lid, controls.blink, iris, flags.lashes]);
    if (entry.last[index]?.key === key) return entry.last[index].glyph;
    const x = sign * (face.eyes?.spacing ?? 30),
      y = face.eyes?.y ?? -12;
    const segments = [];
    if (style.op === 'eye_ellipse') {
      const cap = face.caps?.[index ? 'right' : 'left'] ?? 'round';
      const join = face.caps?.join ?? 'round';
      const sclera = ellipse(0, 0, style.rx, style.ry, {
        fill: style.fill ?? 'eye_white',
        stroke: style.outline?.colour,
        width: style.outline?.width ?? 0,
        cap,
        join,
      });
      segments.push(segment([sclera], [x, y]));
      const pupil = style.pupil,
        r = pupil.r;
      const range = pupil.look_range ?? [7, 7],
        at = pupil.at ?? [0, 0];
      const px = at[0] + controls.look_x * range[0],
        py = at[1] + controls.look_y * range[1];
      const inside = [];
      if (r > 0) {
        if (iris) inside.push(circle(px, py, r, { fill: { direct: true, role: face.eyes.iris } }));
        inside.push(circle(px, py, r * (iris ? 0.65 : 1), { fill: 'feature' }));
        for (const glint of pupil.glints ?? [{ at: [-0.35, -0.4], r: 0.22 }])
          if (glint.r > 0)
            inside.push(
              circle(px + glint.at[0] * r * (pupil.mirror_glints ? sign : 1), py + glint.at[1] * r, glint.r * r, {
                fill: 'shine',
              }),
            );
      }
      const lid = Math.max(style.lid ?? 0, controls.lid, controls.blink);
      if (lid > 0) {
        const ly = -style.ry * 1.2 + style.ry * 2.4 * lid;
        inside.push(
          operation([['rect', -style.rx * 1.2, -style.ry * 1.2, style.rx * 2.4, ly + style.ry * 1.2]], {
            fill: 'eyelid',
          }),
        );
        if ((style.lid_edge?.width ?? 0) > 0)
          inside.push(
            operation(
              [
                ['M', -style.rx * 1.2, ly + sign * (style.slant ?? 0)],
                ['L', style.rx * 1.2, ly - sign * (style.slant ?? 0)],
              ],
              { stroke: style.lid_edge.colour, width: style.lid_edge.width, cap, join },
            ),
          );
      }
      if (inside.length)
        segments.push(segment(inside, [x, y], ellipse(0, 0, Math.max(style.rx - 1, 0), Math.max(style.ry - 1, 0), {})));
    } else {
      let ops;
      if (style.op === 'eye_arc')
        ops = [
          operation(
            [
              [
                index || (style.start + style.end) % (2 * Math.PI) === Math.PI ? 'arc' : 'mirror_arc',
                x,
                y + (style.y ?? 0),
                style.r,
                style.start,
                style.end,
              ],
            ],
            {
              fill: style.fill,
              stroke: style.stroke ?? 'feature',
              width: style.width ?? 5,
              cap: 'round',
              join: 'round',
            },
          ),
        ];
      else if (style.op === 'eye_path')
        ops = [
          operation(mapped(entry.commands, x, y, sign), {
            fill: style.fill ?? 'feature',
            stroke: style.stroke,
            width: style.width ?? 2,
            cap: 'round',
            join: 'round',
          }),
        ];
      else
        ops = style.centres.map(([dx, dy]) =>
          circle(x + sign * dx, y + dy, style.r, { fill: style.fill ?? 'feature' }),
        );
      segments.push(segment(ops));
    }
    if (flags.lashes !== false) segments.push(segment(lashes(style, face, sign, x, y)));
    const glyph = { segments, emit: true };
    entry.last[index] = { key, glyph };
    return glyph;
  };
  const brow = (entry, face, index) => {
    if ((entry.style.width ?? 3.5) === 0) return null;
    if (!entry.paths[index]) {
      const sign = index ? 1 : -1;
      entry.paths[index] = {
        emit: true,
        segments: [
          segment([
            operation(
              mapped(
                entry.commands,
                sign * (face.eyes?.spacing ?? 30),
                (face.eyes?.y ?? -12) + (entry.style.y ?? -25),
                sign,
              ),
              { stroke: entry.style.stroke ?? 'feature', width: entry.style.width ?? 3.5, cap: 'round', join: 'round' },
            ),
          ]),
        ],
      };
    }
    return entry.paths[index];
  };
  const mouth = (entry, face, open) => {
    if (entry.last?.open === open) return entry.last.glyph;
    const [sx, height] = entry.style.box ?? [20, 12],
      sy = height * open;
    const y = face.mouth?.y ?? 24;
    const ops = entry.style.items.map((item, index) => {
      const style = { ...item, cap: item.cap ?? 'round', join: item.join ?? 'round' };
      if (item.shape === 'ellipse')
        return ellipse((item.x ?? 0) * sx, y + (item.y ?? 0) * sy, item.rx * sx, item.ry * sy, style);
      return operation(mapped(entry.commands[index], 0, y, sx, sy), style);
    });
    const glyph = { emit: true, segments: [segment(ops)] };
    entry.last = { open, glyph };
    return glyph;
  };

  const intersect = (a, b) => [Math.max(a[0], b[0]), Math.max(a[1], b[1]), Math.min(a[2], b[2]), Math.min(a[3], b[3])];
  const glowPass = (ctx, op, clip, colour, glow, pixelScale, type) => {
    const style = op.style;
    const width = type === 'stroke' ? (style.width ?? 2.5) / 2 : 0;
    let bounds = op.bounds.map((value, index) => value + (index < 2 ? -width : width));
    if (clip) bounds = intersect(bounds, clip.bounds);
    if (bounds[2] < bounds[0] || bounds[3] < bounds[1]) return false;
    return ns.geometry.glowPass(
      ctx,
      op.path,
      bounds,
      ctx.getTransform(),
      clip ? { path: clip.path } : null,
      colour,
      glow,
      pixelScale,
      type,
      style,
      1,
    );
  };
  const paintGlyph = (ctx, glyph, source, colours, original, glow, pixelScale, counts) => {
    if (glow && glyph.emit) {
      let emitted = false;
      const colour = ns.geometry.paint(ctx, 'feature', source, colours);
      for (const part of glyph.segments) {
        ctx.save();
        try {
          ctx.translate(...part.at);
          if (part.clip) ctx.clip(part.clip.path);
          for (const op of part.ops) {
            for (const type of ['fill', 'stroke']) {
              if (!op.style[type] || (type === 'stroke' && (op.style.width ?? 2.5) === 0)) continue;
              if (glowPass(ctx, op, part.clip, colour, glow, pixelScale, type)) {
                counts.paint_passes++;
                emitted = true;
              }
            }
          }
        } finally {
          ctx.restore();
        }
      }
      if (emitted) counts.glow_emitters++;
    }
    for (const part of glyph.segments) {
      ctx.save();
      try {
        ctx.translate(...part.at);
        if (part.clip) {
          ctx.clip(part.clip.path);
          counts.clip_applications++;
          counts.path_numbers += part.clip.numbers;
        }
        for (const op of part.ops) {
          const style = op.style;
          ctx.save();
          try {
            ctx.globalAlpha *= style.alpha ?? 1;
            ctx.lineCap = style.cap ?? 'round';
            ctx.lineJoin = style.join ?? 'round';
            ctx.miterLimit = 10;
            if (style.fill) {
              const colour = paintStyle(ctx, style.fill, source, colours, original);
              ctx.fillStyle =
                style.fill_alpha === undefined
                  ? colour
                  : ns.geometry.alphaColour(colour, style.fill_alpha, '$.face.blush');
              ctx.fill(op.path);
              counts.paint_passes++;
              if (style.fill && typeof style.fill === 'object' && !style.fill.direct) counts.gradient_uses++;
            }
            if (style.stroke && (style.width ?? 2.5) > 0) {
              ctx.strokeStyle = paintStyle(ctx, style.stroke, source, colours, original);
              ctx.lineWidth = style.width ?? 2.5;
              ctx.stroke(op.path);
              counts.paint_passes++;
            }
            if (style.fill || (style.stroke && (style.width ?? 2.5) > 0)) {
              counts.painted_items += op.items ?? 1;
              counts.path_numbers += op.numbers;
            }
          } finally {
            ctx.restore();
          }
        }
      } finally {
        ctx.restore();
      }
    }
  };
  const select = (map, id, path) => {
    if (!map.has(id)) fail('missing_reference', path, 'Name a declared style.');
    return map.get(id);
  };

  // Caller orders this face invocation among the ordinary part layers. It owns
  // no timers or host state; all motion and detail-band inputs are explicit.
  const draw = (ctx, compiled, state, controls = {}, colours = {}, options = {}) => {
    const counts = emptyCounts(),
      { source } = compiled,
      face = source.face;
    if (!face) return counts;
    const data = prepared.get(compiled),
      kit = face.kit_definition;
    const owner = own(state.parts, face.part);
    if (!owner) fail('missing_reference', '$.face.part', 'Name a resolved owner part.');
    const value = {
      look_x: number(controls.look_x ?? 0, '$.face.look_x', -1, 1),
      look_y: number(controls.look_y ?? 0, '$.face.look_y', -1, 1),
      blink: number(controls.blink ?? 0, '$.face.blink', 0, 1),
      lid: number(controls.lid ?? 0, '$.face.lid', 0, 1),
    };
    const open = number(controls.open ?? 1, '$.face.open', 0, 1);
    const scale = positive(controls.scale ?? 1, '$.face.scale');
    const band = state.band ?? 'full',
      lod = source.lod?.[band] ?? {},
      flags = lod.face ?? {};
    let eyes = controls.eyes ?? kit.defaults.eyes;
    eyes = Array.isArray(eyes) ? eyes : [eyes, eyes];
    if (eyes.length !== 2) fail('input_type', '$.face.eyes', 'Select one style or a left/right pair.');
    if (value.blink >= 0.96) eyes = ['closed', 'closed'];
    const selected = eyes.map((id) => select(data.eyes, id, '$.face.eyes'));
    const browEntry = select(data.brows, controls.brows ?? kit.defaults.brows, '$.face.brows');
    const mouthEntry = select(data.mouths, controls.mouth ?? kit.defaults.mouth, '$.face.mouth');
    const blush = controls.blush ?? kit.defaults.blush ?? 0;
    if (blush !== 'strong') number(blush, '$.face.blush', 0, 1);
    const glyphs = [];
    if (face.blush && blush) {
      if (data.blush?.value !== blush) {
        const b = face.blush,
          strong = blush === 'strong';
        const style = {
          fill: strong ? 'blush_strong' : 'blush',
          fill_alpha: (strong ? (b.strong_alpha ?? 0.55) : (b.alpha ?? 0.45)) * (strong ? 1 : blush),
        };
        let ops;
        if (Math.abs(b.x) >= b.rx) {
          // Disjoint equal paints can share a fill. Besides avoiding a pass this
          // retains the native multi-subpath rasterisation. Overlapping cheeks
          // remain separate so their item alpha still composites twice.
          const batch = operation(
            [
              ['ellipse', -b.x, b.y, b.rx, b.ry, 0, 0, 7],
              ['M', b.x + b.rx, b.y],
              ['ellipse', b.x, b.y, b.rx, b.ry, 0, 0, 7],
            ],
            style,
          );
          batch.items = 2;
          batch.numbers = 14;
          ops = [batch];
        } else ops = [-1, 1].map((sign) => ellipse(sign * b.x, b.y, b.rx, b.ry, style));
        data.blush = { value: blush, glyph: { emit: false, segments: [segment(ops)] } };
      }
      glyphs.push(data.blush.glyph);
    }
    selected.forEach((entry, index) => {
      glyphs.push(eye(entry, face, index, value, flags));
    });
    if (flags.brows !== false)
      selected.forEach((entry, index) => {
        if (!entry.style.hide_brows) {
          const item = brow(browEntry, face, index);
          if (item) glyphs.push(item);
        }
      });
    glyphs.push(mouth(mouthEntry, face, open));
    const mappedColours = palette(face, colours);
    // Resolve every selected paint before the first pixel, including gradients.
    for (const glyph of glyphs)
      for (const part of glyph.segments)
        for (const op of part.ops)
          for (const key of ['fill', 'stroke'])
            if (op.style[key]) paintStyle(ctx, op.style[key], source, mappedColours, colours);
    const matrix = options.matrix ?? owner.matrix;
    if (!owner.available || !owner.opacity || Math.abs(matrix[0] * matrix[3] - matrix[1] * matrix[2]) < 1e-12)
      return counts;
    const base = ctx.getTransform();
    const pixelScale = positive(options.pixel_scale ?? Math.hypot(base.a, base.b), '$.pixel_scale');
    let glow = (lod.glow ?? band !== 'micro') ? kit.glow : null;
    if (glow) {
      number(glow.blur, '$.face.glow.blur', 0);
      glow = { ...glow, alpha: number(glow.alpha ?? 1, '$.face.glow.alpha', 0, 1) };
      if (!glow.alpha) glow = null;
    }
    ctx.save();
    try {
      if (face.clip) {
        const [partId, itemId] = face.clip.split('.'),
          target = own(state.parts, partId);
        const item = target?.items.find((item) => item.id === itemId);
        if (!item) fail('missing_reference', '$.face.clip', 'Resolve the active clip item.');
        // Compiled once per clip item, not per frame.
        let geometry = clipGeometry.get(item);
        if (!geometry) {
          geometry = ns.geometry.compile(item, source.shapes);
          clipGeometry.set(item, geometry);
        }
        const matrix = ns.parts.multiply(target.matrix, geometry.transform);
        if (Math.abs(matrix[0] * matrix[3] - matrix[1] * matrix[2]) < 1e-12) return counts;
        ctx.setTransform(...ns.parts.multiply([base.a, base.b, base.c, base.d, base.e, base.f], target.matrix));
        ctx.clip(geometry.path);
        counts.clip_applications++;
        counts.path_numbers += geometry.numbers;
        ctx.setTransform(base);
      }
      ctx.transform(...matrix);
      ctx.translate(...(face.at ?? [0, 0]));
      const size = positive(face.scale ?? 1, '$.face.scale') * scale * positive(flags.scale ?? 1, '$.lod.face.scale');
      ctx.scale(size, size);
      ctx.globalAlpha *= owner.opacity;
      for (const glyph of glyphs) paintGlyph(ctx, glyph, source, mappedColours, colours, glow, pixelScale, counts);
    } finally {
      ctx.restore();
    }
    return counts;
  };

  const clipGeometry = new WeakMap();
  const effects = (ctx, compiled, state, controls = {}, colours = {}, options = {}) => {
    const counts = emptyCounts(),
      { source } = compiled,
      data = prepared.get(compiled);
    for (const id of Object.keys(controls))
      if (!data.effects.has(id)) fail('missing_reference', `$.effects.${id}`, 'Map the requested kit effect.');
    if (!source.face) return counts;
    const mappedColours = palette(source.face, colours);
    const frame = number(options.frame ?? 0, '$.frame', 0, Number.MAX_SAFE_INTEGER);
    const deadline = number(options.activity_deadline ?? 150, '$.activity_deadline', 0, Number.MAX_SAFE_INTEGER);
    for (const [id, record] of [...data.effects].sort(
      (a, b) => (a[1].definition.layer ?? 3) - (b[1].definition.layer ?? 3),
    )) {
      const control = controls[id] ?? 0;
      if (!control) continue;
      const { definition, effect, compiled: drawing } = record;
      // A gesture trigger names its own anchor (options.effect_anchors); otherwise the mapping's anchor.
      const anchorName = own(options.effect_anchors, id) ?? definition.anchor;
      const anchor = own(state.anchors, anchorName);
      if (!anchor) fail('missing_reference', `$.effects.${id}.anchor`, 'Resolve the effect anchor.');
      const owner = own(state.parts, source.anchors[anchorName].part);
      if (!owner) fail('missing_reference', `$.effects.${id}.anchor`, 'Resolve the anchor owner.');
      if (!anchor.available || !owner.opacity) continue;
      let x = 0,
        y = 0,
        sx = 1,
        sy = 1,
        opacity = 1,
        reduced = false;
      if (effect.mode === 'progress') {
        const u = number(control, `$.effects.${id}`, 0, 1),
          fade = effect.fade_at ?? 0.9;
        x = (effect.sway ?? 2) * Math.sin(u * (effect.sway_rate ?? 12));
        y = u * (effect.travel ?? 26);
        opacity = u <= fade ? 1 : (1 - u) / (1 - fade);
      } else if (options.reduced) reduced = true;
      else if (effect.mode === 'pulse')
        sx = sy = 1 + (effect.amplitude ?? 0.18) * Math.sin((effect.rate ?? 9) * (Math.min(frame, deadline) / 30));
      else {
        const values = own(options.effect_states, id);
        if (!values) fail('capability', `$.effects.${id}`, 'Supply the bounded track state from the track scheduler.');
        x = number(values.x ?? 0, '$.effect.x');
        y = number(values.y ?? 0, '$.effect.y');
        sx = number(values.scale_x ?? 1, '$.effect.scale_x', -16, 16);
        sy = number(values.scale_y ?? 1, '$.effect.scale_y', -16, 16);
        opacity = number(values.opacity ?? 0, '$.effect.opacity', 0, 1);
      }
      const at = effect.at ?? [0, 0];
      const channels = {
        'glyph.x': at[0] + x,
        'glyph.y': at[1] + y,
        'glyph.scale_x': sx,
        'glyph.scale_y': sy,
        'glyph.opacity': opacity,
        'glyph.variant': reduced ? 'reduced' : 'default',
      };
      const drawingState = ns.parts.frame(drawing, channels, state.band ?? 'full', { x: 0, base_y: 0 });
      ctx.save();
      try {
        ctx.transform(...anchor.matrix);
        ctx.globalAlpha *= owner.opacity;
        addCounts(counts, ns.geometry.draw(ctx, drawing, drawingState, mappedColours));
      } finally {
        ctx.restore();
      }
    }
    return counts;
  };
  ns.faces = Object.freeze({ readKit, compile, draw, effects });
})();
