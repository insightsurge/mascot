/* Provisional Tessa bridge through format-v1 parts and geometry. Harsh Verma; MIT. */
(() => {
  const ns = window.mascot;
  if (!ns || ns.tessaAdapter) return;

  // This opt-in bridge keeps the old face/effects/arms until E3/M1. Nothing in
  // the host enables it. It exercises real part placement and geometry painting.
  const shape = (item) => ({
    ...item,
    shape: item.shape === 'roundRect' ? 'round_rect' : item.shape,
    width: item.lineWidth ?? 2.5,
    cap: item.round ? 'round' : 'butt',
    join: item.round ? 'round' : 'miter',
  });
  function drawBase(ctx, character, pose, colours) {
    if (!ns.parts || !ns.geometry) throw new Error('mascot: the Tessa adapter needs parts and geometry modules');
    if (character.id !== 'tessa') throw new Error('mascot: the provisional adapter supports only Tessa');
    const parts = [];
    const feet = character.feet;
    if (feet) {
      const tucked = pose.feet === 'tuck' || (pose.feet === 'auto' && pose.lift > 6);
      if (tucked) {
        for (const sign of [-1, 1]) {
          parts.push({
            id: sign < 0 ? 'foot_left' : 'foot_right',
            at: [sign * feet.tuck.x, feet.tuck.y],
            rotate: -sign * feet.tuck.rotate,
            layer: 0,
            items: [
              {
                ...feet.tuck.rect,
                shape: 'round_rect',
                fill: 'limb',
                stroke: 'outline',
                width: feet.lineWidth,
                cap: 'butt',
                join: 'miter',
              },
            ],
          });
        }
      } else {
        feet.stand.forEach((foot, index) => {
          parts.push({
            id: `foot_${index}`,
            layer: 0,
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
        });
      }
    }
    parts.push({ id: 'body', layer: 1, items: character.body.map(shape) });
    const compiled = ns.parts.compile({ format_version: 1, ground: { centre_height: 0 }, parts });
    const state = ns.parts.frame(compiled, {}, 'full', { x: 0, base_y: 0 });
    return ns.geometry.draw(ctx, compiled, state, colours);
  }
  ns.tessaAdapter = Object.freeze({ drawBase });
})();
