/**
 * Records the story frame by frame with WebCodecs (H.264) and writes a plain MP4 (ISO BMFF) in memory.
 * Used by build-story.R in headless Chrome, together with vclock.js. Nothing is downloaded or installed:
 * the encoder is the browser's own, and the MP4 boxes below are the minimum a player needs for one video track
 * (ftyp, moov with a single sample table, mdat). The result is left in window.__mp4b64 (base64).
 */
(() => {
  'use strict';

  const u32 = (n) => [(n >>> 24) & 255, (n >>> 16) & 255, (n >>> 8) & 255, n & 255];
  const u16 = (n) => [(n >>> 8) & 255, n & 255];
  const ascii = (s) => Array.from(s, (c) => c.charCodeAt(0));
  function box(type, ...parts) {
    let size = 8;
    for (const p of parts) size += p.length;
    const out = new Uint8Array(size);
    out.set(u32(size), 0);
    out.set(ascii(type), 4);
    let at = 8;
    for (const p of parts) {
      out.set(p, at);
      at += p.length;
    }
    return out;
  }
  const fullBox = (type, version, flags, ...parts) =>
    box(type, [version, (flags >>> 16) & 255, (flags >>> 8) & 255, flags & 255], ...parts);
  const MATRIX = [0x00010000, 0, 0, 0, 0x00010000, 0, 0, 0, 0x40000000].flatMap(u32);

  function moov({ width, height, timescale, delta, samples, avcC, offset }) {
    const n = samples.length;
    const mediaDuration = n * delta;
    const movieDuration = Math.round((mediaDuration * 1000) / timescale);
    const mvhd = fullBox(
      'mvhd', 0, 0,
      u32(0), u32(0), u32(1000), u32(movieDuration), u32(0x00010000), u16(0x0100), u16(0), u32(0), u32(0),
      MATRIX, new Array(24).fill(0), u32(2),
    );
    const tkhd = fullBox(
      'tkhd', 0, 3,
      u32(0), u32(0), u32(1), u32(0), u32(movieDuration), u32(0), u32(0), u16(0), u16(0), u16(0), u16(0),
      MATRIX, u32(width * 65536), u32(height * 65536),
    );
    const mdhd = fullBox('mdhd', 0, 0, u32(0), u32(0), u32(timescale), u32(mediaDuration), u16(0x55c4), u16(0));
    const hdlr = fullBox('hdlr', 0, 0, u32(0), ascii('vide'), u32(0), u32(0), u32(0), ascii('VideoHandler'), [0]);
    const vmhd = fullBox('vmhd', 0, 1, u16(0), u16(0), u16(0), u16(0));
    const dinf = box('dinf', fullBox('dref', 0, 0, u32(1), fullBox('url ', 0, 1)));
    const avc1 = box(
      'avc1',
      new Array(6).fill(0), u16(1), u16(0), u16(0), new Array(12).fill(0), u16(width), u16(height),
      u32(0x00480000), u32(0x00480000), u32(0), u16(1), new Array(32).fill(0), u16(0x0018), u16(0xffff),
      box('avcC', avcC),
    );
    const stsd = fullBox('stsd', 0, 0, u32(1), avc1);
    const stts = fullBox('stts', 0, 0, u32(1), u32(n), u32(delta));
    const keys = [];
    samples.forEach((s, i) => {
      if (s.key) keys.push(i + 1);
    });
    const stss = fullBox('stss', 0, 0, u32(keys.length), keys.flatMap(u32));
    const stsc = fullBox('stsc', 0, 0, u32(1), u32(1), u32(n), u32(1));
    const sizes = new Uint8Array(n * 4);
    samples.forEach((s, i) => sizes.set(u32(s.data.length), i * 4));
    const stsz = fullBox('stsz', 0, 0, u32(0), u32(n), sizes);
    const stco = fullBox('stco', 0, 0, u32(1), u32(offset));
    const stbl = box('stbl', stsd, stts, stss, stsc, stsz, stco);
    const minf = box('minf', vmhd, dinf, stbl);
    const mdia = box('mdia', mdhd, hdlr, minf);
    const trak = box('trak', tkhd, mdia);
    return box('moov', mvhd, trak);
  }

  function mp4(options) {
    const ftyp = box('ftyp', ascii('isom'), u32(512), ascii('isom'), ascii('iso2'), ascii('avc1'), ascii('mp41'));
    const sizeOfMoov = moov({ ...options, offset: 0 }).length;
    const offset = ftyp.length + sizeOfMoov + 8;
    const head = moov({ ...options, offset });
    let total = 0;
    for (const s of options.samples) total += s.data.length;
    const mdat = new Uint8Array(8 + total);
    mdat.set(u32(8 + total), 0);
    mdat.set(ascii('mdat'), 4);
    let at = 8;
    for (const s of options.samples) {
      mdat.set(s.data, at);
      at += s.data.length;
    }
    const out = new Uint8Array(ftyp.length + head.length + mdat.length);
    out.set(ftyp, 0);
    out.set(head, ftyp.length);
    out.set(mdat, ftyp.length + head.length);
    return out;
  }

  function base64(bytes) {
    let s = '';
    for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return btoa(s);
  }
  const pause = () => new Promise((resolve) => setTimeout(resolve, 0));

  window.recordStory = async (opts = {}) => {
    const width = opts.width || 1280;
    const height = opts.height || 720;
    const fps = opts.fps || 30;
    const story = window.story;
    const clock = window.__vclock;
    if (!story || !clock) throw new Error('story or virtual clock missing');
    story.startRecording(width, height, Boolean(opts.tall));
    clock.manual();
    // 33.34 ms, not 1000/30: the engine floors elapsed time into frames, and an exact third can round down.
    const step = 33.34;
    for (let i = 0; i < fps; i++) {
      story.cue(0);
      clock.advance(step);
      await pause();
    }
    const samples = [];
    let avcC = null;
    let failure = null;
    const encode = opts.encode !== false;
    const encoder = !encode ? null : new VideoEncoder({
      output(chunk, meta) {
        if (!avcC && meta?.decoderConfig?.description) avcC = new Uint8Array(meta.decoderConfig.description);
        const data = new Uint8Array(chunk.byteLength);
        chunk.copyTo(data);
        samples.push({ data, key: chunk.type === 'key', timestamp: chunk.timestamp });
      },
      error(error) {
        failure = new Error(`encoder: ${error.message}`);
      },
    });
    const config = {
      codec: opts.codec || 'avc1.640028',
      width,
      height,
      bitrate: opts.bitrate || 560000,
      bitrateMode: 'variable',
      framerate: fps,
      latencyMode: 'quality',
      hardwareAcceleration: opts.hardware || 'no-preference',
      avc: { format: 'avc' },
    };
    // The platform encoder (VideoToolbox on a Mac) gives cleaner frames at this bitrate; fall back to software.
    if (encode && !(await VideoEncoder.isConfigSupported(config)).supported) {
      config.codec = 'avc1.42001f';
      config.hardwareAcceleration = 'prefer-software';
    }
    encoder?.configure(config);
    const frames = Math.round(story.duration * fps);
    const posters = {};
    const wanted = (opts.posters || []).map((t) => Math.round(t * fps));
    for (let i = 0; i < frames; i++) {
      const t = i / fps;
      story.cue(t);
      clock.advance(step);
      story.draw(t);
      if (wanted.includes(i)) posters[i] = story.canvas.toDataURL('image/png');
      if (!encode) {
        if (i >= Math.max(...wanted)) break;
        continue;
      }
      const frame = new VideoFrame(story.canvas, { timestamp: Math.round((i * 1e6) / fps), duration: Math.round(1e6 / fps) });
      if (failure) throw failure;
      encoder.encode(frame, { keyFrame: i % Math.round(fps * (opts.keyEvery || 5)) === 0 });
      frame.close();
      if (failure) throw failure;
      while (encoder.encodeQueueSize > 3) await new Promise((resolve) => setTimeout(resolve, 2));
      if (i % 10 === 0) await pause();
    }
    if (!encode) {
      window.__posters = posters;
      return { frames, stills: Object.keys(posters).length };
    }
    await encoder.flush();
    encoder.close();
    if (failure) throw failure;
    if (!avcC) throw new Error('the encoder gave no avcC description');
    const ordered = samples.every((s, i) => i === 0 || s.timestamp > samples[i - 1].timestamp);
    const bytes = mp4({ width, height, timescale: fps * 1000, delta: 1000, samples, avcC });
    window.__mp4b64 = base64(bytes);
    window.__posters = posters;
    return {
      frames,
      samples: samples.length,
      keyframes: samples.filter((s) => s.key).length,
      ordered,
      bytes: bytes.length,
      codec: config.codec,
      hardware: config.hardwareAcceleration,
      profile: Array.from(avcC.slice(1, 4), (b) => b.toString(16).padStart(2, '0')).join(''),
    };
  };
})();
