# Proposal: character engine and format v1

Status: revised design for review, 2026-10-14. No proposed renderer, validator or authoring function has been implemented by this document. Current-code comparison baseline (not the design branch parent): main ace06f5; previous proposal: 6b8cc22. This revision replaces that proposal's contracts, examples and build plan. R construction is specified in [r-builder-proposal.md](r-builder-proposal.md); public API decisions are in [r-api-decisions-0.1.0.md](r-api-decisions-0.1.0.md).

## Changes in this revision

Targeted queue review of 14a2a20 found B1-B4. This revision preserves whole-call atomicity, buffers during all delivery stalls, issues tokens without a session and defines field ownership on remount. Q1 gates U1/I1 independently of core implementation work. Earlier fix-log rows remain historical; this round supersedes their pre-mount atomicity exception.

Recheck follow-up against ace9181: cumulative acknowledgement windows/server-issued tokens, segmented pre-mount compaction, positional listings, headed hardware nominations, baseline-store prerequisites, strict optimisation-safe checks, contrast metadata and preserved condition/mouth details are recorded in the new round of the fix log.

Follow-up to the independent review of 95afd34: corrected brow directions and face migration details; explicit saved kit snapshots, palette opt-out, accepted-update replay, condition classes, process registry, serialization, frame bounds and build milestones. The finding-by-finding record is [2026-10-14-design-fix-log.md](reviews/2026-10-14-design-fix-log.md). These are revised design contracts, not implemented fixes.

| Fix | Sections | Correction |
|---|---|---|
| F1 | 3.12, 4, 6 | Complete typed classic/screen kits and bounded generic face operations; coherent tuning, mirroring, clips, blink and open controls. Proof remains an implementation acceptance task. |
| F2 | 4, 9, 11 | Separate complete Tessa migration data from later artwork; keep wiggle and existing palette; moving variant anchors; near-look approval and 3:1 minimum, not exact old/new pixel equality. |
| F3 | 8, 9 | Contracts precede validators/renderers; explicit integration join before migration/adapter removal; host gaze/status/theme/queue/swap included. |
| F4 | 3.8, 3.11, 3.17, 5, 9 | All-pick fixture tasks, independent draw layers, addressable attachments, explicit affine edge cases and mandatory robot promotion. |
| F5 | 2.4, 6, 9 | Expanded work budgets, one named glow emitter per part, alpha/blur semantics and fail-on-limit workloads including physical-phone acceptance. |
| F6 | 3.14-3.16, 6, 8 | Syntax-only helpers; membership at use; outgoing mood fallback; gesture needs/cycles; atomic queued updates and data-derived statuses. |
| F7 | 3-8 | Reconciled capabilities, examples, merge/null/array rules, clips, reduced stills and colour order. Existing gesture-replaces-change semantics retained; connector/ring pulse reserved. |
| F8 | 9, 11 | Explicit source-package exclusion of heavy visual baselines/tooling; compact offline tests remain. |
| F9 | 9 T1, 11 | One locked Ubuntu screenshot profile; local smoke/repeatability checks; reviewed near-look migration followed by strict approved-baseline regression checks. |

## 1. Agreed scope and ownership

The file describes the character; the engine provides reusable drawing and movement rules. The host handles DOM, panels, focus, sizing and Shiny delivery. R constructs and validates descriptions. Built-ins use the same internal path as user-created data.

Settled requirements:
- Permanent snake_case ids/roles; mandatory family; no runtime character inheritance (`extends` reserved).
- Families may supply reusable defaults; each character can override them. Family membership does not invent anatomy. This supersedes the earlier categories-only proposal.
- Five shared moods: idle, thinking, happy, worried, celebrating. Extra moods and gestures have checked fallbacks. No facial assumption.
- 0.1.0 ships Tessa (hexonians), Neer (elementals) and one robot (visorfolk). The founder chooses alpha_visor or Knurl later. Both robots and all eight picks need complete acceptance fixtures before format freeze.
- Faces near today's and the improved references are acceptable after visual review. Small face details require 3:1; 4.5:1 is a design aim for new characters. Status text has its own text-contrast requirements.
- Palette APIs are mascot_theme(preset =) and mascot_palettes(); approval uses actual characters in the studio, light/dark and small sizes.
- Read/build/check/register/save authoring remains internal in 0.1.0. Experimental exports may follow in 0.1.x. Full remix can ship later; cross-family composition and user-defined anchors are designed now. Builder app is separate from studio; the package never calls an AI model.
- Connector and ring_pulse runtime wait for 0.1.x. Springs, particles, continuous morphs, blend modes, numeric app inputs, fitting and vividness are later scoped capabilities. Required 0.1.0 files must not depend on them.

The eight core capability groups are parts/anchors/layers, paints/clips, size-dependent outlines, data faces, budgeted glow/alpha, mood colour/visibility/shape, arbitrary-part tracks/fallbacks, and 160/96/24 px detail levels. Additional finished characters may be prepared on a development branch; fixture acceptance and release promotion are separate.

## 2. Engine changes and constraints

### 2.1 Today and migration boundary

Current mascot-draw.js draws a fixed shadow/feet/body/face/accessories/effects/arms sequence, with FACE_STYLE and eye/brow/mouth algorithms in code. Tessa's JSON carries a flat body list, known anchors, arm presets and five poses. R hard-codes the mood/gesture vocabulary and only Tessa is registered. The report's other characters are artwork references, not installed built-ins.

Keep the pure frame-based motion core, seeded blink, swap compositing and lifecycle safeguards. Add general part matrices, stable layers, gradients/clips, size-aware outlines, data kits, typed tracks and resolved drawing budgets. An adapter reads provisional data until the complete integrated Tessa migration is accepted. Keep current main's restore/redraw fix; the older design branch's host is not the implementation baseline.

### 2.2 Operations and invariant boundaries

Numbers are finite. Data contains no scripts, expressions, callbacks, URLs or downloadable assets. Supported shape/path/control vocabularies are closed. Unknown keys, versions and required capabilities fail clearly. Files cannot raise engine limits, force motion against the visitor's preference, alter the five-second cap or read clocks/random generators.

Drawing is a pure function of resolved immutable character data, palette, state and frame number. Scheduling and bubble timeouts may use real time in the host/player; drawing does not. One per-element controller and reference-counted listeners support multiple independent mascots; destroy cancels callbacks and removes resources. All source and assets ship offline and are recorded in COPYRIGHTS.

### 2.3 Frame pipeline and caches

1. Resolve shown/target mood and its status; choose the selected character during a swap.
2. Resolve part defaults, named pose, then mood channels. Apply the mood's item/style/variant/recolour choices.
3. Apply the current change OR gesture, using the interruption contract in 3.16; ordinary gestures replace changes as today. Apply bounded idle breathing/blink, then held host/user channels last.
4. Choose the detail band from untransformed CSS width. Evaluate threshold switches, then apply band variant/visibility/face/glow overrides: an explicit band variant wins over the switch and mood/track choice. Bands apply independently to full data; micro does not inherit small. Settle effective variants and hidden ancestors before resolving variant anchors, world transforms and attachment availability.
5. Expand accessories using those final anchor matrices/availability, then kits, refs and effects into a bounded draw list. Resize repeats these stages without resetting state/time; hidden owners suppress their attachments immediately.
6. Draw ground shadow, stable layer-sorted items, face and effects at their declared layers. Resolve each clip in world space; save/restore state per operation.
7. Composite a swap's complete character once through a private canvas, so per-item alpha cannot bypass swap opacity. Draw the terminal resting/reduced frame once, then stop animation requests.

Caches key immutable resolved content (not id alone): parsed paths, resolved kit geometry, per-band expanded lists and paint geometry. Palette changes invalidate colour-dependent paints; resize/DPR changes invalidate backing dimensions/glow conversion; neither replays movement. Registry ids cannot be silently rebound to different content (5).

### 2.4 Resource and performance contract

These are proposed limits/targets, not measurements. One shipped internal policy table is read by R and JS; character files cannot override it. Count expanded items after refs/kits/accessories, every reachable variant/mood/effect and every supported band, taking the worst reachable combination. Do not add mutually exclusive variants together; do count repeated refs separately. Inactive fallback candidates count towards input limits; only reachable playable work counts towards draw limits.

| Per-character limit | full | small | micro |
|---|---:|---:|---:|
| Declared active parts, including attachment parts | 64 | 40 | 16 |
| Expanded painted items, including face/effects | 160 | 90 | 30 |
| Fill/stroke/outline/glow passes | 320 | 180 | 60 |
| Expanded path numbers | 1500 | 900 | 300 |
| Clip applications | 12 | 6 | 2 |
| Gradient uses | 16 | 8 | 2 |
| Glow emitters, including emissive face glyphs | 8 | 4 | 0 |
| Blur radius in design units | 16 | 10 | 0 |
| Sum of inflated glow rectangles / canvas area | 1.0 | 0.5 | 0 |

Deterministic work expansion is part of the versioned operation contract. Each ordinary shape instance counts as one painted item, even when its path has multiple subpaths. A fill, a detail stroke and each enabled outline stroke are separate passes; a glow emitter adds one pass. Eye ellipses expand into separate sclera, optional iris, pupil, each glint, active lid cover and each lash items; lid cover counts whenever its resolved extent is nonzero. Each eye_path/eye_arc is one item, eye_dots is one item per dot, each brow_path is one item, and mouth_path/effect items count individually. Each blush ellipse and ground shadow counts as one item. One shared inset clip counts per ellipse eye using pupils/iris/glints/lid fill/lid edge; those operations reuse it rather than nesting duplicate clips; an outer face clip counts once per face invocation, with nested pupil clips additionally counted. Per-item clips count per invocation. Clip-only target geometry is counted in path work and clip work, but is not a painted item/pass unless separately painted. Gradient uses count per actual fill/stroke invocation, not per distinct paint id. Path numbers count all expanded explicit numeric geometry operands, including repeated clip targets; the operation manifest fixes each generated primitive's numeric operand count identically for R and JS. Limits take the worst legal reachable combination of held face controls, mood, variants, effects and active accessories, not just the five default screenshots. R1a/R1c must record exact per-band totals from this shared expansion for every canonical fixture before declaring it valid; the JSON syntax/reference checks in this design task are not that evidence.

Input bounds: 256 KiB UTF-8 file, depth 32, 10,000 structural nodes, 256 declared parts, 64 moods, 128 gestures, 64 keys per track, 256 tracks per gesture. Bound lexical nesting before JSON parsing; walk R lists iteratively before recursive semantic work. Missing values, duplicate JSON object keys, non-finite values and over-limit inputs error with a path. Any integer frame duration is 1..150. Endpoints are checked after all defaults and fallbacks resolve.

Part opacity multiplies ancestor opacity and item alpha on each paint operation; it is not an isolated group-opacity composite. Overlap may therefore darken. A part's glow names exactly one item emitter; it draws one bounded shadow pass for that item plus its normal passes, never a shadow on every item. Kit glyph emitters are counted separately. No arbitrary blend mode is available.

The file's blur is in design units. The renderer converts explicitly to backing pixels: blur * CSS_width / 300 * DPR. Native shadowBlur is not scaled by the canvas transform ([Canvas shadows](https://html.spec.whatwg.org/multipage/canvas.html#shadows)). Inflate each emitter's transformed bounds by three converted blur radii for the conservative budget estimate; use a bounded scratch rectangle/canvas, not an unbounded full-page surface. The estimate is a cost bound, not an assertion about an exact browser blur kernel.

E5c must exit non-zero on a missing workload, failed precondition or exceeded target. Proposed desktop target: p95 synchronous pose+draw duration <=4 ms for one 160 px mascot at DPR2, fourfold CPU throttling, canonical Chrome. Warm caches with 150 frames, then measure 600 deterministic frames containing mood changes, every gesture and worst-case glow/variants; repeat three times and report the worst p95. Measure the whole page with six mascots too: p95 total <=24 ms. Exclude navigation/cold parsing from frame timings and report their bounded load costs separately.

Synchronous JS timing is only one gate: canvas paint/raster/compositing may occur separately ([Chrome Performance reference](https://developer.chrome.com/docs/devtools/performance/reference), [Chromium compositing design](https://www.chromium.org/developers/design-documents/gpu-accelerated-compositing-in-chrome/)). E5c must also capture browser frame/presentation traces for the same one/six-instance worst-glow workloads, both a founder-nominated headed desktop hardware run and the throttled headless T1 profile. Before hardware testing, record the founder-selected desktop model, OS, GPU, exact browser build, display refresh rate and DPR; no desktop is selected by this document. Headless T1 traces are diagnostics only and cannot pass a display-presentation gate. Report refresh rate, presented/dropped/partial frames and raster/composite costs; RAF intervals are supporting diagnostics, not proof pixels were presented. Proposed 30Hz presentation gate for headed hardware runs on that desktop and the nominated phone, with thresholds locked before measurements: after warm-up, p95 interval between changed presented frames <=50ms and missed scheduled 30Hz presentation ticks <=1% over active changed-frame windows in the 600-frame workload (exclude deliberate settled stills; action schedule is fixed before timing). Report idle/control measurements separately; no activity beyond the deadline. A missing usable trace is not run, never pass. Pixel readback, if used to force completion for a diagnostic stress case, is a separate workload, not interchangeable with ordinary presentation timing. CPU throttling alone does not establish GPU/raster cost.

Physical-phone acceptance uses the founder's nominated phone, recording model/OS/browser/DPR before testing, at real DPR>=2, both modes and all bands with one/six instances. Proposed target: p95 total pose+draw <=24 ms for six instances and no activity callback beyond the action deadline; report dropped frames and thermal conditions too. If an available phone has DPR<2, high-DPR acceptance remains not run. Desktop and phone nomination, headed presentation traces and actual timing are outstanding release evidence; desktop throttling is not a substitute. Improve generic operations, budgets or character data after a failure; do not add character-specific renderer branches.

## 3. The format (v1)

Geometry x/y/rotate default0 where omitted; radii/width/height required by a shape must be positive except an explicitly permitted zero stroke/outline. All finite/range and input bounds in2.4 apply. Optional colour_descriptions maps role names to nonempty descriptions, default humanised role id; unknown role keys error. This metadata is also allowed in family defaults and does not affect drawing.

### 3.0 Conventions
- **File:** UTF-8 JSON, one character per file, file name `<id>.json`. Built-ins live in `inst/characters/`;
  face kits in `inst/faces/`; families in `inst/families/`.
- **Keys:** snake_case, `^[a-z][a-z0-9_]*$`. Ids of characters: `^[a-z][a-z0-9_]{1,31}$`.
- **Units:** a 300 by 300 design frame, area 90,000 square design units, maps to the CSS canvas size. Ground origin is frame [150,270]; local visible bounds are x[-150,150], y[-270,30].
  The origin is the centre of the ground line; **y grows downwards** (as canvas does); angles in radians,
  positive clockwise.
- **Colours** in files: `#rgb`, `#rrggbb` or `rgba(r, g, b, a)`; anywhere a colour is used, the file names a
  **colour role**, never a literal colour (so every colour can be themed).
- **Time:** gestures have `frames` (at 30 fps, at most 150) and keyframes at fractions `0`–`1`.
- **`note`:** any object may carry a `note` string for authors and AI skills; the engine ignores it. (JSON has no
  comments; the `//` lines in this document's examples are reading notes and are not allowed in files.)
- **Defaults:** a key with a default may be left out. "Required" means the validator reports its absence.

### 3.1 Top level

| Key | Type | Default | Rule |
|---|---|---|---|
| `format_version` | integer | required | `1`. Higher than the package supports: error naming the version needed. |
| `id` | string | required | Permanent, flat, snake_case; not a reserved built-in id (unless the file is the built-in). |
| `name` | string | required | Display name ("Tessa"). |
| `family` | string | required | Family id; supply family_definition for a user-defined family (section5). |
| `description` | string | required | One or two plain sentences: who the character is and what it suits. |
| `resolved` | boolean | false | True only for complete checked output; all semantic checks still run (section5). |
| `family_definition` | object | none | Source defaults or resolved metadata snapshot, id matching family (section5). |
| `palette_sources` | map | resolved: required, possibly {} | One character/family origin per materialised palette; computed on source resolution, saved unchanged (section5). |
| `pronouns` | string | none | Free text ("she/her"); used in docs and the studio only. |
| `requires` | array of strings | required | Engine capabilities the file uses (section 3.18). Unknown: error "needs a newer mascot". |
| `colours` | object | required | Colour roles (3.2). |
| `colour_descriptions` | map of strings | `{}` | Declared-role descriptions; missing descriptions humanise the role id. |
| `follows` | object | `{}` | Derived roles (3.2). |
| `brand` | object | `{}` | `primary`, `secondary` → leader roles. |
| `contrast` | array | `[]` | Contrast pairs (3.2). |
| `modes` | object | `{}` | `dark` colour overrides (3.2). |
| `palettes` | object | `{}` | Named presets (3.3). |
| `paints` | object | `{}` | Gradients (3.4). |
| `shapes` | object | `{}` | Named reusable shapes (3.5). |
| `ground` | object | required | `centre_height`, `shadow` (3.6). |
| `outline` | object | from family | Outline style (3.7). |
| `parts` | array | required | The part tree (3.8). |
| `anchors` | object | `{}` | Named attachment points (3.11). |
| `face` | object or `null` | `null` | Face (3.12). `null` for faceless characters (Strata). |
| `poses` | object | `{}` | Named channel sets (3.13). |
| `moods` | object | required | Moods (3.14). |
| `gestures` | object | from family | Gestures (3.15). |
| `motion` | object | from family | Change and idle settings (3.16). |
| `effects` | object | `{}` | Effect placement and overrides (3.16). |
| `lod` | object | `{}` | Band overrides (3.10). |
| `accessories` | object | `{}` | Accessories (3.17). |
| `wear` | array of strings | `[]` | Accessories worn by default (today's `pose.accessory`). |
| `note` | string | none | Ignored by the engine. |

### 3.2 Colours, derived roles, contrast and dark mode

**`colours`**: `{ role: colour }`. Required roles depend on what the file uses: every role named anywhere must be
here. The face kit declares the roles it needs (for `classic`: `feature`, `eye_white`, `shine`, `eyelid`,
`teeth`, `tongue`, `sweat`, `sparkle`, `sparkle_outline`, `outline`, `blush`, `blush_strong`) and maps them through `face.colours` if the character names them differently.

**`follows`** (today's rules, snake_case):

| Key | Type | Default | Rule |
|---|---|---|---|
| `from` | array of roles | required | Leaders in priority order; acyclic. |
| `shade` | `"same"`, `"lighter"`, `"darker"` | `"same"` | As today's `shadeColour()`. |
| `amount` | number −1..1 | `0` | Signed HSL lightness shift. |
| `saturation` | number −1..1 | `0` | Signed HSL saturation shift. |

**`contrast`**: an array of pairs the character promises; checked at check time for the file's own colours
(error) and at theme time for user colours (warning, class `mascot_contrast`, as today).

| Key | Type | Default | Rule |
|---|---|---|---|
| `fg` | role | required | Foreground role. |
| `bg` | role, `"page"`, `"page_light"` or `"page_dark"` | required | `"page"` means both page backgrounds (white and `#212529`, or the bslib theme's); the other two mean one of them. |
| `bg_paint` | paint id | none | Optional declared background gradient over bg; check conservative colour bounds, not guessed overlapping items (section6). |
| `min` | number | `3` | 3 minimum for meaningful graphics/face details; 4.5 is an aim for new characters, not compulsory migration. |
| `where` | string | none | Plain words for the message ("eyes on the visor"). |

**`modes`**: `{ "dark": { "colours": { role: colour } } }`. Roles not listed keep their light value. This is how
Neer's dark flip (light body, ink features) is written, and how Tessa keeps one palette (no `dark` entry).

### 3.3 Palettes (presets)
`palettes`: `{ preset_id: { description, light: { role: colour }, dark: { role: colour } } }`. A preset normally lists
**leaders** (usually the brand roles), but can set other declared roles explicitly; `follows` derives the rest. The studio palette picker shows each preset
on the real character. Reserved inside a preset: `vividness` (later API idea; error in v1).

### 3.4 Paints

| Key | Type | Default | Rule |
|---|---|---|---|
| `type` | `"linear"` or `"radial"` | required | |
| `from`, `to` | `[x, y]` | required for linear | In the local space of the part being drawn. |
| `centre` | `[x, y]` | required for radial | |
| `r0`, `r1` | numbers ≥ 0 | `0`, required | Inner and outer radius. |
| `focus` | `[x, y]` | `centre` | Radial focus. |
| `stops` | array of `[offset, role]` or `[offset, role, alpha]` | required | 2–6 stops, offsets ascending in 0..1. |

An item uses a paint with `"fill": { "paint": "body_gem" }`; a plain role is `"fill": "body"`.

### 3.5 Shapes (items) and named shapes
Every part draws a list of **items**. An item is a shape plus how to paint it.

| Key | Type | Default | Rule |
|---|---|---|---|
| `id` | string | none | Needed only to clip to it, to change it per mood, or to hide it per band. Unique in its part. |
| `shape` | one of `polygon`, `hexagon`, `circle`, `ellipse`, `rect`, `round_rect`, `path`, `polyline`, `arc`, `ref` | required | |
| geometry | see below | | Numbers in the part's space. |
| `fill` | role or `{ "paint": id }` | none | |
| `stroke` | role | none | Detail line (not the outline). |
| `width` | number > 0 | `2.5` | Stroke width. |
| `alpha` | number 0..1 | `1` | Applies to fill and stroke. |
| `outline` | boolean | `false` | Stroke with the character's outline style (3.7). |
| `cap`, `join` | `butt/round/square`, `miter/round/bevel` | `round`, `round` | |
| `transform` | `[x, y, rotate]` | none | Moves and turns this one item inside its part (Tessa's tucked feet). |
| `clip` | `"part_id.item_id"` | none | Clip this item to that item's outline (in that item's world transform). |
| `lod` | array of bands | all | Bands where the item shows. |

Geometry per shape:

| Shape | Keys |
|---|---|
| `polygon` | `sides` (3–12), `r`, `corner` (default 0), `x`, `y` (default 0), `rotate` (default 0 = a point at the top) |
| `hexagon` | as `polygon` with `sides: 6` (kept so today's files read naturally) |
| `circle` | `x`, `y`, `r` |
| `ellipse` | `x`, `y`, `rx`, `ry`, `rotate` |
| `rect` | `x`, `y`, `w`, `h` |
| `round_rect` | `x`, `y`, `w`, `h`, `r` (number or four numbers) |
| `path` | `d` (absolute `M L Q C Z`) |
| `polyline` | `points` (`[[x, y], ...]`, at least 2), stroke only |
| `arc` | `x`, `y`, `r`, `start`, `end` (radians), stroke only unless `closed: true` |
| `ref` | `use` (a key in `shapes`), optional `x`, `y`, `rotate`, `scale` |

`shapes`: `{ shape_id: item }`, reusable geometry (for example one hexagon used for the body fill, the clip and
the outline). Items in `shapes` may not themselves be `ref`.

### 3.6 Ground

| Key | Type | Default | Rule |
|---|---|---|---|
| `centre_height` | number ≥ 0 | required | Height of the body centre above the ground. `root.rotate` and the wiggle pivot here (as today's `centreHeight`). |
| `shadow` | object or `null` | `null` | `rx`, `ry`, `alpha`, `colour` (role, default `shadow`). Drawn by the engine: not squashed, shrinks and fades with lift, as today. |

### 3.7 Outline

| Key | Type | Default | Rule |
|---|---|---|---|
| `width` | number ≥ 0 | from family | `0` means no outline. |
| `colour` | role | `outline` | |
| `join` | `miter/round/bevel` | `round` | |
| `cap` | `butt/round/square` | `round` | |
| `second` | object or `null` | `null` | A second contour drawn first and wider: `{ "width": 5, "colour": "outline_light" }` (round 5's ivory plus ink). |
| `lod` | `{ band: { width, second } }` | `{}` | Per band; widths are in canvas units, so a `micro` override can keep the line visible at 24 px. |

Hexonians' family sets `{ "width": 2.5, "colour": "outline" }` with ink `#16201b`-like roles: slim and black.

### 3.8 Parts

| Key | Type | Default | Rule |
|---|---|---|---|
| `id` | string | required | Unique; not `root`, `face`, `effects` (channel prefixes). |
| `parent` | part id or `"root"` | `"root"` | Acyclic. `root` is the ground origin; it carries lift, squash and flip. |
| `at` | `[x, y]` | `[0, 0]` | Position of this part's pivot in the parent's space. The part's own items are drawn around its pivot. |
| `rotate` | number | `0` | Resting rotation (radians). |
| `scale` | number or `[sx, sy]` | `1` | Resting scale. |
| `layer` | number | `0` | Draw order: lower first; ties keep array order. Independent of `parent`. |
| `items` | array of items | `[]` | What the part draws. |
| `variants` | `{ name: [items] }` | none | Alternative item lists; `items` is the variant `default`. A mood, track or switch picks one (shape swap). |
| `switch` | object | none | `{ "channel": "root.lift", "above": 6, "variant": "tuck" }`: a declarative threshold, no expressions. |
| `opacity` | number 0..1 | `1` | |
| `glow` | object or `null` | `null` | `{ "item": item_id, "colour": role, "blur": n, "alpha": a }` within budget. |
| `visible` | boolean | `true` | |
| `keep_upright` | boolean | `false` | Uses the explicit affine rule below; position follows parent. |
| `no_flip` | boolean | `false` | Removes the defined inherited reflection, by the affine rule below. |
| `lod` | array of bands | all | Bands where the part shows. |

Every part has these **channels** for poses and tracks: `x`, `y` (offsets added to `at`), `rotate`, `scale_x`,
`scale_y`, `opacity` (numbers), `visible` (boolean), `variant` (name). Channel names are written
`part_id.channel` (`head.rotate`).

**Rig channels** the engine provides on every character:

| Channel | Meaning | Today's pose field |
|---|---|---|
| `root.lift` | Height above the ground (positive up) | `lift` |
| `root.rotate` | Body tilt about `centre_height` | `rot` |
| `root.scale_x`, `root.scale_y` | Squash and stretch about the ground | `sx`, `sy` |
| `root.flip` | `1` or `-1` | `flip` |
| `face.look_x`, `face.look_y` | Gaze, −1..1 | `look`, `lookY` |
| `face.blink` | 0..1 | `blink` |
| `face.eyes`, `face.mouth`, `face.brows` | Style names | `eyes`, `mouth`, `brows` |
| `face.open`, `face.lid` | Mouth openness / minimum eyelid cover, 0..1 (3.12). | new |
| `face.blush` | 0..1, or `"strong"` | `blush` |
| `effects.sweat` | 0..1 progress | `sweat` |
| `effects.sparkle` | boolean | `sparkle` |

### 3.9 Per-mood part changes
A mood can change parts in four ways, all data:

| Key in a mood | Example | Use |
|---|---|---|
| `channels` | `{ "core.variant": "blue", "head.rotate": 0.08 }` | Shape swap, pose tweaks, visibility. Values are set, not added (tracks add). |
| `recolour` | `{ "light": "light_happy" }` | For this mood, role `light` takes the colour of role `light_happy`. Themeable, because both are roles. |
| `items` | `{ "chest.lamp": { "fill": "light_worried" } }` | Change one item's fill, stroke or alpha. |
| `effects` | `{ "sweat": 0.35, "sparkle": true }` | Effects from the kit. |

`recolour` covers alpha_visor's chest light and Cinder's blue core colours; `channels` with `variant` covers
Cinder's core shape and Brim's ghost card; `items` covers one-off changes.

### 3.10 Levels of detail

| Key | Type | Default | Rule |
|---|---|---|---|
| `small`, `micro` | object | `{}` | Overrides for that band. `full` is the file as written. |
| `…hide` | array of `part` or `part.item` | `[]` | Hidden in this band (the same as `lod` on the part, written from the band's side). |
| `…outline` | outline object | none | Overrides 3.7 for the band. |
| `…face` | object | none | `{ "scale": 1.3, "lashes": false, "brows": false, "iris": false }`: bigger, simpler faces at 24 px. |
| `…glow` | boolean | `true` in `small`, `false` in `micro` | |
| `…variants` | `{ part: variant }` | none | A simpler shape for this band (Knurl's 24 px chassis). |

Bands: `full` 128 CSS px and above, `small` 48–127, `micro` below 48 (attachment E's review bands, here as the
engine's thresholds). The host measures the canvas's CSS size and passes the band; the band can change on resize,
which redraws without resetting motion.

### 3.11 Anchors

| Key | Type | Default | Rule |
|---|---|---|---|
| `part` | part id | required | The anchor moves with this part. |
| `at` | `[x, y]` | `[0, 0]` | In the part's space. |
| `rotate` | number | `0` | |
| `scale` | number | `1` | |
| `side` | `"l"` or `"r"` | none | Anatomical side (does not swap on flip). |
| `description` | string | required | Shown by mascot_anchors(). |
| `variants` | map | {} | Owning-part variant -> {at, rotate, scale}; only these local anchor fields override. |

Names are any snake_case string. Paired anchors are written out (`hand_l`, `hand_r`), not generated from one entry
as `shoulders` and `feet` are today. Custom names such as badge or tool_grip are supported; positions may be outside the painted silhouette. **Recommended vocabulary** (so shared accessories find their place):
`crown`, `forehead`, `hair`, `eyes`, `upper_lip`, `chin`, `neck`, `collar`, `chest`, `back`, `waist`,
`shoulder_l/r`, `hand_l/r`, `foot_l/r`, `face`, `sparkle`, `sweat`. An accessory asking for an anchor the
character lacks is a check error, never a silent `(0, 0)`.


#### Exact transform, visibility and reference rules

Root coordinates use ground origin with y down. Let T/R/S be ordinary affine matrices; the root matrix is T(x,base_y-lift) * S(flip*scale_x,scale_y) * T(0,-centre_height) * R(rotate) * T(0,centre_height). A body centred above ground sits at [0,-centre_height]. This reproduces the existing pivot/ground-squash ordering. Each part's local matrix is T(at+[x,y]) * R(rotate) * S(scale_x,scale_y). Resting rotate/scale initialise channel values; poses set absolute values, numeric add tracks add offsets. Do not add a resting rotate twice. Parent matrices multiply local matrices; layer order is independent. Tied layers use original expanded array order.

For orientation flags, first compute the child world pivot p = parent_translation + A * (at + [x,y]) using the original inherited parent linear matrix A. Filter only the inherited linear block, never this world pivot. For det(A)<0 define F=diag(-1,1), otherwise identity; B=A*F. QR-decompose positive-determinant B as R(theta)*U, U upper-triangular with positive diagonal. With no_flip omit F; with keep_upright omit R and U's shear but retain U's positive diagonal stretches (and F unless no_flip). Let the filtered linear block be C; assemble the final child matrix as [C, p] * R(local_rotate) * S(local_scale_x,local_scale_y). The child local translation has already been consumed in p and is not applied twice. Thus keep_upright means no inherited tilt/shear, not removal of authored local rotation; a tool needing both world-up and unmirrored uses both flags. Numeric cases with child at[10,0] and identity local rotation/scale: parent R(pi/2), keep_upright gives p[0,10], C=identity; parent diag(-1,1), no_flip gives p[-10,0], C=identity; parent R(pi/2)*diag(2,3), keep_upright gives p[0,20], C=diag(2,3). Test these and nested shear/reflection numerically. Singular/zero-scale ancestors collapse their entire subtree for that frame; do not invert, divide by zero or resurrect children via orientation flags. Values with |det|<1e-12 are treated as singular under the bounded coordinate domain. x/y/geometry coordinates lie within +/-4096 design units and scales within[-16,16]; transformed bounds also count towards resources.

Hidden/LOD-excluded parents suppress descendant painting but retain nonsingular transforms for declared geometry; anchors expose availability=false to attachments. Variant anchor overrides select by owning part's active variant and recompute with that matrix. An anchor's local matrix is T(at)*R(rotate)*S(scale,scale); scale>0. Anchor names are globally unique within a character. No point is inferred from a magic name.

Clips use the active target item's filled geometry in its world matrix, even if that item is hidden for painting. The target id must exist in every reachable active variant where its source can paint; absent/inactive-variant geometry is a semantic error. A clip uses geometry only (no nested clip, glow or alpha); cycles in geometry/ref dependencies error. A singular clip target suppresses its source for that frame. A ref cannot reference another ref. Allowed ref overrides are fill/stroke/width/alpha/outline/cap/join/lod and x/y/rotate/scale; geometry keys other than these error. Apply ref's transform after resolving reusable geometry; a shape definition has no part-specific id/clip/lod. Arrays are not merged. All resolved uses are counted, including clip-only geometry work.


### 3.12 Face kits: closed grammar and coherent tuning

A face is optional (`null` for faceless characters). Otherwise fields are: part (required real part), at [0,0], scale 1, layer (owning layer+0.5), kit (family default or required classic/screen), kit_definition (required complete matching kit in resolved/saved data, including built-ins; optional in source), clip (optional filled item), eyes {y:-12,spacing:30,lashes:true,iris:null}, mouth {y:24}, blush (optional ellipse placement), colours (kit-role mapping), tune (style numeric overrides), styles (complete replacement style objects), caps {left:"round",right:"round",join:"round"}. Numbers are finite; scale>0; spacing>=0. eyes.iris is a colour-role name or null; it enables an iris layer in ellipse eyes. Each colour actually used must map to a declared role. Unused kit roles need no dummy colour.

The kit fields are id, description, roles (array), defaults {eyes,mouth,brows,blush:0}, eye_styles, brow_styles, mouth_styles, effects and glow (optional {blur,alpha}). All maps use named styles; unknown fields error. A valid closed eye style is required. Every default style must exist; defaults.blush is 0..1 or strong. Eye styles may set hide_brows (boolean, default false); when true they suppress the selected brow on that eye. There are no parameter expressions, arbitrary callbacks or style-name switches in engine code. A kit selects bounded generic operations described below; an operation may serve any character/family.

| Operation | Required data | Optional defaults and algorithm |
|---|---|---|
| eye_ellipse | rx>0, ry>0, pupil {r>=0} | pupil look_range [7,7]; lid 0; slant 0; fill eye_white. Draw sclera ellipse with optional outline {colour,width}, then share one inset ellipse clip max(rx-1,0), max(ry-1,0) for iris/pupil/glints/lid fill/lid edge. Pupil at [0,0] plus face.look_x/y times look_range determines its centre; optional lid_edge {colour,width} draws the clipped boundary. Widths are nonnegative face units; omitted outline/lid_edge means no stroke. Both use face caps/join. Iris radius is pupil.r when enabled, black pupil radius is 0.65*pupil.r; otherwise pupil radius is pupil.r. |
| eye_arc | r>0,start,end | y0,width5,fill none,stroke feature; draw an arc with standard Canvas radians. Gaze has no effect. |
| eye_path | d | fill feature, stroke none,width2; M/L/Q/C/Z grammar, local eye coordinates; gaze has no effect. |
| eye_dots | centres array of [x,y], r>0 | fill feature; finite dots; no scan/clock loop. Gaze has no effect. A scan style is static; any visible scan movement must use explicit bounded part tracks. |
| brow_path | d | width3.5,stroke feature, y:-25; width0 suppresses the operation; path local to each eye; mirror left. |
| mouth_path | items array of path/ellipse/polyline shapes only | box [20,12] is positive half-width/half-height, not full dimensions. For normalised item coordinates (u,v), map x=box[0]*u and y=box[1]*face.open*v before painting. Radii/control points use the same map; widths stay in face units and are unaffected by box/open. At open0 filled geometry collapses, strokes remain bounded paths. No arc, nested ref, item transform or nested clip in this operation. No functions/bindings inside paths. |

An ellipse pupil has glints [{at:[-0.35,-0.4],r:0.22}] by default, in pupil-radius units with shine fill; the array may be empty. Additional offsets are finite and radii0..1. pupil.at defaults[0,0] in face units and is added after eye mirroring, like gaze. pupil.mirror_glints defaults false: both eyes retain the same face-space highlight direction; true reflects glint x on the left eye. Pupil r is at most min(rx,ry); pupil/glints remain clipped.

Lashes are optional {angles:[radians],length:7,width:3,radii:[rx,ry],at:[0,0]}; ellipse radii default to the current eye radii, arc radii default[r,r]. Explicit radii are positive and at is a finite two-vector relative to the eye origin, independently of arc.y. On the right, a lash starts at at+[rx*cos(a),ry*sin(a)] and extends length*[cos(a),sin(a)]; mirror x for the left. This is a radial ray, not the ellipse normal. Stroke feature, round cap/join; never translate lashes by pupil gaze. Tuning unspecified radii follows the eye, while explicitly authored radii remain explicit.

The ellipse lid uses u=max(style.lid,face.lid,face.blink), all0..1. Fill a rectangle from [-1.2*rx,-1.2*ry] to [1.2*rx,ly], where ly=-1.2*ry+2.4*ry*u; the shared inset clip trims it. Its edge runs from [-1.2*rx,ly+slant] to [1.2*rx,ly-slant], mirrored for the left. Slant is bounded by +/-ry. Paint sclera/outline, clipped iris/pupil/glints, clipped lid fill/edge, then unclipped lashes. With blink>=0.96 select the required closed style on both eyes; this intentional threshold rule overrides happy as well. Brow/arc strokes default round caps/join; ellipse outline/lid edge use face caps/join. Left eye mirrors local geometry except the documented pupil/gaze/glint offsets. Root reflection then applies; host gaze compensates it to point to the requested page side.

Controls: face.look_x/y in[-1,1], face.blink/lid/open in[0,1], face.scale>0, face.eyes string or two-element [left,right], face.mouth/brows style names, face.blush number0..1 or "strong", default kit.defaults.blush. A supplied face.blush placement uses colour roles blush/blush_strong, alpha0.45/strong_alpha0.55 by default; numeric control multiplies alpha. No placement means no blush operation/role requirement. face.open defaults1; it means mouth openness, not an undefined eye operation. `brows:"none"` is a defined empty style. Blink wins eye style; explicit style selection wins kit defaults; character styles replace a whole kit style before tune; tune may override only numeric leaves already present (including fixed-length numeric arrays) and is revalidated. No tune creates keys/changes an operation. General geometry changes use a replacement style. Layer order: blush, eyes, brows, mouth; surrounding face clip applies to all. Character-level face scale scales eyes/mouth/line widths together; per-band flags disable iris/lashes/brows explicitly.

Kit glow is per emitted glyph (left eye/right eye/mouth, brows only when visible); ordinary geometry and budget limits apply. Emissive styles use feature colour and no sclera, implemented through eye_path/eye_dots/eye_arc styles. No additive blend is implied. Classic uses no glow by default. All stills remain readable with glow off at micro.

Effects use generic sweat_drop and sparkle_star operations available to any kit. Valid operation/mode pairs are sweat_drop: progress or track, sparkle_star: pulse or track. Any other pair errors. Each declares items (ordinary shapes), at [0,0], and one valid mode; pulse/track additionally permit reduced_items (static shapes, default empty). Character effects map names to {anchor,layer}; missing anchor is an error. Sweat progress u=effects.sweat in0..1 places geometry at [sway*sin(u*sway_rate),u*travel] with defaults sway2,sway_rate12,travel26; opacity is1 up to fade_at0.9 then (1-u)/(1-fade_at), and u0 suppresses it. It is a static pose control, not a moving particle. Sparkle pulse multiplies scale by 1+amplitude*sin(rate*t), defaults amplitude0.18 (range0..0.5), rate9 (positive<=30), t=min(frame,activity_deadline)/30; after the deadline its phase is held. Reduction retains progress geometry at the same authored u, placement and opacity: it is already a static pose, with no frame dependency. For progress mode reduced_items must be absent; its presence is a validation error. Pulse/track modes instead use reduced_items without pulsing or track motion, at their declared effect origin; empty means hidden. Reduction must not remove Tessa's static worried sweat mark. These reproduce the ordinary effects' semantics with generic data operations, distinct from deferred particles/rings.

Only track-mode effects permit frames and tracks; frames on progress/pulse error. Additional mode track effects have frames1..150 and local x/y/scale_x/scale_y/opacity absolute tracks; they share3.15's key/type/easing rules but not the gesture return-to-mood endpoint rule. Their terminal rest is hidden (opacity0), so an effect can move down/fade without leaving a held part pose. Clip their schedule to the action deadline, discard pending effects under reduction, and draw reduced_items instead. No timers, unbounded loops, executable formulas or ring expansion are authored. All effects are expanded into budgets before approval. Complete examples follow in4; near-looking acceptance must be demonstrated, not inferred from this grammar.

### 3.13 Poses, merge and saved resolution

poses is a map from pose id to typed channel values. Part defaults -> named pose -> mood channels, with later present keys replacing earlier ones. Missing means inherit at this authored merge stage. Scalars replace; objects recursively merge by key; arrays replace whole, never concatenate. A present null is permitted only in fields explicitly typed nullable (including source-only inherited palette opt-outs in5) and suppresses the inherited optional value. Non-nullable null is an error, not deletion. A named gesture/style/palette/shape definition is an atomic replacement, not a recursive merge of an incomplete definition. Moods merge by field; channels/item overrides merge by their named keys. Family/character merge uses the same rules (5).

Track null has a separate meaning: return to the currently displayed mood's base value. Runtime update NULL has a third, documented R meaning: leave unchanged. These contexts must not be conflated.

### 3.14 Moods, statuses and swap fallback

Each mood has description and status (nonempty strings after defaults), fallback (required for extras), pose (optional), face (typed face controls), channels, recolour, items, effects and reduced. Default mood is idle regardless of JSON key order. The resolved character must contain all five core moods; each authored character lists their ids explicitly, even when fields inherit family metadata. Core moods have no fallback. An extra's acyclic chain must end in a core mood; missing targets error. Faceless moods use arrangements/colours/parts plus status, not dummy eyes.

reduced is restricted to {channels,face,recolour,items,effects}; each uses the same types as its mood equivalent, effects are static reduced selections, and it cannot contain tracks/durations/gestures. Reduction shows target mood plus this optional still immediately, with held channels last. No reduced override can force motion. Absence uses target resting pose.

A new explicit mood must belong to the selected incoming character: a spelling error is not silently converted by a fallback. On a character-only swap, retain the outgoing target mood if the incoming character has that id; otherwise traverse the outgoing character's fallback chain until an id supported by the incoming character is reached. The five shared moods guarantee a terminus. If no outgoing character/state is known (first mount/early update), use idle. Status mode mood follows the shown character/mood's status; a supplied custom status persists until reset. Foldlings example: saved -> fallback happy, deleted -> idle, warning -> worried; status can say "Saved", "Deleted" or "Check the item". Their moods need not draw faces.

This is an intentional proposed improvement over today's character-only reset to the first mood; it needs same-call/queue/swap regression cases. Explicit incoming mood always wins. During a swap, updates affect only the incoming target; the outgoing visual snapshot keeps its captured status until the shown character changes.

### 3.15 Gestures and fallbacks

A gesture has description (required after defaults), frames integer1..150, needs (array of part ids, default[]), fallback (gesture id or null), tracks (required map) and effects (bounded effect triggers, default[]). Shared callable names nod/wave must exist or resolve to a playable fallback; rock is a reusable root-rotation fallback. Unknown gesture names error. Known gestures unavailable because declared needed parts are absent follow their fallback; missing/cyclic/unplayable fallback paths error.

Validate vocabulary/types for every authored gesture; resolve needs availability before requiring playable part targets. An absent track-target part may be waived only when it is explicitly in that candidate's needs and the fallback path is playable. A typo outside needs still errors. Unknown capabilities/unsafe geometry are never waived. The checked result records the selected playable gesture per callable id, so JS never improvises a different fallback.

Tracks are [[at,value,ease?],...] or {mode:"add"|"set",keys:[...]}. At values strictly increase from0 to1, inclusive; at least two keys. Numeric add defaults to additive offsets, first/last offset0; numeric set endpoints null mean mood base, and all set tracks must end null or the identical base value for every usable mood. Discrete tracks are set, switch at keyframes, start/end null; keyframe interpolation never invents a variant/style. A requested intermediate value of null interpolates to/from the current base. Allowed easings linear/ease_in/ease_out/ease_in_out/step. Their formulas are respectively t, t*t, 1-(1-t)^2, smoothstep3t^2-2t^3, and hold until next key. Interpolation uses the easing on the starting key. Every target's type/range is checked, including composed scales/opacity in reachable poses. All track motion ends at the scheduled rest; there is no implicit hold after1.

Effect triggers are {at:0..1,effect:kit_effect_id,anchor:anchor_id}; all references must exist and work stays within the action deadline. No ring_pulse is supported. Knurl's discrete clamp variant must include a terminal [1,null], not stop at0.55.

### 3.16 Motion scheduling and host behaviour

motion.change: style wiggle/hop/gesture (default wiggle), frames18, angle0.06, height8, swap_at0.5; gesture required for style gesture. motion.idle: frames150, blink_every120, blink_jitter30, blink_frames6, breathe0.012, breathe_period90, breathe_part root, extra null. Durations are finite and positive; blink_jitter+blink_frames/2 < blink_every. Breathe amplitude0..0.1, period>0. Change/idle frames integer1..150. Extra names one playable gesture and plays once; no loop.

Mount, a changed mood, gesture, changed held pose or play-after-pause begins one activity window of at most150 frames at30fps. A gesture replaces an in-progress change or gesture and commits the target mood immediately; a later mood change replaces the gesture and starts from the currently shown face. Repeating target mood does not restart. Same-call character/mood applies first; gesture follows. During an animated character swap a supplied valid gesture is discarded because the swap movement owns the window; reduced motion discards movement too. Independent idle/mood_change/gestures/swap/minimising/restoring/messages/others switches retain current meanings. A disabled gesture does not discard other valid fields.

All change, idle extra, effect and delayed tracks share the window's absolute deadline. Schedule a late effect/extra by proportionally fitting its finite duration into the remaining frames; if no frame remains, discard it. New distinct user/server actions can begin a new window, but queued effects/children cannot extend one themselves. Idle fades in the final third; crossing blink windows are skipped. At the deadline settle all channels/effects to the target rest, emit one final frame, cancel RAF. Pause freezes frame time; destroy cancels everything; hidden elements pause scheduling without replaying discarded actions when shown.

Enabling reduced motion settles immediately and clears pending movement. Disabling it does not replay old change/gesture/extra/swap/effects. Colour changes, resize/DPR changes, detail-band changes and redraw do not start activity. Held host gaze is instantaneous, not animation; it clears only look channels. No gaze channels are sent for faceless/no-gaze kits. Shiny status/ARIA use shown state, never a pending invisible target. Build the canvas accessible label from character display name plus shown status, never raw character/mood ids.

Character swap retains today's private-canvas fade, bounded out/in duration, captured outgoing state, retarget/reversal speed and no-visible-pending-target behaviour. Fit total phases to incoming activity budget. Mid-swap mood changes commit without wiggle and do not extend it. Reduction or swap:false finishes immediately; re-enabling never replays it. Same id/content is ordinary update; same id/different content is rejected before state change.

#### Queues, atomic buffering and cumulative acknowledgements

An invalid runtime call changes no fields, including before a mount. Invalid explicit presets reject their bubble/status and every other field from the same call. The pre-mount exception in the 14a2a20 draft is withdrawn. Namespacing happens once; update journals, buffers, ownership and checkpoints belong to one Shiny session. Content-token issuance is process-wide as specified below, not update-state storage.

**Two bounded stores.** Keep an immutable journal of at most 20 issued, unresolved wire revisions, and one mutable buffer for all unissued calls. Use that same buffer before first mount, during unmount and whenever the delivery window is full. A full 20-revision window delays delivery; it does not reject another ordinary status/bubble/state call. Capture immutable prepared copies so later R-list mutation cannot change a buffered original. Assign a strictly increasing call sequence before buffering; assign contiguous positive wire revisions only when dispatching retained whole calls. Never alter an issued call by compaction. Dispatch at most the available window capacity, ordered by call sequence, and remove only those calls from the mutable buffer. There is no growing list of frozen batches.

**Atomic compaction.** The buffer has at most 20 character-context segments, including its initial context. A different explicit character/content opens a segment; identical content stays in the current one. Retain the whole original character-changing call as the segment anchor. The patch field manifest fixes the number F of top-level update fields. A call containing mood, character, theme/preset/roles, click actions or gesture is character-dependent: retain its whole original patch and sequence inside its segment, including any bubble, status, size, placement or motion fields supplied with it. Those fields must never become unconditional assignments detached from that call.

Within a character segment, separate calls by their unresolved validation guard: the canonical data-only set of target-sensitive checks (extra mood/gesture names, explicit preset, role names and click-action targets, plus other character-dependent prepare checks). Structural checks already passed; universally supported core moods/shared gestures need no unresolved membership guard. Identical guards in the same character context have the same validity outcome; different guards must never overwrite each other's candidates. Within each guard bucket, point each latest-field slot to the newest call that supplied it. Retain the union of calls owning at least one slot, plus the segment anchor; each retained call keeps its complete original patch, even fields superseded in the slots. Calls containing only character-independent fields use separate global latest-field slots and also retain their complete original patches. A whole call may be discarded as superseded unissued intent only after it owns no slot in its identical-guard bucket and is not a segment anchor. In particular a new, not-yet-validated guard cannot erase an earlier candidate: if preset A would be valid and later preset B invalid, A remains available. Guard equivalence must be conservative; its default key is the canonical complete character-dependent prepared values plus the segment context. Omit data only where the checker proves it cannot affect validity (for example the universally required core moods). A target-sensitive check that R can fully settle for a pinned explicit character needs no unresolved guard. Only R compacts these keys; the browser validates whole calls and computes no guard fingerprint. When equivalence cannot be proven, keep separate buckets. Superseded unvalidated calls have no acceptance outcome; this remains a latest-state buffer, not a promise to deliver every historical call. Already accepted checkpoint values are never discarded by this rule.

Proposed Q1 resource bound: at most 20 distinct unresolved guard buckets per character segment, yielding at most 20*(20*F+1)+F buffered whole calls plus 20 immutable issued calls, subject to existing payload/input bounds. This adds an explicit unresolved-guard bound rather than silently sacrificing atomicity; it is an implementation recommendation for review, not a founder-approved API exception. This bound counts field owners/character contexts, not ordinary calls: 100 or 1000 same-context status updates keep their newest value. Only exceeding the 20-character-segment or 20-unresolved-guard-per-segment bound causes a capacity rejection, atomically for the incoming call; invalid calls can still fail ordinary validation. A call known invalid to R is rejected before it overwrites a slot or opens a segment. Release empty guard buckets when no unissued call owns their slots; issued records keep their immutable guards independently. Release old segments once their anchors/calls are resolved and no unissued call needs their context. A segment anchor reference survives dispatch until its outcome is known.

At dispatch, validate and apply every retained original call in sequence order, all fields or none, against its actual character context. If a segment anchor is rejected, discard that segment's dependent unissued calls as unavailable-context calls, including their coupled independent fields; a later explicit character segment can still establish a valid context. A rejected mixed call drops every value it supplied. Across accepted calls and the checkpoint, the newest surviving sequence wins for each field. For example: standalone bubble "Earlier" at sequence 1, then {theme:"ocean",bubble:"Hi"} at sequence 2 with an unavailable preset leaves "Earlier"; "Hi" never becomes a standalone update. The same rule holds before mount, under window pressure and after remount. No empty/merged patch assembled from several calls receives a new acceptance outcome in place of their original atomic outcomes.

For a buffered startup/remount flush, intermediate character segments establish context without startup swap movement. Validate all retained gesture fields with their original calls; select only the newest accepted buffered gesture for one-shot play after final state establishes. Valid older buffered gestures are consumed as superseded; reduction/disabled-motion policy can consume without playing. No old gesture is revived by replay. U1 tests must cover both overwritten and still-owned fields in mixed calls, valid older candidates followed by an invalid different guard, repeated identical guards and atomic guard-capacity rejection; a structural-only or textual check is not runtime evidence.

**Ready/unmounted lifecycle.** Extend the existing private binding snapshot with lifecycle ready/unmounted. unsubscribe/unmount publishes an unmounted snapshot while the delivery ledger is still available, before DOM/controller teardown, and retains that ledger by id outside the DOM. The notice is best effort: a lost notice cannot lose subsequent updates, because window pressure also uses compaction. Ready on a newer mount requests reconciliation and dispatch of buffered calls when capacity is available. Unmounted is terminal for that mount generation; an older ready notice cannot make it live again. Late outcomes for the same old generation may resolve issued calls but cannot resurrect its liveness. A newer generation supersedes old lifecycle notices.

When no live mount is known, buffer rather than dispatch. When a window is full, buffer and request reconciliation; the browser returns the latest cumulative snapshot with forced event delivery even if unchanged. When acknowledgements/confirmations free capacity, drain retained calls in order. If a ready notice arrives while older issued calls are unresolved, reconcile those outcomes before issuing newer calls; never assume lost revisions were accepted, reset a window on timeout, or discard a rejected-outcome list to make room. U1 includes 100 updates while unmounted, lost unmount notice plus a full window, and duplicate/out-of-order lifecycle messages.

**Process-issued content tokens.** R lazily issues opaque tokens for checked character content from a private R-process issuer. It can run when mascot() constructs static UI with no reactive domain and takes no session argument. The issuer records checked content identity and reuses a token for identical content, including DOM/update envelopes; the browser only echoes tokens and computes no hash. On ready, R validates the token against the issuer's checked descriptor and the emitted UI/update binding for that instance, then records the session's baseline. No per-session content token must pre-exist for global UI to mount. Separately, mount_token identifies the emitted UI specification, including its initial argument values, rather than just character content. A static UI template retains its read-only specification without a session; a dynamically emitted specification belongs to its emitting session. R validates that instance/binding ownership before using the specification; recognising a character token alone is insufficient to obtain another session's UI defaults. Tokens are identifiers, not credentials or a way to register/read another visitor's character data; the character-token issuer is separate from the character catalogue/listings and stores no update queues, user status or bubbles. UI specification records stay with the static template or their emitting session, not the character catalogue. Session state remains isolated and is destroyed on disconnect. No files, network or side effects on package load; tokens expire with the issuing R process. U1 requires the actual R acceptance case ui=shiny::fluidPage(mascot("helper")) outside a domain, then two independent sessions mounting that UI.

**Cumulative delivery snapshot.** Its fields are {mount,mount_token,lifecycle,window_start,resolved_through,rejected,gesture_revision,derived_mood,content_token}. Counters are finite nonnegative integers, window_start positive, lifecycle is ready/unmounted, derived_mood a valid mood id and content_token an R-issued value. resolved_through means every issued revision from window_start through that value was processed in order. rejected is the complete sorted unique list of rejected revisions in that interval; all others were accepted. The interval/list each contain at most 20 revisions. gesture_revision is the highest consumed issued gesture revision, never a rejected one. mount_token identifies the currently rendered UI baseline; derived_mood/content_token describe the final processed delivery prefix, which may still belong to the previous DOM while a remount is being reconciled. Do not replace prefix metadata merely because a new UI specification mounted. First ready starts at window_start1/resolved_through0/rejected[]/gesture_revision0; later mounts retain the delivery watermarks.

The binding subscription callback publishes changed cumulative state; getValue returns the latest snapshot. Several changes in one tick may merge without losing an outcome: through 3/rejected[2] means accepted 1, rejected 2, accepted 3. R validates against the issued journal, folds only accepted original calls and removes entire rejected calls. Duplicate snapshots are idempotent; older prefixes cannot roll state back. Retain the latest 20 confirmed outcomes for duplicate consistency checks; older snapshots are ignored. Verify the echoed token against the final accepted target or validated mount baseline, not any unrelated token from the issuer. Unknown fields, unissued revisions, foreign bindings and inconsistent outcomes never advance the checkpoint.

R repeats confirm_through in subsequent envelopes or an explicit receipt. Until confirmation arrives, the browser retains every outcome in that window; only the confirmed prefix may be evicted. Reconcile/resend uses forced event delivery, so an unchanged snapshot/receipt can recover a lost notification. A new mount preserves the per-id ledger and gesture watermark within the connection. Restore persistent state separately from one-shot delivery; changing restore context uses fresh revisions rather than rewriting old outcomes. Private envelopes distinguish update from restore: an accepted public update owns its supplied fields; a restore carries the existing ownership mask and cannot promote UI defaults into server overrides. An explicit character payload binds its content token; a call without one uses the validated current replay/mount context, not an implicit character override inferred from an old token. This remains one private binding channel, with no new public Shiny input.

**Remount precedence.** Store whether each checkpoint field was explicitly owned by an accepted server update, including an empty-helper reset. Observing a ready snapshot does not turn UI defaults into server overrides. Also retain the previous effective character/mood as fallback context; that metadata alone does not own the character field.

| Group | Remount winner before buffered calls | Revalidation |
|---|---|---|
| Character | Last accepted explicit server character override; otherwise the newly rendered UI character. | A new UI token cannot erase a server-owned override. Later accepted buffered character calls can supersede it. |
| Mood | Server-owned explicit mood, or effective mood derived from an accepted server character change; otherwise the new UI mood. | Resolve against the winning character; unavailable retained mood follows the previous effective character's fallback chain, then idle if unavailable. Never reuse a stale explicit outgoing mood merely by field merge. |
| Theme | Last accepted server theme/reset; otherwise the new UI theme. | Re-resolve retained values for the winning character: missing retained preset drops with mascot_preset_dropped in development, keeping valid explicit overrides. A new explicit invalid preset still rejects its whole call. |
| Independent fields (bubble/status/size/placement/motion) | Last accepted server value/reset where owned; otherwise each new UI value. | Mood-derived status is recomputed from shown character/mood; literal status persists. No value from a rejected mixed call is retained. Accepted checkpoint adaptation is restore, not re-evaluation of a new call. |
| Click | Last accepted server click value/reset where owned; otherwise the new UI click value. | Recheck retained action targets for the winning character; clear an unavailable retained click group with a development diagnostic, keeping independent groups. A new invalid click update rejects its entire call. |
| Gesture | No checkpoint gesture is replayed. | Preserve consumed revisions across mounts; only a newly accepted buffered/live gesture may play under policy. |

Replay these winners, then surviving unresolved/buffered whole calls in sequence order. New mount metadata alone does not overwrite accepted server values or ownership. Tests must show both character outcomes: a cached explicit server alpha_visor overrides newly rendered Tessa; without a server character override, newly rendered alpha_visor wins over the previous UI Tessa. Also cover server theme reset versus a new UI theme, unavailable retained mood/preset, newer buffered overrides, rejected preset+bubble and isolated sessions.

U1 is blocked on independent approval of these B1-B4 corrections (Q1); I1 remains dependent on U1. Format/validator/engine/harness/builder/fixture work has separate core-contract approval and may proceed through its own prerequisites. The Python checker includes a bounded reference model for selected buffering/atomicity/precedence cases; it omits the complete guard compiler, anchor-failure recovery, token issuance and real lifecycle transport; it is not R/JS implementation or Shiny transport evidence.

### 3.17 Addressable accessories and later composition

An accessory definition has description, slot, anchor and parts (ordinary part templates with local ids/parents/layers/items), optional colours and lod. wear lists active accessory ids; two active items in one slot error. Instantiate template part ids under a stable prefix wear_<accessory>_<local_id>; collisions with character parts error. Root accessory parts inherit the selected anchor's matrix and visibility; internal parents use local ids, then are expanded. Shapes/colours resolve to character roles. Channels may address expanded part ids, making bow follow-through possible later. Template layer values are absolute draw layers, independent of parenting; all expansions count towards budgets.

An anchor asking for a missing part/variant is an error. A structurally present anchor whose owner is hidden/collapsed is unavailable for painting that frame, and its attached subtree/effects are hidden too. No fallback to origin. This simple attachment contract does not provide fitting: shared wardrobe surfaces, arbitrary limb substitution and automatic adaptation remain later work.

Cross-family remix is an authoring operation, not renderer inheritance. A component declares required anchors, roles, parts and capabilities. A user can add an anchor on a real part, map roles/targets explicitly, and choose one final family. Mixing family ids itself proves no compatibility. Produce a new complete checked character; retain no donor lookup chain. Full remix export/promotion may wait; prototype only bounded cases on a development branch.

### 3.18 Version/capability compatibility

Supported capabilities in0.1.0: parts, paints, clip, outline, glow, face_kit, tracks, lod. requires is mandatory and contains every capability used after family/kit/accessory resolution; a superset of known capabilities is permitted. Builder/read-resolve tooling computes it, but the checker does not silently fix a submitted file. Missing/unknown/unsupported names error. Ordinary basic shapes require parts. Faces require face_kit; kit emissive glow additionally requires glow. Every file's format_version is1; later additive capabilities can extend1 only without changing existing field meanings.

Reserved unsupported fields/capabilities: extends, connector, ring_pulse, follow, particles, morph, blend, inputs, fit, wardrobe, vividness. Report "not supported by this version of mascot" and a stable capability code; name a minimum package version only if an actual support table provides it. Do not invent 0.1.1 or promise format2. Paper contracts: connector links two existing world anchors, clamps inset to half nonzero length and draws nothing at coincident endpoints; typed numeric inputs require finite type/range/default and explicit channel mapping. Their namespaces/composition rules still need later review; reservation alone is not proof of future compatibility. Neither is an accepted v1 runtime example.


### 3.19 Tessa face migration acceptance

Compare with main ace06f5, not an imagined pixel-identical rewrite. These are intended data/grammar outcomes, pending rendering:

| Feature | Intended result / remaining difference |
|---|---|
| Slanted brows | Preserve right-eye worried/sad inner end higher; determined/angry/frown lower, mirrored left. Width5 except neutral3.5; default none and happy hides brows. Numeric slope assertions required. |
| Eye white/lid edge | Preserve feature2.5 outline, outline-role2.2 lid edge, face caps, shared inset clip and 1.2-radius lid construction. |
| Pupils/glints | Preserve worried pupil y=-2 and face-aligned two highlights on both eyes; gaze remains aligned after reflection. |
| Lashes | Preserve radial-ray placement, three ellipse lashes and two happy/closed lashes with independent15x6/15x3 radii. |
| Blush | Preserve resting blush, named normal/strong roles and0.45/0.55 alpha. |
| Mouths | Preserve face-unit stroke3.5, positions, proud detail2.5, flat/grit/o/teeth geometry (grit/determined use miter joins); smile and grin circular arcs become explicit cubic approximations, an intentional near-look difference requiring approval. Box is half-size20x20. |
| Sweat/sparkle | Preserve outlined/shine sweat and four-tip, eight-vertex radius10/3.2 sparkle (the old source is not an eight-tip star). |
| Blink | Intentional: the closed style wins at blink>=0.96 even for happy; today's happy branch bypasses blink. |
| Wide-eye brow height | Current proposal uses the common brow origin; any difference from today's wide-only offset requires explicit near-look approval. No silent claim of full style equivalence. |

T1 captures these details at160/96/24 in both modes. Structural checks cannot approve facial expression or claim all expanded budgets pass.

## 4. Complete design examples

These JSON examples contain no comments and can be copied intact. They are complete proposals against this document, not evidence of a successful validator/render run. The classic/screen kit data is shown separately as the shipped-kit contract; the complete character examples refer to those known kits. Family data is embedded and resolved to avoid hidden defaults. Full all-pick fixture creation remains an implementation acceptance task.

### 4.1 Complete classic kit

```json
{
  "id": "classic",
  "description": "Painted expressive eyes, brows and mouths.",
  "roles": [
    "feature",
    "eye_white",
    "shine",
    "eyelid",
    "teeth",
    "tongue",
    "sweat",
    "sparkle",
    "sparkle_outline",
    "outline",
    "blush",
    "blush_strong"
  ],
  "defaults": {
    "eyes": "open",
    "mouth": "smile",
    "brows": "none",
    "blush": 1
  },
  "eye_styles": {
    "open": {
      "op": "eye_ellipse",
      "rx": 16.5,
      "ry": 19.5,
      "pupil": {
        "r": 10,
        "look_range": [
          7,
          7
        ],
        "glints": [
          {
            "at": [
              0.35,
              -0.35
            ],
            "r": 0.4
          },
          {
            "at": [
              -0.35,
              0.35
            ],
            "r": 0.22
          }
        ],
        "at": [
          0,
          0
        ],
        "mirror_glints": false
      },
      "lid": 0,
      "slant": 0,
      "lashes": {
        "angles": [
          -0.3490658503988659,
          -0.7853981633974483,
          -1.2217304763960306
        ],
        "length": 7,
        "width": 3
      },
      "outline": {
        "colour": "feature",
        "width": 2.5
      },
      "lid_edge": {
        "colour": "outline",
        "width": 2.2
      }
    },
    "wide": {
      "op": "eye_ellipse",
      "rx": 19,
      "ry": 24,
      "pupil": {
        "r": 7.5,
        "look_range": [
          7,
          7
        ],
        "glints": [
          {
            "at": [
              0.35,
              -0.35
            ],
            "r": 0.4
          },
          {
            "at": [
              -0.35,
              0.35
            ],
            "r": 0.22
          }
        ],
        "at": [
          0,
          0
        ],
        "mirror_glints": false
      },
      "lid": 0,
      "slant": 0,
      "lashes": {
        "angles": [
          -0.3490658503988659,
          -0.7853981633974483,
          -1.2217304763960306
        ],
        "length": 7,
        "width": 3
      },
      "outline": {
        "colour": "feature",
        "width": 2.5
      },
      "lid_edge": {
        "colour": "outline",
        "width": 2.2
      }
    },
    "worried": {
      "op": "eye_ellipse",
      "rx": 16.5,
      "ry": 21,
      "pupil": {
        "r": 8.5,
        "look_range": [
          7,
          7
        ],
        "glints": [
          {
            "at": [
              0.35,
              -0.35
            ],
            "r": 0.4
          },
          {
            "at": [
              -0.35,
              0.35
            ],
            "r": 0.22
          }
        ],
        "at": [
          0,
          -2
        ],
        "mirror_glints": false
      },
      "lid": 0,
      "slant": 0,
      "lashes": {
        "angles": [
          -0.3490658503988659,
          -0.7853981633974483,
          -1.2217304763960306
        ],
        "length": 7,
        "width": 3
      },
      "outline": {
        "colour": "feature",
        "width": 2.5
      },
      "lid_edge": {
        "colour": "outline",
        "width": 2.2
      }
    },
    "focused": {
      "op": "eye_ellipse",
      "rx": 16.5,
      "ry": 19.5,
      "pupil": {
        "r": 10,
        "look_range": [
          7,
          7
        ],
        "glints": [
          {
            "at": [
              0.35,
              -0.35
            ],
            "r": 0.4
          },
          {
            "at": [
              -0.35,
              0.35
            ],
            "r": 0.22
          }
        ],
        "at": [
          0,
          0
        ],
        "mirror_glints": false
      },
      "lid": 0.42,
      "slant": 3,
      "lashes": {
        "angles": [
          -0.3490658503988659,
          -0.7853981633974483,
          -1.2217304763960306
        ],
        "length": 7,
        "width": 3
      },
      "outline": {
        "colour": "feature",
        "width": 2.5
      },
      "lid_edge": {
        "colour": "outline",
        "width": 2.2
      }
    },
    "happy": {
      "op": "eye_arc",
      "r": 15,
      "start": 3.6128315516282616,
      "end": 5.811946409141117,
      "y": 2,
      "width": 5.5,
      "lashes": {
        "angles": [
          -0.5585053606381855,
          -1.0821041362364843
        ],
        "radii": [
          15,
          6
        ],
        "at": [
          0,
          9
        ],
        "length": 7,
        "width": 3
      },
      "hide_brows": true
    },
    "closed": {
      "op": "eye_arc",
      "r": 14,
      "start": 0.5654866776461628,
      "end": 2.57610597594363,
      "y": -6,
      "width": 5,
      "lashes": {
        "angles": [
          -0.5585053606381855,
          -1.0821041362364843
        ],
        "radii": [
          15,
          3
        ],
        "at": [
          0,
          2
        ],
        "length": 7,
        "width": 3
      }
    }
  },
  "brow_styles": {
    "none": {
      "op": "brow_path",
      "d": "M0 0",
      "width": 0,
      "stroke": "feature",
      "y": -25
    },
    "neutral": {
      "op": "brow_path",
      "d": "M-14 6 Q0 1 14 6",
      "width": 3.5,
      "stroke": "feature",
      "y": -25
    },
    "raised": {
      "op": "brow_path",
      "d": "M-15 5 Q0 -6 15 5",
      "width": 5,
      "stroke": "feature",
      "y": -25
    },
    "determined": {
      "op": "brow_path",
      "d": "M-16 10 L18 2",
      "width": 5,
      "stroke": "feature",
      "y": -25
    },
    "angry": {
      "op": "brow_path",
      "d": "M-16 10 L18 2",
      "width": 5,
      "stroke": "feature",
      "y": -25
    },
    "frown": {
      "op": "brow_path",
      "d": "M-16 10 L18 2",
      "width": 5,
      "stroke": "feature",
      "y": -25
    },
    "worried": {
      "op": "brow_path",
      "d": "M-16 2 L18 10",
      "width": 5,
      "stroke": "feature",
      "y": -25
    },
    "sad": {
      "op": "brow_path",
      "d": "M-16 2 L18 10",
      "width": 5,
      "stroke": "feature",
      "y": -25
    }
  },
  "mouth_styles": {
    "smile": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M0.5791542407 0.2950938248 C0.4681874861 0.5128783433 0.2444252792 0.65 3.980102097e-17 0.65 C-0.2444252792 0.65 -0.4681874861 0.5128783433 -0.5791542407 0.2950938248",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "round"
        }
      ]
    },
    "smirk": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-0.4 0.1 Q0 0.45 0.45 0",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "round"
        }
      ]
    },
    "proud": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-0.7 0.15 Q0 0.75 0.75 -0.05",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "round"
        },
        {
          "shape": "path",
          "d": "M0.8 -0.3 L0.9 -0.05",
          "stroke": "feature",
          "width": 2.5,
          "cap": "round",
          "join": "round"
        }
      ]
    },
    "flat": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-0.55 0.4 L0.55 0.4",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "round"
        }
      ]
    },
    "grit": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-0.7 0.15 L-0.25 0 L0.25 0.2 L0.7 0.05",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "miter"
        }
      ]
    },
    "o": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "ellipse",
          "x": 0,
          "y": 0.25,
          "rx": 0.5,
          "ry": 0.75,
          "fill": "feature"
        },
        {
          "shape": "ellipse",
          "x": 0,
          "y": 0.65,
          "rx": 0.35,
          "ry": 0.25,
          "fill": "tongue"
        }
      ]
    },
    "grin": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M0.8 0 C0.8 0.4418277999 0.4418277999 0.8 4.898587197e-17 0.8 C-0.4418277999 0.8 -0.8 0.4418277999 -0.8 9.797174393e-17 Z",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "round",
          "fill": "feature"
        },
        {
          "shape": "path",
          "d": "M-0.65 0 L0.65 0 L0.65 0.3 L-0.65 0.3 Z",
          "fill": "teeth"
        }
      ]
    },
    "determined": {
      "op": "mouth_path",
      "box": [
        20,
        20
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-0.7 0.15 L-0.25 0 L0.25 0.2 L0.7 0.05",
          "stroke": "feature",
          "width": 3.5,
          "cap": "round",
          "join": "miter"
        }
      ]
    }
  },
  "effects": {
    "sweat": {
      "op": "sweat_drop",
      "at": [
        0,
        0
      ],
      "items": [
        {
          "shape": "path",
          "d": "M0 -11 C8 -4 9 6 0 10 C-9 6 -8 -4 0 -11 Z",
          "fill": "sweat",
          "stroke": "feature",
          "width": 1.5
        },
        {
          "shape": "circle",
          "x": 2.5,
          "y": 2.5,
          "r": 2.2,
          "fill": "shine"
        }
      ],
      "mode": "progress",
      "travel": 26,
      "sway": 2,
      "sway_rate": 12,
      "fade_at": 0.9
    },
    "sparkle": {
      "op": "sparkle_star",
      "at": [
        0,
        0
      ],
      "items": [
        {
          "shape": "path",
          "d": "M6.123234e-16 -10 L2.2627417 -2.2627417 L10 0 L2.2627417 2.2627417 L6.123234e-16 10 L-2.2627417 2.2627417 L-10 1.2246468e-15 L-2.2627417 -2.2627417 Z",
          "fill": "sparkle",
          "stroke": "sparkle_outline",
          "width": 1.6
        }
      ],
      "reduced_items": [
        {
          "shape": "path",
          "d": "M6.123234e-16 -10 L2.2627417 -2.2627417 L10 0 L2.2627417 2.2627417 L6.123234e-16 10 L-2.2627417 2.2627417 L-10 1.2246468e-15 L-2.2627417 -2.2627417 Z",
          "fill": "sparkle",
          "stroke": "sparkle_outline",
          "width": 1.6
        }
      ],
      "mode": "pulse",
      "amplitude": 0.18,
      "rate": 9
    }
  }
}
```

### 4.2 Complete screen kit

```json
{
  "id": "screen",
  "description": "Static screen glyphs with budgeted emission.",
  "roles": [
    "feature",
    "sweat",
    "sparkle",
    "sparkle_outline"
  ],
  "defaults": {
    "eyes": "dot",
    "mouth": "smile",
    "brows": "none"
  },
  "glow": {
    "blur": 3,
    "alpha": 0.4
  },
  "eye_styles": {
    "dot": {
      "op": "eye_dots",
      "centres": [
        [
          0,
          0
        ]
      ],
      "r": 6
    },
    "scan": {
      "op": "eye_dots",
      "centres": [
        [
          -3,
          0
        ],
        [
          3,
          0
        ]
      ],
      "r": 3
    },
    "arc": {
      "op": "eye_arc",
      "r": 8,
      "start": 3.3,
      "end": 6.1,
      "width": 3
    },
    "slant": {
      "op": "eye_path",
      "d": "M-7 1 L5 -3",
      "stroke": "feature",
      "width": 3
    },
    "star": {
      "op": "eye_path",
      "d": "M0 -8 L2 -2 L8 0 L2 2 L0 8 L-2 2 L-8 0 L-2 -2 Z",
      "fill": "feature"
    },
    "dots": {
      "op": "eye_dots",
      "centres": [
        [
          -5,
          0
        ],
        [
          5,
          0
        ]
      ],
      "r": 3
    },
    "closed": {
      "op": "eye_path",
      "d": "M-7 0 L7 0",
      "stroke": "feature",
      "width": 3
    }
  },
  "brow_styles": {
    "none": {
      "op": "brow_path",
      "d": "M0 0",
      "width": 0,
      "stroke": "feature"
    }
  },
  "mouth_styles": {
    "smile": {
      "op": "mouth_path",
      "box": [
        10,
        6
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-1 0 Q0 1 1 0",
          "stroke": "feature",
          "width": 2.5
        }
      ]
    },
    "flat": {
      "op": "mouth_path",
      "box": [
        10,
        6
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-1 0 L1 0",
          "stroke": "feature",
          "width": 2.5
        }
      ]
    },
    "wide": {
      "op": "mouth_path",
      "box": [
        10,
        6
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-1 -0.2 Q0 1.5 1 -0.2 Z",
          "fill": "feature",
          "stroke": "feature",
          "width": 2.5
        }
      ]
    },
    "wavy": {
      "op": "mouth_path",
      "box": [
        10,
        6
      ],
      "items": [
        {
          "shape": "path",
          "d": "M-1 0 Q-0.5 -0.8 0 0 Q0.5 0.8 1 0",
          "stroke": "feature",
          "width": 2.5
        }
      ]
    }
  },
  "effects": {
    "sweat": {
      "op": "sweat_drop",
      "at": [
        0,
        0
      ],
      "items": [
        {
          "shape": "path",
          "d": "M0 -8 Q9 2 0 10 Q-9 2 0 -8 Z",
          "fill": "sweat"
        }
      ],
      "mode": "progress",
      "travel": 26,
      "sway": 2,
      "sway_rate": 12,
      "fade_at": 0.9
    },
    "sparkle": {
      "op": "sparkle_star",
      "at": [
        0,
        0
      ],
      "items": [
        {
          "shape": "path",
          "d": "M0 -7 L2 -2 L7 0 L2 2 L0 7 L-2 2 L-7 0 L-2 -2 Z",
          "fill": "sparkle",
          "stroke": "sparkle_outline",
          "width": 1
        }
      ],
      "reduced_items": [
        {
          "shape": "path",
          "d": "M0 -7 L2 -2 L7 0 L2 2 L0 7 L-2 2 L-7 0 L-2 -2 Z",
          "fill": "sparkle",
          "stroke": "sparkle_outline",
          "width": 1
        }
      ],
      "mode": "pulse",
      "amplitude": 0.18,
      "rate": 9
    }
  }
}
```

### 4.3 Complete Tessa migration

This migration keeps original colours, the default wiggle, bow/clip, arm presets and foot tuck threshold. It adds no paints or undeclared paint references. It deliberately uses the new classic kit with near-looking face acceptance, not an exact old/new pixel claim. Micro explicitly hides the worn bow, disables lashes/brows/iris and retains body/limb geometry; these proposed simplifications keep the operation expansion bounded and require small-size visual approval. Full-size migration retains those details. Variant foot anchors use the rotated sole, including under flip/squash. Existing rest/gesture timing is preserved; faces need visual approval.

```json
{
  "format_version": 1,
  "id": "tessa",
  "name": "Tessa",
  "family": "hexonians",
  "description": "A calm green-and-gold hexagonal maker.",
  "resolved": true,
  "family_definition": {
    "id": "hexonians",
    "name": "Hexonians",
    "description": "Hex-shaped characters.",
    "defaults": {}
  },
  "requires": [
    "parts",
    "outline",
    "face_kit",
    "tracks",
    "lod"
  ],
  "colours": {
    "outline": "#26312b",
    "feature": "#16201b",
    "eye_white": "#f5f6f4",
    "shine": "#f5f6f4",
    "teeth": "#f5f6f4",
    "eyelid": "#3f8a66",
    "tongue": "#a33a30",
    "body": "#3f8a66",
    "body_highlight": "#7fcba4",
    "rim": "#d9b35c",
    "limb": "#d9b35c",
    "sleeve": "#3f8a66",
    "blush": "#7fcba4",
    "blush_strong": "#d9b35c",
    "accessory": "#d9b35c",
    "accessory_detail": "#7a5a12",
    "sparkle": "#f5f6f4",
    "sparkle_outline": "#d9b35c",
    "sweat": "#9dc3e6",
    "shadow": "#a2aea7"
  },
  "follows": {
    "sleeve": {
      "from": [
        "body"
      ]
    },
    "eyelid": {
      "from": [
        "body"
      ]
    },
    "body_highlight": {
      "from": [
        "body"
      ],
      "shade": "lighter",
      "amount": 0.2529,
      "saturation": 0.0491
    },
    "blush": {
      "from": [
        "body"
      ],
      "shade": "lighter",
      "amount": 0.2529,
      "saturation": 0.0491
    },
    "limb": {
      "from": [
        "rim",
        "body"
      ]
    },
    "blush_strong": {
      "from": [
        "rim",
        "body"
      ]
    },
    "sparkle_outline": {
      "from": [
        "rim",
        "body"
      ]
    },
    "accessory": {
      "from": [
        "rim"
      ]
    },
    "accessory_detail": {
      "from": [
        "accessory"
      ],
      "shade": "darker",
      "amount": -0.3314,
      "saturation": 0.121
    }
  },
  "brand": {
    "primary": "body",
    "secondary": "rim"
  },
  "contrast": [
    {
      "fg": "feature",
      "bg": "body",
      "min": 3,
      "where": "small face details"
    }
  ],
  "ground": {
    "centre_height": 104,
    "shadow": {
      "rx": 62,
      "ry": 9,
      "alpha": 0.32,
      "colour": "shadow"
    }
  },
  "outline": {
    "width": 3,
    "colour": "outline",
    "join": "miter",
    "cap": "butt"
  },
  "parts": [
    {
      "id": "body",
      "at": [
        0,
        -104
      ],
      "layer": 20,
      "items": [
        {
          "shape": "hexagon",
          "r": 92,
          "corner": 12,
          "fill": "rim",
          "stroke": "outline",
          "width": 3
        },
        {
          "shape": "hexagon",
          "r": 81,
          "corner": 8,
          "fill": "body"
        },
        {
          "shape": "path",
          "d": "M0 -81 L26 -65 L-26 -65 Z",
          "fill": "body_highlight",
          "alpha": 0.35
        }
      ]
    },
    {
      "id": "foot_l",
      "parent": "body",
      "at": [
        -23,
        0
      ],
      "layer": 10,
      "switch": {
        "channel": "root.lift",
        "above": 6,
        "variant": "tuck"
      },
      "items": [
        {
          "x": -15,
          "y": 88,
          "w": 30,
          "h": 16,
          "r": [
            6,
            6,
            8,
            8
          ],
          "shape": "round_rect",
          "fill": "limb",
          "stroke": "outline",
          "width": 2.5,
          "cap": "butt",
          "join": "miter"
        }
      ],
      "variants": {
        "tuck": [
          {
            "x": -12,
            "y": -6,
            "w": 24,
            "h": 14,
            "r": 7,
            "shape": "round_rect",
            "fill": "limb",
            "stroke": "outline",
            "width": 2.5,
            "cap": "butt",
            "join": "miter",
            "transform": [
              -1,
              78,
              0.25
            ]
          }
        ]
      }
    },
    {
      "id": "arm_l",
      "parent": "body",
      "at": [
        -69.67433714816835,
        8
      ],
      "rotate": 1.85,
      "layer": 60,
      "items": [
        {
          "shape": "round_rect",
          "x": 0,
          "y": -7.5,
          "w": 42,
          "h": 15,
          "r": 7.5,
          "fill": "sleeve",
          "stroke": "outline",
          "width": 2.5
        },
        {
          "shape": "circle",
          "x": 39,
          "y": 0,
          "r": 6.75,
          "fill": "limb",
          "stroke": "outline",
          "width": 2.5
        }
      ]
    },
    {
      "id": "foot_r",
      "parent": "body",
      "at": [
        23,
        0
      ],
      "layer": 10,
      "switch": {
        "channel": "root.lift",
        "above": 6,
        "variant": "tuck"
      },
      "items": [
        {
          "x": -15,
          "y": 88,
          "w": 30,
          "h": 16,
          "r": [
            6,
            6,
            8,
            8
          ],
          "shape": "round_rect",
          "fill": "limb",
          "stroke": "outline",
          "width": 2.5,
          "cap": "butt",
          "join": "miter"
        }
      ],
      "variants": {
        "tuck": [
          {
            "x": -12,
            "y": -6,
            "w": 24,
            "h": 14,
            "r": 7,
            "shape": "round_rect",
            "fill": "limb",
            "stroke": "outline",
            "width": 2.5,
            "cap": "butt",
            "join": "miter",
            "transform": [
              1,
              78,
              -0.25
            ]
          }
        ]
      }
    },
    {
      "id": "arm_r",
      "parent": "body",
      "at": [
        69.67433714816835,
        8
      ],
      "rotate": 1.25,
      "layer": 60,
      "items": [
        {
          "shape": "round_rect",
          "x": 0,
          "y": -7.5,
          "w": 42,
          "h": 15,
          "r": 7.5,
          "fill": "sleeve",
          "stroke": "outline",
          "width": 2.5
        },
        {
          "shape": "circle",
          "x": 39,
          "y": 0,
          "r": 6.75,
          "fill": "limb",
          "stroke": "outline",
          "width": 2.5
        }
      ]
    }
  ],
  "anchors": {
    "foot_l": {
      "part": "foot_l",
      "at": [
        0,
        104
      ],
      "description": "Sole attachment point.",
      "side": "l",
      "variants": {
        "tuck": {
          "at": [
            -2.9792316740361837,
            85.75129937368516
          ],
          "rotate": 0.25
        }
      }
    },
    "hand_l": {
      "part": "arm_l",
      "at": [
        39,
        0
      ],
      "side": "l",
      "description": "Moving hand attachment."
    },
    "foot_r": {
      "part": "foot_r",
      "at": [
        0,
        104
      ],
      "description": "Sole attachment point.",
      "side": "r",
      "variants": {
        "tuck": {
          "at": [
            2.9792316740361837,
            85.75129937368516
          ],
          "rotate": -0.25
        }
      }
    },
    "hand_r": {
      "part": "arm_r",
      "at": [
        39,
        0
      ],
      "side": "r",
      "description": "Moving hand attachment."
    },
    "face": {
      "part": "body",
      "at": [
        0,
        0
      ],
      "description": "face attachment.",
      "scale": 1
    },
    "sparkle": {
      "part": "body",
      "at": [
        56,
        -33
      ],
      "description": "sparkle attachment."
    },
    "sweat": {
      "part": "body",
      "at": [
        58,
        -46
      ],
      "description": "sweat attachment."
    },
    "hair": {
      "part": "body",
      "at": [
        -47,
        -54
      ],
      "description": "hair attachment.",
      "rotate": -0.5,
      "scale": 1.2
    },
    "waist": {
      "part": "body",
      "at": [
        0,
        60
      ],
      "description": "waist attachment."
    },
    "crown": {
      "part": "body",
      "at": [
        0,
        -92
      ],
      "description": "crown attachment."
    },
    "forehead": {
      "part": "body",
      "at": [
        0,
        -40
      ],
      "description": "forehead attachment."
    },
    "eyes": {
      "part": "body",
      "at": [
        0,
        -12
      ],
      "description": "eyes attachment."
    },
    "upper_lip": {
      "part": "body",
      "at": [
        0,
        24
      ],
      "description": "upper_lip attachment."
    },
    "chin": {
      "part": "body",
      "at": [
        0,
        65
      ],
      "description": "chin attachment."
    },
    "neck": {
      "part": "body",
      "at": [
        0,
        75
      ],
      "description": "neck attachment."
    },
    "chest": {
      "part": "body",
      "at": [
        0,
        30
      ],
      "description": "chest attachment."
    },
    "back": {
      "part": "body",
      "at": [
        0,
        0
      ],
      "description": "back attachment."
    }
  },
  "face": {
    "part": "body",
    "kit": "classic",
    "at": [
      0,
      0
    ],
    "eyes": {
      "y": -12,
      "spacing": 30,
      "lashes": true,
      "iris": null
    },
    "mouth": {
      "y": 24
    },
    "caps": {
      "left": "butt",
      "right": "round",
      "join": "miter"
    },
    "blush": {
      "x": 36,
      "y": 18,
      "rx": 13,
      "ry": 7,
      "alpha": 0.45,
      "strong_alpha": 0.55
    },
    "kit_definition": {
      "id": "classic",
      "description": "Painted expressive eyes, brows and mouths.",
      "roles": [
        "feature",
        "eye_white",
        "shine",
        "eyelid",
        "teeth",
        "tongue",
        "sweat",
        "sparkle",
        "sparkle_outline",
        "outline",
        "blush",
        "blush_strong"
      ],
      "defaults": {
        "eyes": "open",
        "mouth": "smile",
        "brows": "none",
        "blush": 1
      },
      "eye_styles": {
        "open": {
          "op": "eye_ellipse",
          "rx": 16.5,
          "ry": 19.5,
          "pupil": {
            "r": 10,
            "look_range": [
              7,
              7
            ],
            "glints": [
              {
                "at": [
                  0.35,
                  -0.35
                ],
                "r": 0.4
              },
              {
                "at": [
                  -0.35,
                  0.35
                ],
                "r": 0.22
              }
            ],
            "at": [
              0,
              0
            ],
            "mirror_glints": false
          },
          "lid": 0,
          "slant": 0,
          "lashes": {
            "angles": [
              -0.3490658503988659,
              -0.7853981633974483,
              -1.2217304763960306
            ],
            "length": 7,
            "width": 3
          },
          "outline": {
            "colour": "feature",
            "width": 2.5
          },
          "lid_edge": {
            "colour": "outline",
            "width": 2.2
          }
        },
        "wide": {
          "op": "eye_ellipse",
          "rx": 19,
          "ry": 24,
          "pupil": {
            "r": 7.5,
            "look_range": [
              7,
              7
            ],
            "glints": [
              {
                "at": [
                  0.35,
                  -0.35
                ],
                "r": 0.4
              },
              {
                "at": [
                  -0.35,
                  0.35
                ],
                "r": 0.22
              }
            ],
            "at": [
              0,
              0
            ],
            "mirror_glints": false
          },
          "lid": 0,
          "slant": 0,
          "lashes": {
            "angles": [
              -0.3490658503988659,
              -0.7853981633974483,
              -1.2217304763960306
            ],
            "length": 7,
            "width": 3
          },
          "outline": {
            "colour": "feature",
            "width": 2.5
          },
          "lid_edge": {
            "colour": "outline",
            "width": 2.2
          }
        },
        "worried": {
          "op": "eye_ellipse",
          "rx": 16.5,
          "ry": 21,
          "pupil": {
            "r": 8.5,
            "look_range": [
              7,
              7
            ],
            "glints": [
              {
                "at": [
                  0.35,
                  -0.35
                ],
                "r": 0.4
              },
              {
                "at": [
                  -0.35,
                  0.35
                ],
                "r": 0.22
              }
            ],
            "at": [
              0,
              -2
            ],
            "mirror_glints": false
          },
          "lid": 0,
          "slant": 0,
          "lashes": {
            "angles": [
              -0.3490658503988659,
              -0.7853981633974483,
              -1.2217304763960306
            ],
            "length": 7,
            "width": 3
          },
          "outline": {
            "colour": "feature",
            "width": 2.5
          },
          "lid_edge": {
            "colour": "outline",
            "width": 2.2
          }
        },
        "focused": {
          "op": "eye_ellipse",
          "rx": 16.5,
          "ry": 19.5,
          "pupil": {
            "r": 10,
            "look_range": [
              7,
              7
            ],
            "glints": [
              {
                "at": [
                  0.35,
                  -0.35
                ],
                "r": 0.4
              },
              {
                "at": [
                  -0.35,
                  0.35
                ],
                "r": 0.22
              }
            ],
            "at": [
              0,
              0
            ],
            "mirror_glints": false
          },
          "lid": 0.42,
          "slant": 3,
          "lashes": {
            "angles": [
              -0.3490658503988659,
              -0.7853981633974483,
              -1.2217304763960306
            ],
            "length": 7,
            "width": 3
          },
          "outline": {
            "colour": "feature",
            "width": 2.5
          },
          "lid_edge": {
            "colour": "outline",
            "width": 2.2
          }
        },
        "happy": {
          "op": "eye_arc",
          "r": 15,
          "start": 3.6128315516282616,
          "end": 5.811946409141117,
          "y": 2,
          "width": 5.5,
          "lashes": {
            "angles": [
              -0.5585053606381855,
              -1.0821041362364843
            ],
            "radii": [
              15,
              6
            ],
            "at": [
              0,
              9
            ],
            "length": 7,
            "width": 3
          },
          "hide_brows": true
        },
        "closed": {
          "op": "eye_arc",
          "r": 14,
          "start": 0.5654866776461628,
          "end": 2.57610597594363,
          "y": -6,
          "width": 5,
          "lashes": {
            "angles": [
              -0.5585053606381855,
              -1.0821041362364843
            ],
            "radii": [
              15,
              3
            ],
            "at": [
              0,
              2
            ],
            "length": 7,
            "width": 3
          }
        }
      },
      "brow_styles": {
        "none": {
          "op": "brow_path",
          "d": "M0 0",
          "width": 0,
          "stroke": "feature",
          "y": -25
        },
        "neutral": {
          "op": "brow_path",
          "d": "M-14 6 Q0 1 14 6",
          "width": 3.5,
          "stroke": "feature",
          "y": -25
        },
        "raised": {
          "op": "brow_path",
          "d": "M-15 5 Q0 -6 15 5",
          "width": 5,
          "stroke": "feature",
          "y": -25
        },
        "determined": {
          "op": "brow_path",
          "d": "M-16 10 L18 2",
          "width": 5,
          "stroke": "feature",
          "y": -25
        },
        "angry": {
          "op": "brow_path",
          "d": "M-16 10 L18 2",
          "width": 5,
          "stroke": "feature",
          "y": -25
        },
        "frown": {
          "op": "brow_path",
          "d": "M-16 10 L18 2",
          "width": 5,
          "stroke": "feature",
          "y": -25
        },
        "worried": {
          "op": "brow_path",
          "d": "M-16 2 L18 10",
          "width": 5,
          "stroke": "feature",
          "y": -25
        },
        "sad": {
          "op": "brow_path",
          "d": "M-16 2 L18 10",
          "width": 5,
          "stroke": "feature",
          "y": -25
        }
      },
      "mouth_styles": {
        "smile": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M0.5791542407 0.2950938248 C0.4681874861 0.5128783433 0.2444252792 0.65 3.980102097e-17 0.65 C-0.2444252792 0.65 -0.4681874861 0.5128783433 -0.5791542407 0.2950938248",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "round"
            }
          ]
        },
        "smirk": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-0.4 0.1 Q0 0.45 0.45 0",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "round"
            }
          ]
        },
        "proud": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-0.7 0.15 Q0 0.75 0.75 -0.05",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "round"
            },
            {
              "shape": "path",
              "d": "M0.8 -0.3 L0.9 -0.05",
              "stroke": "feature",
              "width": 2.5,
              "cap": "round",
              "join": "round"
            }
          ]
        },
        "flat": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-0.55 0.4 L0.55 0.4",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "round"
            }
          ]
        },
        "grit": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-0.7 0.15 L-0.25 0 L0.25 0.2 L0.7 0.05",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "miter"
            }
          ]
        },
        "o": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "ellipse",
              "x": 0,
              "y": 0.25,
              "rx": 0.5,
              "ry": 0.75,
              "fill": "feature"
            },
            {
              "shape": "ellipse",
              "x": 0,
              "y": 0.65,
              "rx": 0.35,
              "ry": 0.25,
              "fill": "tongue"
            }
          ]
        },
        "grin": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M0.8 0 C0.8 0.4418277999 0.4418277999 0.8 4.898587197e-17 0.8 C-0.4418277999 0.8 -0.8 0.4418277999 -0.8 9.797174393e-17 Z",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "round",
              "fill": "feature"
            },
            {
              "shape": "path",
              "d": "M-0.65 0 L0.65 0 L0.65 0.3 L-0.65 0.3 Z",
              "fill": "teeth"
            }
          ]
        },
        "determined": {
          "op": "mouth_path",
          "box": [
            20,
            20
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-0.7 0.15 L-0.25 0 L0.25 0.2 L0.7 0.05",
              "stroke": "feature",
              "width": 3.5,
              "cap": "round",
              "join": "miter"
            }
          ]
        }
      },
      "effects": {
        "sweat": {
          "op": "sweat_drop",
          "at": [
            0,
            0
          ],
          "items": [
            {
              "shape": "path",
              "d": "M0 -11 C8 -4 9 6 0 10 C-9 6 -8 -4 0 -11 Z",
              "fill": "sweat",
              "stroke": "feature",
              "width": 1.5
            },
            {
              "shape": "circle",
              "x": 2.5,
              "y": 2.5,
              "r": 2.2,
              "fill": "shine"
            }
          ],
          "mode": "progress",
          "travel": 26,
          "sway": 2,
          "sway_rate": 12,
          "fade_at": 0.9
        },
        "sparkle": {
          "op": "sparkle_star",
          "at": [
            0,
            0
          ],
          "items": [
            {
              "shape": "path",
              "d": "M6.123234e-16 -10 L2.2627417 -2.2627417 L10 0 L2.2627417 2.2627417 L6.123234e-16 10 L-2.2627417 2.2627417 L-10 1.2246468e-15 L-2.2627417 -2.2627417 Z",
              "fill": "sparkle",
              "stroke": "sparkle_outline",
              "width": 1.6
            }
          ],
          "reduced_items": [
            {
              "shape": "path",
              "d": "M6.123234e-16 -10 L2.2627417 -2.2627417 L10 0 L2.2627417 2.2627417 L6.123234e-16 10 L-2.2627417 2.2627417 L-10 1.2246468e-15 L-2.2627417 -2.2627417 Z",
              "fill": "sparkle",
              "stroke": "sparkle_outline",
              "width": 1.6
            }
          ],
          "mode": "pulse",
          "amplitude": 0.18,
          "rate": 9
        }
      }
    }
  },
  "poses": {
    "idle": {
      "arm_l.rotate": 1.85,
      "arm_r.rotate": 1.25
    },
    "up": {
      "arm_l.rotate": -2.25,
      "arm_r.rotate": -0.85
    },
    "shock": {
      "arm_l.rotate": -2.45,
      "arm_r.rotate": -0.65
    },
    "type": {
      "arm_l.rotate": 2.55,
      "arm_r.rotate": 2.35
    },
    "hold": {
      "arm_l.rotate": -2.79,
      "arm_r.rotate": -0.35
    },
    "wave": {
      "arm_l.rotate": 1.85,
      "arm_r.rotate": -1.0
    },
    "point": {
      "arm_l.rotate": 1.85,
      "arm_r.rotate": -0.15
    },
    "hips": {
      "arm_l.rotate": 2.35,
      "arm_r.rotate": 0.8
    }
  },
  "moods": {
    "idle": {
      "description": "Idle state.",
      "status": "Idle",
      "pose": "idle",
      "face": {
        "eyes": "open",
        "mouth": "smile",
        "brows": "none"
      }
    },
    "thinking": {
      "description": "Thinking state.",
      "status": "Thinking",
      "pose": "hips",
      "face": {
        "eyes": "focused",
        "mouth": "flat",
        "brows": "raised",
        "look_x": 0.6,
        "look_y": -0.6
      }
    },
    "happy": {
      "description": "Happy state.",
      "status": "Happy",
      "pose": "wave",
      "face": {
        "eyes": "happy",
        "mouth": "grin",
        "brows": "none"
      }
    },
    "worried": {
      "description": "Worried state.",
      "status": "Worried",
      "pose": "idle",
      "face": {
        "eyes": "worried",
        "mouth": "flat",
        "brows": "worried"
      },
      "effects": {
        "sweat": 0.35
      }
    },
    "celebrating": {
      "description": "Celebrating state.",
      "status": "Celebrating",
      "pose": "up",
      "face": {
        "eyes": "happy",
        "mouth": "grin",
        "brows": "none",
        "blush": "strong"
      },
      "channels": {
        "root.lift": 10
      },
      "effects": {
        "sparkle": true
      }
    }
  },
  "gestures": {
    "rock": {
      "description": "Rock gently.",
      "frames": 18,
      "tracks": {
        "root.rotate": [
          [
            0,
            0
          ],
          [
            0.25,
            0.06
          ],
          [
            0.75,
            -0.03
          ],
          [
            1,
            0
          ]
        ]
      }
    },
    "nod": {
      "description": "Nod once.",
      "frames": 18,
      "tracks": {
        "root.scale_y": [
          [
            0,
            0
          ],
          [
            0.25,
            -0.04
          ],
          [
            0.45,
            0
          ],
          [
            0.65,
            -0.04
          ],
          [
            1,
            0
          ]
        ],
        "root.lift": [
          [
            0,
            0
          ],
          [
            0.25,
            -3
          ],
          [
            0.45,
            0
          ],
          [
            0.65,
            -3
          ],
          [
            1,
            0
          ]
        ]
      }
    },
    "wave": {
      "description": "Wave once.",
      "frames": 30,
      "needs": [
        "arm_r"
      ],
      "fallback": "rock",
      "tracks": {
        "arm_r.rotate": {
          "mode": "set",
          "keys": [
            [
              0,
              null
            ],
            [
              0.2,
              -0.9
            ],
            [
              0.4,
              -0.3
            ],
            [
              0.6,
              -0.9
            ],
            [
              0.8,
              -0.3
            ],
            [
              1,
              null
            ]
          ]
        },
        "root.rotate": [
          [
            0,
            0
          ],
          [
            0.2,
            -0.025
          ],
          [
            0.8,
            -0.025
          ],
          [
            1,
            0
          ]
        ]
      }
    }
  },
  "motion": {
    "change": {
      "style": "wiggle",
      "frames": 18,
      "angle": 0.06,
      "height": 8,
      "swap_at": 0.5
    },
    "idle": {
      "frames": 150,
      "blink_every": 120,
      "blink_jitter": 30,
      "blink_frames": 6,
      "breathe": 0.012,
      "breathe_period": 90
    }
  },
  "effects": {
    "sparkle": {
      "anchor": "sparkle",
      "layer": 50
    },
    "sweat": {
      "anchor": "sweat",
      "layer": 50
    }
  },
  "accessories": {
    "bow": {
      "description": "Bow.",
      "slot": "hair",
      "anchor": "hair",
      "parts": [
        {
          "id": "ornament",
          "layer": 40,
          "items": [
            {
              "shape": "path",
              "d": "M0 0 Q-10 -13 -21 -8 Q-25 0 -21 8 Q-10 13 0 0 Z",
              "fill": "accessory",
              "stroke": "outline",
              "width": 2.2,
              "cap": "round",
              "join": "round"
            },
            {
              "shape": "path",
              "d": "M-7 -1 L-17 -3 M-7 2 L-17 3",
              "stroke": "accessory_detail",
              "width": 1.6,
              "cap": "round",
              "join": "round"
            },
            {
              "shape": "path",
              "d": "M0 0 Q10 -13 21 -8 Q25 0 21 8 Q10 13 0 0 Z",
              "fill": "accessory",
              "stroke": "outline",
              "width": 2.2,
              "cap": "round",
              "join": "round"
            },
            {
              "shape": "path",
              "d": "M7 -1 L17 -3 M7 2 L17 3",
              "stroke": "accessory_detail",
              "width": 1.6,
              "cap": "round",
              "join": "round"
            },
            {
              "shape": "circle",
              "x": 0,
              "y": 0,
              "r": 5.5,
              "fill": "accessory",
              "stroke": "outline",
              "width": 2.2,
              "cap": "round",
              "join": "round"
            }
          ]
        }
      ]
    },
    "clip": {
      "description": "Clip.",
      "slot": "hair",
      "anchor": "hair",
      "parts": [
        {
          "id": "ornament",
          "layer": 40,
          "items": [
            {
              "shape": "round_rect",
              "x": -15,
              "y": -5,
              "w": 30,
              "h": 10,
              "r": 5,
              "fill": "accessory",
              "stroke": "outline",
              "width": 2.2,
              "cap": "round",
              "join": "round"
            },
            {
              "shape": "rect",
              "x": -5,
              "y": -4,
              "w": 3,
              "h": 8,
              "fill": "accessory_detail"
            },
            {
              "shape": "rect",
              "x": 3,
              "y": -4,
              "w": 3,
              "h": 8,
              "fill": "accessory_detail"
            },
            {
              "shape": "rect",
              "x": -12,
              "y": -3,
              "w": 5,
              "h": 2,
              "fill": "shine",
              "alpha": 0.7
            }
          ]
        }
      ]
    }
  },
  "wear": [
    "bow"
  ],
  "lod": {
    "micro": {
      "hide": [
        "wear_bow_ornament"
      ],
      "face": {
        "lashes": false,
        "brows": false,
        "iris": false
      },
      "glow": false
    }
  },
  "palette_sources": {}
}
```

### 4.4 Complete alpha_visor contract example

The display name remains alpha_visor in this draft; the founder chooses the shipping robot's display name.

The screen kit supplies all named eye/mouth styles. Beep scales the lamp once without rings. A custom processing mood falls back to thinking on a swap to a character without it. This is one possible robot fixture; it does not select which robot ships. Remaining robot artwork and Knurl's whole-file fixture must both be built/tested before freeze.

```json
{
  "format_version": 1,
  "id": "alpha_visor",
  "name": "alpha_visor",
  "family": "visorfolk",
  "description": "A calm helper robot with a screen face and a hard hat; suits build pipelines and job logs.",
  "requires": [
    "parts",
    "paints",
    "clip",
    "outline",
    "glow",
    "face_kit",
    "tracks",
    "lod"
  ],
  "colours": {
    "outline": "#1b1230",
    "outline_light": "#fffdf4",
    "shell": "#8a6bff",
    "shell_shade": "#6750bf",
    "shell_shine": "#c9bbff",
    "trim": "#3a3550",
    "hat": "#ffc400",
    "hat_shade": "#c79400",
    "screen": "#0a1038",
    "glow": "#4df3ff",
    "light": "#4df3ff",
    "light_thinking": "#ffb020",
    "light_happy": "#3ddc84",
    "light_worried": "#ff5a6e",
    "light_celebrating": "#ff5ce1",
    "boot": "#fffdf4",
    "sparkle": "#fffdf4",
    "sparkle_outline": "#ffc400",
    "sweat": "#9dc3e6",
    "shadow": "#a2aea7"
  },
  "follows": {
    "shell_shade": {
      "from": [
        "shell"
      ],
      "shade": "darker",
      "amount": -0.12
    },
    "shell_shine": {
      "from": [
        "shell"
      ],
      "shade": "lighter",
      "amount": 0.2
    },
    "hat_shade": {
      "from": [
        "hat"
      ],
      "shade": "darker",
      "amount": -0.12
    },
    "light": {
      "from": [
        "glow"
      ]
    }
  },
  "brand": {
    "primary": "shell",
    "secondary": "hat"
  },
  "contrast": [
    {
      "fg": "glow",
      "bg": "screen",
      "min": 4.5,
      "where": "eyes and mouth on the visor",
      "bg_paint": "visor_glass"
    },
    {
      "fg": "shell",
      "bg": "page",
      "min": 3
    }
  ],
  "paints": {
    "shell_round": {
      "type": "radial",
      "centre": [
        -14,
        -18
      ],
      "r0": 4,
      "r1": 58,
      "stops": [
        [
          0,
          "shell_shine"
        ],
        [
          0.55,
          "shell"
        ],
        [
          1,
          "shell_shade"
        ]
      ]
    },
    "visor_glass": {
      "type": "linear",
      "from": [
        0,
        -18
      ],
      "to": [
        0,
        18
      ],
      "stops": [
        [
          0,
          "glow",
          0.18
        ],
        [
          0.4,
          "screen",
          0
        ],
        [
          1,
          "screen",
          0
        ]
      ]
    }
  },
  "ground": {
    "centre_height": 78,
    "shadow": {
      "rx": 48,
      "ry": 7,
      "alpha": 0.3
    }
  },
  "outline": {
    "width": 2.5,
    "colour": "outline",
    "second": {
      "width": 5,
      "colour": "outline_light"
    },
    "lod": {
      "micro": {
        "width": 4,
        "second": null
      }
    }
  },
  "parts": [
    {
      "id": "leg_l",
      "parent": "root",
      "at": [
        -16,
        -34
      ],
      "layer": 1,
      "items": [
        {
          "shape": "polyline",
          "points": [
            [
              0,
              0
            ],
            [
              -5,
              5
            ],
            [
              5,
              10
            ],
            [
              -5,
              15
            ],
            [
              0,
              20
            ]
          ],
          "stroke": "trim",
          "width": 4
        }
      ]
    },
    {
      "id": "leg_r",
      "parent": "root",
      "at": [
        16,
        -34
      ],
      "layer": 1,
      "items": [
        {
          "shape": "polyline",
          "points": [
            [
              0,
              0
            ],
            [
              5,
              5
            ],
            [
              -5,
              10
            ],
            [
              5,
              15
            ],
            [
              0,
              20
            ]
          ],
          "stroke": "trim",
          "width": 4
        }
      ]
    },
    {
      "id": "boot_l",
      "parent": "leg_l",
      "at": [
        0,
        20
      ],
      "layer": 2,
      "items": [
        {
          "shape": "round_rect",
          "x": -13,
          "y": 0,
          "w": 24,
          "h": 13,
          "r": [
            7,
            7,
            4,
            4
          ],
          "fill": "boot",
          "outline": true
        },
        {
          "shape": "rect",
          "x": -13,
          "y": 10,
          "w": 24,
          "h": 3,
          "fill": "trim"
        }
      ]
    },
    {
      "id": "boot_r",
      "parent": "leg_r",
      "at": [
        0,
        20
      ],
      "layer": 2,
      "items": [
        {
          "shape": "round_rect",
          "x": -11,
          "y": 0,
          "w": 24,
          "h": 13,
          "r": [
            7,
            7,
            4,
            4
          ],
          "fill": "boot",
          "outline": true
        },
        {
          "shape": "rect",
          "x": -11,
          "y": 10,
          "w": 24,
          "h": 3,
          "fill": "trim"
        }
      ]
    },
    {
      "id": "torso",
      "parent": "root",
      "at": [
        0,
        -78
      ],
      "layer": 10,
      "items": [
        {
          "id": "shell",
          "shape": "path",
          "d": "M0 -44 C28 -44 42 -18 42 8 C42 32 24 44 0 44 C-24 44 -42 32 -42 8 C-42 -18 -28 -44 0 -44 Z",
          "fill": {
            "paint": "shell_round"
          },
          "outline": true
        },
        {
          "id": "gloss",
          "shape": "ellipse",
          "x": -16,
          "y": -22,
          "rx": 12,
          "ry": 6,
          "rotate": -0.5,
          "fill": "shell_shine",
          "alpha": 0.6,
          "clip": "torso.shell"
        }
      ]
    },
    {
      "id": "belly_light",
      "parent": "torso",
      "at": [
        0,
        12
      ],
      "layer": 11,
      "glow": {
        "colour": "light",
        "blur": 10,
        "alpha": 0.7,
        "item": "lamp"
      },
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 13,
          "fill": "trim",
          "outline": true
        },
        {
          "id": "lamp",
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 8,
          "fill": "light"
        }
      ]
    },
    {
      "id": "arm_l",
      "parent": "torso",
      "at": [
        -46,
        -10
      ],
      "rotate": 1.9,
      "layer": 20,
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 6,
          "fill": "trim"
        },
        {
          "shape": "round_rect",
          "x": 4,
          "y": -6,
          "w": 20,
          "h": 12,
          "r": 6,
          "fill": "shell",
          "outline": true
        }
      ]
    },
    {
      "id": "fore_l",
      "parent": "arm_l",
      "at": [
        28,
        0
      ],
      "layer": 21,
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 5,
          "fill": "trim"
        },
        {
          "shape": "round_rect",
          "x": 3,
          "y": -5,
          "w": 16,
          "h": 10,
          "r": 5,
          "fill": "shell",
          "outline": true
        }
      ]
    },
    {
      "id": "hand_l",
      "parent": "fore_l",
      "at": [
        22,
        0
      ],
      "layer": 22,
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 7,
          "fill": "boot",
          "outline": true
        }
      ]
    },
    {
      "id": "arm_r",
      "parent": "torso",
      "at": [
        46,
        -10
      ],
      "rotate": 1.24,
      "layer": 20,
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 6,
          "fill": "trim"
        },
        {
          "shape": "round_rect",
          "x": 4,
          "y": -6,
          "w": 20,
          "h": 12,
          "r": 6,
          "fill": "shell",
          "outline": true
        }
      ]
    },
    {
      "id": "fore_r",
      "parent": "arm_r",
      "at": [
        28,
        0
      ],
      "layer": 21,
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 5,
          "fill": "trim"
        },
        {
          "shape": "round_rect",
          "x": 3,
          "y": -5,
          "w": 16,
          "h": 10,
          "r": 5,
          "fill": "shell",
          "outline": true
        }
      ]
    },
    {
      "id": "hand_r",
      "parent": "fore_r",
      "at": [
        22,
        0
      ],
      "layer": 22,
      "items": [
        {
          "shape": "circle",
          "x": 0,
          "y": 0,
          "r": 7,
          "fill": "boot",
          "outline": true
        }
      ]
    },
    {
      "id": "neck",
      "parent": "torso",
      "at": [
        0,
        -44
      ],
      "layer": 5,
      "items": [
        {
          "shape": "round_rect",
          "x": -8,
          "y": -10,
          "w": 16,
          "h": 12,
          "r": 4,
          "fill": "trim"
        }
      ]
    },
    {
      "id": "head",
      "parent": "neck",
      "at": [
        0,
        -8
      ],
      "layer": 30,
      "items": [
        {
          "id": "helmet",
          "shape": "ellipse",
          "x": 0,
          "y": -34,
          "rx": 40,
          "ry": 36,
          "fill": {
            "paint": "shell_round"
          },
          "outline": true
        },
        {
          "id": "visor",
          "shape": "round_rect",
          "x": -30,
          "y": -50,
          "w": 60,
          "h": 34,
          "r": 14,
          "fill": "screen",
          "outline": true
        },
        {
          "id": "glass",
          "shape": "round_rect",
          "x": -30,
          "y": -50,
          "w": 60,
          "h": 34,
          "r": 14,
          "fill": {
            "paint": "visor_glass"
          }
        }
      ]
    },
    {
      "id": "ear_l",
      "parent": "head",
      "at": [
        -41,
        -34
      ],
      "layer": 29,
      "items": [
        {
          "shape": "ellipse",
          "x": 0,
          "y": 0,
          "rx": 7,
          "ry": 11,
          "fill": "trim",
          "outline": true
        }
      ]
    },
    {
      "id": "ear_r",
      "parent": "head",
      "at": [
        41,
        -34
      ],
      "layer": 29,
      "items": [
        {
          "shape": "ellipse",
          "x": 0,
          "y": 0,
          "rx": 7,
          "ry": 11,
          "fill": "trim",
          "outline": true
        }
      ]
    },
    {
      "id": "hard_hat",
      "parent": "head",
      "at": [
        0,
        -66
      ],
      "layer": 40,
      "items": [
        {
          "shape": "path",
          "d": "M-34 4 C-34 -18 -18 -30 0 -30 C18 -30 34 -18 34 4 Z",
          "fill": "hat",
          "outline": true
        },
        {
          "shape": "round_rect",
          "x": -44,
          "y": 2,
          "w": 88,
          "h": 8,
          "r": 4,
          "fill": "hat_shade",
          "outline": true
        },
        {
          "shape": "rect",
          "x": -3,
          "y": -28,
          "w": 6,
          "h": 30,
          "fill": "hat_shade",
          "lod": [
            "full",
            "small"
          ]
        }
      ]
    }
  ],
  "anchors": {
    "crown": {
      "part": "hard_hat",
      "at": [
        0,
        -30
      ],
      "description": "Top of the hard hat"
    },
    "chest": {
      "part": "belly_light",
      "at": [
        0,
        0
      ],
      "description": "Centre of the belly light"
    },
    "hand_l": {
      "part": "hand_l",
      "side": "l",
      "description": "hand l attachment."
    },
    "hand_r": {
      "part": "hand_r",
      "side": "r",
      "description": "hand r attachment."
    },
    "neck": {
      "part": "neck",
      "at": [
        0,
        -4
      ],
      "description": "neck attachment."
    },
    "sparkle": {
      "part": "head",
      "at": [
        46,
        -62
      ],
      "description": "sparkle attachment."
    },
    "sweat": {
      "part": "head",
      "at": [
        44,
        -48
      ],
      "description": "sweat attachment."
    }
  },
  "face": {
    "part": "head",
    "at": [
      0,
      -33
    ],
    "kit": "screen",
    "clip": "head.visor",
    "eyes": {
      "y": -4,
      "spacing": 14
    },
    "mouth": {
      "y": 8
    },
    "colours": {
      "feature": "glow"
    },
    "kit_definition": {
      "id": "screen",
      "description": "Static screen glyphs with budgeted emission.",
      "roles": [
        "feature",
        "sweat",
        "sparkle",
        "sparkle_outline"
      ],
      "defaults": {
        "eyes": "dot",
        "mouth": "smile",
        "brows": "none"
      },
      "glow": {
        "blur": 3,
        "alpha": 0.4
      },
      "eye_styles": {
        "dot": {
          "op": "eye_dots",
          "centres": [
            [
              0,
              0
            ]
          ],
          "r": 6
        },
        "scan": {
          "op": "eye_dots",
          "centres": [
            [
              -3,
              0
            ],
            [
              3,
              0
            ]
          ],
          "r": 3
        },
        "arc": {
          "op": "eye_arc",
          "r": 8,
          "start": 3.3,
          "end": 6.1,
          "width": 3
        },
        "slant": {
          "op": "eye_path",
          "d": "M-7 1 L5 -3",
          "stroke": "feature",
          "width": 3
        },
        "star": {
          "op": "eye_path",
          "d": "M0 -8 L2 -2 L8 0 L2 2 L0 8 L-2 2 L-8 0 L-2 -2 Z",
          "fill": "feature"
        },
        "dots": {
          "op": "eye_dots",
          "centres": [
            [
              -5,
              0
            ],
            [
              5,
              0
            ]
          ],
          "r": 3
        },
        "closed": {
          "op": "eye_path",
          "d": "M-7 0 L7 0",
          "stroke": "feature",
          "width": 3
        }
      },
      "brow_styles": {
        "none": {
          "op": "brow_path",
          "d": "M0 0",
          "width": 0,
          "stroke": "feature"
        }
      },
      "mouth_styles": {
        "smile": {
          "op": "mouth_path",
          "box": [
            10,
            6
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-1 0 Q0 1 1 0",
              "stroke": "feature",
              "width": 2.5
            }
          ]
        },
        "flat": {
          "op": "mouth_path",
          "box": [
            10,
            6
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-1 0 L1 0",
              "stroke": "feature",
              "width": 2.5
            }
          ]
        },
        "wide": {
          "op": "mouth_path",
          "box": [
            10,
            6
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-1 -0.2 Q0 1.5 1 -0.2 Z",
              "fill": "feature",
              "stroke": "feature",
              "width": 2.5
            }
          ]
        },
        "wavy": {
          "op": "mouth_path",
          "box": [
            10,
            6
          ],
          "items": [
            {
              "shape": "path",
              "d": "M-1 0 Q-0.5 -0.8 0 0 Q0.5 0.8 1 0",
              "stroke": "feature",
              "width": 2.5
            }
          ]
        }
      },
      "effects": {
        "sweat": {
          "op": "sweat_drop",
          "at": [
            0,
            0
          ],
          "items": [
            {
              "shape": "path",
              "d": "M0 -8 Q9 2 0 10 Q-9 2 0 -8 Z",
              "fill": "sweat"
            }
          ],
          "mode": "progress",
          "travel": 26,
          "sway": 2,
          "sway_rate": 12,
          "fade_at": 0.9
        },
        "sparkle": {
          "op": "sparkle_star",
          "at": [
            0,
            0
          ],
          "items": [
            {
              "shape": "path",
              "d": "M0 -7 L2 -2 L7 0 L2 2 L0 7 L-2 2 L-7 0 L-2 -2 Z",
              "fill": "sparkle",
              "stroke": "sparkle_outline",
              "width": 1
            }
          ],
          "reduced_items": [
            {
              "shape": "path",
              "d": "M0 -7 L2 -2 L7 0 L2 2 L0 7 L-2 2 L-7 0 L-2 -2 Z",
              "fill": "sparkle",
              "stroke": "sparkle_outline",
              "width": 1
            }
          ],
          "mode": "pulse",
          "amplitude": 0.18,
          "rate": 9
        }
      }
    }
  },
  "poses": {
    "rest": {
      "arm_l.rotate": 1.9,
      "arm_r.rotate": 1.24
    },
    "chin": {
      "arm_l.rotate": 1.9,
      "arm_r.rotate": -2.4,
      "fore_r.rotate": -1.6,
      "head.rotate": 0.06
    },
    "wave": {
      "arm_l.rotate": 1.9,
      "arm_r.rotate": -1.0,
      "fore_r.rotate": -0.8
    },
    "inward": {
      "arm_l.rotate": 1.4,
      "fore_l.rotate": 0.9,
      "arm_r.rotate": 1.7,
      "fore_r.rotate": -0.9
    },
    "up": {
      "arm_l.rotate": -2.3,
      "arm_r.rotate": -0.85,
      "fore_l.rotate": -0.3,
      "fore_r.rotate": 0.3
    }
  },
  "moods": {
    "idle": {
      "status": "Idle",
      "pose": "rest",
      "face": {
        "eyes": "dot",
        "mouth": "smile"
      },
      "description": "Idle state."
    },
    "thinking": {
      "status": "Thinking",
      "pose": "chin",
      "face": {
        "eyes": "scan",
        "mouth": "flat",
        "look_x": 0.6
      },
      "recolour": {
        "light": "light_thinking"
      },
      "description": "Thinking state."
    },
    "happy": {
      "status": "Happy",
      "pose": "wave",
      "face": {
        "eyes": "arc",
        "mouth": "wide"
      },
      "recolour": {
        "light": "light_happy"
      },
      "description": "Happy state."
    },
    "worried": {
      "status": "Worried",
      "pose": "inward",
      "face": {
        "eyes": "slant",
        "mouth": "wavy"
      },
      "recolour": {
        "light": "light_worried"
      },
      "effects": {
        "sweat": 0.35
      },
      "description": "Worried state."
    },
    "celebrating": {
      "status": "Celebrating",
      "pose": "up",
      "face": {
        "eyes": "star",
        "mouth": "wide"
      },
      "recolour": {
        "light": "light_celebrating"
      },
      "channels": {
        "root.lift": 8
      },
      "effects": {
        "sparkle": true
      },
      "description": "Celebrating state."
    },
    "processing": {
      "description": "Working through a queue.",
      "status": "Processing",
      "fallback": "thinking",
      "pose": "rest",
      "face": {
        "eyes": "dots",
        "mouth": "flat"
      },
      "recolour": {
        "light": "light_thinking"
      }
    }
  },
  "gestures": {
    "nod": {
      "frames": 18,
      "needs": [
        "head"
      ],
      "tracks": {
        "head.rotate": [
          [
            0,
            0
          ],
          [
            0.25,
            0.12,
            "ease_out"
          ],
          [
            0.45,
            0
          ],
          [
            0.65,
            0.12,
            "ease_out"
          ],
          [
            1,
            0
          ]
        ]
      },
      "description": "Nod."
    },
    "wave": {
      "frames": 30,
      "needs": [
        "arm_r",
        "fore_r"
      ],
      "fallback": "rock",
      "tracks": {
        "arm_r.rotate": {
          "mode": "set",
          "keys": [
            [
              0,
              null
            ],
            [
              0.2,
              -1.1
            ],
            [
              0.8,
              -1.1
            ],
            [
              1,
              null
            ]
          ]
        },
        "fore_r.rotate": {
          "mode": "set",
          "keys": [
            [
              0,
              null
            ],
            [
              0.2,
              -0.4
            ],
            [
              0.4,
              -1.1
            ],
            [
              0.6,
              -0.4
            ],
            [
              0.8,
              -1.1
            ],
            [
              1,
              null
            ]
          ]
        },
        "root.rotate": [
          [
            0,
            0
          ],
          [
            0.2,
            -0.025
          ],
          [
            0.8,
            -0.025
          ],
          [
            1,
            0
          ]
        ]
      },
      "description": "Wave."
    },
    "beep": {
      "description": "A short beep: the belly light pulses once.",
      "frames": 20,
      "tracks": {
        "belly_light.scale_x": [
          [
            0,
            0
          ],
          [
            0.3,
            0.18,
            "ease_out"
          ],
          [
            1,
            0
          ]
        ],
        "belly_light.scale_y": [
          [
            0,
            0
          ],
          [
            0.3,
            0.18,
            "ease_out"
          ],
          [
            1,
            0
          ]
        ]
      }
    },
    "hat_hop": {
      "description": "The hard hat hops and lands with a small squash.",
      "frames": 24,
      "tracks": {
        "hard_hat.y": [
          [
            0,
            0
          ],
          [
            0.4,
            -14,
            "ease_out"
          ],
          [
            0.75,
            0,
            "ease_in"
          ],
          [
            1,
            0
          ]
        ],
        "hard_hat.scale_y": [
          [
            0,
            0
          ],
          [
            0.75,
            0
          ],
          [
            0.85,
            -0.12
          ],
          [
            1,
            0
          ]
        ],
        "leg_l.scale_y": [
          [
            0,
            0
          ],
          [
            0.1,
            -0.15
          ],
          [
            0.3,
            0.05
          ],
          [
            1,
            0
          ]
        ],
        "leg_r.scale_y": [
          [
            0,
            0
          ],
          [
            0.1,
            -0.15
          ],
          [
            0.3,
            0.05
          ],
          [
            1,
            0
          ]
        ]
      }
    },
    "rock": {
      "description": "Rock gently.",
      "frames": 18,
      "tracks": {
        "root.rotate": [
          [
            0,
            0
          ],
          [
            0.25,
            0.06
          ],
          [
            0.75,
            -0.03
          ],
          [
            1,
            0
          ]
        ]
      }
    }
  },
  "motion": {
    "change": {
      "style": "gesture",
      "gesture": "hat_hop",
      "frames": 24,
      "swap_at": 0.5
    }
  },
  "lod": {
    "small": {
      "hide": [
        "torso.gloss",
        "head.glass"
      ]
    },
    "micro": {
      "hide": [
        "leg_l",
        "leg_r",
        "ear_l",
        "ear_r",
        "arm_l",
        "fore_l",
        "hand_l",
        "arm_r",
        "fore_r",
        "hand_r",
        "torso.gloss",
        "head.glass"
      ],
      "face": {
        "scale": 1.4
      },
      "glow": false
    }
  },
  "resolved": true,
  "family_definition": {
    "id": "visorfolk",
    "name": "Visorfolk",
    "description": "Characters with screen faces.",
    "defaults": {}
  },
  "effects": {
    "sweat": {
      "anchor": "sweat",
      "layer": 45
    },
    "sparkle": {
      "anchor": "sparkle",
      "layer": 45
    }
  },
  "palette_sources": {
    "sea_glass": "family",
    "night_screen": "family"
  },
  "palettes": {
    "sea_glass": {
      "description": "A cool screen.",
      "light": {
        "screen": "#06232a"
      }
    },
    "night_screen": {
      "description": "A deeper screen.",
      "light": {
        "screen": "#03151a"
      }
    }
  }
}
```

### 4.5 Complete source family and expected Study Bot resolution

This is the exact built-in visorfolk source-default fixture for the builder walkthrough. It is distinct from the empty-default resolved metadata snapshots above. Family defaults imply no body parts; nod, wave and rock use the explicitly defined root rotation channel. Anatomy-dependent needs/fallbacks belong to the character-local candidates in the builder example. Characters that supply their own nod/wave replace these whole definitions.

```json
{
  "id": "visorfolk",
  "name": "Visorfolk",
  "description": "Characters with screen faces.",
  "defaults": {
    "gestures": {
      "rock": {
        "description": "A brief whole-character tilt.",
        "frames": 18,
        "tracks": {
          "root.rotate": {
            "mode": "add",
            "keys": [
              [
                0,
                0
              ],
              [
                0.3,
                0.08
              ],
              [
                1,
                0
              ]
            ]
          }
        }
      },
      "nod": {
        "description": "A brief whole-character acknowledgement tilt.",
        "frames": 18,
        "tracks": {
          "root.rotate": {
            "mode": "add",
            "keys": [
              [
                0,
                0
              ],
              [
                0.3,
                0.08
              ],
              [
                1,
                0
              ]
            ]
          }
        }
      },
      "wave": {
        "description": "A brief whole-character greeting tilt.",
        "frames": 30,
        "tracks": {
          "root.rotate": {
            "mode": "add",
            "keys": [
              [
                0,
                0
              ],
              [
                0.3,
                0.08
              ],
              [
                1,
                0
              ]
            ]
          }
        }
      }
    },
    "palettes": {
      "sea_glass": {
        "description": "A cool screen.",
        "light": {
          "screen": "#06232a"
        }
      },
      "night_screen": {
        "description": "A deeper screen.",
        "light": {
          "screen": "#03151a"
        }
      }
    }
  }
}
```

Study Bot supplies character-local nod/wave candidates plus greet and overrides sea_glass with a complete palette. Expected resolved gesture keys, in authored merge order, are rock, nod, wave, greet. Its local nod and wave retain their declared 18/30-frame candidates but resolve to playable rock (18 frames) because Study Bot has neither nod_joint nor hand_r. greet remains playable at18 frames. No arm/effect/colour is invented. Expected requires is parts, outline, clip, face_kit, glow, tracks, lod (order canonicalised by policy, all supported); expected palette_sources is {"sea_glass":"character","night_screen":"family"}. Its saved family_definition has the same id/name/description with defaults:{}; gestures/palettes/provenance are materialised independently and rereading never applies the source defaults again. R1c must compare these outcomes and final resource totals; this is an expected result, not a report of an executed checker.

Family nod/wave defaults above are safe whole-root tilts. Study Bot explicitly overrides them with anatomy-dependent candidates to exercise the fallback contract; there is no anatomy inferred from family membership.

### 4.6 Small conformance fragments (not whole passing characters)

Knurl's clamp variant set track: {"mode":"set","keys":[[0,null],[0.4,"open"],[0.55,"default"],[1,null]]}. Its spanner part has keep_upright:true and no_flip:true; the affine rule in3.11 applies under nested squash/reflection. A user badge anchor is {"part":"torso","at":[18,-12],"rotate":0,"description":"Badge pin."}. This adds no missing limb or fitting solver. Sela's hair_back and hair_front share a head parent but have layers5 and35 around body20. These fragments require the complete fixture tasks in10.


## 5. Families, identity and resolution

Family fields: id, name, description (required); defaults (object, default{}). Defaults may include outline, face, moods, gestures, motion, colours/colour_descriptions/follows/brand/contrast and palettes. Family gesture defaults use root channels only (root.rotate, root.lift, root.scale_x and root.scale_y); character-local overrides explicitly name their own anatomy. A conventional part name never opts a member into an anatomical family motion. They may not add parts, anchors, ground, accessories or wear. A suggested starting character is a builder/UI choice, never implicit anatomy. Family kit defaults are checked against each actual character after merge; missing declared needed parts in character-local gesture overrides invoke checked fallbacks. Built-in families: hexonians, elementals, visorfolk. New families are checked objects, not hard-coded engine branches.

A source character references a known family or supplies family_definition {id,name,description,defaults}. That id must equal family; duplicate/conflicting source definitions for a registered family error. A resolved family_definition is a local metadata snapshot, not a source default definition: it never registers/replaces family defaults and is never compared against the live default map. Snapshot labels are preserved on that character even if today's registry labels differ; the global family listing uses registry labels. A snapshot cannot be used as a known-family source of defaults for a new character. The checker first validates family structure, applies the deterministic merge in3.13, then validates semantic geometry/references/limits. It marks output resolved:true and materialises all family-provided behaviour defaults. Stable version1 operation defaults may remain implicit, but complete kit definitions must be embedded. A saved resolved file embeds family_definition {id,name,description,defaults:{}} and complete resolved values; its resolved:true prevents reapplying package family defaults on read. A claimed resolved file still receives every semantic check and complete-required-field check. This preserves the category/identity without a live inheritance link. Resolution also computes palette_sources with exactly the keys of palettes and values character or family. A whole character-level palette replacement has character origin, including an identical-value replacement; an inherited palette has family origin. Source specifications omit palette_sources; raw resolved input must supply and validate it ({} when no palettes). Save/read preserve this checked origin map without consulting current family defaults. Synthetic original is native listing metadata, not a stored palette/source-map entry. Every resolved/saved face embeds its complete face.kit_definition with matching id, including classic/screen. Source kit ids select authoring defaults only; resolution copies the complete kit. Read/render uses the embedded definition, never substitutes today's package kit by id. Version1 operation semantics remain frozen; changed operation semantics require a format version change. Custom and built-in snapshots receive the same checks. No external asset lookup or script is permitted.

Source-only palette opt-out: palettes may contain an inherited family palette id with null to omit that entire palette. The id must exist in family defaults; a null for an unknown id errors. Resolution removes the entry and its provenance; resolved/saved palettes contain no nulls. Inherited palettes naming a missing character role error unless explicitly omitted; never guess a role mapping or silently skip the palette. Complete character palette replacements remain atomic. The R builder exposes omit_family_palettes for this source operation.

R distinguishes draft authoring components, source character specification, fully checked mascot_character_data, and the public mascot_character selector/helper. Never accept an unchecked draft as UI character data. Input/output class fields are internal. A supplied checked object is verified for integrity/content before use, since R lists can be mutated. Id lookup, direct object and built-in paths converge on the same checker. Registration has R-process lifetime, is explicit and intended only for app start-up/development (reject an active Shiny reactive domain), writes no files, and cannot replace built-in ids. Per-visitor characters pass checked objects directly and never enter the shared process registry. Listings by id describe the process catalogue, not another visitor's objects. Re-registering identical content is idempotent; conflicting content with the same id errors. Remix requires a new explicit permanent id; final family is required even for a hybrid. Only runtime instance id belongs to Shiny; it is distinct from character id and part/anchor ids.

## 6. Validation contract

Pure R jsonlite/checkmate/cli, no mandatory schema/V8 framework. One ordered process: bounded input/JSON syntax and duplicate keys -> version/capabilities -> key/type/local ranges -> family/kit structure -> deterministic resolution -> unique ids/acyclic parents -> paints/roles/paths/shape refs -> variant/clip/anchor integrity -> mood and gesture fallback/needs resolution -> reachable composed channels -> expanded per-band work/budgets -> built-in contrast promises and required core states. Stop a dependent stage when its prerequisite fails; collect at most ten independent problems at a stage with exact JSON path, code, value and fix suggestion.

R conditions use the classes in the companion API document section1: specific argument/choice/dots/character/file classes inherit mascot_error; update/contrast/preset/unknown-name warning classes inherit mascot_warning. Character failures retain stable code/path/value/fix fields. Preserve informational mascot_placement_ignored inheriting mascot_message. Browser diagnostics carry matching codes where applicable but are not R conditions. JSON paths use $.parts[0].items[1].fill (zero-based arrays) consistently in R/JS diagnostics, irrespective of R list indexing. Stable common codes: input_type, version, capability, unknown_key, non_finite, missing_reference, invalid_channel, invalid_colour, budget. R-only family/global semantic checks have their own codes. JS guards only its documented common subset, plus runtime state membership; compare code/path for common bad fixtures, not every first English message from every R-only check.

Built-in authored contrast promises error below3:1 for required graphic details in both resolved modes, using the explicit declared foreground/background pairs below; no geometric overlap guessing. New characters target4.5:1 but missing that aim alone does not reject a valid3:1 character. Decorative accents need not become false hard promises. User colours remain exact and warn in development mode, always in preview/studio unless explicitly silenced; CSS-resolved warnings belong to browser diagnostics. Status text retains its independent accessibility requirements. Save/check never silently recolours.

Contrast backgrounds are authored promises: bg identifies a solid role/page baseline; optional bg_paint identifies the specific background paint composited over that base. Check every resolved mode/preset under test. For gradients, derive conservative per-channel min/max bounds across stops and alpha composition over bg; convert these to a luminance interval and use the nearest possible background luminance to foreground luminance for the worst contrast. A translucent foreground is composited over the same background bounds before comparison; an unprovable bound is unverified, never pass. This may conservatively reject a good-looking gradient; it cannot call an uncertain backdrop a pass. Authors can use a solid declared face backdrop instead. Arbitrary overlapping/translucent artwork not represented by a declared pair is unverified, reported for visual review, never silently inferred as a contrast pass.

At default host root x/y/rotation/scale, every reachable authored mood, gesture, effect and accessory, including automatic blink/gaze ranges, must fit the 300x300 frame, including strokes and conservative three-blur-radius bounds. R1c computes conservative transformed bounds; E5b tests boundary cases and captures all bands. If bounds cannot be proven, require an explicit bounded fixture check before acceptance. Arbitrary externally supplied root/held-pose transforms or face scaling can deliberately clip and are not covered by this authored-fit promise; safety ranges are not a promise that every external transform fits; preview reports that limitation. There is no automatic fitter. A local hat y of about -248 alone does not prove overflow: the ground is at270 and full transformed extents must be calculated.

R examples of useful diagnostics: "$.anchors.tool_grip.part names elbow, which is not a declared part"; "$.gestures.wave.fallback -> rock -> wave is cyclic"; "$.requires omits glow used by the screen kit". None is claimed to be an implemented message yet.

## 7. Colour and palette precedence

For the selected mode, build a baseline from original colours plus mode overrides. Select a named preset after family/character resolution; character preset of the same id atomically replaces family preset. A preset has description, light and dark role maps; missing dark map uses that preset's light map, while missing individual roles retain baseline values. Reserve original as a synthetic palette available for every character: it means native mode colours with no preset overrides; user/family presets cannot redefine it. Listing source is native. A role literal, gradient stop or style must resolve to a declared semantic role.

Then build supplied overrides: preset leaders -> explicit light/dark map or brand leaders -> CSS-selected roles (existing CSS priority). Resolve follows recursively only from supplied/filled leaders, never from untouched baseline leaders. Detect cycles; use first available ordered leader. Next apply mood recolour/item style choices to roles without an explicit user override on that destination. Explicit supplied role colours remain exact; an explicit role cannot be overwritten by follows or mood recolour. CSS mapping with missing/invalid value returns that role's baseline and warns, and blocks follows for that destination, as today. A theme replaces the prior theme, rather than incrementally leaking old overrides.

Mood recolour redirects a role to another resolved role; source/destination chains must be acyclic and are resolved before gradients. User override on the destination wins; an overridden source can still supply a non-overridden destination. Transparency is composed only during painting, not by mutating supplied colour channels. Mode/preset/recolour changes invalidate paint caches; no movement replay. Status never depends on colour alone.

Family presets are not automatically portable across unrelated role systems. On swap, re-resolve retained theme for the incoming character; explicit unknown roles are ignored for retained themes, while an explicit new invalid map/preset rejects the atomic patch. Founder-approved missing-retained-preset policy (2026-10-14): discard the unavailable retained preset with a development warning, use the incoming native baseline and keep valid explicit overrides; do not silently select a similarly named palette. An explicitly supplied invalid incoming preset still rejects the atomic update. Palette inspection uses the actual three release characters in light/dark and all sizes.

## 8. R and host integration

R builder signatures/complete example: r-builder-proposal.md. API recommendations and Today/Options/Reason/User-effect records: r-api-decisions-0.1.0.md. No signatures in these documents are implemented here.

mascot_mood()/mascot_gesture() helpers validate syntax alone; selected-character membership occurs in mascot()/preview/character-aware listings and update use. UI creation errors before emitting invalid data. Updates validate structural types in R; selected target content comes from explicit same-call character or known retained state. If R cannot know the mounted target, membership is deferred to the known-target host's atomic prepare stage, which warns/no-change on invalid vocabulary. In development mode R additionally emits mascot_name_unverified for a syntactically valid mood/gesture absent from every currently known process-catalogue character; it is informational and never rejects a possibly valid custom browser target. Emit once per name/kind per session with bounded diagnostic storage. Final target membership remains authoritative. Do not falsely claim server R validated an unknown browser target. Full R validation remains authoritative for character files.

Host migration must translate held look/lookY to face.look_x/y, support no-gaze/faceless kits, derive shown status from the selected file, preserve explicit custom status, theme reapplication and module namespace-once delivery. Preserve _click/_menu/_position/_minimised semantics, dynamic UI retention, one-shot gesture revisions, panel timers/focus, hidden layout, DPI resize and unsubscribe cleanup. No CSS/internal protocol changes are necessary merely because data moves to parts. Public approved styling hooks stay documented; internal messages/JS/data attributes remain internal. No output/render pair, no htmlwidgets, no runtime network.

## 9. Bounded build order and acceptance

Each later implementation unit needs an issue in the repository epic tree and a small reviewable PR. Every export/argument change includes roxygen, NEWS and studio updates in that same PR. No fixed PR count is promised. Parallelism starts only after contracts exist and uses separate files/worktrees.

| Unit | Prerequisites | Deliverable and decisive done-when | Track |
|---|---|---|---|
| R1a | none | Complete grammar, kit/family/examples/limit data and good/bad case expectations; baseline store/owner prerequisite documented; core design review accepted independently of queue-contract Q1 approval. | Contract |
| T1 | R1a | Named store/owner recorded before T1 starts; locked canonical visual harness and old baselines pinned to main ace06f5 before E1; planted missing-eye/wrong-mood/displaced-anchor defects fail non-zero. | Tests |
| R1b | R1a | Bounded parser, types, keys, versions, structural diagnostics; malformed/deep/duplicate input cases. | R |
| R1c | R1b | Family/kit merge, semantics, fallbacks, contrasts and expanded budgets; canonical good/bad fixtures give expected codes/paths. | R |
| E1 | R1a,T1 | Numeric work may develop alongside T1; appearance acceptance requires its locked baselines. Part matrices, layers, anchors and provisional adapter; numeric transforms and same-profile comparisons accepted. | Engine parallel R |
| E2 | E1 | Shapes/refs/paints/clips/outlines; fixtures cover local/world coordinates and hidden active clip geometry. | Engine |
| R2 | R1c | Internal checked-data and process registry, reserved ids/content identity; unit acceptance only, mount waits for I1. | R parallel E2 |
| E3 | E2,R1a | Generic classic/screen faces, coherent tuning and effects; near-look evidence and faceless case. | Engine |
| E4a | E3 | Tracks, needs/fallback, interruption/reduction/deadlines; numeric frame/terminal assertions. | Engine |
| E4b | E4a | Mood channels, variants/anchors/recolour, ordinary sweat/sparkle and switches; no deferred runtimes. | Engine |
| E5a | E2,R1a | Named emitter glow/alpha composition and unit conversion; expanded work accounted. | Engine, overlap if files allow |
| E5b | E3,E4b,E5a | LOD and policy enforcement; band resize without replay; all effective variants counted. | Engine |
| R3a | R2,R1a | Helpers/listings/status metadata and unit acceptance, with own studio/docs changes. | R parallel engine |
| B1 | R2,R1a | Internal authoring constructors, custom anchors and check/save round-trip; builder example checks. | R parallel engine |
| Q1 | none | Independent queue-contract approval of B1-B4: atomic compaction, lost/unmounted delivery, process issuer and remount ownership cases. This gate does not block core units. | Protocol review |
| U1 | R2,R3a,Q1 | Accepted checkpoint, whole-call compaction at any delivery stall and cumulative lifecycle snapshots; actual R/JS static-UI token, atomicity, remount/pressure/multi-session tests. | R/host |
| I1 | R2,R3a,U1,E3,E4b,E5b | Custom data mounts end-to-end; host gaze/status/theme, namespaces/queues/swap/remount; preview works. | Join |
| M1 | I1,T1 | Complete Tessa migration, approved near-look and preserved wiggle/anchors/accessories; only then remove adapter. | Character/integration |
| R4 | I1 | Character/family/anchor API and same-PR studio; family merge already finished. | R |
| M3 | R1c,E3,E4b,E5b,T1 | Complete alpha_visor fixture and section10 acceptance; independent of M2 polish. | Character fixture |
| M5a | R1c,E3,E4b,E5b,T1 | Complete Sela fixture and section10 acceptance; independent of M2 polish. | Character fixture |
| M5b | R1c,E3,E4b,E5b,T1 | Complete Brim fixture and section10 acceptance; independent of M2 polish. | Character fixture |
| M5c | R1c,E3,E4b,E5b,T1 | Complete Iso fixture and section10 acceptance; independent of M2 polish. | Character fixture |
| M6 | R1c,E3,E4b,E5b,T1 | Complete Knurl fixture and section10 acceptance; independent of M2 polish. | Character fixture |
| M7 | R1c,E3,E4b,E5b,T1 | Complete Cinder fixture and section10 acceptance; independent of M2 polish. | Character fixture |
| M4 | I1,R4 | Neer with simplified sheen, dark palette, moods/sizes and studio review. | Character |
| CHOICE | M3,M6,S1/R5,M4 | Founder compares both robots with the actual palette picker and records one release choice. | Review |
| MR | I1,R4,CHOICE | Promote only chosen fixture with studio/docs/full acceptance. | Character |
| S1/R5 | M1,R4,R1a | Palette APIs and live picker; inspect both robot fixture objects before promotion (no MR dependency), then verify Neer via M4 before CHOICE. | R/studio |
| C1 | R1c,E3,E4b,E5b,T1 | Complete Rustle fixture: ear/tail finite follow-through and micro silhouette. | Conformance |
| C2 | R1c,E3,E4b,E5b,T1 | Complete Mote fixture: finite satellite orbit and24px readability. | Conformance |
| C3 | R1c,E3,E4b,E5b,T1 | Complete Strata/Gather fixture: face:null and mood arrangements. | Conformance |
| C4 | R1c,E3,E4b,E5b,T1 | Complete Foldlings fixture: custom moods/fallbacks/status and rigid variants. | Conformance |
| C5 | R1c,E3,E4b,E5b,T1 | Lab/molecule paper good/bad contract cases; reject unsupported capabilities, no passing runtime claim. | Conformance |
| E5c | E5b,T1,M1,M4,MR,S1/R5,M3,M5a,M5b,M5c,M6,M7,C1,C2,C3,C4,C5 | Nominated headed desktop/phone presentation runs plus canonical JS timings; T1 headless traces are diagnostic only, limits fail non-zero; release acceptance records all three characters. | Final join |
| FREEZE | B1,E5c,C1,C2,C3,C4,C5,M3,M5a,M5b,M5c,M6,M7 | All eight picks plus representative cases, saved round-trips, kit/grammar/work totals and measured limits accepted; freeze format1 before public authoring exports. | Review |

T1 canonical visual profile (headless traces are diagnostic only; E5c headed device nominations are separate): Ubuntu24.04 container pinned by digest on the ubuntu-26.04 CI host, x86_64, headless Chrome for Testing with software rasterisation, viewport1280x960, DPR1 and2, sRGB, fixed locale/timezone, no external fonts/assets, explicit screenshot CSS sizes160/96/24. Before creating any approved baseline, commit a profile lock containing container digest, exact browser build/SHA, flags, bundled-font package checksums and capture settings. Missing/different lock is an error, not automatic regeneration. This chooses the environment now; the exact installed build/digest is recorded by T1 before any acceptance claim. Chrome's headless mode has a documented browser implementation ([Chrome Headless](https://developer.chrome.com/docs/automation-and-testing/headless)); it does not guarantee equality across operating systems.

Before T1 starts, the founder must choose a named retained baseline store and responsible owner; The T1 record gives its exact location/store name, owner, access, retention/backup policy and pinned archive retrieval contract; R1a defines this prerequisite without blocking unrelated validator work on the choice. Neither store nor owner is selected here. Missing that record blocks T1; it cannot be deferred to rebaselining. Keep a small reviewed PNG set and manifest in git; store heavy baseline PNG sets as immutable content-addressed archives with pinned digests in retained artifact storage, cached locally under build-excluded and gitignored dev/visual-baselines/. Record retention/backup policy; expiring CI job artifacts cannot be the only copy. A hash without available decoded images is insufficient: strict comparison fails if the pinned archive cannot be supplied. Review visual diffs before changing the manifest; never regenerate automatically. Tooling lives under excluded tools. Compact semantic/JSON/numeric tests remain in tests and run offline from the installed package without browser dependencies; optional local visual checks clearly skip missing prerequisites.

T1 supplies a separate repository-root runner with --strict and a future .github/workflows/engine-visual.yml workflow; strict mode fails on absent/different profile, missing baselines or planted defects. It is mascot-specific and stays outside the generic CRAN gate. The implementation PR must explicitly update the CI rules to permit this named workflow, use workflow_dispatch and selected engine/character paths for PR triggers under #113's private-repository minute budget, and restore the full required policy under #115 before public release. Do not weaken existing required checks. The installed-package test suite cannot assume dev/tools exists.

Compare decoded RGBA pixels exactly within the locked profile, not PNG bytes. Capture old ace06f5/new frames in that same profile for founder near-look approval; strict regression then uses the approved new baseline. Environment/art changes require reviewed rebaselining; no blanket tolerance hides defects. macOS/other browsers use smoke, semantic and same-environment repeatability checks, not Ubuntu pixel hashes.

Coverage includes five moods, selected moving frames, every gesture, worn/alternate accessories, three sizes, light/dark, reduced-motion changes, flip/non-uniform squash, moving/hidden/variant anchors, palette/user colours, queued messages, retargeted swaps and multiple elements. Test numeric matrices/anchor coordinates, deadline boundaries and callbacks in addition to pictures. Baselines do not prove speed; E5c separately measures it. Release check inspects source tarball contents/size to prove exclusions, not merely CRAN skip execution ([Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Building-package-tarballs)).

## 10. Character conformance and release promotion

| Character/case | Complete fixture/task acceptance before freeze | Honest simplification |
|---|---|---|
| Tessa | Five moods, bow/clip, classic tuning, stand/tuck anchors, held flip/squash and wiggle; full migration file in4. | Near-looking face permitted; further gradient/iris/facet polish M2 separate, not a prerequisite for others. |
| Neer | Wave/curl, shell, clipped simplified sheen, dark-mode palette and face detail at all bands. | Finite crest-group movement, not continuous crest morph; avoid busy background water. |
| alpha_visor | Screen styles, jointed arms/boots, hat hop, per-mood lamp, nod/wave fallback, processing extra. | Lamp scale/colour pulse instead of ring pulse; no runtime particles. |
| Knurl | Wheel, head/screen, two-joint clamp, spanner world-up under reflected/non-uniform transforms, terminal clamp variant. | Sparkle instead of weld particles; both robot fixtures mandatory, either can be promoted by MR. |
| Sela | Back/front hair with independent layer/parent behaviour, finite delayed keys and time-block props. | Delayed finite keys instead of spring hair. |
| Brim | Cap with group pivot, hand-attached card, moustache part and ghost-card variant with opacity. | Discrete mood variants; no semantic document renderer or fitted clothing. |
| Iso | Quiff, untinted glasses, chart-panel paths and independently opening tool. | Finite paths/variants/tracks; no live numeric chart input claim. |
| Cinder | Mask, flame layers, blue thinking core and five discrete shape/pose states. | No continuous flame morph, smoke, particles or blend modes. |
| Rustle | Ear/tail parts with finite follow-through, micro silhouette. | No physical springs/leaves. |
| Mote | Core/satellites, finite orbit ending before deadline, readable24px. | No endless orbit. |
| Strata/Gather | face:null, distinct mood arrangements plus status, all three bands. | No face requirement. |
| Foldlings | save/delete/warning extras, checked shared fallbacks/status and rigid/variant geometry. | True folding deformation later. |
| Lab/molecule paper cases | Typed-input/connector contracts and explicit unsupported-capability rejection. | Do not call these successful0.1.0 runtime character fixtures. |

For every picked character, the implementation task supplies a whole validated file, all required family/kit data and good/bad expectations, then numeric/visual/budget acceptance. A fragment is not a complete passing fixture. Each fixture may precede finished artwork promotion; more built-ins can be prepared on a development branch. Palette picker and both robot options must be ready before the founder's release choice.

Brim sketch: cap parts parented to body with one cap pivot; card parented to a hand anchor through an expanded accessory; card has default/ghost item variants and matching local anchor overrides. Moustache left/right parts change rotation via moods/tracks. Iso sketch: panel as independent layered parts; curve items selected by variants, glasses unfilled strokes above eyes, divider blades as two children with opposite rotation tracks. Their complete fixture tasks must resolve every id/role/clip/track; these sketches do not count as proof.

## 11. Remaining decisions, risks and evidence

Founder choices still open: which robot ships and its display name (alpha_visor remains the draft example name); approval of near-look faces and palettes after rendering; nomination of the headed desktop and physical phone; named retained baseline store and owner before T1; remaining recommendations in the API document, including experimental lifecycle and later bubble/Quarto choices. Focused preview and missing-retained-preset handling were approved on 2026-10-14. Custom anchors, mandatory families, family defaults, no character inheritance and three-family release coverage are settled and must not be asked again.

Risks: face kits can still be visually inadequate despite complete grammar; fixtures and visual review decide. Canonical screenshot environment is not yet provisioned/locked. Performance and phone cost are unmeasured. Count limits can need tightening after measurements, before freeze. Source/package exclusions must be checked on the actual tarball. Later reserved capabilities need independent contracts and may require format changes if existing meanings cannot be preserved. A family/component catalogue grows only as its specific combinations are checked; no universal combination count is promised.

No R, package gate, proposed validator/renderer, baseline harness, runtime screenshot, CI, tarball build or phone measurement was run for this revision. Annotated examples are design data; JSON parsing only proves syntax. All proposed tests and timings above are acceptance requirements, not reported passes. No new dependency or shipped asset is installed by these documents.
