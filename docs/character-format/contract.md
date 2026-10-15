# Character format v1: R1a core contract

Status: reference contract and fixture preparation, 2026-10-14; issue [#278](https://github.com/insightsurge/mascot/issues/278), parent #3 under M1 #11.

This set makes the reviewed recipe concrete. It does not implement the parser, full validator, renderer or R builder. No fixture is certified valid merely because it parses. The operation manifest and reference per-band counts are now recorded. R1a acceptance still requires review of the new accounting details; R1c must independently reproduce the counts and conservative glow-area bounds through the implementation. Visual acceptance and performance remain separate.

## Reading order and ownership

1. Read this contract for the format, defaults, resolution and errors.
2. Read [limits.json](limits.json) for the single candidate data table to be consumed by R and JS later. It is not loaded by the current package and its version describes this policy table, not a new package release.
3. Read [fixtures/manifest.json](fixtures/manifest.json) for file roles, expected outcomes, diagnostic codes/paths, numeric expectations and outstanding evidence. Paths in that manifest are relative to its own directory.
4. Read the [R builder proposal](../r-builder-proposal.md) for proposed constructors and the complete R walkthrough. Read the [API decisions](../r-api-decisions-0.1.0.md) for user-facing conditions and helper contracts.
5. Run `python3 -I docs/character-format/check.py` from the repository root for the limited checks described below.

The core below is synchronised with the [engine proposal](../engine-format-proposal.md), based on design commit 9194ac0, with the explicitly recorded R1a counting clarifications. The Tessa micro clip change is described in [work-counts.md](work-counts.md). The checker compares each block against the proposal so duplicated text cannot drift unnoticed; this is a consistency check, not new independent approval. Original section numbers and cross-references are retained: references to sections 4, 8, 9, 10 and 11 mean the proposal. JSON files replace copying examples out of prose; the five extracted examples must remain data-identical to their proposal counterparts.

Source recipes are editable input; expected resolved files are test oracles, not output from an executed R checker. A resolved:true flag never bypasses validation. The field schema is given by the tables and closed-operation rules below; this delivery does not claim to supply a complete machine-executable schema. Unknown keys must eventually fail at every typed boundary, not just the top level. Exact conditional/type enforcement belongs to R1b/R1c.

The fixture codes/paths choose concrete expectations from the existing common diagnostic vocabulary. English error sentences may change; codes and zero-based JSON paths are the comparison contract. A dotted track name is one map key even when shown in the proposal's dotted diagnostic notation. Duplicate-key rejection points at the repeated key. These selected fixtures do not exhaust the diagnostic or malformed-input space.

## What the small examples enable

- Study Bot is the complete data counterpart of the proposed R walkthrough: one family, actual geometry, five moods, a custom badge point, copied family palettes and gestures, and an embedded saved screen kit. Missing head-joint/hand candidates fall back to a root tilt; no anatomy is invented.
- Anchor Probe has no face. Its badge accessory actually attaches to a custom anchor. A variant moves the pin; hiding the owner or selecting micro suppresses the attachment without moving it to the origin. Expected coordinates are ground-relative, before host positioning.
- Deliberately broken whole recipes cover missing family/parts/roles/moods, unsupported capabilities, unknown keys, incorrect types and frames. Raw malformed files retain duplicate keys and a JSON number that overflows to infinity for the future parser.
- Save/read scenarios preserve kit snapshots, family metadata, palette origins, null endpoints and array types. They are future executable acceptance cases, not evidence that those APIs exist.

## Check boundary and remaining acceptance

The Python checker is development documentation tooling using only the standard library. It reads files without modifying them, rejects duplicate keys/non-finite numbers, compares extracted examples and limits with the proposal, checks the manifest and selected references/fixtures, and fails non-zero under ordinary or optimised Python. It is deliberately not the shared package validator or engine. Invalid fixtures may carry only their expected first diagnostic; the future ordered pipeline must stop dependent stages and report that field.

The [accounting checker](budget.py) separately recomputes the current reference profile’s separable componentwise integer upper bounds and conservative authored glow-area bounds from [operations.json](operations.json); [budgets.json](budgets.json) records twelve rows and per-metric witnesses. It fails on unsupported counting constructs and on a limit overrun. It is not a generic renderer/state-space verifier.

Not checked here: every nested unknown key/type/range; full needs/fallback resolution; generic composed animation state space; independent R/JS reproduction of the reference counts and bounds; conservative frame fit and contrast; R construction/save/read; actual accessory transforms/painting; screenshots; Shiny transport; performance; CRAN; tarball contents. A selected-reference pass must never be reported as those checks passing.

Before T1 starts, record a founder-chosen retained baseline store and responsible owner, its exact location, access, retention/backup and pinned archive retrieval contract. Neither is chosen here. The locked screenshot profile, old-main ace06f5 captures and approved new baselines follow T1 in proposal section 9. Missing this record blocks T1, not unrelated parser work. Other picked characters and both robot options require complete fixtures before format freeze. Only Tessa, Neer and the later selected robot ship in 0.1.0; adding a reference fixture does not install a built-in.

Q1 independently reviews the queue contract in proposal section 3.16. This set excludes that protocol and does not unblock U1/I1. No new public R functions or package assets are added by this documentation step.

<!-- BEGIN source resource rules -->
### 2.4 Resource and performance contract

These are proposed limits/targets, not measurements. One shipped internal policy table is read by R and JS; character files cannot override it. Count expanded items after refs/kits/accessories, every reachable variant/mood/effect and every supported band, using the deterministic separable componentwise upper bound defined below, rather than enumerating all joint combinations. Do not add mutually exclusive variants together; do count repeated refs separately. Inactive fallback candidates count towards input limits; only reachable playable work counts towards draw limits.

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

Deterministic work expansion is part of the versioned operation contract. Each ordinary shape instance counts as one painted item, even when its path has multiple subpaths. A fill, a detail stroke and each enabled outline stroke are separate passes; a glow emitter adds one blurred pass for each distinct compatible paint operation (fill and stroke are separate). Merge subpaths only when operation/alpha and stroke width/cap/join agree; a solid emission colour does not reinvoke its source gradient. Emission-only geometry still contributes an item and its geometry operands. Eye ellipses expand into separate sclera, optional iris, pupil, each glint, active lid cover, active lid edge and each lash items; lid cover counts whenever its resolved extent is nonzero. Each eye_path/eye_arc is one item, eye_dots is one item per dot, each brow_path is one item, and mouth_path/effect items count individually. Each blush ellipse and ground shadow counts as one item. One shared inset clip counts per ellipse eye using pupils/iris/glints/lid fill/lid edge; those operations reuse it rather than nesting duplicate clips; an outer face clip counts once per face invocation, with nested pupil clips additionally counted. Per-item clips count per invocation. Clip-only target geometry is counted in path work and clip work, but is not a painted item/pass unless separately painted. Gradient uses count per actual fill/stroke invocation, not per distinct paint id. Path numbers count all expanded explicit numeric geometry operands, including repeated clip targets; the operation manifest fixes each generated primitive's numeric operand count identically for R and JS. Limits take the worst legal reachable combination of held face controls, mood, variants, effects and active accessories, not just the five default screenshots. R1a/R1c must record reproducible per-band integer upper bounds from this shared expansion for every canonical fixture before declaring it valid; the JSON syntax/reference checks in this design task are not that evidence.

Operation manifest version 2 and policy version 2 are recorded in docs/character-format/operations.json and limits.json; budgets.json and work-counts.md record the supported reference corpus. Normative integers are separable componentwise upper bounds: sum the per-part maxima, maximum per exclusive accessory slot, face bound, ground and concurrent effects; blur takes a maximum. A cross-component clip reference uses the largest target-geometry cost over band-resolved variants; a same-part item clip uses the already selected source variant. This avoids a Cartesian product; component choices need not form one legal joint frame and must not be labelled an exact joint maximum. R and JS must reproduce the same integer bounds. Resolve face styles then tune, mood/reduced item paints and all reachable opacity/visibility/variant changes first; zero at rest is not proof of zero in every reachable state. Apply accessory LOD like ordinary band overrides. Count visible empty pivots, plus transform-only clip owners/ancestors once; root and pseudo-groups are excluded. The reference must explicitly refuse unsupported constructs. Glow area is a conservative authored-transform bound, not a raster maximum. Resource-sensitive live updates whose bound exceeds the target band reject atomically before application unless a tighter proved bound passes; never silently clamp or drop glow. Drawing-budget diagnostics use code budget and root path $, with explicit full/small/micro context and the metric/component choices in the fix; full is not an authored lod.full object. No runtime guard is implemented here.

Counting-semantic changes increment operation_manifest_version; limit changes increment policy_version. Current versions supersede unfrozen design versions, not released file guarantees. After format-v1 freeze, admission ceilings may rise but not fall for a matching accounting version; a counting change requires a new format version or a compatible old-admission path after freeze, never silently invalidating a previously valid file. Drawing caps remain candidates, not measurements. Complete picked-character fixtures, full R/JS reproduction, per-counter/band rejection fixtures and allocation/band-control decisions remain before freeze.

Input bounds: 256 KiB UTF-8 file, depth 32, 10,000 structural nodes, 256 declared parts, 64 moods, 128 gestures, 64 keys per track, 256 tracks per gesture, 256 effect triggers per gesture. Bound lexical nesting before JSON parsing; walk R lists iteratively before recursive semantic work. Missing values, duplicate JSON object keys, non-finite values and over-limit inputs error with a path. Any integer frame duration is 1..150. Endpoints are checked after all defaults and fallbacks resolve.

Part opacity multiplies ancestor opacity and item alpha on each paint operation; it is not an isolated group-opacity composite. Overlap may therefore darken. A part's glow names exactly one item emitter; it emits only that item's compatible paint operations, not every item in the part. Each emitted fill/stroke group is a separate blurred pass; an emission-only item uses a filled silhouette. Kit glyph emitters are counted separately. No arbitrary blend mode is available.

The file's blur is in design units. The renderer converts explicitly to backing pixels: blur * CSS_width / 300 * DPR. Native shadowBlur is not scaled by the canvas transform ([Canvas shadows](https://html.spec.whatwg.org/multipage/canvas.html#shadows)). Inflate each emitter's transformed bounds by three converted blur radii for the conservative budget estimate; use a bounded scratch rectangle/canvas, not an unbounded full-page surface. The estimate is a cost bound, not an assertion about an exact browser blur kernel. It is summed per blurred paint operation. The full band has no CSS-width cap: normalised work counters cannot promise bounded backing-pixel memory or performance at arbitrary CSS width/DPR. E5c/allocation policy must cover the actual supported envelope. Swap caches the outgoing bitmap; incoming drawing plus at most two host drawImage passes is the separate swap workload, not two vector budgets.

<!-- END source resource rules -->

<!-- BEGIN source format rules -->
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

In every band, an explicit band variant overrides rest, pose, mood, discrete-track and switch variants. Variant anchors follow that final band variant, as in pipeline step 2.3.

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

Effects use generic sweat_drop and sparkle_star operations available to any kit. Valid operation/mode pairs are sweat_drop: progress or track, sparkle_star: pulse or track. Any other pair errors. Each declares items (ordinary shapes without clip), at [0,0], and one valid mode; reduced_items likewise forbid clip because kit definitions cannot bind character-specific item ids. Faceless characters cannot map kit effects or trigger them, but may animate ordinary parts. pulse/track additionally permit reduced_items (static shapes, default empty). Character effects map names to {anchor,layer}; missing anchor is an error. Sweat progress u=effects.sweat in0..1 places geometry at [sway*sin(u*sway_rate),u*travel] with defaults sway2,sway_rate12,travel26; opacity is1 up to fade_at0.9 then (1-u)/(1-fade_at), and u0 suppresses it. It is a static pose control, not a moving particle. Sparkle pulse multiplies scale by 1+amplitude*sin(rate*t), defaults amplitude0.18 (range0..0.5), rate9 (positive<=30), t=min(frame,activity_deadline)/30; after the deadline its phase is held. Reduction retains progress geometry at the same authored u, placement and opacity: it is already a static pose, with no frame dependency. For progress mode reduced_items must be absent; its presence is a validation error. Pulse/track modes instead use reduced_items without pulsing or track motion, at their declared effect origin; empty means hidden. Reduction must not remove Tessa's static worried sweat mark. These reproduce the ordinary effects' semantics with generic data operations, distinct from deferred particles/rings.

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

Effect triggers are {at:0..1,effect:kit_effect_id,anchor:anchor_id}; at most 256 per gesture, all references must exist and work stays within the action deadline. Each trigger creates a separate instance, even for the same effect and anchor; it does not replace another running instance. Budget all instances whose lifetimes may overlap, plus any held mood effect, taking the maximum over mutually exclusive playable gestures/changes. A conservative sum of all triggers in the selected gesture is permitted; never deduplicate by effect name. No ring_pulse is supported. Knurl's discrete clamp variant must include a terminal [1,null], not stop at0.55.

### 3.16 Motion scheduling and host behaviour

Built-in hop adds root.lift = height*sin(pi*u) for normalised action progress u, with no squash/scale contribution; any squash must be an explicit bounded track. Idle breathing multiplies each selected part scale axis by a factor bounded by [1-breathe,1+breathe], rather than adding to that axis. Attachment scale bounds include anchor.scale and reachable variant-anchor scales.

motion.change: style wiggle/hop/gesture (default wiggle), frames18, angle0.06, height8, swap_at0.5; gesture required for style gesture. motion.idle: frames150, blink_every120, blink_jitter30, blink_frames6, breathe0.012, breathe_period90, breathe_part root, extra null. Durations are finite and positive; blink_jitter+blink_frames/2 < blink_every. Breathe amplitude0..0.1, period>0. Change/idle frames integer1..150. Extra names one playable gesture and plays once; no loop.

Mount, a changed mood, gesture, changed held pose or play-after-pause begins one activity window of at most150 frames at30fps. A gesture replaces an in-progress change or gesture and commits the target mood immediately; a later mood change replaces the gesture and starts from the currently shown face. Repeating target mood does not restart. Same-call character/mood applies first; gesture follows. During an animated character swap a supplied valid gesture is discarded because the swap movement owns the window; reduced motion discards movement too. Independent idle/mood_change/gestures/swap/minimising/restoring/messages/others switches retain current meanings. A disabled gesture does not discard other valid fields.

All change, idle extra, effect and delayed tracks share the window's absolute deadline. Schedule a late effect/extra by proportionally fitting its finite duration into the remaining frames; if no frame remains, discard it. New distinct user/server actions can begin a new window, but queued effects/children cannot extend one themselves. Idle fades in the final third; crossing blink windows are skipped. At the deadline settle all channels/effects to the target rest, emit one final frame, cancel RAF. Pause freezes frame time; destroy cancels everything; hidden elements pause scheduling without replaying discarded actions when shown.

Enabling reduced motion settles immediately and clears pending movement. Disabling it does not replay old change/gesture/extra/swap/effects. Colour changes, resize/DPR changes, detail-band changes and redraw do not start activity. Held host gaze is instantaneous, not animation; it clears only look channels. No gaze channels are sent for faceless/no-gaze kits. Shiny status/ARIA use shown state, never a pending invisible target. Build the canvas accessible label from character display name plus shown status, never raw character/mood ids.

Character swap retains today's private-canvas fade, bounded out/in duration, captured outgoing state, retarget/reversal speed and no-visible-pending-target behaviour. Fit total phases to incoming activity budget. Mid-swap mood changes commit without wiggle and do not extend it. Reduction or swap:false finishes immediately; re-enabling never replays it. Same id/content is ordinary update; same id/different content is rejected before state change.

<!-- END source format rules -->

<!-- BEGIN source accessory and capability rules -->
### 3.17 Addressable accessories and later composition

An accessory definition has description, slot, anchor and parts (ordinary part templates with local ids/parents/layers/items), optional colours and lod. wear lists active accessory ids; two active items in one slot error. Instantiate template part ids under a stable prefix wear_<accessory>_<local_id>; collisions with character parts error. Root accessory parts inherit the selected anchor's matrix and visibility; internal parents use local ids, then are expanded. Shapes/colours resolve to character roles. Channels may address expanded part ids, making bow follow-through possible later. Template layer values are absolute draw layers, independent of parenting; all expansions count towards budgets.

An anchor asking for a missing part/variant is an error. A structurally present anchor whose owner is hidden/collapsed is unavailable for painting that frame, and its attached subtree/effects are hidden too. No fallback to origin. This simple attachment contract does not provide fitting: shared wardrobe surfaces, arbitrary limb substitution and automatic adaptation remain later work.

Cross-family remix is an authoring operation, not renderer inheritance. A component declares required anchors, roles, parts and capabilities. A user can add an anchor on a real part, map roles/targets explicitly, and choose one final family. Mixing family ids itself proves no compatibility. Produce a new complete checked character; retain no donor lookup chain. Full remix export/promotion may wait; prototype only bounded cases on a development branch.

### 3.18 Version/capability compatibility

Supported capabilities in0.1.0: parts, paints, clip, outline, glow, face_kit, tracks, lod. requires is mandatory and contains every capability used after family/kit/accessory resolution; a superset of known capabilities is permitted. Builder/read-resolve tooling computes it, but the checker does not silently fix a submitted file. Missing/unknown/unsupported names error. Ordinary basic shapes require parts. Faces require face_kit; kit emissive glow additionally requires glow. Every file's format_version is1; later additive capabilities can extend1 only without changing existing field meanings.

Reserved unsupported fields/capabilities: extends, connector, ring_pulse, follow, particles, morph, blend, inputs, fit, wardrobe, vividness. Report "not supported by this version of mascot" and a stable capability code; name a minimum package version only if an actual support table provides it. Do not invent 0.1.1 or promise format2. Paper contracts: connector links two existing world anchors, clamps inset to half nonzero length and draws nothing at coincident endpoints; typed numeric inputs require finite type/range/default and explicit channel mapping. Their namespaces/composition rules still need later review; reservation alone is not proof of future compatibility. Neither is an accepted v1 runtime example.


<!-- END source accessory and capability rules -->

<!-- BEGIN source resolution and validation rules -->
## 5. Families, identity and resolution

Family fields: id, name, description (required); defaults (object, default{}). Defaults may include outline, face, moods, gestures, motion, colours/colour_descriptions/follows/brand/contrast and palettes. Family gesture defaults use root channels only (root.rotate, root.lift, root.scale_x and root.scale_y); character-local overrides explicitly name their own anatomy. A conventional part name never opts a member into an anatomical family motion. They may not add parts, anchors, ground, accessories or wear. A suggested starting character is a builder/UI choice, never implicit anatomy. Family kit defaults are checked against each actual character after merge; missing declared needed parts in character-local gesture overrides invoke checked fallbacks. Built-in families: hexonians, elementals, visorfolk. New families are checked objects, not hard-coded engine branches.

A source character references a known family or supplies family_definition {id,name,description,defaults}. That id must equal family; duplicate/conflicting source definitions for a registered family error. A resolved family_definition is a local metadata snapshot, not a source default definition: it never registers/replaces family defaults and is never compared against the live default map. Snapshot labels are preserved on that character even if today's registry labels differ; the global family listing uses registry labels. A snapshot cannot be used as a known-family source of defaults for a new character. The checker first validates family structure, applies the deterministic merge in3.13, then validates semantic geometry/references/limits. It marks output resolved:true and materialises all family-provided behaviour defaults. Stable version1 operation defaults may remain implicit, but complete kit definitions must be embedded. A saved resolved file embeds family_definition {id,name,description,defaults:{}} and complete resolved values; its resolved:true prevents reapplying package family defaults on read. A claimed resolved file still receives every semantic check and complete-required-field check. This preserves the category/identity without a live inheritance link. Resolution also computes palette_sources with exactly the keys of palettes and values character or family. A whole character-level palette replacement has character origin, including an identical-value replacement; an inherited palette has family origin. Source specifications omit palette_sources; raw resolved input must supply and validate it ({} when no palettes). Save/read preserve this checked origin map without consulting current family defaults. Synthetic original is native listing metadata, not a stored palette/source-map entry. Every resolved/saved face embeds its complete face.kit_definition with matching id, including classic/screen. Source kit ids select authoring defaults only; resolution copies the complete kit. Read/render uses the embedded definition, never substitutes today's package kit by id. Version1 operation semantics remain frozen; changed operation semantics require a format version change. Custom and built-in snapshots receive the same checks. No external asset lookup or script is permitted.

Source-only palette opt-out: palettes may contain an inherited family palette id with null to omit that entire palette. The id must exist in family defaults; a null for an unknown id errors. Resolution removes the entry and its provenance; resolved/saved palettes contain no nulls. Inherited palettes naming a missing character role error unless explicitly omitted; never guess a role mapping or silently skip the palette. Complete character palette replacements remain atomic. The R builder exposes omit_family_palettes for this source operation.

R distinguishes draft authoring components, source character specification, fully checked mascot_character_data, and the public mascot_character selector/helper. Never accept an unchecked draft as UI character data. Input/output class fields are internal. A supplied checked object is verified for integrity/content before use, since R lists can be mutated. Id lookup, direct object and built-in paths converge on the same checker. Registration has R-process lifetime, is explicit and intended only for app start-up/development (reject an active Shiny reactive domain), writes no files, and cannot replace built-in ids. Per-visitor characters pass checked objects directly and never enter the shared process registry. Listings by id describe the process catalogue, not another visitor's objects. Re-registering identical content is idempotent; conflicting content with the same id errors. Remix requires a new explicit permanent id; final family is required even for a hybrid. Only runtime instance id belongs to Shiny; it is distinct from character id and part/anchor ids.

## 6. Validation contract

Pure R jsonlite/checkmate/cli, no mandatory schema/V8 framework. One ordered process: bounded input/JSON syntax and duplicate keys -> version/capabilities -> key/type/local ranges -> family/kit structure -> deterministic resolution -> unique ids/acyclic parents -> paints/roles/paths/shape refs -> variant/clip/anchor integrity -> mood and gesture fallback/needs resolution -> reachable composed channels -> expanded per-band work/budgets -> built-in contrast promises and required core states. Stop a dependent stage when its prerequisite fails. In format version 1 the R checker stops at the first problem and reports its exact JSON path, code, value and fix suggestion (founder decision, 2026-10-14); collecting several independent problems per stage is a later improvement for the AI-skill loop.

R conditions use the classes in the companion API document section1: specific argument/choice/dots/character/file classes inherit mascot_error; update/contrast/preset/unknown-name warning classes inherit mascot_warning. Character failures retain stable code/path/value/fix fields. Preserve informational mascot_placement_ignored inheriting mascot_message. Browser diagnostics carry matching codes where applicable but are not R conditions. JSON paths use $.parts[0].items[1].fill (zero-based arrays) consistently in R/JS diagnostics, irrespective of R list indexing. Stable common codes: input_type, version, capability, unknown_key, non_finite, missing_reference, invalid_channel, invalid_colour, budget. R-only family/global semantic checks have their own codes. JS guards only its documented common subset, plus runtime state membership; compare code/path for common bad fixtures, not every first English message from every R-only check.

Built-in authored contrast promises error below3:1 for required graphic details in both resolved modes, using the explicit declared foreground/background pairs below; no geometric overlap guessing. A built-in character with a face must declare at least one pair whose foreground is its face feature role (`face.colours.feature`, else `feature`), so its eyes and mouth always carry a checked promise (founder decision, 2026-10-14). New characters target4.5:1 but missing that aim alone does not reject a valid3:1 character. Decorative accents need not become false hard promises. User colours remain exact and warn in development mode, always in preview/studio unless explicitly silenced; CSS-resolved warnings belong to browser diagnostics. Status text retains its independent accessibility requirements. Save/check never silently recolours.

Contrast backgrounds are authored promises: bg identifies a solid role/page baseline; optional bg_paint identifies the specific background paint composited over that base. Check every resolved mode/preset under test. For gradients, derive conservative per-channel min/max bounds across stops and alpha composition over bg; convert these to a luminance interval and use the nearest possible background luminance to foreground luminance for the worst contrast. A translucent foreground is composited over the same background bounds before comparison; an unprovable bound is unverified, never pass. This may conservatively reject a good-looking gradient; it cannot call an uncertain backdrop a pass. Authors can use a solid declared face backdrop instead. Arbitrary overlapping/translucent artwork not represented by a declared pair is unverified, reported for visual review, never silently inferred as a contrast pass.

At default host root x/y/rotation/scale, every reachable authored mood, gesture, effect and accessory, including automatic blink/gaze ranges, must fit the 300x300 frame, including strokes and conservative three-blur-radius bounds. R1c computes conservative transformed bounds; E5b tests boundary cases and captures all bands. If bounds cannot be proven, require an explicit bounded fixture check before acceptance. Arbitrary externally supplied root/held-pose transforms or face scaling can deliberately clip and are not covered by this authored-fit promise; safety ranges are not a promise that every external transform fits; preview reports that limitation. There is no automatic fitter. A local hat y of about -248 alone does not prove overflow: the ground is at270 and full transformed extents must be calculated.

R examples of useful diagnostics: "$.anchors.tool_grip.part names elbow, which is not a declared part"; "$.gestures.wave.fallback -> rock -> wave is cyclic"; "$.requires omits glow used by the screen kit". None is claimed to be an implemented message yet.

## 7. Colour and palette precedence

For the selected mode, build a baseline from original colours plus mode overrides. Select a named preset after family/character resolution; character preset of the same id atomically replaces family preset. A preset has description, light and dark role maps; missing dark map uses that preset's light map, while missing individual roles retain baseline values. Reserve original as a synthetic palette available for every character: it means native mode colours with no preset overrides; user/family presets cannot redefine it. Listing source is native. A role literal, gradient stop or style must resolve to a declared semantic role.

Then build supplied overrides: preset leaders -> explicit light/dark map or brand leaders -> CSS-selected roles (existing CSS priority). Resolve follows recursively only from supplied/filled leaders, never from untouched baseline leaders. Detect cycles; use first available ordered leader. Next apply mood recolour/item style choices to roles without an explicit user override on that destination. Explicit supplied role colours remain exact; an explicit role cannot be overwritten by follows or mood recolour. CSS mapping with missing/invalid value returns that role's baseline and warns, and blocks follows for that destination, as today. A theme replaces the prior theme, rather than incrementally leaking old overrides.

Mood recolour redirects a role to another resolved role; source/destination chains must be acyclic and are resolved before gradients. User override on the destination wins; an overridden source can still supply a non-overridden destination. Transparency is composed only during painting, not by mutating supplied colour channels. Mode/preset/recolour changes invalidate paint caches; no movement replay. Status never depends on colour alone.

Family presets are not automatically portable across unrelated role systems. On swap, re-resolve retained theme for the incoming character; explicit unknown roles are ignored for retained themes, while an explicit new invalid map/preset rejects the atomic patch. Founder-approved missing-retained-preset policy (2026-10-14): discard the unavailable retained preset with a development warning, use the incoming native baseline and keep valid explicit overrides; do not silently select a similarly named palette. An explicitly supplied invalid incoming preset still rejects the atomic update. Palette inspection uses the actual three release characters in light/dark and all sizes.

<!-- END source resolution and validation rules -->
