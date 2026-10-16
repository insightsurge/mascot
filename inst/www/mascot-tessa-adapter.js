/* Provisional Tessa bridge through format-v1 parts and geometry. Harsh Verma; MIT. */
(() => {
  const ns = window.mascot;
  if (!ns || ns.tessaAdapter) return;

  // Character definitions are snapshots: replace the character object when authoring
  // new geometry, as for the legacy face-style cache. Weak keys release unused data.
  const scenes = new WeakMap();
  const shadows = new WeakMap();
  const faces = new WeakMap();

  // Provisional body bridge: no saved-format claim or live-host switch. Faces
  // and effects use embedded kits; complete migration and host joins are later.
  function build(character, tucked, selected) {
    const bindings = [];
    let roleIndex = 0;
    const items = (parts, overrides = {}) =>
      parts.map((item) => {
        let fill = item.fill;
        let stroke = item.stroke;
        // Legacy alpha affects fill only; format item alpha affects both paints.
        // Keep the old meaning with an explicit RGBA role, including overrides.
        const role = (name, alpha) => {
          const key = `adapter_colour_${roleIndex++}`;
          bindings.push({ key, name, alpha, override: overrides[name] });
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
      for (const sign of [-1, 1]) {
        const id = sign < 0 ? 'arm_left' : 'arm_right';
        parts.push({
          id,
          parent: 'torso',
          layer: arms.layer ?? 4,
          at: [sign * character.anchors.shoulders.x, character.anchors.shoulders.y],
          rotate: 0,
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
    selected.forEach((item, index) => {
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
    // E5b: a character's detail-band overrides (lod) travel with the compiled source; characters without lod are unchanged.
    const compiled = ns.parts.compile({
      format_version: 1,
      ground: { centre_height: character.centreHeight },
      parts,
      anchors,
      accessories,
      wear,
      ...(character.lod !== undefined ? { lod: character.lod } : {}),
    });
    return { compiled, bindings };
  }

  function scene(character, pose, colours, x = 0, baseY = 0, band = 'full') {
    if (!ns.parts || !ns.geometry) throw new Error('mascot: the Tessa adapter needs parts and geometry modules');
    if (character.id !== 'tessa') throw new Error('mascot: the provisional adapter supports only Tessa');
    // Resolve/validate the worn set even on a cache hit (duplicate slots still error).
    const selected = ns.drawing.accessories(character, pose);
    const tucked = pose.feet === 'tuck' || (pose.feet === 'auto' && pose.lift > 6);
    const names = (Array.isArray(pose.accessory) ? pose.accessory : [pose.accessory]).filter(
      (name) => name !== undefined && name !== 'none',
    );
    const key = JSON.stringify([tucked, !!character.arms, names]);
    let cache = scenes.get(character);
    if (!cache) {
      cache = new Map();
      scenes.set(character, cache);
    }
    if (!cache.has(key)) cache.set(key, build(character, tucked, selected));
    const { compiled, bindings } = cache.get(key);
    const palette = { ...colours };
    for (const { key, name, alpha, override } of bindings) {
      const colour = override ?? colours[name];
      palette[key] = alpha === undefined ? colour : ns.drawing.rgba(colour, alpha);
    }
    const channels = {
      'root.lift': pose.lift,
      'root.rotate': pose.rot,
      'root.scale_x': pose.scale * pose.sx,
      'root.scale_y': pose.scale * pose.sy,
      'root.flip': pose.flip,
    };
    if (character.arms) {
      const angles = ns.drawing.armAngles(character, pose);
      channels['arm_left.rotate'] = angles.L;
      channels['arm_right.rotate'] = angles.R;
    }
    const state = ns.parts.frame(compiled, channels, band, { x, base_y: baseY });
    for (const [id, partState] of Object.entries(state.parts)) {
      if (![0, 1, 3, 4].includes(partState.layer)) {
        throw new Error(`mascot: unsupported part layer ${partState.layer} for part '${id}'; must be in {0, 1, 3, 4}`);
      }
    }
    return { compiled, state, colours: palette };
  }

  function faceDefinition(character) {
    if (!ns.faces) throw new Error('mascot: the Tessa adapter needs the face-kit module');
    if (!faces.has(character)) {
      const old = character.face;
      faces.set(
        character,
        ns.faces.compile({
          face: old
            ? {
                part: 'torso',
                kit: 'classic',
                kit_definition: ns.faces.readKit('classic'),
                eyes: { ...old.eyes, lashes: old.lashes },
                mouth: old.mouth,
                blush: old.blush ? { ...old.blush, strong_alpha: old.blush.strongAlpha } : undefined,
                caps: {
                  left: old.outline?.leftCap ?? 'round',
                  right: old.outline?.rightCap ?? 'round',
                  join: old.outline?.join ?? 'miter',
                },
                colours: { eye_white: 'eyeWhite', blush_strong: 'blushStrong', sparkle_outline: 'sparkleOutline' },
              }
            : null,
          anchors: Object.fromEntries(Object.keys(character.anchors).map((id) => [id, { part: 'torso' }])),
          effects: Object.fromEntries(
            ['sweat', 'sparkle']
              .filter((id) => Object.hasOwn(character.anchors, id))
              .map((id) => [id, { anchor: id, layer: 3 }]),
          ),
        }),
      );
    }
    return faces.get(character);
  }

  // E5b fix 2: the work bound of every scene the character can reach in one band. The scene depends only on the feet
  // (tucked or not) and on the worn accessories, so the reachable scenes are: tucked both ways, times every selection of
  // declared accessories with at most one per slot (the rule ns.drawing.accessories enforces). Moods, variants and the
  // held pose only change parts inside a scene, which bandBound already covers by taking the largest candidate of each
  // part. Componentwise maximum (blur included), frozen, cached per character and band. Enumerating selections is a
  // product over slots: fine for Tessa's few accessories; the native engine (M1) uses the contract's per-slot maxima.
  const bounds = new WeakMap();
  function selections(character) {
    const slots = new Map();
    for (const name of Object.keys(character.accessories ?? {})) {
      const slot = character.accessories[name].slot;
      if (!slots.has(slot)) slots.set(slot, []);
      slots.get(slot).push(name);
    }
    let chosen = [[]];
    for (const names of slots.values())
      chosen = chosen.flatMap((partial) => [partial, ...names.map((name) => [...partial, name])]);
    return chosen;
  }
  function bound(character, band) {
    if (!ns.parts || !ns.geometry) throw new Error('mascot: the Tessa adapter needs parts and geometry modules');
    ns.geometry.checkWork({}, band); // validates the band name before anything is cached
    if (character.id !== 'tessa') throw new Error('mascot: the provisional adapter supports only Tessa');
    let perBand = bounds.get(character);
    if (!perBand) {
      perBand = new Map();
      bounds.set(character, perBand);
    }
    if (perBand.has(band)) return perBand.get(band);
    const total = {
      active_parts: 0,
      painted_items: 0,
      paint_passes: 0,
      path_numbers: 0,
      glow_emitters: 0,
      blur_design_units: 0,
    };
    for (const names of selections(character)) {
      let selected;
      try {
        selected = ns.drawing.accessories(character, { accessory: names });
      } catch {
        continue; // an accessory the drawing would refuse (for example a missing anchor) is not a reachable scene
      }
      for (const tucked of [false, true]) {
        const work = ns.geometry.bandBound(build(character, tucked, selected).compiled, band);
        for (const key of Object.keys(total)) total[key] = Math.max(total[key], work[key]);
      }
    }
    Object.freeze(total);
    perBand.set(band, total);
    return total;
  }
  // Throws budget at $ when any reachable scene of the character is over the band's caps. No painting.
  function check(character, band) {
    const work = bound(character, band); // the guards run here, before any geometry lookup
    ns.geometry.checkWork(work, band);
  }

  function draw(ctx, character, pose, colours, x, baseY, band = 'full') {
    // E5b fix 2: the per-character bound is checked first (cached after the first call): a band that can be reached
    // is refused before anything is built or painted.
    check(character, band);
    // Build before painting: missing modules or unsupported characters leave the
    // caller's canvas state/pixels unchanged rather than half drawing a frame.
    const frame = scene(character, pose, colours, x, baseY, band);
    const face = faceDefinition(character);
    const counts = { painted_items: 0, paint_passes: 0 };
    const add = (cost) => {
      ns.geometry.combineCounts(counts, cost);
    };
    const paint = (compiled, state, palette) => {
      const cost = ns.geometry.draw(ctx, compiled, state, palette);
      add(cost);
    };
    if (pose.shadow && character.shadow && pose.scale !== 0) {
      const shade = character.shadow;
      const k = 1 / (1 + pose.lift / 200);
      let compiled = shadows.get(character);
      if (!compiled) {
        compiled = ns.parts.compile({
          format_version: 1,
          ground: { centre_height: 0 },
          parts: [
            { id: 'ground_shadow', items: [{ shape: 'ellipse', rx: shade.rx, ry: shade.ry, fill: 'shadow_fill' }] },
          ],
        });
        shadows.set(character, compiled);
      }
      const channels = {
        'ground_shadow.scale_x': pose.scale * k * (0.6 + 0.4 * pose.sx),
        'ground_shadow.scale_y': pose.scale * k,
      };
      paint(compiled, ns.parts.frame(compiled, channels, 'full', { x, base_y: baseY - 1 }), {
        shadow_fill: ns.drawing.rgba(colours.shadow, shade.alpha * k),
      });
    }
    const layer = (test) =>
      paint(
        frame.compiled,
        { ...frame.state, layers: frame.state.layers.filter((id) => test(frame.state.parts[id].layer)) },
        frame.colours,
      );
    layer((value) => value < 2);
    if (frame.state.anchors.face.available) {
      const eyes = pose.eyes === 'blink' ? 'closed' : pose.eyes === 'wink' ? ['open', 'happy'] : pose.eyes;
      const controls = {
        eyes,
        mouth: pose.mouth,
        brows: pose.brows ?? (pose.eyes === 'worried' ? 'worried' : pose.eyes === 'focused' ? 'frown' : 'none'),
        look_x: Math.max(-1, Math.min(1, pose.look)),
        look_y: Math.max(-1, Math.min(1, pose.lookY)),
        blink: pose.blink,
        blush: pose.blush === 'strong' ? 'strong' : pose.blush ? 1 : 0,
      };
      add(ns.faces.draw(ctx, face, frame.state, controls, colours, { matrix: frame.state.anchors.face.matrix }));
    }
    layer((value) => value === 3);
    if (frame.state.parts.torso.available)
      add(
        ns.faces.effects(
          ctx,
          face,
          frame.state,
          {
            ...(Object.hasOwn(character.anchors, 'sweat') ? { sweat: pose.sweat === true ? 0.5 : pose.sweat } : {}),
            ...(Object.hasOwn(character.anchors, 'sparkle') ? { sparkle: pose.sparkle } : {}),
          },
          colours,
          { frame: pose.t * 30, activity_deadline: 150, reduced: ns.internal?.reducedMotion === true },
        ),
      );
    layer((value) => value === 4);
    return { counts, state: frame.state };
  }
  ns.tessaAdapter = Object.freeze({ scene, draw, check, bound });
})();
