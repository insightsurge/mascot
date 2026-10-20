# The Bridge at Five

A short animated story for the article "Meet your mascots". At dusk, Tessa is one plank short of
finishing a little bridge; Knurl brings the last plank but drops it into the stream, and the
five o'clock opening is suddenly in doubt. Neer rises from the water, notices the plank was upside
down, lifts it back up, and the four of them open the bridge right on time as the lanterns come on.

All four mascots are real `mascot()` elements drawn by the package's own engine (`inst/www`); the
stage only places, lights and films them. Their moods, gestures and status lines are driven from
JavaScript with `window.mascot.host.receive()`, and the status tags in the film are read live from
each mascot's own status element.

## Files

| File | Size | What it is |
|---|---|---|
| `story.html` | 683 KB | The live scene: one offline page (engine, characters, stage and captions inlined). Built by `build-story.R`, not committed (`.gitignore`). |
| `story.mp4` | 3.5 MB | The same story as H.264 (High profile), 1280 x 720, 30 fps, 50 s, no audio. |
| `poster.png` | 1.2 MB | A still at 41.3 s: the lanterns are lit and all four status lines show. |
| `transcript.md` | 4 KB | Who says what and what happens: the text alternative to the film. |
| `build-story.R` | 10 KB | Rebuilds `story.html`, `story.mp4` and `poster.png`, and checks the video. |
| `src/template.html` | 2 KB | The page skeleton; `build-story.R` fills in the engine, the cast and the stage. |
| `src/stage.js` | 60 KB | The stage: script, set, camera, light, bubbles, captions and playback. |
| `src/stage.css` | 5 KB | Page and controls (light and dark). |
| `src/vclock.js` | 1 KB | Recording only: a virtual clock so the engine draws exactly one frame per video frame. |
| `src/record.js` | 8 KB | Recording only: `WebCodecs` H.264 encoding and a small MP4 writer. |

No GIF: making one needs a GIF encoder (palette reduction and `LZW`) written for this, and the MP4 and
the live page already cover it.

## Rebuild

From the repository root (or anywhere: the script finds its own folder):

```sh
RENV_CONFIG_AUTOLOADER_ENABLED=FALSE \
R_LIBS=~/Library/Caches/org.R-project.R/R/renv/library/mascot-88913ebe/macos/R-4.6/aarch64-apple-darwin23 \
Rscript vignettes/articles/story/build-story.R            # all: html, video, verify
```

Single steps: `build-story.R html`, `build-story.R video`, `build-story.R verify`, and for checking
the look, `build-story.R stills 7.4 21.7 42` (stills of the 16:9 stage at those seconds) or
`build-story.R stills-tall 21.7` (the phone layout). Stills and verification frames go to
`STORY_OUT` (default: a temporary folder). The whole build takes about 20 seconds.

It needs `pkgload`, `htmltools`, `chromote` and `jsonlite`, plus a Chrome that `chromote` can find.
Nothing is installed, and no `ffmpeg` or other encoder is used.

Edit `src/` and rerun; never edit `story.html` by hand. The engine and the characters are copied
from this checkout (`inst/www`, `mascot()`), so rebuilding after an engine change films the new
engine.

## How the recording is made

1. `build-story.R` opens `story.html` in headless Chrome (`chromote`), with `src/vclock.js` added
   before any other script. It replaces `requestAnimationFrame` and `performance.now()` with a
   clock that only moves when the recorder says so.
2. `src/record.js` steps through the story at 30 frames a second. For each frame it sends that
   moment's moods and gestures to the mascots, advances the clock by one frame (so the engine
   draws its next frame), composes the stage, and hands the canvas to the browser's own H.264
   encoder (`WebCodecs` `VideoEncoder`, `avc1.640028`; it falls back to software Baseline if the
   platform encoder is missing). Because time is virtual, no frame is ever dropped, however slow
   the machine.
3. The encoded frames are written into an MP4 by about a hundred lines of JavaScript (`ftyp`,
   `moov` with one sample table, `mdat`; the index comes first, so the file starts playing before it
   has fully downloaded). The page passes it back to R as base64.
4. `verify` loads `story.mp4` in a `<video>` element and reports `duration` (50 s), `videoWidth` x
   `videoHeight` (1280 x 720) and `readyState` (4), plays two seconds and checks that every
   presented frame is 1/30 s after the last, and screenshots frames at 0.5, 2, 8, 19.7, 30, 36,
   43.4 and 48.5 s.

Bitrate is 560 kbit/s, which keeps the file under 4 MB. Settings can be changed with
`STORY_BITRATE`, `STORY_CODEC`, `STORY_HARDWARE` and `STORY_KEY_EVERY` (seconds between key frames).

## The live page

- Nothing moves until Play is pressed. Before that the page shows the title card as a poster, and
  the hidden engine mascots rest outside the window, where the engine pauses them.
- Play, Pause and Restart; Play again at the end. A progress bar and the time.
- With `prefers-reduced-motion`, the page offers 14 still scenes with Previous and Next (no camera
  moves, no shake), and a button to play the animation after all.
- Captions under the film are real text in a polite live region: what happens, who says what, and
  the status lines on screen. "Read the whole story" lists the full script.
- Below 560 pixels wide the stage switches to a 4:5 frame with larger text, shows one status tag at
  a time, and puts the end card in a 2 by 2 grid.
- Works from a local file and from a web server; it loads nothing from the network.

To show it in a `pkgdown` article, list the files under `resource_files` in the article's YAML (`pkgdown`
copies only what is listed) and embed the page, for example
`<iframe src="story/story.html" title="The Bridge at Five" loading="lazy" style="width:100%;aspect-ratio:16/12;border:0"></iframe>`,
or the video with `<video src="story/story.mp4" poster="story/poster.png" controls muted playsinline>`
and a link to `transcript.md`.

## Known limits

- Only the 16:9 stage is recorded; the phone layout exists in the live page only.
- Text in the film is drawn on the canvas, so in the MP4 it is about 10 to 15 pixels high on a phone.
  The live page's captions and `transcript.md` carry every word.
- The H.264 encoder is the platform's (`VideoToolbox` on a Mac), so two builds give slightly different
  files; the frames that go in are identical. Fast camera moves show some softness at this bitrate.
- Knurl faces left while it carries the plank: the stage mirrors its engine canvas. The character
  itself is unchanged.
- The stage trims each mascot's own ground shadow and draws one of its own, so the feet sit on the
  ground or the bridge.
- `story.html` carries a copy of the engine, so it shows the engine as it was when it was built.
- Dusk darkens the set but only slightly dims the mascots, so their own colours stay readable.
