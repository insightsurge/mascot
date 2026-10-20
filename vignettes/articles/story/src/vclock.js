/**
 * A virtual clock for recording, added to the page before any other script (build-story.R only; never in story.html).
 * Until the recorder takes over it simply follows real time. In manual mode, animation frames and performance.now()
 * only move when the recorder calls advance(), so the engine draws exactly one frame per video frame, however long
 * encoding takes.
 */
(() => {
  'use strict';
  const realRaf = window.requestAnimationFrame.bind(window);
  const realNow = performance.now.bind(performance);
  let now = 0;
  let queue = [];
  let nextId = 0;
  let manual = false;
  function flush() {
    const due = queue;
    queue = [];
    for (const [, callback] of due) {
      try {
        callback(now);
      } catch (error) {
        console.error(error);
      }
    }
  }
  function pump() {
    if (manual) return;
    now = realNow();
    flush();
    realRaf(pump);
  }
  window.requestAnimationFrame = (callback) => {
    nextId += 1;
    queue.push([nextId, callback]);
    return nextId;
  };
  window.cancelAnimationFrame = (id) => {
    queue = queue.filter(([queued]) => queued !== id);
  };
  Object.defineProperty(performance, 'now', {
    configurable: true,
    value: () => (manual ? now : realNow()),
  });
  window.__vclock = {
    manual() {
      manual = true;
      now = Math.ceil(realNow());
    },
    advance(ms) {
      now += ms;
      flush();
    },
  };
  realRaf(pump);
})();
