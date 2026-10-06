/**
 * mascot drawing code (canvas 2D, no dependencies).
 *
 * First written for the R Engineering Playbook's trailer engine (tools/animate/engine.js, commit bf1aa9a). Here
 * the drawing is generic: a character is data (inst/characters/<id>.json: colours, body parts, anchors, arms,
 * accessories, moods), and these functions draw any character from it. The calls and their order are kept from
 * the playbook, so Tessa's data draws her pixel for pixel like the playbook does.
 *
 * Every function is a pure function of its arguments: no clock, no randomness. Time enters only as `pose.t`
 * (seconds), which mascot.draw() computes from a frame number.
 *
 * Namespace: window.mascot.drawing (internal implementation, not a supported API).
 */
(() => {
  // biome-ignore lint/suspicious/noRedundantUseStrict: loaded with a <script> tag (a classic script, not a module)
  'use strict';

  const ns = window.mascot || {};
  window.mascot = ns;
  if (ns.drawing) return;

  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  function rgba(value, alpha) {
    if (value.startsWith('#')) {
      let hex = value.slice(1);
      if (hex.length === 3)
        hex = hex
          .split('')
          .map((x) => x + x)
          .join('');
      return `rgba(${parseInt(hex.slice(0, 2), 16)}, ${parseInt(hex.slice(2, 4), 16)}, ${parseInt(hex.slice(4, 6), 16)}, ${alpha})`;
    }
    const channels = value
      .slice(value.indexOf('(') + 1, -1)
      .split(',')
      .map(Number);
    return `rgba(${channels[0]}, ${channels[1]}, ${channels[2]}, ${alpha * (channels[3] === undefined ? 1 : channels[3])})`;
  }

  // Minimum screen width uses the smaller singular value of the current canvas transform.
  function stroke(g, minimum = 0, cap = 'round', join = 'miter') {
    g.lineCap = cap;
    g.lineJoin = join;
    if (minimum) {
      const { a, b, c, d } = g.getTransform();
      const sum = a * a + b * b + c * c + d * d;
      const largest = Math.sqrt((sum + Math.sqrt(Math.max(0, sum * sum - 4 * (a * d - b * c) ** 2))) / 2);
      const scale = largest ? Math.abs(a * d - b * c) / largest : 0;
      if (scale) g.lineWidth = Math.max(g.lineWidth, minimum / scale);
    }
    g.stroke();
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

  /**
   * Starts a new path from an SVG-style path string. Absolute commands only (M, L, Q, C, Z), numbers separated by
   * spaces or commas: a subset any SVG editor can write, so a character's parts can be drawn as SVG later.
   */
  const PATH_ARGS = { M: 2, L: 2, Q: 4, C: 6, Z: 0, z: 0 };
  const isLetter = (token) => /^[A-Za-z]$/.test(token);
  function svgPath(ctx, d) {
    const tokens = d.match(/[A-Za-z]|[+-]?\d*\.?\d+(?:e[+-]?\d+)?/g) || [];
    if (d.replace(/[A-Za-z]|[+-]?\d*\.?\d+(?:e[+-]?\d+)?/g, '').replace(/[\s,]/g, '')) {
      throw new Error(`mascot: invalid path text in '${d}'`);
    }
    if (tokens[0] !== 'M') throw new Error(`mascot: path must start with M in '${d}'`);
    ctx.beginPath();
    let i = 0;
    while (i < tokens.length) {
      const cmd = tokens[i];
      if (!Object.hasOwn(PATH_ARGS, cmd)) throw new Error(`mascot: unsupported path command '${cmd}' in '${d}'`);
      const n = PATH_ARGS[cmd];
      i += 1;
      if (n === 0) {
        ctx.closePath();
        continue;
      }
      if (i >= tokens.length || isLetter(tokens[i])) throw new Error(`mascot: '${cmd}' needs ${n} numbers in '${d}'`);
      // Numbers after a command repeat it, as in SVG (after M they draw lines).
      let first = true;
      while (i < tokens.length && !isLetter(tokens[i])) {
        const v = tokens.slice(i, i + n).map(Number);
        if (v.length < n || v.some((x) => !Number.isFinite(x))) {
          throw new Error(`mascot: '${cmd}' needs ${n} numbers in '${d}'`);
        }
        if (cmd === 'M' && first) ctx.moveTo(v[0], v[1]);
        else if (cmd === 'M' || cmd === 'L') ctx.lineTo(v[0], v[1]);
        else if (cmd === 'Q') ctx.quadraticCurveTo(v[0], v[1], v[2], v[3]);
        else ctx.bezierCurveTo(v[0], v[1], v[2], v[3], v[4], v[5]);
        first = false;
        i += n;
      }
    }
  }

  function rr(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
  }

  /** Fill plus a cartoon outline for the current path. */
  function fs(ctx, fill, lw, outline, minimum = 0) {
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    if (fill) {
      ctx.fillStyle = fill;
      ctx.fill();
    }
    ctx.lineWidth = lw === undefined ? 2.5 : lw;
    ctx.strokeStyle = outline;
    stroke(ctx, minimum, 'round', 'round');
  }

  /** A colour from the character's colours, by role, with an optional alpha. */
  function colour(c, role, alpha) {
    const hex = c[role];
    if (!Object.hasOwn(c, role)) throw new Error(`mascot: the character has no colour '${role}'`);
    return alpha === undefined ? hex : rgba(hex, alpha);
  }

  /**
   * Draws one part described as data: { shape, ..., fill, stroke, lineWidth, alpha, round }.
   * shape: 'hexagon' (r, corner), 'path' (d), 'circle' (x, y, r), 'roundRect' (x, y, w, h, r), 'rect' (x, y, w, h;
   * fill only). round: true sets round joins and caps first, like a cartoon outline.
   */
  function drawPart(g, c, part, minimum = 0) {
    if (part.shape === 'rect') {
      g.fillStyle = colour(c, part.fill, part.alpha);
      g.fillRect(part.x, part.y, part.w, part.h);
      return;
    }
    if (part.shape === 'hexagon') hexPath(g, 0, 0, part.r, part.corner);
    else if (part.shape === 'path') svgPath(g, part.d);
    else if (part.shape === 'circle') {
      g.beginPath();
      g.arc(part.x, part.y, part.r, 0, 7);
    } else if (part.shape === 'roundRect') rr(g, part.x, part.y, part.w, part.h, part.r);
    else throw new Error(`mascot: unknown part shape '${part.shape}'`);
    if (part.round) {
      g.lineJoin = 'round';
      g.lineCap = 'round';
    }
    if (part.fill) {
      g.fillStyle = colour(c, part.fill, part.alpha);
      g.fill();
    }
    if (part.stroke) {
      g.strokeStyle = colour(c, part.stroke);
      g.lineWidth = part.lineWidth === undefined ? 2.5 : part.lineWidth;
      stroke(g, minimum, part.round ? 'round' : 'butt', part.round ? 'round' : 'miter');
    }
  }

  // Pose fields every character understands; a character's own `pose` and `moods` change them.
  const DEFAULT_POSE = {
    detail: 'full',
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
    accessory: 'none',
    armL: null,
    armR: null,
    arms: 'idle',
    armJitter: 0,
    feet: 'auto',
    shadow: true,
    t: 0,
  };

  // Each layer has its own place; a later gesture layer belongs between the mood and the explicit pose.
  function resolvePose(ch, given = {}, frame) {
    const mood = given.mood === undefined ? {} : Object.hasOwn(ch.moods, given.mood) ? ch.moods[given.mood] : null;
    if (!mood) throw new Error(`mascot: the character '${ch.id}' has no mood '${given.mood}'`);
    const p = Object.assign({}, DEFAULT_POSE, ch.pose || {}, mood, given);
    if (frame !== undefined) p.t = frame / ns.fps;
    guardPose(ch, p);
    return p;
  }

  const FACE_STYLE = {
    open: { ew: 16.5, eh: 19.5, pr: 10 },
    wide: { ew: 19, eh: 24, pr: 7.5 },
    worried: { ew: 16.5, eh: 21, pr: 8.5, pupilY: -2 },
    focused: { ew: 16.5, eh: 19.5, pr: 10, lid: 0.42, slant: 3 },
    happy: { r: 15, y: 2, start: 1.15, end: 1.85, lineWidth: 5.5, lashY: 9, lashW: 15, lashH: 6 },
    closed: { r: 14, y: -6, start: 0.18, end: 0.82, lineWidth: 5, lashY: 2, lashW: 15, lashH: 3 },
    pupil: { lookX: 7, lookY: 7 },
    lashes: { two: [-32, -62], three: [-20, -45, -70], length: 7, lineWidth: 3 },
    brows: {
      offset: 25,
      wideOffset: 30,
      outer: 18,
      inner: 16,
      high: 2,
      low: 10,
      neutralWidth: 14,
      neutralY: 6,
      neutralControlY: 1,
      raisedWidth: 15,
      raisedY: 5,
      raisedControlY: -6,
      lineWidth: 5,
      neutralLineWidth: 3.5,
    },
  };

  function faceStyle(style = {}) {
    return Object.fromEntries(Object.entries(FACE_STYLE).map(([key, value]) => [key, { ...value, ...style[key] }]));
  }

  const names = {
    eyes: ['open', 'wide', 'happy', 'blink', 'wink', 'focused', 'worried'],
    mouth: ['smile', 'smirk', 'proud', 'flat', 'grit', 'determined', 'o', 'grin'],
    brows: ['none', 'neutral', 'raised', 'determined', 'angry', 'frown', 'worried', 'sad'],
    hide: ['lashes', 'highlight', 'blush', 'sweat', 'accessories', 'shadow', 'sparkle', 'brows'],
    shape: ['hexagon', 'path', 'circle', 'roundRect', 'rect'],
    anchor: [
      'hair',
      'crown',
      'forehead',
      'eyes',
      'upperLip',
      'chin',
      'neck',
      'chest',
      'back',
      'waist',
      'shoulders',
      'hands',
      'feet',
      'face',
      'sparkle',
      'sweat',
    ],
  };
  const pathGuard = Object.fromEntries(
    ['beginPath', 'closePath', 'moveTo', 'lineTo', 'quadraticCurveTo', 'bezierCurveTo'].map((key) => [key, () => {}]),
  );
  function accessories(ch, p, field = 'pose') {
    const slots = new Set();
    return (Array.isArray(p.accessory) ? p.accessory : [p.accessory])
      .filter((name) => name !== undefined && name !== 'none')
      .map((name) => {
        if (!Object.hasOwn(ch.accessories || {}, name))
          throw new Error(`mascot: ${field}.accessory: no accessory '${name}'`);
        const item = ch.accessories[name];
        if (item.side !== undefined && !['L', 'R'].includes(item.side))
          throw new Error(`mascot: accessories.${name}.side: unknown name '${item.side}'`);
        const anchor = item.anchor || 'hair';
        if (
          (anchor === 'hands' && !ch.arms) ||
          (!Object.hasOwn(ch.anchors || {}, anchor) && !(anchor === 'hands' && ch.arms))
        )
          throw new Error(`mascot: ${field}.accessory '${name}': missing anchor '${anchor}'`);
        if (slots.has(item.slot)) throw new Error(`mascot: ${field}.accessory: slot '${item.slot}' is used twice`);
        slots.add(item.slot);
        return item;
      });
  }
  function guardPose(ch, p, field = 'pose') {
    for (const [key, choices] of Object.entries({
      eyes: names.eyes,
      mouth: names.mouth,
      brows: names.brows,
      detail: ['full', 'simple'],
      feet: ['auto', 'stand', 'tuck'],
    })) {
      if (p[key] !== undefined && p[key] !== null && !choices.includes(p[key]))
        throw new Error(`mascot: ${field}.${key}: unknown name '${p[key]}'`);
    }
    if (
      p.arms !== undefined &&
      ((ch.arms && !Object.hasOwn(ch.arms.presets || {}, p.arms)) || (!ch.arms && p.arms !== 'idle'))
    )
      throw new Error(`mascot: ${field}.arms '${p.arms}' is not an arm preset`);
    accessories(ch, p, field);
  }
  // Required small block: faceScale multiplies the normal face frame; minLineWidth is in screen pixels.
  // hide lists optional features to omit. Parts marked detail: 'full' are also omitted, without role checks.
  // Accessories: { parts, slot, anchor = 'hair', colours = {}, side = 'R' }; side selects paired anchors.
  // face.outline sets leftCap/rightCap/join explicitly (defaults: round/round/miter).
  const styles = new WeakMap();
  const hidden = (ch, p, name) => p.detail === 'simple' && ch.small.hide.includes(name);
  const visible = (part, p) => p.detail !== 'simple' || part.detail !== 'full';
  function armAngles(ch, p) {
    if (!Object.hasOwn(ch.arms.presets, p.arms)) throw new Error(`mascot: pose.arms '${p.arms}' is not an arm preset`);
    const preset = ch.arms.presets[p.arms];
    const jit = Math.sin(p.t * 26) * p.armJitter;
    return { L: (p.armL === null ? preset.L : p.armL) + jit, R: (p.armR === null ? preset.R : p.armR) - jit };
  }

  // ---- face pieces ------------------------------------------------------------------------------
  // Soft eyelashes: `n` short strokes at the outer top corner of an eye (s = -1 left, +1 right).
  function lashes(g, f, s, cx, cy, ew, eh, n) {
    g.strokeStyle = f.c.feature;
    g.lineWidth = f.style.lashes.lineWidth;
    g.lineCap = 'round';
    const style = f.style.lashes;
    const angs = n === 2 ? style.two : style.three;
    for (const deg of angs) {
      const th = (deg * Math.PI) / 180;
      const ux = Math.cos(th) * s;
      const uy = Math.sin(th);
      const ex = cx + Math.cos(th) * ew * s;
      const ey = cy + Math.sin(th) * eh;
      g.beginPath();
      g.moveTo(ex, ey);
      g.lineTo(ex + ux * style.length, ey + uy * style.length);
      stroke(g, f.minimum);
    }
  }

  function eyeHappy(g, f, s, cx, cy) {
    const style = f.style.happy;
    g.strokeStyle = f.c.feature;
    g.lineWidth = style.lineWidth;
    g.lineCap = 'round';
    g.beginPath();
    g.arc(cx, cy + style.y, style.r, Math.PI * style.start, Math.PI * style.end, false);
    stroke(g, f.minimum);
    if (f.lashes) lashes(g, f, s, cx, cy + style.lashY, style.lashW, style.lashH, 2);
  }

  function eyeClosed(g, f, s, cx, cy) {
    const style = f.style.closed;
    g.strokeStyle = f.c.feature;
    g.lineWidth = style.lineWidth;
    g.lineCap = 'round';
    g.beginPath();
    g.arc(cx, cy + style.y, style.r, Math.PI * style.start, Math.PI * style.end, false);
    stroke(g, f.minimum);
    if (f.lashes) lashes(g, f, s, cx, cy + style.lashY, style.lashW, style.lashH, 2);
  }

  function eyeOpen(g, f, s, cx, cy, o) {
    const c = f.c;
    g.save();
    g.translate(cx, cy);
    g.beginPath();
    g.ellipse(0, 0, o.ew, o.eh, 0, 0, 7);
    g.fillStyle = c.eyeWhite;
    g.fill();
    g.strokeStyle = c.feature;
    g.lineWidth = 2.5;
    stroke(g, f.minimum, s === -1 ? f.outline.leftCap : f.outline.rightCap, f.outline.join);
    g.beginPath();
    g.ellipse(0, 0, o.ew - 1, o.eh - 1, 0, 0, 7);
    g.clip();
    const px = o.px;
    const py = o.py;
    const pr = o.pr;
    g.fillStyle = c.feature;
    g.beginPath();
    g.arc(px, py, pr, 0, 7);
    g.fill();
    if (!f.hideHighlight) {
      g.fillStyle = c.shine;
      g.beginPath();
      g.arc(px + pr * 0.35, py - pr * 0.35, pr * 0.4, 0, 7);
      g.fill();
      g.beginPath();
      g.arc(px - pr * 0.35, py + pr * 0.35, pr * 0.22, 0, 7);
      g.fill();
    }
    if (o.lid > 0) {
      // half-lid (focused) or blink
      const ly = -o.eh * 1.2 + o.eh * 2.4 * o.lid;
      g.fillStyle = c.eyelid;
      g.fillRect(-o.ew * 1.2, -o.eh * 1.2, o.ew * 2.4, ly + o.eh * 1.2);
      g.strokeStyle = c.outline;
      g.lineWidth = 2.2;
      g.beginPath();
      g.moveTo(-o.ew * 1.2, ly + s * (o.slant || 0));
      g.lineTo(o.ew * 1.2, ly - s * (o.slant || 0));
      stroke(g, f.minimum, s === -1 ? f.outline.leftCap : f.outline.rightCap, f.outline.join);
    }
    g.restore();
    if (f.lashes) lashes(g, f, s, cx, cy, o.ew, o.eh, 3);
  }

  function drawEyes(g, f, p) {
    const EY = f.eyes.y;
    const SP = f.eyes.spacing;
    const kind = p.eyes;
    const blink = clamp(p.blink, 0, 1);
    if (kind === 'happy') {
      eyeHappy(g, f, -1, -SP, EY);
      eyeHappy(g, f, 1, SP, EY);
    } else if (kind === 'blink' || blink > 0.96) {
      eyeClosed(g, f, -1, -SP, EY);
      eyeClosed(g, f, 1, SP, EY);
    } else {
      const worried = kind === 'worried';
      const focused = kind === 'focused';
      const style = f.style[['wide', 'worried', 'focused'].includes(kind) ? kind : 'open'];
      const o = {
        ew: style.ew,
        eh: style.eh,
        pr: style.pr,
        px: clamp(p.look, -1, 1) * f.style.pupil.lookX,
        py: clamp(p.lookY, -1, 1) * f.style.pupil.lookY + (worried ? style.pupilY : 0),
        lid: focused ? Math.max(style.lid, blink) : blink,
        slant: focused ? style.slant : 0,
      };
      if (kind === 'wink') {
        eyeOpen(g, f, -1, -SP, EY, o);
        eyeHappy(g, f, 1, SP, EY);
      } else {
        eyeOpen(g, f, -1, -SP, EY, o);
        eyeOpen(g, f, 1, SP, EY, o);
      }
    }
    let br = p.brows;
    if (br === null || br === undefined) br = kind === 'worried' ? 'worried' : kind === 'focused' ? 'frown' : 'none';
    if (!f.hideBrows && br && br !== 'none' && kind !== 'happy') {
      g.strokeStyle = f.c.feature;
      const b = f.style.brows;
      g.lineWidth = br === 'neutral' ? b.neutralLineWidth : b.lineWidth;
      g.lineCap = 'round';
      const yy = EY - (kind === 'wide' ? b.wideOffset : b.offset);
      for (const s of [-1, 1]) {
        g.beginPath();
        if (br === 'determined' || br === 'angry' || br === 'frown') {
          g.moveTo(s * (SP + b.outer), yy + b.high);
          g.lineTo(s * (SP - b.inner), yy + b.low);
        } else if (br === 'worried' || br === 'sad') {
          g.moveTo(s * (SP + b.outer), yy + b.low);
          g.lineTo(s * (SP - b.inner), yy + b.high);
        } else if (br === 'neutral') {
          g.moveTo(s * (SP + b.neutralWidth), yy + b.neutralY);
          g.quadraticCurveTo(s * SP, yy + b.neutralControlY, s * (SP - b.neutralWidth), yy + b.neutralY);
        } else {
          // raised
          g.moveTo(s * (SP + b.raisedWidth), yy + b.raisedY);
          g.quadraticCurveTo(s * SP, yy + b.raisedControlY, s * (SP - b.raisedWidth), yy + b.raisedY);
        }
        stroke(g, f.minimum);
      }
    }
  }

  function drawMouth(g, f, p) {
    const c = f.c;
    const my = f.mouth.y;
    g.save();
    g.strokeStyle = c.feature;
    g.fillStyle = c.feature;
    g.lineWidth = 3.5;
    g.lineCap = 'round';
    const m = p.mouth;
    if (m === 'smile') {
      g.beginPath();
      g.arc(0, my, 13, 0.15 * Math.PI, 0.85 * Math.PI, false);
      stroke(g, f.minimum);
    } else if (m === 'smirk') {
      g.beginPath();
      g.moveTo(-8, my + 2);
      g.quadraticCurveTo(0, my + 9, 9, my);
      stroke(g, f.minimum);
    } else if (m === 'proud') {
      g.beginPath();
      g.moveTo(-14, my + 3);
      g.quadraticCurveTo(0, my + 15, 15, my - 1);
      stroke(g, f.minimum);
      g.lineWidth = 2.5;
      g.beginPath();
      g.moveTo(16, my - 6);
      g.lineTo(18, my - 1);
      stroke(g, f.minimum);
    } else if (m === 'flat') {
      g.beginPath();
      g.moveTo(-11, my + 8);
      g.lineTo(11, my + 8);
      stroke(g, f.minimum);
    } else if (m === 'grit' || m === 'determined') {
      g.beginPath();
      g.moveTo(-14, my + 3);
      g.lineTo(-5, my);
      g.lineTo(5, my + 4);
      g.lineTo(14, my + 1);
      stroke(g, f.minimum);
    } else if (m === 'o') {
      g.beginPath();
      g.ellipse(0, my + 5, 10, 15, 0, 0, 7);
      g.fill();
      g.fillStyle = c.tongue;
      g.beginPath();
      g.ellipse(0, my + 13, 7, 5, 0, 0, 7);
      g.fill();
    } else if (m === 'grin') {
      g.beginPath();
      g.arc(0, my, 16, 0, Math.PI, false);
      g.closePath();
      g.fill();
      stroke(g, f.minimum);
      g.fillStyle = c.teeth;
      g.fillRect(-13, my, 26, 6);
    }
    g.restore();
  }

  function drawBlush(g, c, b, kind) {
    g.fillStyle = kind === 'strong' ? rgba(c.blushStrong, b.strongAlpha) : rgba(c.blush, b.alpha);
    g.beginPath();
    g.ellipse(-b.x, b.y, b.rx, b.ry, 0, 0, 7);
    g.moveTo(b.x + b.rx, b.y);
    g.ellipse(b.x, b.y, b.rx, b.ry, 0, 0, 7);
    g.fill();
  }

  function drawSweat(g, c, at, p) {
    const u = p.sweat === true ? 0.5 : clamp(p.sweat, 0, 1);
    if (u <= 0) return;
    g.save();
    g.translate(at.x + Math.sin(u * 12) * 2, at.y + u * 26);
    g.globalAlpha = u < 0.9 ? 1 : (1 - u) * 10;
    g.fillStyle = c.sweat;
    g.strokeStyle = c.feature;
    g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(0, -11);
    g.bezierCurveTo(8, -4, 9, 6, 0, 10);
    g.bezierCurveTo(-9, 6, -8, -4, 0, -11);
    g.closePath();
    g.fill();
    stroke(g, p.minimum);
    if (p.detail !== 'simple') {
      g.fillStyle = c.shine;
      g.beginPath();
      g.arc(2.5, 2.5, 2.2, 0, 7);
      g.fill();
    }
    g.restore();
  }

  function drawSparkle(g, c, at, p) {
    const k = 1 + 0.18 * Math.sin(p.t * 9);
    g.save();
    g.translate(at.x, at.y);
    g.scale(k, k);
    g.beginPath();
    for (let i = 0; i < 8; i++) {
      const r = i % 2 ? 3.2 : 10;
      const a = (i * Math.PI) / 4 - Math.PI / 2;
      g.lineTo(Math.cos(a) * r, Math.sin(a) * r);
    }
    g.closePath();
    fs(g, c.sparkle, 1.6, c.sparkleOutline, p.minimum);
    g.restore();
  }

  // A head accessory: the character's own parts, placed at its head anchor.
  function drawAccessory(g, c, at, parts, p) {
    g.save();
    g.translate(at.x, at.y);
    g.rotate(at.rotate || 0);
    g.scale(at.scale === undefined ? 1 : at.scale, at.scale === undefined ? 1 : at.scale);
    for (const part of parts) {
      if (visible(part, p)) drawPart(g, c, part, p.minimum);
    }
    g.restore();
  }

  function paw(g, c, x, y, r, minimum = 0) {
    g.fillStyle = c.limb;
    g.strokeStyle = c.outline;
    g.lineWidth = 2.5;
    g.beginPath();
    g.arc(x, y, r, 0, 7);
    g.fill();
    stroke(g, minimum, 'round', 'round');
  }

  /**
   * anchors(ch, { x, baseY, pose, frame }): attachment points in canvas coordinates.
   * Paired shoulders, feet and hands have L/R points. Other anchors have one point each.
   * frame supplies arm jitter's frame (otherwise pose.t defaults to 0). Coordinates follow the same
   * rotate is the visual x-axis direction; scale is the uniform pose/anchor factor, sx/sy retain squash/flip.
   * matrix gives the exact linear transform for attachment drawing under rotation and non-uniform squash.
   * Coordinates follow the same transforms as drawing; face.scale affects the face, not its origin. A missing face anchor is the body origin.
   */
  function anchors(ch, { x = 0, baseY = 0, pose = {}, frame } = {}) {
    const errors = ns.validateCharacter(ch);
    if (errors.length) throw new Error(`mascot: ${errors[0]}`);
    const p = resolvePose(ch, pose, frame);
    const point = (px, py, at = {}) => {
      const rx = px * Math.cos(p.rot) - py * Math.sin(p.rot);
      const ry = px * Math.sin(p.rot) + py * Math.cos(p.rot) - ch.centreHeight;
      return {
        x: x + rx * p.flip * p.scale * p.sx,
        y: baseY - p.lift + ry * p.scale * p.sy,
        rotate: Math.atan2(
          Math.sin(p.rot + (at.rotate || 0)) * p.sy,
          Math.cos(p.rot + (at.rotate || 0)) * p.flip * p.sx,
        ),
        scale: p.scale * (at.scale === undefined ? 1 : at.scale),
        matrix: {
          a: Math.cos(p.rot + (at.rotate || 0)) * p.flip * p.scale * p.sx * (at.scale === undefined ? 1 : at.scale),
          b: Math.sin(p.rot + (at.rotate || 0)) * p.scale * p.sy * (at.scale === undefined ? 1 : at.scale),
          c: -Math.sin(p.rot + (at.rotate || 0)) * p.flip * p.scale * p.sx * (at.scale === undefined ? 1 : at.scale),
          d: Math.cos(p.rot + (at.rotate || 0)) * p.scale * p.sy * (at.scale === undefined ? 1 : at.scale),
        },
        sx: p.flip * p.sx,
        sy: p.sy,
      };
    };
    const result = {};
    for (const [name, at] of Object.entries(ch.anchors || {})) {
      if (name === 'shoulders' || name === 'feet') {
        result[name] = { L: point(-at.x, at.y, at), R: point(at.x, at.y, at) };
      } else result[name] = point(at.x, at.y, at);
    }
    if (!result.face) result.face = point(0, 0);
    if (ch.feet && result.feet && (p.feet === 'tuck' || (p.feet === 'auto' && p.lift > 6))) {
      const ft = ch.feet.tuck;
      for (const [name, s] of [
        ['L', -1],
        ['R', 1],
      ]) {
        const angle = -s * ft.rotate;
        const x = ft.rect.x + ft.rect.w / 2;
        const y = ft.rect.y + ft.rect.h;
        result.feet[name] = point(
          s * ft.x + x * Math.cos(angle) - y * Math.sin(angle),
          ft.y + x * Math.sin(angle) + y * Math.cos(angle),
          { rotate: angle },
        );
      }
    }
    if (ch.arms) {
      const angles = armAngles(ch, p);
      const at = ch.anchors.shoulders;
      result.hands = {};
      for (const [name, s] of [
        ['L', -1],
        ['R', 1],
      ]) {
        result.hands[name] = point(
          s * at.x + Math.cos(angles[name]) * ch.arms.paw.offset,
          at.y + Math.sin(angles[name]) * ch.arms.paw.offset,
          { rotate: angles[name] },
        );
      }
    }
    return result;
  }

  /**
   * character(ctx, ch, x, baseY, p): draws the character described by `ch` with its feet on baseY, in pose `p`
   * (already merged with the defaults, the character's pose and its mood).
   */
  function character(ctx, ch, x, baseY, p, colours) {
    const g = ctx;
    const c = colours || ch.colours;
    const sc = p.scale;
    p = { ...p, minimum: p.detail === 'simple' ? ch.small.minLineWidth : 0 };
    if (!styles.has(ch))
      styles.set(ch, {
        style: faceStyle(ch.face.style),
        outline: { leftCap: 'round', rightCap: 'round', join: 'miter', ...ch.face.outline },
      });
    const face = {
      c,
      outline: styles.get(ch).outline,
      eyes: ch.face.eyes,
      mouth: ch.face.mouth,
      lashes: ch.face.lashes && !hidden(ch, p, 'lashes'),
      minimum: p.minimum,
      hideBrows: hidden(ch, p, 'brows'),
      hideHighlight: hidden(ch, p, 'highlight'),
      style: styles.get(ch).style,
    };

    // ground shadow (not affected by squash, shrinks and fades with height)
    if (!hidden(ch, p, 'shadow') && p.shadow && ch.shadow && visible(ch.shadow, p)) {
      const shade = ch.shadow;
      const k = 1 / (1 + p.lift / 200);
      g.save();
      g.fillStyle = rgba(c.shadow, shade.alpha * k);
      g.beginPath();
      g.ellipse(x, baseY - 1, shade.rx * sc * k * (0.6 + 0.4 * p.sx), shade.ry * sc * k, 0, 0, 7);
      g.fill();
      g.restore();
    }

    g.save();
    g.translate(x, baseY - p.lift);
    g.scale(p.flip * sc * p.sx, sc * p.sy);
    g.translate(0, -ch.centreHeight);
    g.rotate(p.rot);

    // A. feet
    const feet = ch.feet;
    if (feet && visible(feet, p)) {
      const tuck = p.feet === 'tuck' || (p.feet === 'auto' && p.lift > 6);
      g.fillStyle = c.limb;
      g.strokeStyle = c.outline;
      g.lineWidth = feet.lineWidth;
      if (tuck && visible(feet.tuck, p) && visible(feet.tuck.rect, p)) {
        const ft = feet.tuck;
        for (const s of [-1, 1]) {
          g.save();
          g.translate(s * ft.x, ft.y);
          g.rotate(-s * ft.rotate);
          g.beginPath();
          g.roundRect(ft.rect.x, ft.rect.y, ft.rect.w, ft.rect.h, ft.rect.r);
          g.fill();
          stroke(g, p.minimum, 'butt');
          g.restore();
        }
      } else if (!tuck) {
        for (const f of feet.stand) {
          if (!visible(f, p)) continue;
          g.beginPath();
          g.roundRect(f.x, f.y, f.w, f.h, f.r);
          g.fill();
          stroke(g, p.minimum, 'butt');
        }
      }
    }

    // B. body
    for (const part of ch.body) {
      if (visible(part, p)) drawPart(g, c, part, p.minimum);
    }

    // C. face
    const at = Object.hasOwn(ch.anchors || {}, 'face') ? ch.anchors.face : {};
    const faceScale = (at.scale === undefined ? 1 : at.scale) * (p.detail === 'simple' ? ch.small.faceScale : 1);
    const framed = (at.x || 0) !== 0 || (at.y || 0) !== 0 || (at.rotate || 0) !== 0 || faceScale !== 1;
    g.save();
    if (framed) {
      g.translate(at.x || 0, at.y || 0);
      if (at.rotate) g.rotate(at.rotate);
      g.scale(faceScale, faceScale);
    }
    if (p.blush && ch.face.blush && !hidden(ch, p, 'blush')) drawBlush(g, c, ch.face.blush, p.blush);
    drawEyes(g, face, p);
    drawMouth(g, face, p);
    g.restore();

    // D. accessory, sparkle, sweat
    if (!hidden(ch, p, 'accessories')) {
      for (const item of accessories(ch, p)) {
        const anchor = item.anchor || 'hair';
        const side = item.side || 'R';
        let at = ch.anchors[anchor];
        const sign = side === 'L' ? -1 : 1;
        if (anchor === 'hands') {
          const angle = armAngles(ch, p)[side];
          const shoulder = ch.anchors.shoulders;
          at = {
            x: sign * shoulder.x + Math.cos(angle) * ch.arms.paw.offset,
            y: shoulder.y + Math.sin(angle) * ch.arms.paw.offset,
            rotate: angle,
          };
        } else if (anchor === 'shoulders' || anchor === 'feet') {
          at = { ...at, x: sign * at.x };
          if (anchor === 'feet' && ch.feet && (p.feet === 'tuck' || (p.feet === 'auto' && p.lift > 6))) {
            const ft = ch.feet.tuck;
            const angle = -sign * ft.rotate;
            const x = ft.rect.x + ft.rect.w / 2;
            const y = ft.rect.y + ft.rect.h;
            at = {
              x: sign * ft.x + x * Math.cos(angle) - y * Math.sin(angle),
              y: ft.y + x * Math.sin(angle) + y * Math.cos(angle),
              rotate: angle,
            };
          }
        }
        drawAccessory(g, { ...c, ...item.colours }, at, item.parts, p);
      }
    }
    if (
      !hidden(ch, p, 'sparkle') &&
      p.sparkle &&
      Object.hasOwn(ch.anchors || {}, 'sparkle') &&
      visible(ch.anchors.sparkle, p)
    )
      drawSparkle(g, c, ch.anchors.sparkle, p);
    if (!hidden(ch, p, 'sweat') && Object.hasOwn(ch.anchors || {}, 'sweat') && visible(ch.anchors.sweat, p))
      drawSweat(g, c, ch.anchors.sweat, p);

    // E. arms
    const arms = ch.arms;
    if (arms && visible(arms, p)) {
      const angles = armAngles(ch, p);
      const shoulder = ch.anchors.shoulders;
      const arm = (ax, ay, a) => {
        g.save();
        g.translate(ax, ay);
        g.rotate(a);
        rr(g, 0, -arms.width / 2, arms.length, arms.width, arms.width / 2);
        fs(g, c.sleeve, 2.5, c.outline, p.minimum);
        paw(g, c, arms.paw.offset, 0, arms.paw.r, p.minimum);
        g.restore();
      };
      arm(-shoulder.x, shoulder.y, angles.L);
      arm(shoulder.x, shoulder.y, angles.R);
    }
    g.restore();
  }

  ns.drawing = {
    names,
    guardPose,
    pathGuard,
    rgba,
    character,
    defaultPose: DEFAULT_POSE,
    faceStyle: FACE_STYLE,
    resolvePose,
    anchors,
    hexPath,
    svgPath,
  };
})();
