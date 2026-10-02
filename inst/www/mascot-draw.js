/**
 * mascot drawing code (canvas 2D, no dependencies).
 *
 * First written for the R Engineering Playbook's trailer engine (tools/animate/engine.js, commit bf1aa9a) and
 * copied here with the same drawing calls in the same order, so the package draws Tessa pixel for pixel like the
 * playbook. Only what draws the character is here: no outfits, held items, backdrops, props or video tools.
 *
 * Every function is a pure function of its arguments: no clock, no randomness. Time enters only as `pose.t`
 * (seconds), which mascot.draw() computes from a frame number.
 *
 * Namespace: window.mascot.drawing
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.drawing) return;

  // Tessa's colours (the playbook's palette, only the entries her drawing uses).
  const C = {
    paper: '#f5f6f4',
    stone4: '#a2aea7',
    dark: '#26312b',
    ink: '#16201b',
    green4: '#7fcba4',
    green5: '#3f8a66',
    ochre2: '#d9b35c',
    ochre3: '#7a5a12',
    fail: '#a33a30',
    sky: '#9dc3e6',
  };

  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  function rgba(hex, a) {
    let c = hex.replace('#', '');
    if (c.length === 3) {
      c = c
        .split('')
        .map((x) => x + x)
        .join('');
    }
    return `rgba(${parseInt(c.slice(0, 2), 16)}, ${parseInt(c.slice(2, 4), 16)}, ${parseInt(c.slice(4, 6), 16)}, ${a})`;
  }

  // ---- shapes ---------------------------------------------------------------------------------
  function hexVerts(cx, cy, r) {
    const h = (r * Math.sqrt(3)) / 2;
    return [
      [cx, cy - r],
      [cx + h, cy - r / 2],
      [cx + h, cy + r / 2],
      [cx, cy + r],
      [cx - h, cy + r / 2],
      [cx - h, cy - r / 2],
    ];
  }

  /** Path of a pointy-top hexagon with rounded corners (call ctx.fill()/stroke() after). */
  function hexPath(ctx, cx, cy, r, cr) {
    const pts = hexVerts(cx, cy, r);
    const n = pts.length;
    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      const pv = pts[(i + n - 1) % n];
      const cu = pts[i];
      const nx = pts[(i + 1) % n];
      const lp = Math.hypot(pv[0] - cu[0], pv[1] - cu[1]);
      const ln = Math.hypot(nx[0] - cu[0], nx[1] - cu[1]);
      const d = Math.min(cr, lp * 0.45, ln * 0.45);
      const a = [cu[0] + ((pv[0] - cu[0]) / lp) * d, cu[1] + ((pv[1] - cu[1]) / lp) * d];
      const b = [cu[0] + ((nx[0] - cu[0]) / ln) * d, cu[1] + ((nx[1] - cu[1]) / ln) * d];
      if (i === 0) ctx.moveTo(a[0], a[1]);
      else ctx.lineTo(a[0], a[1]);
      ctx.quadraticCurveTo(cu[0], cu[1], b[0], b[1]);
    }
    ctx.closePath();
  }

  function rr(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
  }

  /** Fill plus a dark cartoon outline for the current path. */
  function fs(ctx, fill, lw, stroke) {
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    if (fill) {
      ctx.fillStyle = fill;
      ctx.fill();
    }
    ctx.lineWidth = lw === undefined ? 2.5 : lw;
    ctx.strokeStyle = stroke || C.dark;
    ctx.stroke();
  }

  // ---- Tessa's body -----------------------------------------------------------------------------
  const R = 92;
  const RIM = 11;
  const FOOT = 12;
  const HW = (R * Math.sqrt(3)) / 2;

  const ARM_PRESETS = {
    idle: { L: 1.85, R: 1.25 },
    up: { L: -2.25, R: -0.85 },
    shock: { L: -2.45, R: -0.65 },
    type: { L: 2.55, R: 2.35 },
    hold: { L: -2.79, R: -0.35 },
    wave: { L: 1.85, R: -1.0 },
    point: { L: 1.85, R: -0.15 },
    hips: { L: 2.35, R: 0.8 },
  };

  const DEFAULT_POSE = {
    scale: 1,
    sx: 1,
    sy: 1,
    lift: 0,
    rot: 0,
    flip: 1,
    look: 0,
    lookY: 0,
    eyes: 'open',
    blink: 0,
    mouth: 'smile',
    brows: null,
    sweat: 0,
    blush: true,
    sparkle: false,
    accessory: 'bow',
    armL: null,
    armR: null,
    arms: 'idle',
    armJitter: 0,
    feet: 'auto',
    shadow: true,
    t: 0,
  };

  // ---- face pieces ------------------------------------------------------------------------------
  // Soft eyelashes: `n` short strokes at the outer top corner of an eye (s = -1 left, +1 right).
  function lashes(g, s, cx, cy, ew, eh, n) {
    g.strokeStyle = C.ink;
    g.lineWidth = 3;
    g.lineCap = 'round';
    const angs = n === 2 ? [-32, -62] : [-20, -45, -70];
    for (const deg of angs) {
      const th = (deg * Math.PI) / 180;
      const ux = Math.cos(th) * s;
      const uy = Math.sin(th);
      const ex = cx + Math.cos(th) * ew * s;
      const ey = cy + Math.sin(th) * eh;
      g.beginPath();
      g.moveTo(ex, ey);
      g.lineTo(ex + ux * 7, ey + uy * 7);
      g.stroke();
    }
  }

  function eyeHappy(g, s, cx, cy) {
    g.strokeStyle = C.ink;
    g.lineWidth = 5.5;
    g.lineCap = 'round';
    g.beginPath();
    g.arc(cx, cy + 2, 15, Math.PI * 1.15, Math.PI * 1.85, false);
    g.stroke();
    lashes(g, s, cx, cy + 9, 15, 6, 2);
  }

  function eyeClosed(g, s, cx, cy) {
    g.strokeStyle = C.ink;
    g.lineWidth = 5;
    g.lineCap = 'round';
    g.beginPath();
    g.arc(cx, cy - 6, 14, Math.PI * 0.18, Math.PI * 0.82, false);
    g.stroke();
    lashes(g, s, cx, cy + 2, 15, 3, 2);
  }

  function eyeOpen(g, s, cx, cy, o) {
    g.save();
    g.translate(cx, cy);
    g.beginPath();
    g.ellipse(0, 0, o.ew, o.eh, 0, 0, 7);
    g.fillStyle = C.paper;
    g.fill();
    g.strokeStyle = C.ink;
    g.lineWidth = 2.5;
    g.stroke();
    g.beginPath();
    g.ellipse(0, 0, o.ew - 1, o.eh - 1, 0, 0, 7);
    g.clip();
    const px = o.px;
    const py = o.py;
    const pr = o.pr;
    g.fillStyle = C.ink;
    g.beginPath();
    g.arc(px, py, pr, 0, 7);
    g.fill();
    g.fillStyle = C.paper;
    g.beginPath();
    g.arc(px + pr * 0.35, py - pr * 0.35, pr * 0.4, 0, 7);
    g.fill();
    g.beginPath();
    g.arc(px - pr * 0.35, py + pr * 0.35, pr * 0.22, 0, 7);
    g.fill();
    if (o.lid > 0) {
      // half-lid (focused) or blink
      const ly = -o.eh * 1.2 + o.eh * 2.4 * o.lid;
      g.fillStyle = C.green5;
      g.fillRect(-o.ew * 1.2, -o.eh * 1.2, o.ew * 2.4, ly + o.eh * 1.2);
      g.strokeStyle = C.dark;
      g.lineWidth = 2.2;
      g.beginPath();
      g.moveTo(-o.ew * 1.2, ly + s * (o.slant || 0));
      g.lineTo(o.ew * 1.2, ly - s * (o.slant || 0));
      g.stroke();
    }
    g.restore();
    lashes(g, s, cx, cy, o.ew, o.eh, 3);
  }

  function drawEyes(g, p) {
    const EY = -12;
    const SP = 30;
    const kind = p.eyes;
    const blink = clamp(p.blink, 0, 1);
    if (kind === 'happy') {
      eyeHappy(g, -1, -SP, EY);
      eyeHappy(g, 1, SP, EY);
    } else if (kind === 'blink' || blink > 0.96) {
      eyeClosed(g, -1, -SP, EY);
      eyeClosed(g, 1, SP, EY);
    } else {
      const wide = kind === 'wide';
      const worried = kind === 'worried';
      const focused = kind === 'focused';
      const o = {
        ew: wide ? 19 : 16.5,
        eh: wide ? 24 : worried ? 21 : 19.5,
        pr: wide ? 7.5 : worried ? 8.5 : 10,
        px: clamp(p.look, -1, 1) * 7,
        py: clamp(p.lookY, -1, 1) * 7 + (worried ? -2 : 0),
        lid: focused ? Math.max(0.42, blink) : blink,
        slant: focused ? 3 : 0,
      };
      if (kind === 'wink') {
        eyeOpen(g, -1, -SP, EY, o);
        eyeHappy(g, 1, SP, EY);
      } else {
        eyeOpen(g, -1, -SP, EY, o);
        eyeOpen(g, 1, SP, EY, o);
      }
    }
    let br = p.brows;
    if (br === null || br === undefined) br = kind === 'worried' ? 'worried' : kind === 'focused' ? 'frown' : 'none';
    if (br && br !== 'none' && kind !== 'happy') {
      g.strokeStyle = C.ink;
      g.lineWidth = br === 'neutral' ? 3.5 : 5;
      g.lineCap = 'round';
      const yy = EY - (kind === 'wide' ? 30 : 25);
      for (const s of [-1, 1]) {
        g.beginPath();
        if (br === 'determined' || br === 'angry' || br === 'frown') {
          g.moveTo(s * (SP + 18), yy + 2);
          g.lineTo(s * (SP - 16), yy + 10);
        } else if (br === 'worried' || br === 'sad') {
          g.moveTo(s * (SP + 18), yy + 10);
          g.lineTo(s * (SP - 16), yy + 2);
        } else if (br === 'neutral') {
          g.moveTo(s * (SP + 14), yy + 6);
          g.quadraticCurveTo(s * SP, yy + 1, s * (SP - 14), yy + 6);
        } else {
          // raised
          g.moveTo(s * (SP + 15), yy + 5);
          g.quadraticCurveTo(s * SP, yy - 6, s * (SP - 15), yy + 5);
        }
        g.stroke();
      }
    }
  }

  function drawMouth(g, p) {
    const my = 24;
    g.save();
    g.strokeStyle = C.ink;
    g.fillStyle = C.ink;
    g.lineWidth = 3.5;
    g.lineCap = 'round';
    const m = p.mouth;
    if (m === 'smile') {
      g.beginPath();
      g.arc(0, my, 13, 0.15 * Math.PI, 0.85 * Math.PI, false);
      g.stroke();
    } else if (m === 'smirk') {
      g.beginPath();
      g.moveTo(-8, my + 2);
      g.quadraticCurveTo(0, my + 9, 9, my);
      g.stroke();
    } else if (m === 'proud') {
      g.beginPath();
      g.moveTo(-14, my + 3);
      g.quadraticCurveTo(0, my + 15, 15, my - 1);
      g.stroke();
      g.lineWidth = 2.5;
      g.beginPath();
      g.moveTo(16, my - 6);
      g.lineTo(18, my - 1);
      g.stroke();
    } else if (m === 'flat') {
      g.beginPath();
      g.moveTo(-11, my + 8);
      g.lineTo(11, my + 8);
      g.stroke();
    } else if (m === 'grit' || m === 'determined') {
      g.beginPath();
      g.moveTo(-14, my + 3);
      g.lineTo(-5, my);
      g.lineTo(5, my + 4);
      g.lineTo(14, my + 1);
      g.stroke();
    } else if (m === 'o') {
      g.beginPath();
      g.ellipse(0, my + 5, 10, 15, 0, 0, 7);
      g.fill();
      g.fillStyle = C.fail;
      g.beginPath();
      g.ellipse(0, my + 13, 7, 5, 0, 0, 7);
      g.fill();
    } else if (m === 'grin') {
      g.beginPath();
      g.arc(0, my, 16, 0, Math.PI, false);
      g.closePath();
      g.fill();
      g.stroke();
      g.fillStyle = C.paper;
      g.fillRect(-13, my, 26, 6);
    }
    g.restore();
  }

  function drawSweat(g, p) {
    const u = p.sweat === true ? 0.5 : clamp(p.sweat, 0, 1);
    if (u <= 0) return;
    g.save();
    g.translate(58 + Math.sin(u * 12) * 2, -46 + u * 26);
    g.globalAlpha = u < 0.9 ? 1 : (1 - u) * 10;
    g.fillStyle = C.sky;
    g.strokeStyle = C.ink;
    g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(0, -11);
    g.bezierCurveTo(8, -4, 9, 6, 0, 10);
    g.bezierCurveTo(-9, 6, -8, -4, 0, -11);
    g.closePath();
    g.fill();
    g.stroke();
    g.fillStyle = C.paper;
    g.beginPath();
    g.arc(2.5, 2.5, 2.2, 0, 7);
    g.fill();
    g.restore();
  }

  function drawSparkle(g, p) {
    const k = 1 + 0.18 * Math.sin(p.t * 9);
    g.save();
    g.translate(56, -33);
    g.scale(k, k);
    g.beginPath();
    for (let i = 0; i < 8; i++) {
      const r = i % 2 ? 3.2 : 10;
      const a = (i * Math.PI) / 4 - Math.PI / 2;
      g.lineTo(Math.cos(a) * r, Math.sin(a) * r);
    }
    g.closePath();
    fs(g, C.paper, 1.6, C.ochre2);
    g.restore();
  }

  // Head accessory: small ochre hair bow (default) or clip on the upper left of the head.
  function drawAccessory(g, kind) {
    g.save();
    g.translate(-47, -54);
    g.rotate(-0.5);
    g.scale(1.2, 1.2);
    if (kind === 'clip') {
      rr(g, -15, -5, 30, 10, 5);
      fs(g, C.ochre2, 2.2);
      g.fillStyle = C.ochre3;
      g.fillRect(-5, -4, 3, 8);
      g.fillRect(3, -4, 3, 8);
      g.fillStyle = rgba(C.paper, 0.7);
      g.fillRect(-12, -3, 5, 2);
    } else {
      for (const s of [-1, 1]) {
        g.beginPath();
        g.moveTo(0, 0);
        g.quadraticCurveTo(s * 10, -13, s * 21, -8);
        g.quadraticCurveTo(s * 25, 0, s * 21, 8);
        g.quadraticCurveTo(s * 10, 13, 0, 0);
        g.closePath();
        fs(g, C.ochre2, 2.2);
        g.strokeStyle = C.ochre3;
        g.lineWidth = 1.6;
        g.beginPath();
        g.moveTo(s * 7, -1);
        g.lineTo(s * 17, -3);
        g.moveTo(s * 7, 2);
        g.lineTo(s * 17, 3);
        g.stroke();
      }
      g.beginPath();
      g.arc(0, 0, 5.5, 0, 7);
      fs(g, C.ochre2, 2.2);
    }
    g.restore();
  }

  function paw(g, x, y) {
    g.fillStyle = C.ochre2;
    g.strokeStyle = C.dark;
    g.lineWidth = 2.5;
    g.beginPath();
    g.arc(x, y, 15 * 0.45, 0, 7);
    g.fill();
    g.stroke();
  }

  /**
   * tessa(ctx, x, baseY, pose): draws Tessa with her feet on baseY.
   * Pose fields as in the playbook's drawTessa(), without outfits and held items: scale, sx, sy, lift, rot, flip,
   * t (seconds), look, lookY, eyes, blink, brows, mouth, sweat, blush, sparkle, accessory, arms, armL, armR,
   * armJitter, feet, shadow.
   */
  function tessa(ctx, x, baseY, pose) {
    const p = Object.assign({}, DEFAULT_POSE, pose || {});
    const g = ctx;
    const sc = p.scale;

    // ground shadow (not affected by squash, shrinks and fades with height)
    if (p.shadow) {
      const k = 1 / (1 + p.lift / 200);
      g.save();
      g.fillStyle = rgba(C.stone4, 0.32 * k);
      g.beginPath();
      g.ellipse(x, baseY - 1, 62 * sc * k * (0.6 + 0.4 * p.sx), 9 * sc * k, 0, 0, 7);
      g.fill();
      g.restore();
    }

    g.save();
    g.translate(x, baseY - p.lift);
    g.scale(p.flip * sc * p.sx, sc * p.sy);
    g.translate(0, -(R + FOOT));
    g.rotate(p.rot);

    // A. feet
    const tuck = p.feet === 'tuck' || (p.feet === 'auto' && p.lift > 6);
    g.fillStyle = C.ochre2;
    g.strokeStyle = C.dark;
    g.lineWidth = 2.5;
    if (tuck) {
      for (const s of [-1, 1]) {
        g.save();
        g.translate(s * 24, R - 14);
        g.rotate(-s * 0.25);
        g.beginPath();
        g.roundRect(-12, -6, 24, 14, 7);
        g.fill();
        g.stroke();
        g.restore();
      }
    } else {
      g.beginPath();
      g.roundRect(-38, R - 4, 30, 16, [6, 6, 8, 8]);
      g.fill();
      g.stroke();
      g.beginPath();
      g.roundRect(8, R - 4, 30, 16, [6, 6, 8, 8]);
      g.fill();
      g.stroke();
    }

    // B. body: ochre rim, dark outline, green face, highlight
    hexPath(g, 0, 0, R, 12);
    g.fillStyle = C.ochre2;
    g.fill();
    g.strokeStyle = C.dark;
    g.lineWidth = 3;
    g.stroke();
    hexPath(g, 0, 0, R - RIM, 8);
    g.fillStyle = C.green5;
    g.fill();
    g.fillStyle = rgba(C.green4, 0.35);
    g.beginPath();
    g.moveTo(0, -(R - RIM));
    g.lineTo(26, -(R - RIM) + 16);
    g.lineTo(-26, -(R - RIM) + 16);
    g.closePath();
    g.fill();
    if (p.blush) {
      g.fillStyle = p.blush === 'strong' ? rgba(C.ochre2, 0.55) : rgba(C.green4, 0.45);
      g.beginPath();
      g.ellipse(-36, 18, 13, 7, 0, 0, 7);
      g.moveTo(49, 18);
      g.ellipse(36, 18, 13, 7, 0, 0, 7);
      g.fill();
    }

    // C. face
    drawEyes(g, p);
    drawMouth(g, p);

    // D. accessory, sparkle, sweat
    if (p.accessory && p.accessory !== 'none') drawAccessory(g, p.accessory);
    if (p.sparkle) drawSparkle(g, p);
    drawSweat(g, p);

    // E. arms
    const preset = ARM_PRESETS[p.arms] || ARM_PRESETS.idle;
    const jit = Math.sin(p.t * 26) * p.armJitter;
    const aL = (p.armL === null ? preset.L : p.armL) + jit;
    const aR = (p.armR === null ? preset.R : p.armR) - jit;
    const arm = (sx, sy, a) => {
      g.save();
      g.translate(sx, sy);
      g.rotate(a);
      rr(g, 0, -7.5, 42, 15, 7.5);
      fs(g, C.green5);
      paw(g, 39, 0);
      g.restore();
    };
    arm(-HW + 10, 8, aL);
    arm(HW - 10, 8, aR);
    g.restore();
  }

  ns.drawing = { characters: { tessa }, hexPath, armPresets: ARM_PRESETS };
})();
