/* Provisional Tessa bridge through format-v1 parts and geometry. Harsh Verma; MIT. */
(() => {
  const ns = window.mascot;
  if (!ns || ns.tessaAdapter) return;

  // E1 bridge only: no saved-format claim, no live-host switch. E3/E4 still own
  // generic faces/effects. Their current painters are mounted on part matrices.
  function scene(character, pose, colours, x = 0, baseY = 0) {
    if (!ns.parts || !ns.geometry) throw new Error('mascot: the Tessa adapter needs parts and geometry modules');
    if (character.id !== 'tessa') throw new Error('mascot: the provisional adapter supports only Tessa');
    const palette = { ...colours };
    let roleIndex = 0;
    const items = (parts, overrides = {}) =>
      parts.map((item) => {
        let fill = item.fill;
        let stroke = item.stroke;
        // Legacy alpha affects fill only; format item alpha affects both paints.
        // Keep the old meaning with an explicit RGBA role, including overrides.
        const role = (name, alpha) => {
          const key = `adapter_colour_${roleIndex++}`;
          palette[key] =
            alpha === undefined
              ? (overrides[name] ?? colours[name])
              : ns.drawing.rgba(overrides[name] ?? colours[name], alpha);
          return key;
        };
        if (fill && (item.alpha !== undefined || Object.hasOwn(overrides, fill))) fill = role(fill, item.alpha);
        if (stroke && Object.hasOwn(overrides, stroke)) stroke = role(stroke);
        return {
          ...item,
          shape: item.shape === 'roundRect' ? 'round_rect' : item.shape,
          fill,
          stroke,
          alpha: undefined,
          width: item.lineWidth ?? 2.5,
          cap: item.round ? 'round' : 'butt',
          join: item.round ? 'round' : 'miter',
        };
      });
    const parts = [
      {
        id: 'torso',
        at: [0, -character.centreHeight],
        layer: character.body?.layer ?? 1,
        items: items(character.body),
      },
    ];
    const anchors = {};
    const anchor = (id, at, owner = 'torso') => {
      anchors[id] = { part: owner, at: [at.x ?? 0, at.y ?? 0], rotate: at.rotate ?? 0, scale: at.scale ?? 1 };
    };
    for (const [id, at] of Object.entries(character.anchors)) {
      if (id === 'shoulders' || id === 'feet') {
        anchor(`${id}_left`, { ...at, x: -at.x });
        anchor(`${id}_right`, at);
      } else anchor(id, at);
    }
    if (!anchors.face) anchor('face', {});
    const feet = character.feet;
    if (feet) {
      const tucked = pose.feet === 'tuck' || (pose.feet === 'auto' && pose.lift > 6);
      for (const [index, sign] of [-1, 1].entries()) {
        const id = sign < 0 ? 'foot_left' : 'foot_right';
        const foot = tucked ? feet.tuck.rect : feet.stand[index];
        parts.push({
          id,
          parent: 'torso',
          layer: feet.layer ?? 0,
          at: tucked ? [sign * feet.tuck.x, feet.tuck.y] : [0, 0],
          rotate: tucked ? -sign * feet.tuck.rotate : 0,
          items: [
            {
              ...foot,
              shape: 'round_rect',
              fill: 'limb',
              stroke: 'outline',
              width: feet.lineWidth,
              cap: 'butt',
              join: 'miter',
            },
          ],
        });
        if (tucked) anchor(`feet_${sign < 0 ? 'left' : 'right'}`, { x: foot.x + foot.w / 2, y: foot.y + foot.h }, id);
      }
    }
    if (character.arms) {
      const arms = character.arms;
      const angles = ns.drawing.armAngles(character, pose);
      for (const [side, sign] of [
        ['L', -1],
        ['R', 1],
      ]) {
        const id = sign < 0 ? 'arm_left' : 'arm_right';
        parts.push({
          id,
          parent: 'torso',
          layer: arms.layer ?? 4,
          at: [sign * character.anchors.shoulders.x, character.anchors.shoulders.y],
          rotate: angles[side],
          items: [
            {
              shape: 'round_rect',
              x: 0,
              y: -arms.width / 2,
              w: arms.length,
              h: arms.width,
              r: arms.width / 2,
              fill: 'sleeve',
              stroke: 'outline',
              width: 2.5,
              cap: 'round',
              join: 'round',
            },
            {
              shape: 'circle',
              x: arms.paw.offset,
              y: 0,
              r: arms.paw.r,
              fill: 'limb',
              stroke: 'outline',
              width: 2.5,
              cap: 'round',
              join: 'round',
            },
          ],
        });
        anchor(`hands_${sign < 0 ? 'left' : 'right'}`, { x: arms.paw.offset, y: 0 }, id);
      }
    }
    const accessories = {};
    const wear = [];
    ns.drawing.accessories(character, pose).forEach((item, index) => {
      const id = `attachment_${index}`;
      const name = item.anchor || 'hair';
      const paired = ['hands', 'shoulders', 'feet'].includes(name);
      accessories[id] = {
        slot: item.slot,
        anchor: paired ? `${name}_${item.side === 'L' ? 'left' : 'right'}` : name,
        parts: [{ id: 'drawing', layer: item.layer ?? 3, items: items(item.parts, item.colours) }],
      };
      wear.push(id);
    });
    const compiled = ns.parts.compile({
      format_version: 1,
      ground: { centre_height: character.centreHeight },
      parts,
      anchors,
      accessories,
      wear,
    });
    const channels = {
      'root.lift': pose.lift,
      'root.rotate': pose.rot,
      'root.scale_x': pose.scale * pose.sx,
      'root.scale_y': pose.scale * pose.sy,
      'root.flip': pose.flip,
    };
    const state = ns.parts.frame(compiled, channels, 'full', { x, base_y: baseY });
    for (const [id, partState] of Object.entries(state.parts)) {
      if (![0, 1, 3, 4].includes(partState.layer)) {
        throw new Error(`mascot: unsupported part layer ${partState.layer} for part '${id}'; must be in {0, 1, 3, 4}`);
      }
    }
    return { compiled, state, colours: palette };
  }

  function draw(ctx, character, pose, colours, x, baseY, painters) {
    // Build before painting: missing modules or unsupported characters leave the
    // caller's canvas state/pixels unchanged rather than half drawing a frame.
    const frame = scene(character, pose, colours, x, baseY);
    const counts = { painted_items: 0, paint_passes: 0 };
    const paint = (compiled, state, palette) => {
      const cost = ns.geometry.draw(ctx, compiled, state, palette);
      for (const key of Object.keys(cost)) counts[key] = (counts[key] ?? 0) + cost[key];
    };
    if (pose.shadow && character.shadow && pose.scale !== 0) {
      const shade = character.shadow;
      const k = 1 / (1 + pose.lift / 200);
      const compiled = ns.parts.compile({
        format_version: 1,
        ground: { centre_height: 0 },
        parts: [
          {
            id: 'ground_shadow',
            at: [x, baseY - 1],
            items: [
              {
                shape: 'ellipse',
                rx: shade.rx * pose.scale * k * (0.6 + 0.4 * pose.sx),
                ry: shade.ry * pose.scale * k,
                fill: 'shadow_fill',
              },
            ],
          },
        ],
      });
      paint(compiled, ns.parts.frame(compiled, {}, 'full', { x: 0, base_y: 0 }), {
        shadow_fill: ns.drawing.rgba(colours.shadow, shade.alpha * k),
      });
    }
    const layer = (test) =>
      paint(
        frame.compiled,
        { ...frame.state, layers: frame.state.layers.filter((id) => test(frame.state.parts[id].layer)) },
        frame.colours,
      );
    const mounted = (matrix, painter) => {
      ctx.save();
      try {
        ctx.transform(...matrix);
        painter(ctx);
      } finally {
        ctx.restore();
      }
    };
    layer((value) => value < 2);
    if (frame.state.anchors.face.available) mounted(frame.state.anchors.face.matrix, painters.face);
    layer((value) => value === 3);
    if (frame.state.parts.torso.available) mounted(frame.state.parts.torso.matrix, painters.effects);
    layer((value) => value === 4);
    return { counts, state: frame.state };
  }
  ns.tessaAdapter = Object.freeze({ scene, draw });
})();
