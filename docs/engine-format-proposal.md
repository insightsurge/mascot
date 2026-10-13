# Proposal: the enhanced engine and the character file format (v1)

Status: proposal for the founder, 2026-10-13. Design only: nothing in the package changes with this document.
Branch: `design/engine-format`. Inputs: `AGENTS.md`, `docs/scope.md`, `.claude/rules/js-css.md`,
`.claude/rules/r-code.md`, `inst/characters/tessa.json`, `inst/www/mascot-draw.js`, `inst/www/mascot-motion.js`,
`inst/www/mascot.js`, `inst/www/mascot-host.js` (theme code only), the R files named in the brief, and the
attached notes on the founder's picks (Sonnet round 5, the improved Tessa and Neer, the wardrobe model).

Contents: 1 Summary and principles · 2 Engine changes · 3 The format · 4 Examples · 5 Families ·
6 Validation · 7 Authoring · 8 R API effects · 9 Build plan · 10 Decisions for the founder · 11 Risks and
what is left out.

---

## 1. Summary and principles

### Summary
1. A character becomes one JSON file, `format_version: 1`, read and checked by R and drawn by the JavaScript engine.
2. The file describes a **tree of parts** (parent, pivot, position, layer), each drawn from a few shape primitives.
3. The engine gains nine primitives: part tree, gradients, clipping, an outline pass, glow and opacity, a face kit
   renderer, keyframe tracks, levels of detail, and a connector between two anchors.
4. Faces, moods, gestures, poses, effects and per-mood part changes move out of code into data.
5. Today's face drawing becomes a shipped face kit (`classic`); robots get a second kit (`screen`).
6. Families are mandatory and supply defaults (outline, face kit, moods, gestures, motion), never anatomy.
7. `mascot_check_character()` checks everything the engine relies on and reports every problem with where and how
   to fix it; the engine keeps only a thin guard.
8. Features planned for later (springs, particles, changing outlines, blend modes, wardrobe fitting) have reserved
   keys that fail clearly in v1 instead of being ignored.
9. Every picked character (Tessa, Sela, Brim, Iso, alpha_visor, Knurl, Neer, Cinder) can be written in v1 with no
   character-specific engine code; Cinder's moving flame outline waits for `morph` and uses per-mood shapes.
10. The build plan is 18 small PRs on two parallel tracks (engine and R), then one PR per character.

### Principles
- **The file holds the character; the engine holds the rules.** Timing, the five-second limit, reduced motion,
  seeded randomness, performance budgets and accessibility (status text, `role="img"` label) stay in the engine and
  cannot be switched off from a file.
- **Data only.** No expressions, no functions, no URLs in a file. Numbers, names and fixed vocabularies.
- **Pure drawing.** A frame stays a pure function of (character, state, frame number), as today's `pose()` and
  `draw()` are. Nothing in the file can read a clock or `Math.random()`.
- **Unknown means error.** An unknown key, an unknown name or a reserved-for-later key is an error with a fix,
  never silently ignored ("a parser accepting fields without a faithful render is not enough").
- **Names are snake_case and permanent.** Character ids, part ids, colour roles, anchors, moods and gestures.
- **One checker.** R is the authority (`mascot_check_character()`); JS guards only what it needs to draw safely.
  Both read the same bad-file fixtures in tests so they cannot drift.
- **Same path for everyone.** Built-in characters load through the same read, check and register path as user
  files.
- **Small sizes are designed, not shrunk.** Each character says what it shows at 160, 96 and 24 px.
- **The mood never carries meaning alone.** Status text sits beside every mascot at every size; per-mood colour
  (a chest light, a blue core) is decoration on top.

---

## 2. Engine changes

### 2.1 What the engine does today (the base)
- `mascot-draw.js` draws one fixed recipe: shadow, feet (`stand`/`tuck`), the `body` list of shapes
  (`hexagon`, `path`, `circle`, `roundRect`, `rect`), the face (hard-coded eye, brow and mouth functions tuned by
  `FACE_STYLE`), accessories at one of 16 fixed anchor names, sparkle, sweat, then two single-capsule arms.
- `mascot-motion.js` computes a pose per frame: mood change (`wiggle` or `hop`), gestures (`nod`, `wave`) as
  timelines of absolute pose values, idle breathing and seeded blinks, all within a 150-frame window
  (five seconds at 30 fps). Reduced motion returns the target mood at once.
- `mascot.js` checks structure in the browser; `mascot-host.js` resolves themes (`follows`, `brand`,
  `shadeColour()`).

The motion core (pure `pose()`, activity window, swaps through an offscreen canvas, reduced motion) is sound and
stays. What changes is **what** a pose can address: today a fixed list of pose fields (`DEFAULT_POSE`); in v1 any
declared part property, through named channels.

### 2.2 The smallest set of new primitives

| # | Primitive | What it does | Why the picks need it |
|---|---|---|---|
| 1 | **Part tree** | Parts with `parent`, `at` (pivot position in the parent), `rotate`, `scale`, `layer`; world matrix = parent matrix × local matrix. Draw order comes from `layer` (stable sort, computed once), not from parentage. | alpha_visor's head on a neck, Knurl's jointed clamp arm, Sela's hair front and back, Brim's cap. |
| 2 | **Paints** | Linear and radial gradients whose stops are colour roles (so themes recolour them). Coordinates in the part's own space. | Tessa's gem body and gold rim, Cinder's flame, Neer's depth, gloss on every Visorfolk shell. |
| 3 | **Clip** | Clip an item to another item's outline (`"clip": "body.inner"`); the clip moves with that item's part. | Facets, rim light and sheen inside a body; scanlines inside a screen; liquid inside a flask. |
| 4 | **Outline pass** | Per-character outline (width, colour role, joins) applied to items marked `outline: true`; optional second contour; overrides per level of detail; `none`. | Slim black outlines on Hexonians; ivory plus ink double contour from round 5; heavier relative outline at 24 px. |
| 5 | **Glow and opacity** | Per part: `opacity` (0–1) and `glow` (colour role, blur, alpha) via `shadowBlur`, inside a budget. | Screen faces, chest light, time blocks, chart panel, Cinder's light. |
| 6 | **Face kit renderer** | Draws eyes, brows and mouths from a kit file: shapes with numeric controls (`look`, `lid`, `open`), mirrored for left and right; `painted` (ink on body) or `emissive` (glow colour on a dark screen). | Today's faces as presets; irises; screen faces for Visorfolk; Cinder's mask. |
| 7 | **Tracks** | Keyframes on named channels (`head.rotate`, `root.lift`, `face.blink`); numeric channels add to the mood's value or set it; discrete channels switch; named easings. Mood change, gestures and idle extras are all tracks. | Gestures on any part (nod on a neck pivot, cap tip, hat hop, divider flourish, flare). |
| 8 | **Levels of detail** | Three bands chosen from the rendered CSS size: `full` (128 px and above), `small` (48–127 px), `micro` (below 48 px). Parts and items say where they show; the file can override outline, face and glow per band. | 160, 96 and 24 px versions of every pick. |
| 9 | **Connector** | A stroke or capsule drawn between two anchors in world space, recomputed every frame, so it stretches when parts move. | The molecule's bonds; a cable on Knurl (optional). Can come after the first eight. |

New **shape types** inside items (not new primitives, just more shapes): `ellipse`, `polygon` (regular n-gon with
corner radius; `hexagon` stays as the six-sided case), `polyline` (stroke only), `arc`, and `ref` (reuse a named
shape). `path` keeps today's absolute subset (`M L Q C Z`): it is what SVG editors write after "absolute
coordinates", and keeping it small keeps parsing simple. No `A` (elliptical arc) command: `arc` and `ellipse` cover
it.

What the engine does **not** gain in v1: expressions, scripting, physics, path morphing, particles, blend modes,
text. Each has a reserved key (section 3.17).

### 2.3 Render pipeline
For each frame `n` (only while the activity window is open; one resting frame afterwards, as today):

1. **Mood.** Resolve the shown mood (the target, or the previous one before the change's `swap_at`), following
   `fallback` if a mood is missing.
2. **Base channels.** Part defaults → the mood's `pose` (a named entry in `poses`) → the mood's own `channels`.
3. **Change track.** During a mood change, add the change track (`wiggle`, `hop` or a named gesture).
4. **Gesture track.** During a gesture, apply its tracks (add or set), then switch rules (for example feet tuck when
   `root.lift > 6`).
5. **Idle.** Breathing (scale on `root`) and seeded blinks (`face.blink`), fading out over the last third of the
   window, as today.
6. **Held pose.** Values held by `update_mascot()` win last, as today.
7. **Transforms.** Local matrix per part from its channels; world matrices down the tree; `keep_upright` parts
   cancel inherited rotation.
8. **Level of detail.** Drop parts and items not shown at the current band; apply the band's overrides.
9. **Draw list.** Parts in layer order (precomputed per character and band). Per item: save → world transform →
   clip (if any) → glow (if any) → fill (colour role or paint, with alpha) → stroke → outline → restore.
10. **Face.** Drawn as part of the part it belongs to, at the face's own layer.
11. **Effects.** Sparkle, sweat and ring pulses from the kit, at their anchors.
12. **Composite.** Character swaps keep today's offscreen canvas and single `globalAlpha` composite.

**Caches** (built once per immutable description, as today's `WeakMap`s): parsed `Path2D` per path string; the
sorted draw list per (character, band); gradients per (character, resolved palette, item), rebuilt only when
colours change; resolved face kit per character.

**Seeded randomness** stays in one place: the blink hash in `mascot-motion.js` (and later particles) uses the
mascot's `seed`; nothing in a file can ask for randomness except through those engine features.

### 2.4 Performance budget
These are **targets to measure**, not measurements. The validator enforces the counts; the timing target is
checked by a performance script (build plan, PR E5).

| Budget, per character and band | `full` | `small` | `micro` |
|---|---:|---:|---:|
| Parts | 64 | 40 | 16 |
| Path numbers (sum over all `d` strings drawn) | 1,500 | 900 | 300 |
| Clips | 8 | 4 | 1 |
| Gradients | 16 | 8 | 2 |
| Glowing parts (`glow` set) | 4 | 2 | 0 |
| Glow blur (canvas units) | 16 | 10 | – |
| Particles (later) | 24 | 8 | 0 |

Frame-time target: at most 4 ms per frame for one mascot at 160 px with a fourfold CPU slow-down in headless
Chrome, measured over a gesture and a mood change. If a picked character misses it, the fix is in its file (fewer
glows, a simpler small band), not a special case in the engine.

Why glow is the tight one: `shadowBlur` cost grows with the blurred area and is the effect round 5 flagged as
unmeasured on phones. A glow is therefore per part (never per item), capped in number and radius, and off at 24 px.

### 2.5 What moves out of code
Every item listed as hard-coded in the context pack (attachment A, section 5), with its new home.

| Today | New home |
|---|---|
| `R/moods.R:3-14` five mood names and descriptions in `mood_table()` | Family file (shared moods with descriptions and status words); character file `moods` (look, status, fallback). The **five names** stay a package constant (`shared_moods()`) because R code (busy mood, validator binding) relies on them. |
| `R/moods.R:49-51` mood check against `mood_table()` | Per character: the character's moods, plus fallbacks. |
| `R/moods.R:57-60` status label by capitalising the name | `status` in the mood (`"Thinking"`), from the family when the character does not set it. |
| `R/gestures.R:3-11` gestures `nod`, `wave` | Family `gestures` (shared library) and character `gestures`; `nod` and `wave` stay required names (each character has them or a fallback). |
| `R/gestures.R:59-61` gesture check | Per character, with fallbacks. |
| `mascot-draw.js:181-205` `DEFAULT_POSE` | Engine keeps the rig channels (`root.*`, `face.*`) with neutral defaults; everything else becomes part channels with defaults in the file. |
| `mascot-draw.js:217-242` `FACE_STYLE` | Face kit file `inst/faces/classic.json` (sizes, glints, lashes, brow offsets); characters override numbers in `face.tune`. |
| `mascot-draw.js:248-251` names of eyes, mouths, brows | The face kit's style names; the character may add styles. |
| `mascot-draw.js:252` five shape types | Engine shape list (now nine types); still an engine list, because each is drawing code. |
| `mascot-draw.js:253-270` 16 fixed anchor names | Any snake_case anchor name declared in the file; a recommended vocabulary (section 3.11) for wardrobe sharing. |
| `mascot-draw.js:301` feet `auto`/`stand`/`tuck` | Foot parts with `variants` (`stand`, `tuck`) and a `switch` rule (`root.lift` above 6 → `tuck`). |
| `mascot-draw.js:325-342` lash counts and angles | Face kit (`lashes` items per eye style). |
| `mascot-draw.js:344-408` eye drawing | Face kit eye styles (sclera, iris, pupil, glints, lid), drawn by the generic face renderer. |
| `mascot-draw.js:442-468` brow paths | Face kit brow styles (paths with left/right mirroring). |
| `mascot-draw.js:471-529` mouth drawing | Face kit mouth styles (paths, arcs, filled shapes, teeth and tongue items). |
| `mascot-draw.js:540-561` sweat drop | Kit effect `sweat` (shape) plus its track (fall and fade); placed at the `sweat` anchor. |
| `mascot-draw.js:563-577` sparkle star | Kit effect `sparkle` (shape) plus its pulse track; placed at the `sparkle` anchor. |
| `mascot-draw.js:713-740` feet | Ordinary parts in the file. |
| `mascot-draw.js:794-809` capsule arm and paw | Ordinary parts (`arm_l`, `arm_r`, or jointed `upper`, `fore`, `hand`) in the file; arm presets become `poses`. |
| `mascot-motion.js:173-199` motion defaults and `nod`/`wave` timelines | Engine keeps safe defaults; files and families set `motion.change`, `motion.idle`; `nod`/`wave` become family gestures written as tracks. |
| `mascot-motion.js:200` change styles `wiggle`, `hop` | Engine presets `wiggle` and `hop` stay (cheap, well tested); `motion.change.style: "gesture"` plays any named gesture as the change. |
| `mascot-motion.js:250` 150-frame cap | **Stays in the engine.** Files cannot raise it; the validator rejects longer gestures. |
| `mascot-motion.js:294-305` blink hash | **Stays in the engine** (seeded); files set spacing and duration only. |
| `mascot-motion.js:354` reduced motion | **Stays in the engine.** Files may add `reduced` stills (section 3.14), never turn it off. |
| `mascot-motion.js:374-376` hop and wiggle formulas | Stay as engine presets, with `angle`, `height`, `frames` from the file. |
| `mascot-motion.js:379-384` breathing | Stays in the engine; amplitude and period from the file; the part it scales is `root` unless `motion.idle.breathe_part` names another. |
| `mascot-motion.js:136` swap 30/30 frames | Stays a mount option in the engine (it concerns two characters, not one). |

---

## 3. The format (v1)

### 3.0 Conventions
- **File:** UTF-8 JSON, one character per file, file name `<id>.json`. Built-ins live in `inst/characters/`;
  face kits in `inst/faces/`; families in `inst/families/`.
- **Keys:** snake_case, `^[a-z][a-z0-9_]*$`. Ids of characters: `^[a-z][a-z0-9_]{1,31}$`.
- **Units:** canvas units. The character's design box is about 200 units wide; the host scales to the CSS size.
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
| `family` | string | required | Id of a family file the package knows (built-in or registered). |
| `description` | string | required | One or two plain sentences: who the character is and what it suits. |
| `pronouns` | string | none | Free text ("she/her"); used in docs and the studio only. |
| `requires` | array of strings | `[]` | Engine capabilities the file uses (section 3.18). Unknown: error "needs a newer mascot". |
| `colours` | object | required | Colour roles (3.2). |
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
`teeth`, `tongue`) and maps them through `face.colours` if the character names them differently.

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
| `min` | number | `3` | 3 for graphics, 4.5 for small face details. |
| `where` | string | none | Plain words for the message ("eyes on the visor"). |

**`modes`**: `{ "dark": { "colours": { role: colour } } }`. Roles not listed keep their light value. This is how
Neer's dark flip (light body, ink features) is written, and how Tessa keeps one palette (no `dark` entry).

### 3.3 Palettes (presets)
`palettes`: `{ preset_id: { description, light: { role: colour }, dark: { role: colour } } }`. A preset lists
**leaders only** (usually the brand roles); `follows` derives the rest. The studio palette picker shows each preset
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
| `shape` | one of `polygon`, `hexagon`, `circle`, `ellipse`, `rect`, `round_rect`, `path`, `polyline`, `arc`, `ref`, `connector` | required | |
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
| `connector` | `from`, `to` (anchor names), `width`, optional `inset` (shorten each end) |

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
| `glow` | object or `null` | `null` | `{ "colour": role, "blur": n, "alpha": a }` within budget. |
| `visible` | boolean | `true` | |
| `keep_upright` | boolean | `false` | Cancels inherited rotation (Knurl's spanner stays head up). Position still follows the parent. |
| `no_flip` | boolean | `false` | Keeps orientation when the character is flipped (a card with a printed side). |
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
| `effects` | `{ "sweat": 0.35, "sparkle": true, "ring_pulse": "light" }` | Effects from the kit. |

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
| `description` | string | none | Shown by `mascot_anchors()`. |

Names are any snake_case string. Paired anchors are written out (`hand_l`, `hand_r`), not generated from one entry
as `shoulders` and `feet` are today. **Recommended vocabulary** (so shared accessories find their place):
`crown`, `forehead`, `hair`, `eyes`, `upper_lip`, `chin`, `neck`, `collar`, `chest`, `back`, `waist`,
`shoulder_l/r`, `hand_l/r`, `foot_l/r`, `face`, `sparkle`, `sweat`. An accessory asking for an anchor the
character lacks is a check error, never a silent `(0, 0)`.

### 3.12 Face

| Key | Type | Default | Rule |
|---|---|---|---|
| `part` | part id | required | The face moves with this part (Tessa: `body`; alpha_visor: `head`; Cinder: `mask`). |
| `at` | `[x, y]` | `[0, 0]` | Face centre in the part's space. |
| `scale` | number | `1` | |
| `layer` | number | part's layer + 0.5 | |
| `kit` | kit id | from family | `classic` or `screen` (shipped); more kits later. |
| `render` | `"painted"` or `"emissive"` | from kit | Emissive draws features in the glow role with a small glow, no sclera. |
| `clip` | `"part.item"` | none | Keep the face inside a screen or mask. |
| `eyes` | object | kit default | `{ "y": -12, "spacing": 30, "lashes": true, "iris": "iris" }` (`iris` role or `null` for today's black pupils). |
| `mouth` | object | kit default | `{ "y": 24 }`. |
| `blush` | object or `null` | `null` | `{ "x", "y", "rx", "ry", "alpha", "strong_alpha" }`; roles `blush`, `blush_strong`. |
| `colours` | `{ kit_role: role }` | identity | Map kit roles to this character's roles. |
| `tune` | object | `{}` | Number overrides of kit styles (today's `face.style`), by style and key. |
| `styles` | object | `{}` | Extra or replaced eye, brow and mouth styles, in the kit's own item format. |
| `caps` | `{ "left", "right", "join" }` | `round`, `round`, `miter` | Today's `face.outline`. |

**Face kit file** (`inst/faces/<kit>.json`): `roles` (what it needs), `eyes`, `brows`, `mouths`, `effects`. Each
style is a list of items in eye-local (or mouth-local) space, drawn for the right eye and mirrored for the left
(unless `mirror: false`). Items may carry three controls the renderer understands:

| Item control | Meaning |
|---|---|
| `"look": 1` | Moved by `face.look_x/y` × the kit's `look_range` (today 7 units). |
| `"lid": true` | The eyelid: filled from the top down to `max(style lid, face.blink)` and clipped to the sclera. |
| `"clip_to": "sclera"` | Clip to another item of the same eye (pupil and glints inside the eye). |

Kit styles declare named numbers (`"params": { "ew": 16.5, "eh": 19.5, "pr": 10 }`) and items may use a param's
name in place of a number (`"rx": "ew"`): a bare name only, no arithmetic. `face.tune` overrides those numbers per
style, which is how today's `face.style` overrides carry over.

An eye style may be one name for both eyes or a pair (`["open", "happy"]` for a wink). `blink` above 0.96 swaps to
the `closed` style, as today.

### 3.13 Poses
`poses`: `{ pose_id: { channel: value } }`. Today's arm presets become poses:
`"wave": { "arm_l.rotate": 1.85, "arm_r.rotate": -1.0 }`. A mood names one pose and may add channels on top.

### 3.14 Moods

| Key | Type | Default | Rule |
|---|---|---|---|
| `description` | string | family's | Plain words. Required for moods the family does not define. |
| `status` | string | family's | The status word shown beside the mascot ("Thinking"). |
| `fallback` | mood id | none | Required for moods outside the shared five; chain ends in a shared mood; acyclic. |
| `pose` | pose id | none | |
| `face` | `{ "eyes", "mouth", "brows", "look_x", "look_y", "lid", "blush" }` | kit defaults | |
| `channels`, `recolour`, `items`, `effects` | see 3.9 | none | |
| `reduced` | object | none | What to show instead of motion when reduced motion is on (rarely needed: the target still is the default). |

**Shared moods**: `idle`, `thinking`, `happy`, `worried`, `celebrating`. Every character defines all five (the
first one in the file is no longer special: `idle` is the starting mood). A character may add moods
(`processing`, `offline`) with a `fallback` to a shared one; R accepts those names for that character only.

### 3.15 Gestures

| Key | Type | Default | Rule |
|---|---|---|---|
| `description` | string | family's | |
| `frames` | integer 1..150 | required | Compressed further by the activity window, as today. |
| `fallback` | gesture id | none | Used when this gesture cannot play (for example `wave` without arms → `rock`). |
| `needs` | array of part ids | `[]` | If a needed part is missing (family gestures on a character without it), the fallback plays. |
| `tracks` | `{ channel: track }` | required | |
| `effects` | array | `[]` | `[{ "at": 0.4, "effect": "ring_pulse", "anchor": "chest" }]`. |

A **track** is either a list of keyframes or an object:
- list: `[[at, value], [at, value, ease], ...]`, `at` in 0..1 ascending, first `0` and last `1`;
- object: `{ "mode": "add" | "set", "keys": [...] }`. Numeric channels default to `add` (the value is added to
  the mood's value, so one `nod` suits every mood); discrete channels (`variant`, `visible`, face styles) always
  `set` and switch at their keyframe. In `set` mode a value of `null` means "the mood's own value" (today's
  `pose: {}`).
- `ease`: `linear` (default), `ease_in`, `ease_out`, `ease_in_out`, `step`.

**Shared gestures**: `nod`, `wave` (and `rock` as the usual fallback). Character-specific gestures (`beep`,
`cap_tip`, `flare`, `crest_flex`) are allowed by name for that character.

### 3.16 Motion and effects
`motion`:

| Key | Type | Default | Rule |
|---|---|---|---|
| `change.style` | `wiggle`, `hop`, `gesture` | `wiggle` | `gesture` plays `change.gesture` as the change. |
| `change.gesture` | gesture id | none | Required when style is `gesture`. |
| `change.frames` | integer ≤ 150 | `18` | |
| `change.angle`, `change.height` | numbers | `0.06`, `8` | For `wiggle` and `hop`. |
| `change.swap_at` | 0..1 | `0.5` | When the new face appears. |
| `idle.frames` | integer ≤ 150 | `150` | Activity window. |
| `idle.blink_every`, `idle.blink_jitter`, `idle.blink_frames` | integers | `120`, `30`, `6` | Checked: jitter + half duration < spacing. |
| `idle.breathe`, `idle.breathe_period` | numbers | `0.012`, `90` | |
| `idle.breathe_part` | part id or `root` | `root` | |
| `idle.extra` | gesture id | none | One extra idle gesture played once per activity window (alpha_visor's antenna blink). Never loops. |

`effects`: per character placement and overrides of kit effects:
`{ "sweat": { "anchor": "sweat" }, "sparkle": { "anchor": "sparkle" }, "ring_pulse": { "max_rings": 2 } }`.
Kit effects in v1: `sweat`, `sparkle`, `ring_pulse` (one to three expanding rings from an anchor, each ending
within the gesture). All three are bounded tracks, not loops.

### 3.17 Accessories, and keys reserved for later
`accessories`: `{ item_id: { description, slot, anchor, side, items, colours, lod } }`, as today plus
`description` and `lod`; `slot` prevents two items in one place. `wear` lists the defaults.

**Reserved keys** (present in v1: error "not supported yet; planned for format 2", with the issue number once one
exists):

| Key | Where | Planned meaning |
|---|---|---|
| `extends` | top level | Character inheritance (decision 3). |
| `follow` | part | Spring follow-through: `{ "source": "root.rotate", "lag": 4, "damping": 3, "frequency": 8 }`, computed in closed form from the frame number, so still seekable and deterministic. |
| `particles` | top level, gesture | Seeded, bounded particle bursts (sparks, leaves, droplets) that end with the gesture. |
| `morph` | part | Outlines that change shape: paths with the same commands, blended by a channel (Cinder's height and lean, Neer's crest flex). |
| `blend` | item | `screen` / `lighter` compositing (caustics, flame light). |
| `fit`, `wardrobe` | accessory | Fit adapters and shared wardrobe items (attachment E). |
| `inputs` | top level | App values mapped to channels (the flask's `progress`, section 4.8). |
| `vividness` | palette | Saturation control (later API idea). |

### 3.18 Capabilities (`requires`)
The engine and R share one list of capability names for v1: `parts`, `paints`, `clip`, `outline`, `glow`,
`face_kit`, `tracks`, `lod`, `connector`. A file lists the ones it uses (the validator can fill this list
in). Later engines add names (`follow`, `particles`, `morph`, `blend`, `inputs`); an older package that meets an
unknown name says "this character needs a newer version of mascot (capability `morph`)". This lets format 1 grow
without a new version number for every feature, and fails clearly instead of drawing something wrong.

---

## 4. Examples

The `//` lines are reading notes; remove them for a real file (or turn them into `note` strings).

### 4.1 alpha_visor in full

```json
{
  "format_version": 1,
  "id": "alpha_visor",
  "name": "alpha_visor",
  "family": "visorfolk",
  "description": "A calm helper robot with a screen face and a hard hat; suits build pipelines and job logs.",
  "requires": ["parts", "paints", "clip", "outline", "glow", "face_kit", "tracks", "lod"],

  // Roles: a light shell with a dark screen; the face contrasts with the screen, not the page.
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
    "shell_shade": { "from": ["shell"], "shade": "darker", "amount": -0.12 },
    "shell_shine": { "from": ["shell"], "shade": "lighter", "amount": 0.2 },
    "hat_shade": { "from": ["hat"], "shade": "darker", "amount": -0.12 },
    "light": { "from": ["glow"] }
  },
  "brand": { "primary": "shell", "secondary": "hat" },
  "contrast": [
    { "fg": "glow", "bg": "screen", "min": 4.5, "where": "eyes and mouth on the visor" },
    { "fg": "shell", "bg": "page", "min": 3 }
  ],

  "paints": {
    "shell_round": {
      "type": "radial", "centre": [-14, -18], "r0": 4, "r1": 58,
      "stops": [[0, "shell_shine"], [0.55, "shell"], [1, "shell_shade"]]
    },
    "visor_glass": {
      "type": "linear", "from": [0, -18], "to": [0, 18],
      "stops": [[0, "glow", 0.18], [0.4, "screen", 0], [1, "screen", 0]]
    }
  },

  "ground": { "centre_height": 78, "shadow": { "rx": 48, "ry": 7, "alpha": 0.3 } },
  "outline": { "width": 2.5, "colour": "outline", "second": { "width": 5, "colour": "outline_light" },
               "lod": { "micro": { "width": 4, "second": null } } },

  "parts": [
    // Legs and boots: drawn first, behind the torso. Springs squash on the hat hop.
    { "id": "leg_l", "parent": "root", "at": [-16, -34], "layer": 1,
      "items": [{ "shape": "polyline", "points": [[0, 0], [-5, 5], [5, 10], [-5, 15], [0, 20]],
                  "stroke": "trim", "width": 4 }] },
    { "id": "leg_r", "parent": "root", "at": [16, -34], "layer": 1,
      "items": [{ "shape": "polyline", "points": [[0, 0], [5, 5], [-5, 10], [5, 15], [0, 20]],
                  "stroke": "trim", "width": 4 }] },
    { "id": "boot_l", "parent": "leg_l", "at": [0, 20], "layer": 2,
      "items": [{ "shape": "round_rect", "x": -13, "y": 0, "w": 24, "h": 13, "r": [7, 7, 4, 4],
                  "fill": "boot", "outline": true },
                { "shape": "rect", "x": -13, "y": 10, "w": 24, "h": 3, "fill": "trim" }] },
    { "id": "boot_r", "parent": "leg_r", "at": [0, 20], "layer": 2,
      "items": [{ "shape": "round_rect", "x": -11, "y": 0, "w": 24, "h": 13, "r": [7, 7, 4, 4],
                  "fill": "boot", "outline": true },
                { "shape": "rect", "x": -11, "y": 10, "w": 24, "h": 3, "fill": "trim" }] },

    // Torso: a pear shell with gloss clipped inside it.
    { "id": "torso", "parent": "root", "at": [0, -78], "layer": 10,
      "items": [
        { "id": "shell", "shape": "path",
          "d": "M0 -44 C28 -44 42 -18 42 8 C42 32 24 44 0 44 C-24 44 -42 32 -42 8 C-42 -18 -28 -44 0 -44 Z",
          "fill": { "paint": "shell_round" }, "outline": true },
        { "id": "gloss", "shape": "ellipse", "x": -16, "y": -22, "rx": 12, "ry": 6, "rotate": -0.5,
          "fill": "shell_shine", "alpha": 0.6, "clip": "torso.shell" }
      ] },
    // Belly light: its colour changes per mood through `recolour`; a soft glow.
    { "id": "belly_light", "parent": "torso", "at": [0, 12], "layer": 11,
      "glow": { "colour": "light", "blur": 10, "alpha": 0.7 },
      "items": [
        { "shape": "circle", "x": 0, "y": 0, "r": 13, "fill": "trim", "outline": true },
        { "id": "lamp", "shape": "circle", "x": 0, "y": 0, "r": 8, "fill": "light" }
      ] },

    // Floating ball-jointed arms: upper arm, joint, forearm, hand. Each joint is a pivot.
    { "id": "arm_l", "parent": "torso", "at": [-46, -10], "rotate": 1.9, "layer": 20,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 6, "fill": "trim" },
                { "shape": "round_rect", "x": 4, "y": -6, "w": 20, "h": 12, "r": 6, "fill": "shell", "outline": true }] },
    { "id": "fore_l", "parent": "arm_l", "at": [28, 0], "layer": 21,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 5, "fill": "trim" },
                { "shape": "round_rect", "x": 3, "y": -5, "w": 16, "h": 10, "r": 5, "fill": "shell", "outline": true }] },
    { "id": "hand_l", "parent": "fore_l", "at": [22, 0], "layer": 22,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 7, "fill": "boot", "outline": true }] },
    { "id": "arm_r", "parent": "torso", "at": [46, -10], "rotate": 1.24, "layer": 20,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 6, "fill": "trim" },
                { "shape": "round_rect", "x": 4, "y": -6, "w": 20, "h": 12, "r": 6, "fill": "shell", "outline": true }] },
    { "id": "fore_r", "parent": "arm_r", "at": [28, 0], "layer": 21,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 5, "fill": "trim" },
                { "shape": "round_rect", "x": 3, "y": -5, "w": 16, "h": 10, "r": 5, "fill": "shell", "outline": true }] },
    { "id": "hand_r", "parent": "fore_r", "at": [22, 0], "layer": 22,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 7, "fill": "boot", "outline": true }] },

    // Neck and head: the head pivots at the neck, so `nod` tilts only the head.
    { "id": "neck", "parent": "torso", "at": [0, -44], "layer": 5,
      "items": [{ "shape": "round_rect", "x": -8, "y": -10, "w": 16, "h": 12, "r": 4, "fill": "trim" }] },
    { "id": "head", "parent": "neck", "at": [0, -8], "layer": 30,
      "items": [
        { "id": "helmet", "shape": "ellipse", "x": 0, "y": -34, "rx": 40, "ry": 36,
          "fill": { "paint": "shell_round" }, "outline": true },
        { "id": "visor", "shape": "round_rect", "x": -30, "y": -50, "w": 60, "h": 34, "r": 14,
          "fill": "screen", "outline": true },
        { "id": "glass", "shape": "round_rect", "x": -30, "y": -50, "w": 60, "h": 34, "r": 14,
          "fill": { "paint": "visor_glass" } }
      ] },
    { "id": "ear_l", "parent": "head", "at": [-41, -34], "layer": 29,
      "items": [{ "shape": "ellipse", "x": 0, "y": 0, "rx": 7, "ry": 11, "fill": "trim", "outline": true }] },
    { "id": "ear_r", "parent": "head", "at": [41, -34], "layer": 29,
      "items": [{ "shape": "ellipse", "x": 0, "y": 0, "rx": 7, "ry": 11, "fill": "trim", "outline": true }] },

    // Hard hat: its own part, so a gesture can hop it off the head and land it.
    { "id": "hard_hat", "parent": "head", "at": [0, -66], "layer": 40,
      "items": [
        { "shape": "path", "d": "M-34 4 C-34 -18 -18 -30 0 -30 C18 -30 34 -18 34 4 Z",
          "fill": "hat", "outline": true },
        { "shape": "round_rect", "x": -44, "y": 2, "w": 88, "h": 8, "r": 4, "fill": "hat_shade", "outline": true },
        { "shape": "rect", "x": -3, "y": -28, "w": 6, "h": 30, "fill": "hat_shade", "lod": ["full", "small"] }
      ] }
  ],

  "anchors": {
    "crown": { "part": "hard_hat", "at": [0, -30], "description": "Top of the hard hat" },
    "chest": { "part": "belly_light", "at": [0, 0], "description": "Centre of the belly light" },
    "hand_l": { "part": "hand_l", "side": "l" },
    "hand_r": { "part": "hand_r", "side": "r" },
    "neck": { "part": "neck", "at": [0, -4] },
    "sparkle": { "part": "head", "at": [46, -62] },
    "sweat": { "part": "head", "at": [44, -48] }
  },

  // Screen face: glowing features on the visor, clipped to it.
  "face": {
    "part": "head", "at": [0, -33], "kit": "screen", "render": "emissive",
    "clip": "head.visor",
    "eyes": { "y": -4, "spacing": 14 },
    "mouth": { "y": 8 },
    "colours": { "feature": "glow" }
  },

  "poses": {
    "rest": { "arm_l.rotate": 1.9, "arm_r.rotate": 1.24 },
    "chin": { "arm_l.rotate": 1.9, "arm_r.rotate": -2.4, "fore_r.rotate": -1.6, "head.rotate": 0.06 },
    "wave": { "arm_l.rotate": 1.9, "arm_r.rotate": -1.0, "fore_r.rotate": -0.8 },
    "inward": { "arm_l.rotate": 1.4, "fore_l.rotate": 0.9, "arm_r.rotate": 1.7, "fore_r.rotate": -0.9 },
    "up": { "arm_l.rotate": -2.3, "arm_r.rotate": -0.85, "fore_l.rotate": -0.3, "fore_r.rotate": 0.3 }
  },

  "moods": {
    "idle": { "status": "Idle", "pose": "rest", "face": { "eyes": "dot", "mouth": "smile" } },
    "thinking": { "status": "Thinking", "pose": "chin", "face": { "eyes": "scan", "mouth": "flat", "look_x": 0.6 },
                  "recolour": { "light": "light_thinking" } },
    "happy": { "status": "Happy", "pose": "wave", "face": { "eyes": "arc", "mouth": "wide" },
               "recolour": { "light": "light_happy" } },
    "worried": { "status": "Worried", "pose": "inward", "face": { "eyes": "slant", "mouth": "wavy" },
                 "recolour": { "light": "light_worried" }, "effects": { "sweat": 0.35 } },
    "celebrating": { "status": "Celebrating", "pose": "up", "face": { "eyes": "star", "mouth": "wide" },
                     "recolour": { "light": "light_celebrating" }, "channels": { "root.lift": 8 },
                     "effects": { "sparkle": true } },
    // A custom mood: R accepts it for alpha_visor only; other code sees its fallback.
    "processing": { "description": "Working through a queue.", "status": "Processing", "fallback": "thinking",
                    "pose": "rest", "face": { "eyes": "dots", "mouth": "flat" },
                    "recolour": { "light": "light_thinking" } }
  },

  "gestures": {
    "nod": { "frames": 18, "needs": ["head"],
             "tracks": { "head.rotate": [[0, 0], [0.25, 0.12, "ease_out"], [0.45, 0], [0.65, 0.12, "ease_out"], [1, 0]] } },
    "wave": { "frames": 30, "needs": ["arm_r", "fore_r"], "fallback": "rock",
              "tracks": { "arm_r.rotate": { "mode": "set", "keys": [[0, null], [0.2, -1.1], [0.8, -1.1], [1, null]] },
                          "fore_r.rotate": { "mode": "set", "keys": [[0, null], [0.2, -0.4], [0.4, -1.1], [0.6, -0.4], [0.8, -1.1], [1, null]] },
                          "root.rotate": [[0, 0], [0.2, -0.025], [0.8, -0.025], [1, 0]] } },
    "beep": { "description": "A short beep: the belly light pulses once.", "frames": 20,
              "tracks": { "belly_light.scale_x": [[0, 0], [0.3, 0.18, "ease_out"], [1, 0]],
                          "belly_light.scale_y": [[0, 0], [0.3, 0.18, "ease_out"], [1, 0]] },
              "effects": [{ "at": 0.3, "effect": "ring_pulse", "anchor": "chest" }] },
    "hat_hop": { "description": "The hard hat hops and lands with a small squash.", "frames": 24,
                 "tracks": { "hard_hat.y": [[0, 0], [0.4, -14, "ease_out"], [0.75, 0, "ease_in"], [1, 0]],
                             "hard_hat.scale_y": [[0, 0], [0.75, 0], [0.85, -0.12], [1, 0]],
                             "leg_l.scale_y": [[0, 0], [0.1, -0.15], [0.3, 0.05], [1, 0]],
                             "leg_r.scale_y": [[0, 0], [0.1, -0.15], [0.3, 0.05], [1, 0]] } }
  },

  "motion": { "change": { "style": "gesture", "gesture": "hat_hop", "frames": 24, "swap_at": 0.5 } },

  "lod": {
    "small": { "hide": ["torso.gloss", "head.glass"] },
    "micro": { "hide": ["leg_l", "leg_r", "ear_l", "ear_r", "arm_l", "fore_l", "hand_l", "arm_r", "fore_r", "hand_r"],
               "face": { "scale": 1.4 }, "glow": false }
  }
}
```

Notes on the example:
- The `screen` kit provides the eye styles used (`dot`, `scan`, `arc`, `slant`, `star`, `dots`) and mouths
  (`smile`, `flat`, `wide`, `wavy`). Worried has no flicker: round 4's "screen flickers once" is dropped, because
  flicker is on the forbidden list.
- `lod.small.hide` names items by their `id` (`torso.gloss`, `head.glass`); indices are not allowed, so a
  reordered list never hides the wrong item. The same could be written as `"lod": ["full"]` on each item.
- The face contrast pair is 13.6:1 (`#4df3ff` on `#0a1038`, from round 5's measurements).
- Every motion is a bounded track; the hat hop is also the mood change, so a mood change looks like the
  character's own reaction, not a generic wiggle.

### 4.2 Tessa in full (the improved look)
Blocks marked `// NEW` are the improved look. **The pixel-identical migration file is this file without the `NEW`
blocks and with today's colours** (`body` `#3f8a66`); that is PR M1, and the improved look is PR M2, reviewed in
the studio.

```json
{
  "format_version": 1,
  "id": "tessa",
  "name": "Tessa",
  "family": "tessellates",
  "description": "A calm, hardworking maker shaped like an R hex sticker; suits teaching, tutorials and package docs.",
  "pronouns": "she/her",
  "requires": ["parts", "paints", "clip", "outline", "face_kit", "tracks", "lod"],

  "colours": {
    "outline": "#26312b",
    "feature": "#16201b",
    "eye_white": "#fffdf4",
    "shine": "#f5f6f4",
    "teeth": "#f5f6f4",
    "eyelid": "#26a065",
    "tongue": "#a33a30",
    "body": "#26a065",
    "body_highlight": "#7fcba4",
    "body_deep": "#1a7a4b",
    "rim": "#d9b35c",
    "rim_light": "#f3dc96",
    "rim_deep": "#a8832e",
    "limb": "#d9b35c",
    "sleeve": "#26a065",
    "iris": "#2f8f5b",
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
    "sleeve": { "from": ["body"] },
    "eyelid": { "from": ["body"] },
    "body_highlight": { "from": ["body"], "shade": "lighter", "amount": 0.2529, "saturation": 0.0491 },
    "body_deep": { "from": ["body"], "shade": "darker", "amount": -0.1 },
    "iris": { "from": ["body"], "shade": "darker", "amount": -0.03 },
    "blush": { "from": ["body"], "shade": "lighter", "amount": 0.2529, "saturation": 0.0491 },
    "limb": { "from": ["rim", "body"] },
    "rim_light": { "from": ["rim"], "shade": "lighter", "amount": 0.2 },
    "rim_deep": { "from": ["rim"], "shade": "darker", "amount": -0.18 },
    "blush_strong": { "from": ["rim", "body"] },
    "sparkle_outline": { "from": ["rim", "body"] },
    "accessory": { "from": ["rim"] },
    "accessory_detail": { "from": ["accessory"], "shade": "darker", "amount": -0.3314, "saturation": 0.121 }
  },
  "brand": { "primary": "body", "secondary": "rim" },
  "contrast": [
    { "fg": "outline", "bg": "page_light", "min": 3, "where": "the outline carries the silhouette on light pages" },
    { "fg": "rim", "bg": "page_dark", "min": 3, "where": "the ochre rim carries the silhouette on dark pages" },
    { "fg": "feature", "bg": "body", "min": 4.5, "where": "face lines on the body" }
  ],

  // NEW: gradients for the gem body and metallic rim.
  "paints": {
    "body_gem": { "type": "linear", "from": [-50, -70], "to": [50, 70],
                  "stops": [[0, "body_highlight"], [0.35, "body"], [1, "body_deep"]] },
    "rim_gold": { "type": "linear", "from": [-80, -80], "to": [80, 80],
                  "stops": [[0, "rim_light"], [0.5, "rim"], [1, "rim_deep"]] }
  },

  "shapes": {
    "outer": { "shape": "hexagon", "r": 92, "corner": 12 },
    "inner": { "shape": "hexagon", "r": 81, "corner": 8 }
  },

  "ground": { "centre_height": 104, "shadow": { "rx": 62, "ry": 9, "alpha": 0.32 } },
  "outline": { "width": 3, "colour": "outline", "join": "miter", "cap": "butt", "lod": { "micro": { "width": 5 } } },

  "parts": [
    // Feet: two variants, switched by lift (today's `feet: "auto"`).
    { "id": "foot_l", "parent": "body", "at": [-23, 0], "layer": 10,
      "switch": { "channel": "root.lift", "above": 6, "variant": "tuck" },
      "items": [{ "shape": "round_rect", "x": -15, "y": 88, "w": 30, "h": 16, "r": [6, 6, 8, 8],
                  "fill": "limb", "stroke": "outline", "width": 2.5, "cap": "butt", "join": "miter" }],
      "variants": { "tuck": [{ "shape": "round_rect", "transform": [-1, 78, 0.25],
                               "x": -12, "y": -6, "w": 24, "h": 14, "r": 7,
                               "fill": "limb", "stroke": "outline", "width": 2.5, "cap": "butt", "join": "miter" }] } },
    { "id": "foot_r", "parent": "body", "at": [23, 0], "layer": 10,
      "switch": { "channel": "root.lift", "above": 6, "variant": "tuck" },
      "items": [{ "shape": "round_rect", "x": -15, "y": 88, "w": 30, "h": 16, "r": [6, 6, 8, 8],
                  "fill": "limb", "stroke": "outline", "width": 2.5, "cap": "butt", "join": "miter" }],
      "variants": { "tuck": [{ "shape": "round_rect", "transform": [1, 78, -0.25],
                               "x": -12, "y": -6, "w": 24, "h": 14, "r": 7,
                               "fill": "limb", "stroke": "outline", "width": 2.5, "cap": "butt", "join": "miter" }] } },

    // Body: centred on the root's rotation pivot (centre_height above the ground).
    { "id": "body", "parent": "root", "at": [0, -104], "layer": 20,
      "items": [
        { "id": "rim", "shape": "ref", "use": "outer", "fill": { "paint": "rim_gold" }, "outline": true },
        { "id": "face_plate", "shape": "ref", "use": "inner", "fill": { "paint": "body_gem" } },
        { "shape": "path", "d": "M0 -81 L26 -65 L-26 -65 Z", "fill": "body_highlight", "alpha": 0.35 },
        // NEW: faint facets and a mint rim light, clipped to the face plate.
        { "shape": "path", "d": "M0 -81 L0 0 L70 -40 Z", "fill": "body_highlight", "alpha": 0.12,
          "clip": "body.face_plate", "lod": ["full"] },
        { "shape": "path", "d": "M-70 40 L0 0 L0 81 Z", "fill": "body_deep", "alpha": 0.18,
          "clip": "body.face_plate", "lod": ["full"] },
        { "shape": "arc", "x": 0, "y": 0, "r": 76, "start": 3.6, "end": 4.6,
          "stroke": "body_highlight", "width": 4, "alpha": 0.5, "clip": "body.face_plate", "lod": ["full"] }
      ] },

    // Arms: today's capsule and paw, now ordinary parts; presets become poses.
    { "id": "arm_l", "parent": "body", "at": [-69.674337, 8], "rotate": 1.85, "layer": 60,
      "items": [{ "shape": "round_rect", "x": 0, "y": -7.5, "w": 42, "h": 15, "r": 7.5, "fill": "sleeve",
                  "stroke": "outline", "width": 2.5 },
                { "shape": "circle", "x": 39, "y": 0, "r": 6.75, "fill": "limb", "stroke": "outline", "width": 2.5 }] },
    { "id": "arm_r", "parent": "body", "at": [69.674337, 8], "rotate": 1.25, "layer": 60,
      "items": [{ "shape": "round_rect", "x": 0, "y": -7.5, "w": 42, "h": 15, "r": 7.5, "fill": "sleeve",
                  "stroke": "outline", "width": 2.5 },
                { "shape": "circle", "x": 39, "y": 0, "r": 6.75, "fill": "limb", "stroke": "outline", "width": 2.5 }] }
  ],

  "anchors": {
    "hair": { "part": "body", "at": [-47, -54], "rotate": -0.5, "scale": 1.2 },
    "crown": { "part": "body", "at": [0, -92] },
    "forehead": { "part": "body", "at": [0, -40] },
    "eyes": { "part": "body", "at": [0, -12] },
    "upper_lip": { "part": "body", "at": [0, 24] },
    "chin": { "part": "body", "at": [0, 65] },
    "neck": { "part": "body", "at": [0, 75] },
    "chest": { "part": "body", "at": [0, 30] },
    "back": { "part": "body", "at": [0, 0] },
    "waist": { "part": "body", "at": [0, 60] },
    "shoulder_l": { "part": "body", "at": [-69.674337, 8], "side": "l" },
    "shoulder_r": { "part": "body", "at": [69.674337, 8], "side": "r" },
    "hand_l": { "part": "arm_l", "at": [39, 0], "side": "l" },
    "hand_r": { "part": "arm_r", "at": [39, 0], "side": "r" },
    "foot_l": { "part": "foot_l", "at": [0, 104], "side": "l" },
    "foot_r": { "part": "foot_r", "at": [0, 104], "side": "r" },
    "sparkle": { "part": "body", "at": [56, -33] },
    "sweat": { "part": "body", "at": [58, -46] }
  },

  "face": {
    "part": "body", "at": [0, 0], "kit": "classic", "layer": 30,
    "eyes": { "y": -12, "spacing": 30, "lashes": true, "iris": "iris" },
    "mouth": { "y": 24 },
    "blush": { "x": 36, "y": 18, "rx": 13, "ry": 7, "alpha": 0.45, "strong_alpha": 0.55 },
    "caps": { "left": "butt", "right": "round", "join": "miter" },
    // NEW: bigger eyes (the migration file leaves `tune` out and `iris` null).
    "tune": { "open": { "ew": 18, "eh": 21 }, "wide": { "ew": 20.5, "eh": 25 } }
  },

  "poses": {
    "idle": { "arm_l.rotate": 1.85, "arm_r.rotate": 1.25 },
    "up": { "arm_l.rotate": -2.25, "arm_r.rotate": -0.85 },
    "shock": { "arm_l.rotate": -2.45, "arm_r.rotate": -0.65 },
    "type": { "arm_l.rotate": 2.55, "arm_r.rotate": 2.35 },
    "hold": { "arm_l.rotate": -2.79, "arm_r.rotate": -0.35 },
    "wave": { "arm_l.rotate": 1.85, "arm_r.rotate": -1.0 },
    "point": { "arm_l.rotate": 1.85, "arm_r.rotate": -0.15 },
    "hips": { "arm_l.rotate": 2.35, "arm_r.rotate": 0.8 }
  },

  "moods": {
    "idle": { "pose": "idle", "face": { "eyes": "open", "mouth": "smile" } },
    "thinking": { "pose": "hips", "face": { "eyes": "focused", "mouth": "flat", "brows": "raised",
                                            "look_x": 0.6, "look_y": -0.6 } },
    "happy": { "pose": "wave", "face": { "eyes": "happy", "mouth": "grin" } },
    "worried": { "pose": "idle", "face": { "eyes": "worried", "mouth": "flat", "brows": "worried" },
                 "effects": { "sweat": 0.35 } },
    "celebrating": { "pose": "up", "face": { "eyes": "happy", "mouth": "grin", "blush": "strong" },
                     "channels": { "root.lift": 10 }, "effects": { "sparkle": true } }
  },

  // Gestures and status words come from the family; Tessa adds the hop as her mood change.
  "motion": { "change": { "style": "hop", "height": 8, "frames": 18 } },

  "accessories": {
    "bow": {
      "description": "Ochre hair bow.", "slot": "hair", "anchor": "hair",
      "items": [
        { "shape": "path", "d": "M0 0 Q-10 -13 -21 -8 Q-25 0 -21 8 Q-10 13 0 0 Z", "fill": "accessory",
          "stroke": "outline", "width": 2.2 },
        { "shape": "path", "d": "M-7 -1 L-17 -3 M-7 2 L-17 3", "stroke": "accessory_detail", "width": 1.6 },
        { "shape": "path", "d": "M0 0 Q10 -13 21 -8 Q25 0 21 8 Q10 13 0 0 Z", "fill": "accessory",
          "stroke": "outline", "width": 2.2 },
        { "shape": "path", "d": "M7 -1 L17 -3 M7 2 L17 3", "stroke": "accessory_detail", "width": 1.6 },
        { "shape": "circle", "x": 0, "y": 0, "r": 5.5, "fill": "accessory", "stroke": "outline", "width": 2.2 }
      ],
      "lod": ["full", "small", "micro"]
    },
    "clip": {
      "description": "Plain hair clip.", "slot": "hair", "anchor": "hair",
      "items": [
        { "shape": "round_rect", "x": -15, "y": -5, "w": 30, "h": 10, "r": 5, "fill": "accessory",
          "stroke": "outline", "width": 2.2 },
        { "shape": "rect", "x": -5, "y": -4, "w": 3, "h": 8, "fill": "accessory_detail" },
        { "shape": "rect", "x": 3, "y": -4, "w": 3, "h": 8, "fill": "accessory_detail" },
        { "shape": "rect", "x": -12, "y": -3, "w": 5, "h": 2, "fill": "shine", "alpha": 0.7 }
      ]
    }
  },
  "wear": ["bow"],

  "lod": {
    "micro": { "face": { "scale": 1.25, "lashes": false, "iris": false } }
  }
}
```

Notes:
- Today's feet are drawn in body space; in v1 they are children of `body` placed at `±23` (the old
  `anchors.feet.x`) with the same rectangles shifted by that amount. The tucked feet keep today's
  `translate(±24, 78)` and `rotate(∓0.25)` through the item `transform`, so the pixels match.
- Joins and caps are written out where today's code used `butt`/`miter` (rim outline, feet), because v1's default
  is `round`; this is what keeps the migration pixel-identical.
- The face sits on `body` at layer 30, between body (20) and arms (60), which is today's order.
- `outline: true` on the rim keeps today's 3-unit outline stroke; other items keep their explicit strokes, as today.
- Moods carry no `status` or `description`: the family supplies them, so Tessa and Sela read the same.

### 4.3 Sketch: Knurl's clamp arm (jointed parts, a held tool that stays upright)
```json
{
  "parts": [
    { "id": "chassis", "parent": "root", "at": [0, -70], "layer": 10, "items": [] },
    { "id": "shoulder", "parent": "chassis", "at": [30, -20], "rotate": -0.6, "layer": 30,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 8, "fill": "copper", "outline": true }] },
    { "id": "upper", "parent": "shoulder", "at": [0, 0], "layer": 31,
      "items": [{ "shape": "round_rect", "x": 0, "y": -6, "w": 34, "h": 12, "r": 6, "fill": "body", "outline": true }] },
    { "id": "elbow", "parent": "upper", "at": [34, 0], "rotate": 0.9, "layer": 32,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 7, "fill": "copper", "outline": true }] },
    { "id": "fore", "parent": "elbow", "at": [0, 0], "layer": 31,
      "items": [{ "shape": "round_rect", "x": 0, "y": -5, "w": 28, "h": 10, "r": 5, "fill": "body", "outline": true }] },
    { "id": "clamp", "parent": "fore", "at": [28, 0], "layer": 34,
      "variants": { "open": [{ "shape": "path", "d": "M0 -8 L12 -12 L12 -4 Z M0 8 L12 12 L12 4 Z", "fill": "copper", "outline": true }] },
      "items": [{ "shape": "path", "d": "M0 -8 L12 -6 L12 -2 Z M0 8 L12 6 L12 2 Z", "fill": "copper", "outline": true }] },
    { "id": "spanner", "parent": "clamp", "at": [10, 0], "keep_upright": true, "layer": 33,
      "items": [{ "shape": "path", "d": "M-2 -26 L2 -26 L2 6 L-2 6 Z", "fill": "tool", "outline": true },
                { "shape": "path", "d": "M-8 -34 Q0 -40 8 -34 L5 -28 L-5 -28 Z", "fill": "tool", "outline": true }] }
  ],
  "gestures": {
    "clamp_salute": { "frames": 30, "needs": ["shoulder", "elbow", "clamp"],
      "tracks": { "shoulder.rotate": [[0, 0], [0.35, -0.7, "ease_out"], [0.8, -0.7], [1, 0]],
                  "elbow.rotate": [[0, 0], [0.35, 0.5], [0.8, 0.5], [1, 0]],
                  "clamp.variant": [[0, "default"], [0.4, "open"], [0.55, "default"]] } }
  }
}
```
The spanner follows the clamp's position but stays head up (round 5: "spanner always head up"). The far socket
stub is a separate part behind the chassis (`layer` 5), never a hand. Weld sparks wait for `particles`; until then
the gesture shows a `sparkle` effect at the clamp anchor.

### 4.4 Sketch: Sela's hair in front of and behind the head
```json
{
  "parts": [
    { "id": "head", "parent": "root", "at": [0, -104], "layer": 20, "items": [] },
    { "id": "hair_back", "parent": "head", "at": [0, -40], "layer": 5,
      "items": [{ "shape": "path", "d": "M-70 -40 C-90 10 -80 60 -60 70 L60 70 C80 60 90 10 70 -40 C40 -70 -40 -70 -70 -40 Z",
                  "fill": "hair", "outline": true }] },
    { "id": "hair_front", "parent": "head", "at": [0, -40], "layer": 35,
      "items": [{ "shape": "path", "d": "M-66 -38 C-40 -70 40 -70 66 -38 C40 -46 10 -30 -10 -44 C-30 -30 -50 -30 -66 -38 Z",
                  "fill": "hair", "outline": true },
                { "shape": "path", "d": "M-40 -52 C-20 -60 10 -60 30 -54", "stroke": "hair_shine", "width": 3,
                  "lod": ["full"] }] },
    { "id": "clasp", "parent": "hair_front", "at": [44, -44], "layer": 36,
      "items": [{ "shape": "polygon", "sides": 5, "r": 7, "fill": "rim", "outline": true }] }
  ]
}
```
Both hair parts share the parent `head` but draw on either side of the body (layer 5) and face (30). The bob
"catching up a beat later" is spring follow-through (`follow`, later); in v1 a gesture adds a delayed
`hair_back.rotate` keyframe to fake the lag. The clasp sits on `hair_front`; what happens to it when the hair
is taken off is a wardrobe question for later (attachment E: an explicit fallback, never a floating clasp).

### 4.5 Sketch: Cinder's per-mood core
```json
{
  "parts": [
    { "id": "core", "parent": "flame", "at": [0, -20], "layer": 15,
      "items": [{ "shape": "path", "d": "M0 -40 C18 -20 20 10 0 24 C-20 10 -18 -20 0 -40 Z", "fill": { "paint": "core_warm" } }],
      "variants": {
        "blue": [{ "shape": "path", "d": "M0 -40 C18 -20 20 10 0 24 C-20 10 -18 -20 0 -40 Z", "fill": { "paint": "core_blue" } }],
        "low": [{ "shape": "path", "d": "M0 -22 C12 -10 14 8 0 18 C-14 8 -12 -10 0 -22 Z", "fill": { "paint": "core_warm" } }]
      } }
  ],
  "moods": {
    "thinking": { "channels": { "core.variant": "blue" } },
    "worried": { "channels": { "core.variant": "low", "flame.scale_y": 0.88 } },
    "celebrating": { "channels": { "flame.scale_y": 1.12 }, "effects": { "sparkle": true } }
  }
}
```
Paints `core_warm` (`#ffe66b` → `#fff6c9`) and `core_blue` (`#2f7bff` → `#9adfff`) are role-based, so a theme can
retint both. The flame's outline stays fixed per mood in v1 (`variants`); the living, rebuilt-every-frame outline
from round 5 needs `morph` (later). The mask is its own part with `face.part: "mask"` and `face.clip`; its
features use `face.colours` to map `feature` to the ember role. Smoke and sparks wait for `particles`.

### 4.6 Sketch: Neer's simplified sheen
```json
{
  "paints": {
    "water_depth": { "type": "linear", "from": [0, -150], "to": [0, -12],
                     "stops": [[0, "body_light"], [0.5, "body"], [1, "body_deep"]] },
    "sheen": { "type": "radial", "centre": [-50, -110], "r0": 0, "r1": 46,
               "stops": [[0, "highlight", 0.55], [1, "highlight", 0]] }
  },
  "parts": [
    { "id": "body", "parent": "root", "at": [0, 0], "layer": 20,
      "items": [
        { "id": "water", "shape": "path",
          "d": "M -100,-46 C -100,-92 -72,-128 -30,-146 C 8,-162 56,-158 78,-128 C 90,-112 86,-92 72,-92 C 62,-92 60,-104 66,-112 C 56,-118 40,-112 40,-96 C 40,-84 56,-80 76,-76 C 92,-72 100,-58 100,-40 C 100,-24 82,-12 54,-12 L -54,-12 C -84,-12 -100,-26 -100,-46 Z",
          "fill": { "paint": "water_depth" }, "outline": true },
        { "shape": "ellipse", "x": -56, "y": -104, "rx": 30, "ry": 7, "rotate": -0.55,
          "fill": { "paint": "sheen" }, "clip": "body.water", "lod": ["full", "small"] },
        { "shape": "path", "d": "M -10 -132 C 20 -146 58 -138 66 -118", "stroke": "crest_line", "width": 3.4,
          "alpha": 0.85, "lod": ["full"] }
      ] }
  ]
}
```
One clipped radial sheen and one crest line: the busy background wave, caustics and bubbles are dropped as asked.
The path is today's wave crest (`shapes.js`), so the silhouette matches the shipped drawing. In v1, crest flex
is a gesture of small `body.rotate` and `body.scale_y` keyframes about the base; bending the crest itself waits
for `morph`.

### 4.7 Sketch: the lab assistant's progress flask (paper only)
```json
{
  "parts": [
    { "id": "flask", "parent": "hand_r", "at": [0, -6], "keep_upright": true, "layer": 50,
      "items": [{ "id": "glass", "shape": "path", "d": "M-6 -30 L6 -30 L6 -14 L20 14 C22 20 18 24 12 24 L-12 24 C-18 24 -22 20 -20 14 L-6 -14 Z",
                  "fill": "glass", "alpha": 0.35, "outline": true }] },
    { "id": "liquid", "parent": "flask", "at": [0, 24], "layer": 49,
      "items": [{ "shape": "rect", "x": -22, "y": -54, "w": 44, "h": 54, "fill": "liquid", "clip": "flask.glass" }] }
  ],
  "inputs": {
    "progress": { "description": "Share of the work done, 0 to 1.", "min": 0, "max": 1,
                  "drives": [{ "channel": "liquid.scale_y", "from": 0, "to": 1 }] }
  }
}
```
The liquid is a rectangle scaled from its bottom pivot and clipped to the glass, so it fills the flask's real
shape. `inputs` is reserved (later): it would add `update_mascot(id, value = 0.4)`, with the status text still
saying "40% done" (the flask is decoration, never the only signal). Clothing (a lab coat) is ordinary parts on the
torso; sleeves are separate parts on each arm, as attachment E advises.

### 4.8 Sketch: the molecule's bonds (paper only)
```json
{
  "parts": [
    { "id": "atom_a", "parent": "root", "at": [-40, -80], "layer": 20,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 18, "fill": "atom", "outline": true }] },
    { "id": "atom_b", "parent": "root", "at": [40, -90], "layer": 20,
      "items": [{ "shape": "circle", "x": 0, "y": 0, "r": 14, "fill": "atom_alt", "outline": true }] },
    { "id": "bonds", "parent": "root", "layer": 10,
      "items": [{ "shape": "connector", "from": "atom_a_c", "to": "atom_b_c", "width": 6, "stroke": "bond",
                  "inset": 12 }] }
  ],
  "anchors": { "atom_a_c": { "part": "atom_a" }, "atom_b_c": { "part": "atom_b" } }
}
```
When a gesture moves `atom_b.x`, the connector is recomputed from both anchors' world positions, so the bond
stretches. Layer 10 keeps bonds behind atoms. A faceless molecule (`face: null`) shows mood by arrangement
(channels per mood), which is also how Strata and Gather work.

---

## 5. Families

### 5.1 What a family is
A family is a **category with a meaning** and a set of **defaults**. It is mandatory for every character. It never
implies anatomy: membership grants no parts and no anchors (attachment E).

Family file `inst/families/<id>.json`:

| Key | Type | Rule |
|---|---|---|
| `format_version` | integer | `1` |
| `id`, `name`, `description` | strings | Permanent snake_case id. |
| `outline` | outline object | Default outline style. |
| `face` | `{ "kit", "render", "eyes", "mouth" }` | Default face settings. |
| `follows` | object | Templates for derived roles; apply only to roles the character has. |
| `contrast` | array | Rules every member must meet (for example `feature` on `body` at 4.5). |
| `moods` | object | Descriptions and status words for the shared five (and family-wide extras). |
| `gestures` | object | Shared gesture library (`nod`, `wave`, `rock`, ...), using `needs` to fall back. |
| `motion` | object | Default change and idle settings. |
| `skeleton` | `{ "parts": [...], "anchors": [...] }` | Optional: part ids and anchors every member promises, so family gestures and accessories can rely on them. Checked, never generated. |
| `palettes` | object | Family presets (leaders only) that members may offer. |

### 5.2 Merge rule
Family values are defaults; the character's value for the same key wins. Objects merge one level deep by key
(a character's `moods.thinking` replaces the family's `moods.thinking` field by field; a character's
`gestures.nod` replaces the whole `nod`). Arrays are replaced, never concatenated. The merged result is what the
engine receives, so the engine never reads family files.

### 5.3 Can a character extend another?
**Not in v1** (recommendation, decision 3). `extends` is reserved. Reasons: inheritance chains make files hard to
read and hard for an AI skill to edit safely; a changed parent silently changes children. Remixing is done in R:
read a character, edit the list, check it, save it as a full file (`mascot_read_character()` →
`mascot_check_character()` → `mascot_register_character()`), so every file stands alone.

### 5.4 The families for the picks

| Family id | Name | Members | Shares |
|---|---|---|---|
| `tessellates` (or `hexonians`, decision 6) | Tessellates | tessa, sela, brim, iso | slim black outline, `classic` face kit with lashes and blush, five moods with status words, `nod`/`wave`, `hop` change, skeleton `body` + `arm_l/r` + `foot_l/r` + anchors `hair`, `crown`, `hand_l/r` |
| `visorfolk` | Visorfolk | alpha_visor, knurl | `screen` kit (emissive), double contour, `[glow, screen]` contrast rule, `nod` on `head`, `beep` |
| `elementals` | Elementals | neer, cinder | `classic` kit with white features, softer outline, `crest`-style settle as default change |
| `taxa`, `nodes`, `strata`, `foldlings` | later | rustle, mote, strata/gather, foldlings | to be written when one ships |

### 5.5 R functions that list them
- `mascot_families()`: data frame `id`, `name`, `description`, `characters` (comma-separated ids), `built_in`.
- `mascot_characters(family = NULL)`: data frame `id`, `name`, `family`, `description`, `built_in`; `family`
  filters.

---

## 6. Validation

### 6.1 `mascot_check_character(x)`
`x` is a path to a JSON file or a list as returned by `mascot_read_character()`. It returns the merged, checked
character invisibly (class `mascot_character_data`) or stops with a cli error listing up to ten problems
(class `mascot_error`); contrast problems with user colours are warnings (class `mascot_contrast`), as today.

Order of checks (each step runs only if the earlier steps passed, so messages are never caused by an earlier
problem):

1. **Read.** UTF-8 JSON, one object; file size under a limit (say 256 KB). Parse errors give the line.
2. **Version.** `format_version` present and an integer; higher than supported → error naming the package
   version needed; lower than 1 → the provisional format is not read (built-ins move to v1 before 0.1.0).
3. **Capabilities.** Every `requires` name known; every feature used is listed (or the checker adds it and says
   so in `mascot_check_character(x, fix = TRUE)`, later).
4. **Keys.** Every key known for its place; reserved keys → "not supported yet"; misspellings get a "did you
   mean" suggestion (edit distance).
5. **Names.** snake_case for every key and name; id pattern; **reserved ids**: the built-in ids
   (`tessa`, `neer`, and every later built-in) and the words `none`, `default`, `root`, `face`, `effects`, `light`,
   `dark` cannot be used as ids of user characters, parts or roles respectively.
6. **Family.** Known family; merge family defaults.
7. **Types and ranges.** Numbers finite; `alpha`, `opacity` in 0..1; `sides` 3..12; widths ≥ 0; colours parse.
8. **References.** Every role, paint, shape, part, parent, anchor, pose, variant, clip target, face kit style,
   accessory slot and anchor exists; parent chain acyclic; `clip` targets are filled items; `follows` acyclic.
9. **Moods.** The five shared moods present; extra moods have `fallback` chains ending in a shared mood;
   status words present after the merge.
10. **Gestures.** `nod` and `wave` present or reachable by fallback; `frames` 1..150; keyframes ascending from 0 to
    1; channel names real; values of the right type; `set` tracks start and end at `null` or the mood value
    (so gestures end where they started).
11. **Motion.** As today's R/JS checks (blink jitter + half duration < spacing; windows ≤ 150).
12. **Paths.** Every `d` parses with the same grammar as the engine.
13. **Budgets.** Section 2.4, per band.
14. **Contrast.** The file's `contrast` pairs on its own colours (light and dark): error below `min`.
15. **Levels of detail.** Every band leaves at least one filled part; `micro` keeps the face if the character has
    one; no glow in `micro`; `hide` names parts or item ids (no indices).

The JS engine keeps a **thin guard** at draw time (types needed to avoid exceptions, names it looks up), with the
same messages for the same faults. Tests run every fixture in `tests/testthat/fixtures/characters/bad-*.json`
through both and compare the first message, so the two cannot drift.

### 6.2 Three example messages

```
Error in `mascot_check_character()`:
! Character "sela": a part uses a colour role that does not exist.
✖ In `parts[["hair_front"]]$items[[1]]$fill`, the role is "hiar".
ℹ Did you mean "hair"?
ℹ Roles in this character: body, shade, rim, hair, hair_shine, outline, feature, eye_white, ...
ℹ Fix the spelling, or add "hiar" to `colours`.
```

```
Error in `mascot_check_character()`:
! Character "alpha_visor": the fallbacks of mood "processing" go round in a circle.
✖ "processing" falls back to "busy", and "busy" falls back to "processing".
ℹ Every extra mood must fall back, in the end, to one of the five shared moods:
  idle, thinking, happy, worried or celebrating.
ℹ Set `moods$busy$fallback` to "thinking".
```

```
Error in `mascot_check_character()`:
! Character file "knurl.json" uses format 2; this version of mascot reads format 1.
ℹ The file needs a newer version of mascot (capability "particles").
ℹ Update mascot, or ask the file's author for a format 1 version.
```

---

## 7. Authoring

### 7.1 By JSON
The smallest useful file: a new robot in the Visorfolk family, using family moods, gestures, face kit and outline.

```json
{
  "format_version": 1,
  "id": "cube_bot",
  "name": "Cube",
  "family": "visorfolk",
  "description": "A square robot for dashboards.",
  "colours": { "outline": "#1b1230", "outline_light": "#fffdf4", "shell": "#3f82ff", "trim": "#2a3550",
               "screen": "#06232a", "glow": "#7cffe0", "shadow": "#a2aea7" },
  "ground": { "centre_height": 60 },
  "parts": [
    { "id": "head", "parent": "root", "at": [0, -60],
      "items": [{ "shape": "round_rect", "x": -50, "y": -50, "w": 100, "h": 100, "r": 18, "fill": "shell", "outline": true },
                { "id": "visor", "shape": "round_rect", "x": -36, "y": -30, "w": 72, "h": 44, "r": 12, "fill": "screen" }] }
  ],
  "face": { "part": "head", "clip": "head.visor", "at": [0, -8] },
  "moods": {
    "idle": { "face": { "eyes": "dot", "mouth": "smile" } },
    "thinking": { "face": { "eyes": "scan", "mouth": "flat" } },
    "happy": { "face": { "eyes": "arc", "mouth": "wide" } },
    "worried": { "face": { "eyes": "slant", "mouth": "wavy" } },
    "celebrating": { "face": { "eyes": "star", "mouth": "wide" } }
  }
}
```
`wave` needs `arm_r`, which Cube lacks, so the family's `wave` falls back to `rock`; the checker says so as a
message, not an error.

### 7.2 By R
In 0.1.0 these functions are internal; from 0.1.x they are planned as experimental exports, and the code below
runs as written then.

```r
teal <- mascot_read_character("tessa")            # merged, checked list
teal$id <- "teal_tessa"
teal$name <- "Teal Tessa"
teal$colours$body <- "#1f6f78"                    # follows rules derive the rest
teal$wear <- list("clip")
teal <- mascot_check_character(teal)              # errors name the place and the fix
mascot_register_character(teal)                   # this R session only; writes nothing
mascot("helper", character = "teal_tessa")
```
Saving is a separate, later function that writes only to a path the user gives (`mascot_write_character(x, path)`).

### 7.3 By AI skill
The skill (a file the user's own agent runs; the package never calls a model):
1. Reads `docs/character-format.md` (the schema reference from PR R1) and the chosen family file.
2. Writes `<id>.json` from the user's description, starting from the family's skeleton.
3. Runs `Rscript -e 'mascot:::mascot_check_character("<id>.json")'` (or the export, once it exists) and fixes
   every reported problem until the check is clean.
4. Renders the five moods at 160, 96 and 24 px on a light and a dark page (the screenshot harness from PR T1) and
   shows them to the user, who decides.

Example prompt the skill accepts: "Make a calm orange owl for a library app, family `taxa`, glasses as an
accessory, a page-turn gesture."

---

## 8. R API effects

| Function | Change | Notes |
|---|---|---|
| `mascot_character()` | Argument `name` → **`id`** (decision 2); also accepts a checked character (`mascot_character_data`); optional overrides later (display name, `wear`). | Breaking, but before 0.1.0: no deprecation needed (AGENTS.md). |
| `mascot()` / `update_mascot()` `character =` | Accepts an id, a `mascot_character()` or a checked character. | As already decided (polymorphic). |
| `mascot_characters()` (new) | `id`, `name`, `family`, `description`, `built_in`; `family =` filter. | Replaces reading `builtin_characters()`. |
| `mascot_families()` (new) | `id`, `name`, `description`, `characters`, `built_in`. | |
| `mascot_anchors(character)` (new) | `anchor`, `part`, `side`, `description`. | For wardrobe and docs. |
| `mascot_moods(character = NULL)` | `NULL`: the five shared moods (today's output). With a character: `name`, `description`, `status`, `shared`, `fallback`. | Columns added at the end, as the docs promise. |
| `mascot_mood(name)` | Checked against the character's moods when the character is known (in `mascot()`), else against the shared five. | |
| `mascot_gestures(character = NULL)` | `NULL`: shared gestures. With a character: `name`, `description`, `fallback`, `frames`. | |
| `mascot_gesture(name)` | Checked per character at use; unknown gestures error with the character's list. | |
| `mascot_colour_roles(character)` | Roles are already snake_case in v1: `colour_role_names()` conversion is removed. Adds a `used_by` column later. | |
| `mascot_theme()` | `preset =` (decision 7) picks a palette from the character's or family's `palettes`; explicit colours still win. | |
| `mascot_palettes(character)` (new) | `preset`, `description`, `source` (`character` or `family`). | The studio palette picker uses it. |
| `mood_label()` | Reads `status`. | |

Studio (each R PR updates it in the same PR): character chooser shows family and description
(`R/panels.R`, `R/data.R`); moods and gestures lists come from the selected character (`R/data.R`); code builders
use `id =` (`R/code.R`); guide text for new listing functions (`R/guide.R`); the palette picker (PR S1) draws each
preset on the real character in light and dark (`R/ui.R`, `app.R`).

---

## 9. Build plan

Two tracks run in parallel: **E** (engine, `inst/www/`) and **R** (`R/`, `tests/`). **T** is test tooling, **M** is
moving or adding characters, **S** is the studio. Each PR is one coding agent's work, with its own issue in the
epic tree, a `NEWS.md` bullet where users see a change, and studio updates in the same PR when an export changes.
Engine PRs keep reading today's provisional file through a small adapter until M1, so nothing breaks in between.

| PR | Track | Content | Depends on | Done when |
|---|---|---|---|---|
| R1 | R | Schema reference `docs/character-format.md`; unexported `mascot_read_character()` and `mascot_check_character()` for v1 (steps 1–12, 14–15); good and bad fixtures; tests for every message. | – | Every fixture gives its expected message; coverage ≥ 70%; Tessa and alpha_visor example files (section 4, notes removed) pass. |
| E1 | E | Part tree, world matrices, layer sort, `Path2D` cache, rig channels; `fromProvisional()` adapter reads today's `tessa.json`. | – | Tessa draws pixel-identical (T1 or a canvas hash test) in all moods and gestures. |
| T1 | T | Screenshot harness: chromote, seeded, rest frame per character × mood × band (160/96/24) × light/dark; `expect_snapshot_file()`; skipped on CRAN. | – | Snapshots of today's Tessa committed; a planted one-pixel change fails. |
| E2 | E | Paints, clip, outline pass, new shape types (`polygon`, `ellipse`, `polyline`, `arc`, `ref`). | E1 | Fixture character using each feature matches its snapshot; Tessa unchanged. |
| R2 | R | Registry through the read/check path; `mascot_register_character()` (session only); reserved ids; built-ins load the same way. | R1 | Registering `tessa` as a user file errors; a valid user file mounts in a test app. |
| E3 | E | Face kit renderer; `inst/faces/classic.json` from `FACE_STYLE` and the draw functions; `screen.json`; sweat and sparkle as kit effects. | E2 | Tessa pixel-identical with the kit; screen kit fixture snapshots; no face code left in `mascot-draw.js` beyond the renderer. |
| R3 | R | Moods, statuses and gestures from the file; `mascot_moods(character =)`, `mascot_gestures(character =)`; per-character checks in `mascot()` and `update_mascot()`; studio lists. | R2 | Custom mood with fallback works end to end in a shinytest2 test. |
| E4 | E | Tracks (add/set, easings, discrete), change as `wiggle`/`hop`/gesture, switch rules, per-mood `channels`/`recolour`/`items`, `ring_pulse`, connector. | E3 | `nod`/`wave` rewritten as tracks reproduce today's frames; alpha_visor fixture plays `hat_hop`, `beep`; molecule fixture stretches. |
| R4 | R | `mascot_character(id =)`, `mascot_characters()`, `mascot_families()`, `mascot_anchors()`; family files and merge; studio chooser. | R3 | Listing functions documented with examples; studio completeness tests pass. |
| E5 | E | Glow and opacity, budgets enforced, LOD bands from CSS size; `tools/perf-check.R` (fourfold CPU slow-down, frame times over a gesture). | E4 | Budgets checked in JS guard; perf script prints a table; each band snapshot exists. |
| M1 | M | Tessa to v1, look unchanged; delete the adapter. | E3, R2 | T1 snapshots unchanged; `tessa.json` is v1; adapter removed. |
| M2 | M | Tessa improved look (gradients, facets, iris, bigger eyes). | M1, E5 | Founder approves in the studio; new snapshots committed. |
| M3 | M | alpha_visor as a test fixture first (acceptance of the format), then as a built-in if decision 8 changes. | E5, R4 | Five moods × three bands × two modes reviewed; budgets met. |
| M4 | M | Neer v1 with the simplified sheen and dark flip. | E5, R4 | Snapshots; contrast pairs pass. |
| M5 | M | Sela, Brim, Iso (fixtures). | M2 | Each reviewed at three sizes. |
| M6 | M | Knurl (fixture). | M3 | Spanner stays upright under flip and squash (test). |
| M7 | M | Cinder (fixture) with per-mood shapes. | M4 | Reviewed; a note records what waits for `morph`/`particles`. |
| S1 | S | Studio palette picker on the real characters; R5 `mascot_palettes()` and `mascot_theme(preset =)`. | R4, M1 | Founder can switch presets for each character in light and dark. |

**Parallel work:** R1 ‖ E1 ‖ T1 start together. Then R2 ‖ E2, R3 ‖ E3, R4 ‖ E4. E5 and M1 can overlap. M3–M7 are
independent of each other once their engine features exist.

**Later (format grows through `requires`):** `follow` (springs, closed form), `particles` (seeded, bounded),
`morph`, `blend`, `inputs`, wardrobe `fit`, a builder app (separate from the studio).

---

## 10. Decisions for the founder

1. **snake_case everywhere, including colour roles, from v1.** Tessa's roles become `eye_white`,
   `body_highlight` and so on; R already shows them this way, so users see no change, and the R conversion goes.
   *Recommendation: yes.*
2. **`mascot_character(id = "tessa")` instead of `name =`.** The display name and the permanent id are different
   things; `name` would collide with the file's `name`. *Recommendation: `id`.*
3. **No character inheritance in 0.1.0.** Families give defaults; remixing goes through R and produces a full file.
   `extends` stays reserved. *Recommendation: yes.*
4. **Every character defines the five shared moods;** extra moods need a fallback. Apps can then switch characters
   without checking moods. *Recommendation: yes.*
5. **Face kits ship as data** (`inst/faces/classic.json`, `screen.json`), and characters may tune or add styles.
   *Recommendation: yes.*
6. **The hex family's permanent id**, chosen before 0.1.0 because ids never change. *Recommendation:
   `tessellates`* (a real word, tied to Tessa's name; "Hexonians" can stay a nickname in docs).
7. **Palette presets** as `mascot_palettes(character)` and `mascot_theme(preset = "...")`, presets chosen only by
   seeing them on the character in the studio. *Recommendation: yes.*
8. **What ships in 0.1.0:** Tessa and Neer as built-ins (as `docs/scope.md` says); alpha_visor and the other picks
   are test fixtures that prove the format until each is reviewed. *Recommendation: yes; revisit alpha_visor after
   M3.*

---

## 11. Risks and what is left out

### Risks
- **Tessa's pixels during the move.** Small changes in drawing order or rounding change pixels. Mitigation: T1
  first, the adapter, and "pixel-identical" as the done-when of E1, E3 and M1.
- **Glow on phones.** `shadowBlur` cost is not measured yet. Mitigation: per-part glow, caps, none at 24 px, the
  perf script, and design fallbacks (a lighter fill instead of a glow).
- **R and JS checks drifting apart.** Mitigation: R is the authority; shared fixtures in tests.
- **Freezing the format too early.** v1 is frozen at 0.1.0; growth goes through `requires` names and reserved keys,
  so new features do not need format 2 unless an existing meaning changes.
- **Scope before 0.1.0.** Nine primitives and 18 PRs is a lot before the first CRAN release. Mitigation: 0.1.0
  needs R1–R4, E1–E5, T1, M1 and M4; the other characters can follow in 0.1.x without format changes.
- **Face kits too rigid or too loose.** Too few controls and Visorfolk faces look generic; too many and AI-written
  faces break. Mitigation: two kits, three controls, `tune` for numbers, `styles` for new shapes.
- **24 px legibility.** Mitigation: `micro` band overrides (bigger face, thicker outline, fewer parts), reviewed at
  real CSS size on light and dark pages; status text always beside.
- **File size and tarball.** JSON characters are small; screenshots are the size risk, so snapshots live in tests
  (not shipped) and site articles, per AGENTS.md.

### Left out on purpose
- Wardrobe fitting in detail (adapters, collar surfaces, shared items across characters): reserved `fit` and
  `wardrobe`; attachment E's model is the starting point for 0.2.0.
- Springs, particles, morphing outlines and blend modes: reserved keys and a direction (section 3.17), no schema.
- The character builder app, SVG and Lottie export, trailers.
- The vividness control: reserved `vividness` in palettes.
- Exact colours for Sela, Brim, Iso, Knurl and Cinder: round 5's values are the start; they are decided when each
  character is reviewed in the studio.
- Final names (Hexonians or Tessellates, alpha_visor's final name): decisions outside the format.
