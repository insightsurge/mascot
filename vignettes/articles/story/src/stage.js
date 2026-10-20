/**
 * The Bridge at Five: a 2.5D stage for the four built-in mascot characters.
 *
 * The mascots are drawn by the package's own engine: each one is a real `mascot()` element (in .story-cast, under the
 * film), driven with window.mascot.host.receive(). Every frame the stage copies the engine's canvases into its own
 * canvas, together with the set (sky, hills, stream, bridge), the camera, light, speech bubbles and status tags.
 * Everything else here is a pure function of the story time t (seconds), so the same code plays live, steps through
 * still scenes for reduced motion, and renders frame by frame for the recording (window.story.recordAt).
 * No images, fonts or libraries: system fonts and canvas paths only.
 */
(() => {
  'use strict';

  // ------------------------------------------------------------------ small helpers
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, k) => a + (b - a) * k;
  const seg = (t, a, b) => clamp((t - a) / (b - a));
  const smooth = (k) => k * k * (3 - 2 * k);
  const inOut = (k) => (k < 0.5 ? 4 * k * k * k : 1 - (-2 * k + 2) ** 3 / 2);
  const outCubic = (k) => 1 - (1 - k) ** 3;
  const inQuad = (k) => k * k;
  const outBack = (k) => 1 + 2.2 * (k - 1) ** 3 + 1.2 * (k - 1) ** 2;
  function rng(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let r = Math.imul(a ^ (a >>> 15), 1 | a);
      r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
      return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
    };
  }
  const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
  const mix = (a, b, k) => {
    const x = hex(a);
    const y = hex(b);
    return `rgb(${Math.round(lerp(x[0], y[0], k))},${Math.round(lerp(x[1], y[1], k))},${Math.round(lerp(x[2], y[2], k))})`;
  };
  // Interpolate keyed values [[time, a, b, ...], ...] with an ease between keys; a repeated key holds.
  function keyed(keys, t, easing = inOut) {
    if (t <= keys[0][0]) return keys[0].slice(1);
    for (let i = 1; i < keys.length; i++) {
      if (t <= keys[i][0]) {
        const a = keys[i - 1];
        const b = keys[i];
        const k = easing(seg(t, a[0], b[0]));
        return a.slice(1).map((v, j) => lerp(v, b[j + 1], k));
      }
    }
    return keys[keys.length - 1].slice(1);
  }

  // ------------------------------------------------------------------ the script
  const DURATION = 50;
  const CAST = ['tessa', 'sela', 'knurl', 'neer'];
  const NAME = { tessa: 'Tessa', sela: 'Sela', knurl: 'Knurl', neer: 'Neer' };
  const HEIGHT = { tessa: 196, sela: 196, knurl: 176, neer: 138 };

  // Moods: [time, who, mood]. The status line under each mascot is the engine's own text for that mood.
  const MOODS = [
    [4.6, 'tessa', 'thinking'],
    [10.0, 'tessa', 'idle'],
    [13.2, 'knurl', 'thinking'],
    [19.25, 'knurl', 'worried'],
    [19.6, 'sela', 'worried'],
    [19.9, 'tessa', 'worried'],
    [28.4, 'neer', 'thinking'],
    [30.9, 'neer', 'happy'],
    [31.4, 'sela', 'thinking'],
    [32.0, 'knurl', 'thinking'],
    [36.2, 'knurl', 'happy'],
    [36.6, 'tessa', 'happy'],
    [37.0, 'sela', 'happy'],
    [39.5, 'sela', 'celebrating'],
    [39.8, 'neer', 'celebrating'],
    [40.1, 'knurl', 'celebrating'],
    [40.4, 'tessa', 'celebrating'],
  ];
  // Gestures every character has: nod and wave.
  const GESTURES = [
    [11.8, 'sela', 'nod'],
    [15.0, 'knurl', 'nod'],
    [29.6, 'neer', 'nod'],
    [36.4, 'knurl', 'nod'],
    [37.7, 'tessa', 'wave'],
    [41.2, 'sela', 'wave'],
    [41.5, 'neer', 'wave'],
    [41.8, 'knurl', 'wave'],
    [45.0, 'tessa', 'nod'],
  ];
  // Speech bubbles: [start, end, who, text]. Knurl keeps to two or three words.
  const LINES = [
    [5.4, 8.9, 'tessa', 'One plank to go.'],
    [11.2, 14.2, 'sela', 'Opening at five. Plenty of time.'],
    [15.0, 17.3, 'knurl', 'Plank incoming.'],
    [19.9, 22.0, 'knurl', 'Plank lost.'],
    [21.5, 24.1, 'sela', 'Eight minutes to five!'],
    [23.6, 26.0, 'tessa', 'Where did it go?'],
    [29.4, 32.6, 'neer', 'Pegs up. Turn it over.'],
    [36.3, 38.3, 'knurl', 'Flipped. Fitted.'],
    [37.5, 39.6, 'tessa', 'Thank you, Neer!'],
    [41.9, 43.7, 'sela', 'Five o’clock. Right on time.'],
    [42.1, 43.7, 'neer', 'The lights changed.'],
    [45.0, 46.6, 'tessa', 'It holds!'],
  ];
  // Status tags shown under a mascot: [start, end, who]. The text is read live from the engine's status element.
  const TAGS = [
    [4.9, 9.4, 'tessa'],
    [11.0, 14.2, 'sela'],
    [13.5, 17.3, 'knurl'],
    [19.5, 25.4, 'knurl'],
    [19.9, 25.4, 'sela'],
    [20.2, 25.4, 'tessa'],
    [27.4, 33.8, 'neer'],
    [36.4, 39.0, 'knurl'],
    [36.8, 39.0, 'tessa'],
    [37.2, 39.0, 'sela'],
    [39.6, 41.6, 'sela'],
    [39.9, 41.7, 'neer'],
    [40.2, 41.8, 'knurl', 'above'],
    [40.5, 41.9, 'tessa'],
  ];
  // What happens, for captions and the transcript (the film has no sound).
  const NARRATION = [
    [0, 'Title: The Bridge at Five.'],
    [3.4, 'Dusk by a stream. Tessa is finishing a little wooden bridge, but the middle plank is still missing. Sela keeps the timetable on the far bank.'],
    [12.4, 'Knurl rolls in along the bank, carrying the last plank.'],
    [18.0, 'Knurl lowers the plank into the gap. It won’t sit flat.'],
    [19.2, 'The plank slips and drops into the stream with a splash.'],
    [26.2, 'Ripples. Neer rises out of the water, right beside the floating plank.'],
    [32.6, 'Neer lifts the plank on a spout of water. Knurl catches it, turns it over, and it clicks into place.'],
    [39.1, 'Five o’clock. The lanterns along the bridge light up one by one.'],
    [41.2, 'Everyone waves. Then Tessa walks out onto the new plank to try it.'],
    [46.8, 'End card: meet your mascots, Tessa, Sela, Knurl and Neer.'],
  ];
  // Still scenes for reduced motion (and the times the live captions describe).
  const KEYFRAMES = [1.7, 7.4, 12.8, 16.2, 18.7, 21.7, 24.6, 30.6, 33.8, 37.9, 41.0, 43.2, 45.8, 49.0];
  const POSTER_TIME = 1.7;

  // ------------------------------------------------------------------ the set (world units; the wide shot is 1280 x 720)
  const HOME = { x: 640, y: 360 };
  const HORIZON = 302;
  const riverHalf = (y) => 14 + ((y - HORIZON) / 460) * 270;
  const riverX = (y) => 640 + Math.sin((y - HORIZON) / 70) * 16 * (1 - clamp((y - HORIZON) / 260)) + Math.sin((y - HORIZON) / 230) * 8;
  const BX0 = 466;
  const BX1 = 814;
  const PLANKS = 9;
  const PW = (BX1 - BX0) / PLANKS;
  const GAP = 4;
  const deckY = (x) => 524 - 46 * Math.sin((Math.PI * clamp((x - BX0) / (BX1 - BX0))) );
  const GAPX = BX0 + (GAP + 0.5) * PW;
  const WATER_FRONT = 704;

  // Camera keys: [time, centre x, centre y, zoom].
  const CAMERA = [
    [0, 640, 292, 1.06],
    [3.2, 640, 292, 1.06],
    [5.6, 470, 440, 1.5],
    [9.8, 452, 446, 1.5],
    [11.4, 940, 446, 1.45],
    [13.4, 930, 440, 1.42],
    [15.4, 820, 452, 1.38],
    [17.6, 680, 438, 1.6],
    [19.4, 668, 436, 1.62],
    [21.4, 640, 420, 1.04],
    [25.2, 640, 424, 1.04],
    [27.2, 650, 532, 1.45],
    [31.8, 650, 528, 1.45],
    [32.8, 690, 504, 1.32],
    [34.3, 690, 500, 1.32],
    [35.0, 668, 440, 1.8],
    [36.3, 664, 442, 1.8],
    [37.1, 650, 446, 1.5],
    [38.4, 640, 410, 1.12],
    [40.6, 640, 372, 0.98],
    [46.0, 640, 368, 0.98],
  ];
  const SHAKE = [19.6, 20.1];

  function camera(t, reduced) {
    const [x, y, zoom] = keyed(CAMERA, t);
    let sx = 0;
    let sy = 0;
    if (!reduced && t > SHAKE[0] && t < SHAKE[1]) {
      const k = 1 - seg(t, SHAKE[0], SHAKE[1]);
      sx = Math.sin(t * 61) * 3 * k;
      sy = Math.cos(t * 47) * 2.5 * k;
    }
    // A tall (phone) frame shows more sky than story: look a little lower.
    const lower = tall ? 60 / zoom : 0;
    return { x: x + sx, y: y + sy + lower, zoom };
  }

  // Dusk: 0 at the start, 1 when the lanterns are lit.
  const dusk = (t) => smooth(seg(t, 3, 42));
  const lanternOn = (i, t) => smooth(seg(t, 39.1 + i * 0.32, 39.5 + i * 0.32));
  const LANTERNS = [
    { x: BX0 + 2, post: 64 },
    { x: BX0 + 3 * PW, post: 58 },
    { x: BX0 + 6 * PW, post: 58 },
    { x: BX1 - 2, post: 64 },
    { x: 116, ground: 586, post: 120 },
    { x: 1312, ground: 590, post: 120 },
  ];

  // ------------------------------------------------------------------ where everyone is
  function tessaAt(t) {
    // Tessa steps onto the bridge at the end to try the new plank.
    const k = inOut(seg(t, 43.0, 44.9));
    if (k <= 0) return { x: 312, y: 582, z: 0, alpha: 1, bob: 0 };
    const x = lerp(312, GAPX, k);
    const groundY = lerp(582, 582, k);
    const onDeck = x > BX0 ? deckY(x) - 4 : groundY;
    const y = x > BX0 - 30 ? lerp(groundY, onDeck, seg(x, BX0 - 30, BX0 + 30)) : groundY;
    const bob = k > 0 && k < 1 ? -Math.abs(Math.sin(t * 9)) * 6 : 0;
    return { x, y, z: 0, alpha: 1, bob };
  }
  function selaAt() {
    return { x: 1046, y: 590, z: 0, alpha: 1, bob: 0 };
  }
  const KNURL_PATH = [
    [12.2, 742, 318, 0.86],
    [15.9, 872, 556, 0],
    [16.9, 818, deckY(818) - 4, 0],
    [18.1, 706, deckY(706) - 4, 0],
    [38.3, 706, deckY(706) - 4, 0],
    [39.2, 818, deckY(818) - 4, 0],
    [40.0, 866, 574, 0],
  ];
  function knurlAt(t) {
    const [x, y, z] = keyed(KNURL_PATH, t, (k) => k);
    const alpha = smooth(seg(t, 12.2, 12.9));
    const moving = (t > 12.2 && t < 18.1) || (t > 38.3 && t < 40.0);
    const bob = moving ? -Math.abs(Math.sin(t * 11)) * 3 : 0;
    const tilt = moving ? Math.sin(t * 5.5) * 0.03 : 0;
    return { x, y, z, alpha, bob, tilt, mirror: t < 38.3 };
  }
  const NEER_RISE = [26.4, 28.2];
  function neerAt(t) {
    const rise = outCubic(seg(t, NEER_RISE[0], NEER_RISE[1]));
    return { x: 596, y: WATER_FRONT, z: 0, alpha: rise > 0 ? 1 : 0, bob: 0, rise, sway: Math.sin(t * 1.7) * 3 };
  }

  // The last plank: carried, lowered, slipping, floating downstream, lifted on a spout, flipped and fitted.
  function plankAt(t) {
    const kn = knurlAt(t);
    const s0 = 1 - 0.75 * kn.z;
    const held = { x: kn.x - 46 * s0, y: kn.y + (kn.bob - 62) * s0 };
    const gapTop = { x: GAPX, y: deckY(GAPX) - 2 };
    if (t < 17.9) {
      return { show: t > 12.2, alpha: kn.alpha, x: held.x, y: held.y, rot: kn.tilt, flip: -1, scale: 1 - 0.75 * kn.z, z: kn.z };
    }
    if (t < 18.9) {
      const k = inOut(seg(t, 17.9, 18.7));
      return { show: true, alpha: 1, x: lerp(held.x, gapTop.x, k), y: lerp(held.y, gapTop.y - 6, k), rot: 0, flip: -1, scale: 1 };
    }
    if (t < 19.25) {
      const w = Math.sin((t - 18.9) * 40) * 0.12 * (1 - seg(t, 18.9, 19.25));
      return { show: true, alpha: 1, x: gapTop.x, y: gapTop.y - 6, rot: w, flip: -1, scale: 1 };
    }
    if (t < 19.6) {
      const k = inQuad(seg(t, 19.25, 19.6));
      return { show: true, alpha: 1, x: gapTop.x - 8 * k, y: lerp(gapTop.y - 6, 552, k), rot: 1.9 * k, flip: -1, scale: 1 };
    }
    const FLOAT = [
      [19.6, GAPX - 8, 556, 1.0],
      [22.5, GAPX + 30, 604, 1.12],
      [26.2, GAPX + 104, 674, 1.24],
    ];
    if (t < 32.7) {
      const [x, y, s] = keyed(FLOAT, t, (k) => outCubic(k));
      const dip = t < 20.2 ? (1 - seg(t, 19.6, 20.2)) * 10 : 0;
      return { show: true, alpha: 1, x, y: y + Math.sin(t * 2.4) * 2 + dip, rot: 0.06 * Math.sin(t * 1.6), flip: -1, scale: s, floating: true, under: dip };
    }
    // Spout lifts it up beside Knurl, who takes it.
    const lifted = { x: GAPX + 22, y: deckY(GAPX) - 60 };
    if (t < 34.5) {
      const k = inOut(seg(t, 32.7, 34.5));
      const x = lerp(GAPX + 104, lifted.x, k);
      const y = lerp(674, lifted.y, k);
      return { show: true, alpha: 1, x, y, rot: 0.05 * Math.sin(t * 6), flip: -1, scale: lerp(1.24, 1, k), spout: true };
    }
    if (t < 35.6) {
      const k = inOut(seg(t, 34.8, 35.6));
      return { show: true, alpha: 1, x: lifted.x, y: lifted.y - Math.sin(k * Math.PI) * 14, rot: 0, flip: -Math.cos(Math.PI * k), scale: 1 };
    }
    if (t < 36.2) {
      const k = outBack(seg(t, 35.6, 36.2));
      return { show: true, alpha: 1, x: lerp(lifted.x, GAPX, clamp(k)), y: lerp(lifted.y, deckY(GAPX), k), rot: 0, flip: 1, scale: 1 };
    }
    return { show: false, placed: true };
  }
  const plankPlaced = (t) => t >= 36.2;

  // ------------------------------------------------------------------ canvas and view
  const frame = document.getElementById('story-frame');
  const canvas = document.getElementById('story-canvas');
  const ctx = canvas.getContext('2d');
  let W = 1280;
  let H = 720;
  let base = 1;
  let fs = 1;
  let tall = false;
  let fixedSize = null;
  const reduceMedia = window.matchMedia('(prefers-reduced-motion: reduce)');

  function resize() {
    if (fixedSize) {
      [W, H, tall] = fixedSize;
    } else {
      tall = frame.clientWidth < 560;
      frame.classList.toggle('is-tall', tall);
      const dpr = Math.min(2, window.devicePixelRatio || 1);
      W = Math.max(2, Math.round(frame.clientWidth * dpr));
      H = Math.max(2, Math.round(frame.clientHeight * dpr));
    }
    if (canvas.width !== W) canvas.width = W;
    if (canvas.height !== H) canvas.height = H;
    base = tall ? W / 920 : H / 720;
    fs = tall ? W / 560 : H / 720;
  }

  // Far layers (p < 1) zoom and pan less than the ground, but stay glued to the ground's horizon line.
  function layer(cam, p) {
    const z = base * (1 + (cam.zoom - 1) * p);
    const cx = HOME.x + (cam.x - HOME.x) * p;
    if (p < 1) {
      const horizon = H / 2 + (HORIZON - cam.y) * base * cam.zoom;
      return { z, e: W / 2 - cx * z, f: horizon - HORIZON * z };
    }
    const cy = HOME.y + (cam.y - HOME.y) * p;
    return { z, e: W / 2 - cx * z, f: H / 2 - cy * z };
  }
  const setLayer = (L) => ctx.setTransform(L.z, 0, 0, L.z, L.e, L.f);
  const toScreen = (L, x, y) => [L.e + x * L.z, L.f + y * L.z];

  // ------------------------------------------------------------------ pre-rendered far layers (blurred: depth of field)
  function offscreen(x0, y0, w, h, scale, blur, draw) {
    const c = document.createElement('canvas');
    c.width = Math.ceil(w * scale);
    c.height = Math.ceil(h * scale);
    const raw = document.createElement('canvas');
    raw.width = c.width;
    raw.height = c.height;
    const r = raw.getContext('2d');
    r.setTransform(scale, 0, 0, scale, -x0 * scale, -y0 * scale);
    draw(r);
    const g = c.getContext('2d');
    if (blur > 0) g.filter = `blur(${blur * scale}px)`;
    g.drawImage(raw, 0, 0);
    return { c, x0, y0, w, h };
  }
  function ridge(g, seed, y, amp, x0, x1, fill, bottom) {
    const r = rng(seed);
    const pts = [];
    const n = 28;
    const phase = r() * 10;
    for (let i = 0; i <= n; i++) {
      const x = lerp(x0, x1, i / n);
      const v = Math.sin(i * 0.55 + phase) * 0.55 + Math.sin(i * 1.37 + phase * 2) * 0.3 + (r() - 0.5) * 0.35;
      pts.push([x, y - amp * (0.6 + v * 0.5)]);
    }
    g.beginPath();
    g.moveTo(x0, bottom);
    g.lineTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) {
      const [ax, ay] = pts[i - 1];
      const [bx, by] = pts[i];
      g.quadraticCurveTo(ax, ay, (ax + bx) / 2, (ay + by) / 2);
    }
    g.lineTo(x1, bottom);
    g.closePath();
    g.fillStyle = fill;
    g.fill();
  }
  let layers = null;
  function buildLayers() {
    const mountains = offscreen(-900, 120, 3100, 420, 0.8, 3.2, (g) => {
      ridge(g, 7, 262, 120, -900, 2200, '#8a7fbf', 540);
      ridge(g, 11, 290, 90, -900, 2200, '#6f68a8', 540);
    });
    const hills = offscreen(-900, 170, 3100, 400, 1, 1.6, (g) => {
      ridge(g, 23, 312, 52, -900, 2200, '#4f5a8e', 570);
      const r = rng(31);
      for (let i = 0; i < 120; i++) {
        const x = -880 + r() * 3060;
        if (Math.abs(x - 640) < 70) continue;
        const h = 18 + r() * 34;
        const y = 300 + r() * 14;
        g.fillStyle = r() < 0.5 ? '#3d4a7a' : '#44507f';
        g.beginPath();
        if (r() < 0.55) {
          g.moveTo(x - h * 0.28, y);
          g.lineTo(x, y - h);
          g.lineTo(x + h * 0.28, y);
        } else {
          g.ellipse(x, y - h * 0.45, h * 0.32, h * 0.5, 0, 0, Math.PI * 2);
        }
        g.fill();
      }
      g.fillStyle = '#56608e';
      g.fillRect(-900, 306, 3100, 264);
    });
    const front = offscreen(-500, 560, 2300, 420, 0.7, 6, (g) => {
      const r = rng(77);
      const tuft = (cx, cy, size, colour) => {
        g.strokeStyle = colour;
        g.lineCap = 'round';
        for (let i = 0; i < 14; i++) {
          const a = -Math.PI / 2 + (r() - 0.5) * 1.3;
          const l = size * (0.6 + r() * 0.6);
          g.lineWidth = 3 + r() * 5;
          g.beginPath();
          g.moveTo(cx + (r() - 0.5) * size * 0.5, cy);
          g.quadraticCurveTo(cx + Math.cos(a) * l * 0.5, cy + Math.sin(a) * l * 0.6, cx + Math.cos(a) * l, cy + Math.sin(a) * l);
          g.stroke();
        }
      };
      for (let i = 0; i < 10; i++) tuft(-440 + r() * 520, 790 + r() * 60, 90 + r() * 80, i % 2 ? '#1d3a2c' : '#24452f');
      for (let i = 0; i < 10; i++) tuft(1200 + r() * 560, 790 + r() * 60, 90 + r() * 80, i % 2 ? '#1d3a2c' : '#24452f');
    });
    layers = { mountains, hills, front };
  }
  function drawLayer(cam, p, item) {
    setLayer(layer(cam, p));
    ctx.drawImage(item.c, item.x0, item.y0, item.w, item.h);
  }

  // ------------------------------------------------------------------ the set, drawn live
  function drawSky(t, cam) {
    const d = dusk(t);
    const L = layer(cam, 0.08);
    const hy = toScreen(L, 0, HORIZON)[1];
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const g = ctx.createLinearGradient(0, hy - 620 * L.z, 0, hy);
    g.addColorStop(0, mix('#3b3f86', '#0b0f2e', d));
    g.addColorStop(0.55, mix('#9a7cc4', '#2b2766', d));
    g.addColorStop(0.85, mix('#f2a98f', '#6c4a86', d));
    g.addColorStop(1, mix('#ffd3a1', '#b4708a', d));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    // Stars come out with the lanterns.
    const sa = smooth(seg(t, 34, 42));
    if (sa > 0) {
      const r = rng(5);
      setLayer(L);
      for (let i = 0; i < 90; i++) {
        const x = -400 + r() * 2100;
        const y = -420 + r() * 640;
        const tw = 0.6 + 0.4 * Math.sin(t * (1 + r() * 2) + i);
        ctx.fillStyle = `rgba(255,248,230,${(sa * tw * (0.35 + r() * 0.6)).toFixed(3)})`;
        ctx.beginPath();
        ctx.arc(x, y, 0.8 + r() * 1.4, 0, Math.PI * 2);
        ctx.fill();
      }
    }
    // The sun sets behind the hills.
    const S = layer(cam, 0.12);
    setLayer(S);
    const sy = lerp(236, 330, smooth(seg(t, 0, 40)));
    const glow = ctx.createRadialGradient(640, sy, 10, 640, sy, 360);
    glow.addColorStop(0, `rgba(255,214,160,${0.75 * (1 - d * 0.8)})`);
    glow.addColorStop(1, 'rgba(255,214,160,0)');
    ctx.fillStyle = glow;
    ctx.fillRect(-200, sy - 400, 1700, 800);
    ctx.fillStyle = mix('#fff1d2', '#ff9f7a', d);
    ctx.beginPath();
    ctx.arc(640, sy, 34, 0, Math.PI * 2);
    ctx.fill();
  }

  function drawGround(t, L) {
    setLayer(L);
    const d = dusk(t);
    // Meadow, misty at the horizon.
    const g = ctx.createLinearGradient(0, HORIZON, 0, 760);
    g.addColorStop(0, '#5a6290');
    g.addColorStop(0.1, '#566f78');
    g.addColorStop(0.3, '#46705a');
    g.addColorStop(1, '#2f6a3e');
    ctx.fillStyle = g;
    ctx.fillRect(-1200, HORIZON - 2, 3700, 1400);
    // The path Knurl takes, along the right bank.
    ctx.fillStyle = '#9a8566';
    ctx.beginPath();
    ctx.moveTo(700, HORIZON + 6);
    ctx.quadraticCurveTo(760, 420, 880, 600);
    ctx.lineTo(1010, 760);
    ctx.lineTo(1120, 760);
    ctx.quadraticCurveTo(980, 600, 852, 420);
    ctx.lineTo(724, HORIZON + 6);
    ctx.closePath();
    ctx.fill();
    // Stream: it flows towards us, so it widens.
    const top = HORIZON;
    const bottom = 1300;
    ctx.beginPath();
    for (let y = top; y <= bottom; y += 20) ctx.lineTo(riverX(y) - riverHalf(y), y);
    for (let y = bottom; y >= top; y -= 20) ctx.lineTo(riverX(y) + riverHalf(y), y);
    ctx.closePath();
    const wg = ctx.createLinearGradient(0, top, 0, 800);
    wg.addColorStop(0, mix('#ffd9b0', '#c890a8', d));
    wg.addColorStop(0.25, mix('#9b8dc8', '#4c4a8f', d));
    wg.addColorStop(1, mix('#3f5aa0', '#283a78', d));
    ctx.fillStyle = wg;
    ctx.fill();
    // Banks.
    ctx.strokeStyle = 'rgba(40,52,40,0.55)';
    ctx.lineWidth = 5;
    for (const side of [-1, 1]) {
      ctx.beginPath();
      for (let y = top + 4; y <= bottom; y += 20) ctx.lineTo(riverX(y) + side * (riverHalf(y) + 2), y);
      ctx.stroke();
    }
    // Shimmer drifting downstream, and the sun's reflection.
    const r = rng(19);
    ctx.lineCap = 'round';
    for (let i = 0; i < 70; i++) {
      const u = (r() + t * (0.012 + r() * 0.01)) % 1;
      const y = top + 6 + u * u * 520;
      const half = riverHalf(y);
      const x = riverX(y) + (r() * 2 - 1) * half * 0.85;
      const len = 6 + (y - top) * 0.09;
      const a = 0.18 + 0.25 * Math.sin(t * 2 + i);
      ctx.strokeStyle = `rgba(235,240,255,${Math.max(0, a).toFixed(3)})`;
      ctx.lineWidth = 1 + (y - top) * 0.006;
      ctx.beginPath();
      ctx.moveTo(x - len / 2, y);
      ctx.lineTo(x + len / 2, y);
      ctx.stroke();
    }
    for (let i = 0; i < 9; i++) {
      const y = top + 6 + i * 9;
      const w = 10 + i * 3 + Math.sin(t * 3 + i) * 3;
      ctx.strokeStyle = `rgba(255,236,200,${(0.55 * (1 - d) * (1 - i / 10)).toFixed(3)})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(riverX(y) - w / 2, y);
      ctx.lineTo(riverX(y) + w / 2, y);
      ctx.stroke();
    }
    // Distant bushes along both banks, then a band of mist over the horizon.
    const bush = rng(57);
    for (let i = 0; i < 20; i++) {
      const y = HORIZON + 4 + bush() ** 1.6 * 70;
      const side = i % 2 ? -1 : 1;
      const x = riverX(y) + side * (riverHalf(y) + 10 + bush() * 90);
      const r0 = 2 + (y - HORIZON) * 0.07 + bush() * 2;
      ctx.fillStyle = bush() < 0.5 ? '#2c4a40' : '#335446';
      ctx.beginPath();
      ctx.ellipse(x, y - r0 * 0.6, r0 * 1.4, r0 * 0.8, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    const mist = ctx.createLinearGradient(0, HORIZON - 46, 0, HORIZON + 70);
    mist.addColorStop(0, 'rgba(214,196,232,0)');
    mist.addColorStop(0.42, `rgba(214,196,232,${(0.5 - 0.25 * d).toFixed(3)})`);
    mist.addColorStop(1, 'rgba(214,196,232,0)');
    ctx.fillStyle = mist;
    ctx.fillRect(-1200, HORIZON - 46, 3700, 116);
    // Grass tufts on the banks.
    const q = rng(41);
    ctx.strokeStyle = '#24502f';
    ctx.lineWidth = 2.2;
    for (let i = 0; i < 140; i++) {
      const y = 380 + q() * 380;
      const side = q() < 0.5 ? -1 : 1;
      const x = riverX(y) + side * (riverHalf(y) + 20 + q() * 700);
      const h = 4 + (y - 380) * 0.035;
      ctx.beginPath();
      ctx.moveTo(x - h * 0.4, y);
      ctx.lineTo(x - h * 0.1, y - h);
      ctx.moveTo(x, y);
      ctx.lineTo(x + h * 0.15, y - h * 1.2);
      ctx.moveTo(x + h * 0.4, y);
      ctx.lineTo(x + h * 0.5, y - h * 0.9);
      ctx.stroke();
    }
  }

  function plankShape(x, y, rot, flip, scale, colours) {
    // A plank 42 wide: front face, a lighter top face (2.5D) and two pegs on its underside.
    const [top, face, edge, peg] = colours;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(rot);
    ctx.scale(scale, scale * (Math.abs(flip) < 0.08 ? 0.08 * Math.sign(flip || 1) : flip));
    const pegs = () => {
      ctx.fillStyle = peg;
      ctx.strokeStyle = edge;
      ctx.lineWidth = 1.5;
      for (const px of [-12, 12]) {
        ctx.beginPath();
        ctx.roundRect(px - 4.5, 5, 9, 12, 2.5);
        ctx.fill();
        ctx.stroke();
      }
    };
    pegs();
    ctx.fillStyle = face;
    ctx.strokeStyle = edge;
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.roundRect(-21, -6, 42, 13, 2.5);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = top;
    ctx.beginPath();
    ctx.moveTo(-21, -6);
    ctx.lineTo(-17, -12);
    ctx.lineTo(19, -12);
    ctx.lineTo(21, -6);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = 'rgba(70,40,20,0.35)';
    ctx.beginPath();
    ctx.moveTo(-16, 0);
    ctx.lineTo(14, 1);
    ctx.stroke();
    ctx.restore();
  }
  const WOOD = ['#e2b47e', '#b07a4a', '#4a2f1d', '#6b3f22'];

  function drawBridge(t, L) {
    setLayer(L);
    // Posts and the rope rail behind the deck.
    ctx.strokeStyle = '#4a2f1d';
    ctx.lineWidth = 2;
    const posts = [0, 3, 6, 9].map((i) => BX0 + i * PW);
    posts.forEach((x, i) => {
      const h = i === 0 || i === 3 ? 64 : 58;
      const y = deckY(x);
      ctx.fillStyle = '#7a5134';
      ctx.fillRect(x - 4, y - h, 8, h + 30);
      ctx.strokeRect(x - 4, y - h, 8, h + 30);
    });
    ctx.strokeStyle = '#d9c39a';
    ctx.lineWidth = 2.4;
    for (let i = 0; i < posts.length - 1; i++) {
      const a = posts[i];
      const b = posts[i + 1];
      const ya = deckY(a) - (i === 0 ? 60 : 54);
      const yb = deckY(b) - (i === 2 ? 60 : 54);
      ctx.beginPath();
      ctx.moveTo(a, ya);
      ctx.quadraticCurveTo((a + b) / 2, (ya + yb) / 2 + 12, b, yb);
      ctx.stroke();
    }
    // Arch beam under the deck.
    ctx.strokeStyle = '#5a3a24';
    ctx.lineWidth = 9;
    ctx.beginPath();
    for (let x = BX0 - 6; x <= BX1 + 6; x += 6) ctx.lineTo(x, deckY(x) + 16);
    ctx.stroke();
    // Deck planks; the middle one is missing until it is fitted.
    for (let i = 0; i < PLANKS; i++) {
      if (i === GAP && !plankPlaced(t)) continue;
      const xa = BX0 + i * PW + 1;
      const xb = BX0 + (i + 1) * PW - 1;
      const ya = deckY(xa);
      const yb = deckY(xb);
      ctx.fillStyle = i === GAP ? '#c99a62' : '#a8754a';
      ctx.strokeStyle = '#4a2f1d';
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(xa, ya);
      ctx.lineTo(xb, yb);
      ctx.lineTo(xb, yb + 13);
      ctx.lineTo(xa, ya + 13);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = i === GAP ? '#e8bd86' : '#d7a874';
      ctx.beginPath();
      ctx.moveTo(xa, ya);
      ctx.lineTo(xa + 3, ya - 7);
      ctx.lineTo(xb + 3, yb - 7);
      ctx.lineTo(xb, yb);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
    }
    // Footings on each bank.
    ctx.fillStyle = '#6b6f86';
    for (const x of [BX0 - 14, BX1 + 14]) {
      ctx.beginPath();
      ctx.ellipse(x, deckY(x) + 20, 26, 9, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function lanternPos(l) {
    if (l.ground) return { x: l.x, y: l.ground - l.post - 4, base: l.ground };
    return { x: l.x, y: deckY(l.x) - l.post - 6, base: null };
  }
  function drawLanternPosts(L) {
    setLayer(L);
    for (const l of LANTERNS) {
      if (!l.ground) continue;
      ctx.fillStyle = '#3a2a22';
      ctx.fillRect(l.x - 4, l.ground - l.post, 8, l.post);
      ctx.fillRect(l.x - 14, l.ground - l.post, 28, 5);
    }
  }
  function drawLanterns(t, L) {
    setLayer(L);
    LANTERNS.forEach((l, i) => {
      const p = lanternPos(l);
      const on = lanternOn(i, t);
      ctx.strokeStyle = '#2a1d16';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(p.x, p.y - 12);
      ctx.lineTo(p.x, p.y - 4);
      ctx.stroke();
      ctx.fillStyle = mix('#5a4a52', '#ffd27a', on);
      ctx.strokeStyle = '#2a1d16';
      ctx.beginPath();
      ctx.roundRect(p.x - 8, p.y - 4, 16, 20, 4);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = '#2a1d16';
      ctx.fillRect(p.x - 10, p.y - 6, 20, 4);
    });
  }
  function drawLanternGlow(t, L) {
    setLayer(L);
    ctx.globalCompositeOperation = 'lighter';
    LANTERNS.forEach((l, i) => {
      const on = lanternOn(i, t);
      if (on <= 0) return;
      const p = lanternPos(l);
      const flick = 0.92 + 0.08 * Math.sin(t * 9 + i * 2);
      const g = ctx.createRadialGradient(p.x, p.y + 6, 2, p.x, p.y + 6, 150);
      g.addColorStop(0, `rgba(255,190,110,${(0.55 * on * flick).toFixed(3)})`);
      g.addColorStop(0.35, `rgba(255,150,80,${(0.16 * on * flick).toFixed(3)})`);
      g.addColorStop(1, 'rgba(255,140,60,0)');
      ctx.fillStyle = g;
      ctx.fillRect(p.x - 150, p.y - 144, 300, 300);
      // Reflection on the water for the bridge lanterns.
      if (!l.ground) {
        const ry = 2 * deckY(l.x) - p.y + 70;
        const rg = ctx.createRadialGradient(p.x, ry, 1, p.x, ry, 40);
        rg.addColorStop(0, `rgba(255,200,120,${(0.35 * on).toFixed(3)})`);
        rg.addColorStop(1, 'rgba(255,200,120,0)');
        ctx.fillStyle = rg;
        ctx.save();
        ctx.translate(p.x, ry);
        ctx.scale(0.5, 1.6);
        ctx.translate(-p.x, -ry);
        ctx.fillRect(p.x - 40, ry - 40, 80, 80);
        ctx.restore();
      }
    });
    ctx.globalCompositeOperation = 'source-over';
  }

  function clockText(t) {
    const minutes = t < 21 ? lerp(0, 2, seg(t, 0, 21)) : lerp(2, 10, seg(t, 21, 39.1));
    const m = Math.min(10, Math.floor(minutes + 1e-6));
    return m >= 10 ? '5:00' : `4:5${m}`;
  }
  function drawBoard(t, L) {
    setLayer(L);
    const x = 1214;
    const y = 462;
    // Easel legs.
    ctx.strokeStyle = '#4a3326';
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.moveTo(x - 50, y + 60);
    ctx.lineTo(x - 66, 596);
    ctx.moveTo(x + 50, y + 60);
    ctx.lineTo(x + 66, 596);
    ctx.moveTo(x, y + 40);
    ctx.lineTo(x + 6, 588);
    ctx.stroke();
    // Board.
    ctx.fillStyle = '#f4f1fb';
    ctx.strokeStyle = '#4a3326';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.roundRect(x - 78, y - 66, 156, 132, 8);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#6a4fb3';
    ctx.beginPath();
    ctx.roundRect(x - 70, y - 58, 140, 20, 4);
    ctx.fill();
    const blocks = [
      ['#c7b8f0', 0, 70],
      ['#9d86e0', 74, 52],
      ['#e9c46a', 0, 40],
      ['#c7b8f0', 44, 46],
      ['#8bd3c7', 94, 46],
    ];
    blocks.forEach(([c, dx, w], i) => {
      ctx.fillStyle = c;
      ctx.beginPath();
      ctx.roundRect(x - 70 + dx, y - 30 + (i < 2 ? 0 : 18), w, 13, 3);
      ctx.fill();
    });
    // The clock everybody watches.
    const clash = t > 19.6 && t < 37.0;
    ctx.fillStyle = clash ? '#c2410c' : '#2b2160';
    ctx.font = '700 34px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(clockText(t), x, y + 36);
  }
  function drawPlankStack(L) {
    setLayer(L);
    for (let i = 0; i < 3; i++) plankShape(176 + (i % 2) * 4, 584 - i * 15, 0, 1, 1.25, WOOD);
  }

  // ------------------------------------------------------------------ the engine's mascots
  const els = {};
  const boxes = {};
  for (const id of CAST) els[id] = document.getElementById(`cast-${id}`);
  const canvasOf = (id) => els[id]?.querySelector('canvas.mascot-canvas');

  // The painted area inside each engine canvas, measured once at rest: it puts feet on the ground.
  function measure(id) {
    const c = canvasOf(id);
    if (!c || c.width < 8) return null;
    let data;
    try {
      data = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
    } catch {
      return null;
    }
    let x0 = c.width;
    let y0 = c.height;
    let x1 = -1;
    let y1 = -1;
    for (let y = 0; y < c.height; y += 2) {
      for (let x = 0; x < c.width; x += 2) {
        if (data[(y * c.width + x) * 4 + 3] > 170) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    if (x1 < 0) return null;
    return { x0: x0 / c.width, y0: y0 / c.height, x1: x1 / c.width, y1: y1 / c.height };
  }
  function measureAll() {
    for (const id of CAST) if (!boxes[id]) boxes[id] = measure(id);
    return CAST.every((id) => boxes[id]);
  }

  // Draw one engine canvas with its feet at (x, y) in world units. Returns the head point for bubbles.
  function drawMascot(id, pos, L, opts = {}) {
    const c = canvasOf(id);
    const b = boxes[id];
    if (!c || !b || pos.alpha <= 0) return null;
    const s = 1 - 0.75 * (pos.z || 0);
    const h = HEIGHT[id] * s;
    const k = h / ((b.y1 - b.y0) * c.width);
    const size = c.width * k;
    const cx = (b.x0 + b.x1) / 2;
    const left = pos.x - cx * size;
    const top = pos.y + (pos.bob || 0) - b.y1 * size;
    const inkW = (b.x1 - b.x0) * size;
    setLayer(L);
    if (!opts.noShadow) {
      ctx.fillStyle = `rgba(12,14,40,${(0.22 * pos.alpha).toFixed(3)})`;
      ctx.beginPath();
      ctx.ellipse(pos.x, pos.y + 2, inkW * 0.42, 7 * s, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.save();
    // Clip just below the feet: the stage draws its own ground shadow, so the engine's is left out here.
    const clipY = opts.clipY ?? pos.y + (pos.bob || 0) + 3;
    ctx.beginPath();
    ctx.rect(pos.x - 400, clipY - 900, 800, 900);
    ctx.clip();
    ctx.globalAlpha = pos.alpha;
    const blur = (pos.z || 0) * 2.6 * L.z;
    const bright = opts.bright ?? 1;
    const filters = [];
    if (blur > 0.3) filters.push(`blur(${blur.toFixed(2)}px)`);
    if (bright < 0.995) filters.push(`brightness(${bright.toFixed(3)})`);
    if (filters.length) ctx.filter = filters.join(' ');
    ctx.translate(pos.x, pos.y);
    if (pos.tilt) ctx.rotate(pos.tilt);
    if (pos.mirror) ctx.scale(-1, 1);
    ctx.translate(-pos.x, -pos.y);
    ctx.drawImage(c, left, top, size, size);
    ctx.restore();
    ctx.filter = 'none';
    return { head: [pos.x, top + b.y0 * size], feet: [pos.x, pos.y], width: inkW };
  }

  // ------------------------------------------------------------------ water effects
  function ripple(L, x, y, age, scale = 1, strength = 1) {
    if (age < 0 || age > 2.2) return;
    setLayer(L);
    for (let i = 0; i < 3; i++) {
      const a = age - i * 0.28;
      if (a < 0) continue;
      const r = (10 + a * 70) * scale;
      const alpha = (1 - a / 2.2) * 0.55 * strength;
      if (alpha <= 0) continue;
      ctx.strokeStyle = `rgba(230,240,255,${alpha.toFixed(3)})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 0.28, 0, 0, Math.PI * 2);
      ctx.stroke();
    }
  }
  function splash(L, x, y, age) {
    if (age < 0 || age > 1.1) return;
    setLayer(L);
    const r = rng(99);
    for (let i = 0; i < 22; i++) {
      const vx = (r() - 0.5) * 220;
      const vy = -160 - r() * 220;
      const px = x + vx * age;
      const py = y + vy * age + 520 * age * age;
      if (py > y + 6) continue;
      ctx.fillStyle = `rgba(225,238,255,${(0.9 * (1 - age)).toFixed(3)})`;
      ctx.beginPath();
      ctx.arc(px, py, 2.5 + r() * 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  function spout(L, t, plank) {
    const k = seg(t, 32.5, 32.9) * (1 - seg(t, 34.5, 35.0));
    if (k <= 0) return;
    setLayer(L);
    const baseX = GAPX + 104;
    const baseY = 676;
    const topX = plank.x;
    const topY = plank.y + 10;
    const w0 = 22 * k;
    const w1 = 10 * k;
    ctx.beginPath();
    const steps = 16;
    for (let i = 0; i <= steps; i++) {
      const u = i / steps;
      const x = lerp(baseX, topX, u) + Math.sin(u * 9 + t * 14) * 3 - lerp(w0, w1, u);
      ctx.lineTo(x, lerp(baseY, topY, u));
    }
    for (let i = steps; i >= 0; i--) {
      const u = i / steps;
      const x = lerp(baseX, topX, u) + Math.sin(u * 9 + t * 14 + 1) * 3 + lerp(w0, w1, u);
      ctx.lineTo(x, lerp(baseY, topY, u));
    }
    ctx.closePath();
    const g = ctx.createLinearGradient(0, baseY, 0, topY);
    g.addColorStop(0, `rgba(140,190,255,${0.75 * k})`);
    g.addColorStop(1, `rgba(220,240,255,${0.85 * k})`);
    ctx.fillStyle = g;
    ctx.fill();
    ctx.strokeStyle = `rgba(255,255,255,${0.6 * k})`;
    ctx.lineWidth = 1.5;
    ctx.stroke();
    const r = rng(3);
    for (let i = 0; i < 10; i++) {
      const a = (t * 2 + r()) % 1;
      ctx.fillStyle = `rgba(235,245,255,${(0.8 * k * (1 - a)).toFixed(3)})`;
      ctx.beginPath();
      ctx.arc(topX + (r() - 0.5) * 40 * a, topY - 4 - a * 16 + a * a * 30, 2 + r() * 2, 0, Math.PI * 2);
      ctx.fill();
    }
    ripple(L, baseX, baseY, (t - 32.5) % 0.9, 0.6, k);
  }
  function sparkles(L, x, y, age) {
    if (age < 0 || age > 0.9) return;
    setLayer(L);
    const r = rng(12);
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2 + r() * 0.3;
      const d = 14 + age * 50;
      const s = (1 - age) * 5;
      const px = x + Math.cos(a) * d;
      const py = y - 6 + Math.sin(a) * d * 0.6;
      ctx.fillStyle = `rgba(255,236,170,${(1 - age).toFixed(3)})`;
      ctx.beginPath();
      ctx.moveTo(px, py - s);
      ctx.lineTo(px + s * 0.35, py);
      ctx.lineTo(px, py + s);
      ctx.lineTo(px - s * 0.35, py);
      ctx.closePath();
      ctx.fill();
    }
  }
  function fireflies(t, cam) {
    const a = smooth(seg(t, 37, 41));
    if (a <= 0) return;
    const r = rng(8);
    ctx.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 34; i++) {
      const far = r() < 0.7;
      const L = layer(cam, far ? 1 : 1.3);
      setLayer(L);
      const x = r() * 1400 - 60 + Math.sin(t * 0.7 + i) * 20;
      const y = (far ? 380 : 560) + r() * 260 + Math.cos(t * 0.9 + i * 2) * 12;
      const tw = 0.5 + 0.5 * Math.sin(t * (2 + r() * 2) + i * 3);
      const rad = far ? 7 : 16;
      const g = ctx.createRadialGradient(x, y, 0, x, y, rad);
      g.addColorStop(0, `rgba(255,240,170,${(0.85 * a * tw).toFixed(3)})`);
      g.addColorStop(1, 'rgba(255,220,120,0)');
      ctx.fillStyle = g;
      ctx.fillRect(x - rad, y - rad, rad * 2, rad * 2);
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  // ------------------------------------------------------------------ bubbles, tags and cards (screen space)
  const FONT = 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';
  function wrap(text, maxW) {
    const words = text.split(' ');
    const lines = [];
    let line = '';
    for (const w of words) {
      const next = line ? `${line} ${w}` : w;
      if (ctx.measureText(next).width > maxW && line) {
        lines.push(line);
        line = w;
      } else line = next;
    }
    if (line) lines.push(line);
    return lines;
  }
  function bubble(text, anchor, appear, reduced, placed = []) {
    const a = reduced ? 1 : appear;
    if (a <= 0) return;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const size = 30 * fs;
    ctx.font = `650 ${size}px ${FONT}`;
    const lines = wrap(text, (tall ? 0.7 : 0.36) * W);
    const lh = size * 1.22;
    const tw = Math.max(...lines.map((l) => ctx.measureText(l).width));
    const padX = 20 * fs;
    const padY = 13 * fs;
    const bw = tw + padX * 2;
    const bh = lines.length * lh + padY * 2;
    const m = 14 * fs;
    let ax = anchor[0];
    let ay = anchor[1] - 12 * fs;
    ax = clamp(ax, m + 20 * fs, W - m - 20 * fs);
    ay = clamp(ay, bh + m + 18 * fs, H - m);
    let bx = clamp(ax - bw / 2, m, W - m - bw);
    let by = ay - 18 * fs - bh;
    // Two bubbles at once: slide the later one sideways, or lift it if there is no room beside the first.
    for (const r of placed) {
      if (!(bx < r.x + r.w + 8 * fs && bx + bw > r.x - 8 * fs && by < r.y + r.h + 8 * fs && by + bh > r.y - 8 * fs)) continue;
      const side = ax > r.x + r.w / 2 ? r.x + r.w + 10 * fs : r.x - bw - 10 * fs;
      if (side >= m && side <= W - m - bw) bx = side;
      else by = r.y - bh - 10 * fs;
    }
    by = Math.max(m, by);
    placed.push({ x: bx, y: by, w: bw, h: bh });
    const pop = reduced ? 1 : outBack(clamp(appear * 1.0));
    ctx.save();
    ctx.globalAlpha = clamp(a * 1.4);
    ctx.translate(ax, ay);
    ctx.scale(0.86 + 0.14 * pop, 0.86 + 0.14 * pop);
    ctx.translate(-ax, -ay);
    ctx.shadowColor = 'rgba(10,12,40,0.35)';
    ctx.shadowBlur = 16 * fs;
    ctx.shadowOffsetY = 4 * fs;
    ctx.fillStyle = 'rgba(255,255,255,0.97)';
    ctx.beginPath();
    ctx.roundRect(bx, by, bw, bh, 16 * fs);
    const tx = clamp(ax, bx + 22 * fs, bx + bw - 22 * fs);
    ctx.moveTo(tx - 11 * fs, by + bh - 1);
    ctx.lineTo(ax, ay);
    ctx.lineTo(tx + 11 * fs, by + bh - 1);
    ctx.fill();
    ctx.shadowColor = 'transparent';
    ctx.fillStyle = '#1d2340';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    lines.forEach((l, i) => {
      ctx.fillText(l, bx + padX, by + padY + lh * (i + 0.5));
    });
    ctx.restore();
  }
  const MOOD_DOT = { idle: '#9aa6c8', thinking: '#f2c14e', happy: '#5ccf8a', worried: '#ff8a6b', celebrating: '#c9a3ff' };
  function statusOf(id) {
    const el = els[id];
    const text = el?.querySelector('.mascot-status')?.textContent?.trim() || '';
    const mood = el?.dataset.shownMood || el?.dataset.mood || 'idle';
    return { text, mood };
  }
  function tag(id, feet, appear, placed, above = false) {
    if (appear <= 0) return;
    const { text, mood } = statusOf(id);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const size = 17 * fs * (tall ? 1.15 : 1);
    const nameFont = `700 ${size}px ${FONT}`;
    const textFont = `500 ${size}px ${FONT}`;
    ctx.font = nameFont;
    const nw = ctx.measureText(NAME[id]).width;
    ctx.font = textFont;
    const sw = ctx.measureText(text).width;
    const dot = 9 * fs;
    const gap = 8 * fs;
    const padX = 12 * fs;
    const w = padX + dot + gap + nw + gap + sw + padX;
    const h = size * 1.9;
    const m = 10 * fs;
    let x = clamp(feet[0] - w / 2, m, W - m - w);
    let y = clamp(above ? feet[1] - h - 12 * fs : feet[1] + 12 * fs, m, H - m - h);
    // Keep tags from sitting on each other.
    for (const r of placed) {
      if (x < r.x + r.w + 6 * fs && x + w > r.x - 6 * fs && y < r.y + r.h && y + h > r.y) y = r.y + r.h + 6 * fs;
    }
    y = Math.min(y, H - m - h);
    placed.push({ x, y, w, h });
    ctx.save();
    ctx.globalAlpha = clamp(appear);
    ctx.fillStyle = 'rgba(16,18,46,0.82)';
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, h / 2);
    ctx.fill();
    ctx.fillStyle = MOOD_DOT[mood] || MOOD_DOT.idle;
    ctx.beginPath();
    ctx.arc(x + padX + dot / 2, y + h / 2, dot / 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'left';
    ctx.fillStyle = '#ffffff';
    ctx.font = nameFont;
    ctx.fillText(NAME[id], x + padX + dot + gap, y + h / 2 + 1);
    ctx.fillStyle = '#dfe3ff';
    ctx.font = textFont;
    ctx.fillText(text, x + padX + dot + gap + nw + gap, y + h / 2 + 1);
    ctx.restore();
  }
  function titleCard(t, reduced) {
    const a = reduced ? (t < 3.4 ? 1 : 0) : smooth(seg(t, 0.1, 0.8)) * (1 - smooth(seg(t, 2.8, 3.6)));
    if (a <= 0) return;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, `rgba(12,14,46,${0.55 * a})`);
    g.addColorStop(0.6, `rgba(12,14,46,${0.25 * a})`);
    g.addColorStop(1, `rgba(12,14,46,${0.1 * a})`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    ctx.globalAlpha = a;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#fff6e8';
    ctx.shadowColor = 'rgba(0,0,0,0.35)';
    ctx.shadowBlur = 12 * fs;
    ctx.font = `600 ${(tall ? 64 : 76) * fs}px Georgia, "Times New Roman", serif`;
    const lift = reduced ? 0 : (1 - outCubic(seg(t, 0.1, 1.2))) * 14 * fs;
    ctx.fillText('The Bridge at Five', W / 2, H * (tall ? 0.2 : 0.3) + lift);
    ctx.font = `500 ${26 * fs}px ${FONT}`;
    ctx.fillStyle = '#ffe9cf';
    ctx.fillText('A short story with Tessa, Sela, Knurl and Neer', W / 2, H * (tall ? 0.2 : 0.3) + 64 * fs + lift);
    ctx.shadowColor = 'transparent';
    ctx.globalAlpha = 1;
  }
  function endCard(t, reduced) {
    const a = reduced ? (t >= 46.8 ? 1 : 0) : smooth(seg(t, 46.7, 47.4));
    if (a <= 0) return;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, '#1b1c4a');
    g.addColorStop(1, '#2c1f4f');
    ctx.globalAlpha = a;
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    const c = smooth(seg(t, 47.1, 47.9)) || (reduced ? 1 : 0);
    ctx.globalAlpha = a * (reduced ? 1 : c);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#fff6e8';
    ctx.font = `600 ${(tall ? 54 : 60) * fs}px Georgia, "Times New Roman", serif`;
    ctx.fillText('Meet your mascots', W / 2, H * (tall ? 0.12 : 0.17));
    // The four, drawn by the engine, in a row.
    const n = CAST.length;
    const cols = tall ? 2 : n;
    const slot = tall ? W * 0.42 : Math.min(W / (n + 0.6), 250 * fs);
    CAST.forEach((id, i) => {
      const cv = canvasOf(id);
      const b = boxes[id];
      if (!cv || !b) return;
      const col = i % cols;
      const row = Math.floor(i / cols);
      const rowY = tall ? H * (0.42 + row * 0.25) : H * 0.56;
      const cx = W / 2 + (col - (cols - 1) / 2) * slot;
      const h = slot * (tall ? 0.5 : 0.82) * (HEIGHT[id] / 196);
      const size = h / (b.y1 - b.y0);
      const left = cx - ((b.x0 + b.x1) / 2) * size;
      const top = rowY - b.y1 * size;
      const hop = reduced ? 0 : Math.max(0, Math.sin((t - 47.5 - i * 0.18) * 5)) * 8 * fs * (1 - seg(t, 48.6, 49.4));
      ctx.drawImage(cv, left, top - hop, size, size);
      ctx.fillStyle = '#ffffff';
      ctx.font = `700 ${24 * fs}px ${FONT}`;
      ctx.fillText(NAME[id], cx, rowY + 28 * fs);
    });
    ctx.fillStyle = '#e6e1ff';
    ctx.font = `500 ${(tall ? 22 : 24) * fs}px ${FONT}`;
    const l1 = 'Drawn live, in code, by the mascot package.';
    const l2 = 'Five moods each, and a status line for every mood.';
    if (tall) {
      ctx.font = `500 ${18 * fs}px ${FONT}`;
      ctx.fillText(l1, W / 2, H * 0.84);
      ctx.fillText(l2, W / 2, H * 0.84 + 28 * fs);
    } else {
      ctx.fillText(l1, W / 2, H * 0.72);
      ctx.fillText(l2, W / 2, H * 0.72 + 38 * fs);
    }
    ctx.globalAlpha = 1;
  }

  // ------------------------------------------------------------------ one frame
  function multiplyOverlay(t) {
    const d = dusk(t);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = 'multiply';
    ctx.fillStyle = mix('#ffffff', '#7d82c4', d * 0.72);
    ctx.fillRect(0, 0, W, H);
    ctx.globalCompositeOperation = 'source-over';
  }
  function vignette() {
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const g = ctx.createRadialGradient(W / 2, H * 0.52, Math.min(W, H) * 0.35, W / 2, H / 2, Math.max(W, H) * 0.75);
    g.addColorStop(0, 'rgba(8,8,30,0)');
    g.addColorStop(1, 'rgba(8,8,30,0.5)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
  }
  function sunWash(t, cam) {
    const d = dusk(t);
    const L = layer(cam, 0.12);
    const [sx, sy] = toScreen(L, 640, lerp(236, 330, smooth(seg(t, 0, 40))));
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = 'screen';
    const g = ctx.createRadialGradient(sx, sy, 0, sx, sy, Math.max(W, H) * 0.7);
    g.addColorStop(0, `rgba(255,170,110,${(0.28 * (1 - d)).toFixed(3)})`);
    g.addColorStop(1, 'rgba(255,170,110,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    ctx.globalCompositeOperation = 'source-over';
  }

  function render(t, reduced = false) {
    if (!layers) buildLayers();
    const cam = camera(t, reduced);
    const L = layer(cam, 1);
    const d = dusk(t);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalAlpha = 1;
    ctx.filter = 'none';
    drawSky(t, cam);
    drawLayer(cam, 0.2, layers.mountains);
    drawLayer(cam, 0.45, layers.hills);
    drawGround(t, L);
    drawLanternPosts(L);
    drawPlankStack(L);
    drawBoard(t, L);
    const plank = plankAt(t);
    // The splash and the plank in the water belong to the set; the bridge stands in front of the far water.
    ripple(L, GAPX - 8, 556, t - 19.6, 0.8);
    if (plank.show && plank.floating) {
      ripple(L, plank.x, plank.y + 6, (t - 19.6) % 1.6, plank.scale * 0.5, 0.7);
      plankShape(plank.x, plank.y + (plank.under || 0), plank.rot, plank.flip, plank.scale, WOOD);
    }
    splash(L, GAPX - 8, 556, t - 19.6);
    drawBridge(t, L);
    drawLanterns(t, L);
    multiplyOverlay(t);
    sunWash(t, cam);

    // Mascots, back to front.
    const bright = lerp(1, 0.86, d);
    const anchors = {};
    const kn = knurlAt(t);
    const ne = neerAt(t);
    anchors.knurl = drawMascot('knurl', kn, L, { bright });
    if (plank.show && !plank.floating && plank.z !== undefined && plank.z > 0.05) {
      setLayer(L);
      plankShape(plank.x, plank.y, plank.rot, plank.flip, plank.scale, WOOD);
    }
    anchors.tessa = drawMascot('tessa', tessaAt(t), L, { bright });
    anchors.sela = drawMascot('sela', selaAt(t), L, { bright });
    if (plank.show && !plank.floating && !(plank.z > 0.05)) {
      spout(L, t, plank);
      setLayer(L);
      plankShape(plank.x, plank.y, plank.rot, plank.flip, plank.scale, WOOD);
    }
    sparkles(L, GAPX, deckY(GAPX), t - 36.2);
    if (ne.rise > 0) {
      const lift = (1 - ne.rise) * HEIGHT.neer * 1.1;
      const pos = { ...ne, y: ne.y + lift, x: ne.x + ne.sway };
      anchors.neer = drawMascot('neer', pos, L, { bright, clipY: WATER_FRONT - 18, noShadow: true });
      if (anchors.neer) anchors.neer.feet = [ne.x, WATER_FRONT - 10];
      setLayer(L);
      ctx.strokeStyle = 'rgba(225,238,255,0.55)';
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.ellipse(ne.x + ne.sway, WATER_FRONT - 18, 58, 9, 0, 0, Math.PI * 2);
      ctx.stroke();
    }
    ripple(L, ne.x, WATER_FRONT - 18, t - 25.6, 1.1);
    ripple(L, ne.x, WATER_FRONT - 18, t - 26.2, 1.3);
    if (t > NEER_RISE[1]) ripple(L, ne.x, WATER_FRONT - 18, (t - NEER_RISE[1]) % 2.6, 0.9, 0.5);

    drawLanternGlow(t, L);
    fireflies(t, cam);
    drawLayer(cam, 1.35, layers.front);
    vignette();

    // Status tags and speech bubbles, in screen space.
    const placed = [];
    // On a phone-sized frame only the newest status tag shows; the captions under the film list them all.
    let newest = -1;
    if (tall) TAGS.forEach(([a, b], i) => {
      if (t >= a && t <= b + 0.4) newest = i;
    });
    for (const [i, [a, b, id, where]] of TAGS.entries()) {
      if (t < a || t > b + 0.4) continue;
      if (tall && i !== newest) continue;
      const anchor = anchors[id];
      if (!anchor) continue;
      const appear = reduced ? 1 : seg(t, a, a + 0.3) * (1 - seg(t, b, b + 0.4));
      const at = where === 'above' ? toScreen(L, anchor.head[0], anchor.head[1]) : toScreen(L, anchor.feet[0], anchor.feet[1]);
      tag(id, at, appear, placed, where === 'above');
    }
    const said = [];
    for (const [a, b, id, text] of LINES) {
      if (t < a || t > b + 0.3) continue;
      const anchor = anchors[id];
      if (!anchor) continue;
      const appear = seg(t, a, a + 0.25) * (1 - seg(t, b, b + 0.3));
      bubble(text, toScreen(L, anchor.head[0], anchor.head[1]), appear, reduced && t <= b, said);
    }
    titleCard(t, reduced);
    endCard(t, reduced);
  }

  // ------------------------------------------------------------------ driving the engine
  const host = () => window.mascot?.host;
  const sent = {};
  function send(id, patch) {
    const h = host();
    if (!h) return;
    h.receive({ id: `cast-${id}`, patch });
  }
  function moodAt(id, t) {
    let mood = 'idle';
    for (const [time, who, m] of MOODS) if (who === id && time <= t) mood = m;
    return mood;
  }
  let lastT = -1;
  function applyCues(t, withGestures = true) {
    for (const id of CAST) {
      const mood = moodAt(id, t);
      if (sent[id] !== mood) {
        sent[id] = mood;
        send(id, { mood, status: { mode: 'mood' } });
      }
    }
    if (withGestures) {
      for (const [time, id, gesture] of GESTURES) {
        if (time > lastT && time <= t && t - time < 0.5) send(id, { gesture });
      }
    }
    lastT = t;
  }
  function resetCues() {
    lastT = -1;
    applyCues(0, false);
  }

  // ------------------------------------------------------------------ captions and transcript (real DOM text)
  const captions = document.getElementById('story-captions');
  let captionKey = '';
  function captionAt(t) {
    let narration = '';
    for (const [time, text] of NARRATION) if (time <= t) narration = text;
    const said = LINES.filter(([a, b]) => t >= a && t <= b + 0.3);
    const tags = [];
    for (const [a, b, id] of TAGS) if (t >= a + 0.3 && t <= b) tags.push(id);
    return { narration, said, tags: [...new Set(tags)] };
  }
  function updateCaptions(t) {
    const c = captionAt(t);
    const statuses = c.tags.map((id) => `${NAME[id]}: ${statusOf(id).text}`);
    const key = JSON.stringify([c.narration, c.said.map((l) => l[3]), statuses]);
    if (key === captionKey) return;
    captionKey = key;
    captions.replaceChildren();
    const p = document.createElement('p');
    p.className = 'story-caption-narration';
    p.textContent = c.narration;
    captions.append(p);
    for (const [, , who, text] of c.said) {
      const line = document.createElement('p');
      const name = document.createElement('span');
      name.className = 'story-caption-who';
      name.textContent = `${NAME[who]}: `;
      line.append(name, document.createTextNode(text));
      captions.append(line);
    }
    if (statuses.length) {
      const s = document.createElement('p');
      s.className = 'story-caption-status';
      s.textContent = `Status lines: ${statuses.join(' · ')}`;
      captions.append(s);
    }
  }
  function buildTranscript() {
    const list = document.getElementById('story-transcript-list');
    if (!list) return;
    const items = [
      ...NARRATION.map(([time, text]) => ({ time, text, who: null })),
      ...LINES.map(([time, , who, text]) => ({ time, text, who })),
    ].sort((a, b) => a.time - b.time);
    for (const item of items) {
      const li = document.createElement('li');
      if (item.who) {
        const b = document.createElement('strong');
        b.textContent = `${NAME[item.who]}: `;
        li.append(b, document.createTextNode(item.text));
      } else {
        const e = document.createElement('em');
        e.textContent = item.text;
        li.append(e);
      }
      list.append(li);
    }
  }

  // ------------------------------------------------------------------ playback
  const playBtn = document.getElementById('story-play');
  const bigPlay = document.getElementById('story-big-play');
  const restartBtn = document.getElementById('story-restart');
  const prevBtn = document.getElementById('story-prev');
  const nextBtn = document.getElementById('story-next');
  const note = document.getElementById('story-motion-note');
  const animateBtn = document.getElementById('story-animate');
  const bar = document.getElementById('story-progress-bar');
  const timeEl = document.getElementById('story-time');
  let playing = false;
  let current = 0;
  let startedAt = 0;
  let request = null;
  let stepMode = false;
  let stepIndex = -1;
  let settle = null;
  let ready = false;
  let recording = false;

  // The engine pauses mascots that are outside the window; the cast rests there while nothing plays.
  const rest = (on) => frame.classList.toggle('is-resting', on && !recording);
  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
  function progress(t) {
    bar.style.width = `${(100 * clamp(t / DURATION)).toFixed(2)}%`;
    timeEl.textContent = stepMode && stepIndex >= 0 ? `${stepIndex + 1} / ${KEYFRAMES.length}` : fmt(t);
  }
  function loop(now) {
    request = null;
    if (!playing) return;
    current = Math.min(DURATION, (now - startedAt) / 1000);
    applyCues(current);
    render(current, false);
    updateCaptions(current);
    progress(current);
    if (current >= DURATION) {
      playing = false;
      rest(true);
      playBtn.textContent = 'Play again';
      bigPlay.hidden = false;
      bigPlay.querySelector('.story-big-play-label').textContent = 'Play again';
      return;
    }
    request = window.requestAnimationFrame(loop);
  }
  function play() {
    if (!ready) return;
    stopSettle();
    stepMode = false;
    if (current >= DURATION) restart(false);
    playing = true;
    rest(false);
    startedAt = performance.now() - current * 1000;
    playBtn.textContent = 'Pause';
    bigPlay.hidden = true;
    canvas.setAttribute('aria-label', 'The Bridge at Five is playing. Captions are below the film.');
    if (request === null) request = window.requestAnimationFrame(loop);
  }
  function pause() {
    playing = false;
    rest(true);
    playBtn.textContent = 'Play';
    if (request !== null) window.cancelAnimationFrame(request);
    request = null;
  }
  function restart(autoplay = true) {
    pause();
    current = 0;
    resetCues();
    progress(0);
    if (autoplay && !stepMode) play();
    else render(stepMode ? KEYFRAMES[0] : POSTER_TIME, stepMode);
  }
  function stopSettle() {
    if (settle !== null) window.cancelAnimationFrame(settle);
    settle = null;
  }
  // Still scenes: moods are set, then the scene is redrawn for a moment while the engine shows the new faces.
  function showStill(t) {
    stopSettle();
    current = t;
    lastT = t;
    applyCues(t, false);
    updateCaptions(t);
    progress(t);
    rest(false);
    const until = performance.now() + 1200;
    const step = (now) => {
      render(t, true);
      settle = now < until ? window.requestAnimationFrame(step) : null;
      if (settle === null) rest(true);
    };
    settle = window.requestAnimationFrame(step);
  }
  function step(dir) {
    pause();
    stepMode = true;
    bigPlay.hidden = true;
    stepIndex = clamp(stepIndex + dir, 0, KEYFRAMES.length - 1);
    prevBtn.disabled = stepIndex === 0;
    nextBtn.disabled = stepIndex === KEYFRAMES.length - 1;
    showStill(KEYFRAMES[stepIndex]);
    canvas.setAttribute('aria-label', `The Bridge at Five, scene ${stepIndex + 1} of ${KEYFRAMES.length}. Captions are below the film.`);
  }
  function useReducedMode(on) {
    prevBtn.hidden = !on;
    nextBtn.hidden = !on;
    note.hidden = !on;
    playBtn.hidden = on;
    bigPlay.querySelector('.story-big-play-label').textContent = on ? 'Start the story' : 'Play the story';
  }

  function poster() {
    resize();
    resetCues();
    render(POSTER_TIME, true);
    progress(0);
    rest(true);
  }
  function whenReady(done, tries = 0) {
    // Wait until the engine has painted every mascot once, so their size and feet can be measured.
    if (measureAll() || tries > 240) {
      ready = true;
      done();
      return;
    }
    window.setTimeout(() => whenReady(done, tries + 1), 50);
  }

  playBtn.addEventListener('click', () => (playing ? pause() : play()));
  restartBtn.addEventListener('click', () => {
    if (stepMode) {
      stepIndex = -1;
      step(1);
    } else restart(true);
  });
  bigPlay.addEventListener('click', () => {
    if (reduceMedia.matches && !stepMode && current === 0) step(1);
    else play();
  });
  prevBtn.addEventListener('click', () => step(-1));
  nextBtn.addEventListener('click', () => step(1));
  animateBtn.addEventListener('click', () => {
    useReducedMode(false);
    stepMode = false;
    current = 0;
    resetCues();
    play();
  });
  reduceMedia.addEventListener?.('change', () => {
    if (!playing) useReducedMode(reduceMedia.matches);
  });
  window.addEventListener('resize', () => {
    if (recording) return;
    resize();
    if (!playing && ready) render(stepMode ? current : current || POSTER_TIME, stepMode || current === 0);
  });

  buildTranscript();
  useReducedMode(reduceMedia.matches);
  resize();
  whenReady(poster);

  // ------------------------------------------------------------------ recording hook (used by build-story.R)
  window.story = {
    duration: DURATION,
    posterTime: POSTER_TIME,
    keyframes: KEYFRAMES,
    canvas,
    isReady: () => ready,
    startRecording(width, height, isTall = false) {
      recording = true;
      pause();
      fixedSize = [width, height, isTall];
      resize();
      resetCues();
    },
    // Recording: cue(t) sends the moods and gestures, the recorder lets the engine draw, then draw(t) composes.
    cue(t) {
      applyCues(t);
    },
    draw(t) {
      render(t, false);
    },
    frameAt(t) {
      applyCues(t);
      render(t, false);
      updateCaptions(t);
    },
    captionsAt: captionAt,
  };
})();
