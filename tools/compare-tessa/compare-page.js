// Draws every case twice, once with the playbook engine (window.Engine) and once with the package
// (window.mascot), on canvases of the same size in the same page, and counts the pixels that differ.
// Used by compare.R; results go to window.__result, a contact sheet to window.__sheet (PNG data URL).
(() => {
  'use strict';

  const SIZE = 400;
  const X = 200;
  const BASE_Y = 370;
  const FPS = 30;

  // The five shared moods in Tessa's pose fields (provisional mapping from her design record).
  const MOODS = {
    idle: { eyes: 'open', mouth: 'smile', arms: 'idle' },
    thinking: { eyes: 'focused', mouth: 'flat', brows: 'raised', look: 0.6, lookY: -0.6, arms: 'hips' },
    happy: { eyes: 'happy', mouth: 'grin', arms: 'wave' },
    worried: { eyes: 'worried', mouth: 'flat', brows: 'worried', sweat: 0.35, arms: 'idle' },
    celebrating: { eyes: 'happy', mouth: 'grin', arms: 'up', sparkle: true, blush: 'strong', lift: 10 },
  };

  const cases = [];
  const add = (name, pose, frame) => cases.push({ name, pose, frame: frame || 0 });
  for (const [m, pose] of Object.entries(MOODS)) add(`mood ${m}`, pose);
  for (const v of ['open', 'wide', 'happy', 'blink', 'wink', 'focused', 'worried']) add(`eyes ${v}`, { eyes: v });
  for (const v of ['smile', 'grin', 'o', 'flat', 'determined', 'proud', 'smirk']) add(`mouth ${v}`, { mouth: v });
  for (const v of ['none', 'neutral', 'raised', 'frown', 'worried', 'determined']) add(`brows ${v}`, { brows: v });
  for (const v of ['idle', 'up', 'shock', 'type', 'hold', 'wave', 'point', 'hips']) add(`arms ${v}`, { arms: v });
  for (const v of ['bow', 'clip', 'none']) add(`accessory ${v}`, { accessory: v });
  for (const v of [true, 'strong', false]) add(`blush ${v}`, { blush: v });
  for (const v of [0.35, 0.9]) add(`sweat ${v}`, { sweat: v });
  for (const f of [0, 7, 15, 29]) add(`sparkle frame ${f}`, { sparkle: true }, f);
  add('blink 0.5', { blink: 0.5 });
  add('look right up', { look: 1, lookY: -1 });
  add('look left down', { look: -1, lookY: 1 });
  add('flip', { flip: -1, arms: 'point' });
  add('scale 0.5', { scale: 0.5 });
  add('scale 1.4', { scale: 1.4 });
  add('squash', { sx: 1.2, sy: 0.8 });
  add('stretch', { sx: 0.8, sy: 1.2 });
  add('lift 10', { lift: 10 });
  add('lift 40', { lift: 40 });
  add('lean right', { rot: 0.2 });
  add('lean left', { rot: -0.2 });
  add('no shadow', { shadow: false });
  add('feet tuck', { feet: 'tuck' });
  add('feet stand in the air', { feet: 'stand', lift: 40 });
  add('arm jitter frame 5', { armJitter: 0.3, arms: 'wave' }, 5);
  add('arm angles', { armL: 0.4, armR: 2.9 });

  const canvas = () => {
    const c = document.createElement('canvas');
    c.width = SIZE;
    c.height = SIZE;
    return c;
  };
  const context = (c) => c.getContext('2d', { willReadFrequently: true });

  const rows = [];
  const results = [];
  for (const k of cases) {
    const a = canvas();
    const b = canvas();
    window.Engine.drawTessa(context(a), X, BASE_Y, Object.assign({}, k.pose, { t: k.frame / FPS }));
    window.mascot.draw(context(b), 'tessa', X, BASE_Y, k.pose, k.frame);
    const da = context(a).getImageData(0, 0, SIZE, SIZE).data;
    const db = context(b).getImageData(0, 0, SIZE, SIZE).data;
    const d = canvas();
    const dc = context(d);
    dc.globalAlpha = 0.25;
    dc.drawImage(b, 0, 0);
    dc.globalAlpha = 1;
    const marks = dc.getImageData(0, 0, SIZE, SIZE);
    let pixels = 0;
    let maxDelta = 0;
    for (let i = 0; i < da.length; i += 4) {
      let delta = 0;
      for (let j = 0; j < 4; j++) delta = Math.max(delta, Math.abs(da[i + j] - db[i + j]));
      if (delta > 0) {
        pixels++;
        maxDelta = Math.max(maxDelta, delta);
        marks.data.set([220, 0, 0, 255], i);
      }
    }
    dc.putImageData(marks, 0, 0);
    results.push({ case: k.name, frame: k.frame, pixels_differing: pixels, max_delta: maxDelta });
    rows.push([k.name, a, b, d]);
  }

  // Contact sheet: per case, playbook | package | differences (red), at half size.
  const cell = SIZE / 2;
  const label = 22;
  const sheet = document.createElement('canvas');
  sheet.width = cell * 3;
  sheet.height = rows.length * (cell + label);
  const g = sheet.getContext('2d');
  g.fillStyle = '#ffffff';
  g.fillRect(0, 0, sheet.width, sheet.height);
  g.font = '14px sans-serif';
  rows.forEach(([name, a, b, d], i) => {
    const y = i * (cell + label);
    g.fillStyle = '#16201b';
    [a, b, d].forEach((c, j) => {
      g.drawImage(c, j * cell, y, cell, cell);
    });
    g.fillText(`${name}: playbook | package | differences (${results[i].pixels_differing} px)`, 6, y + cell + 16);
  });

  window.__result = results;
  window.__sheet = sheet.toDataURL('image/png');
  window.__done = true;
})();
