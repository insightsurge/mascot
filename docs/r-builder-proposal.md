# Proposal: R character construction and later remix

Status: design for review, 2026-10-14. These signatures and examples are proposed; they do not run in the current package. Internal implementation follows independent design review. The format and semantics are in [engine-format-proposal.md](engine-format-proposal.md); stable application API decisions are in [r-api-decisions-0.1.0.md](r-api-decisions-0.1.0.md).

## 1. One authoring path

An R script, a later visual builder and the user's AI skill use the same constructors, checker and serializer. The engine receives checked data, irrespective of authoring route. The studio demonstrates exported functions; it does not become the creation app. The package does not call models or download art/assets.

There are four stages: individually checked components -> source specification (cross-references may be incomplete while editing) -> completely checked/resolved character -> preview/use/save. A source specification is not accepted by mascot() or update_mascot(). Constructor classes/fields remain internal in0.1.0. The final public authoring names are designed now and planned as experimental exports later, not silently added to the0.1.0 public API.

Every character has one family. Starting from a family selects reusable defaults but still requires actual body geometry. A UI may offer a checked starter character in that family. Starting from a character copies its resolved data into a new source specification; there is no parent pointer to the donor. Cross-family feature mixing is later experimental authoring, not runtime multiple inheritance.

## 2. Constructor signatures and format mapping

Required arguments precede `...`; all optional arguments after it must be named. A meaningful single-argument shortcut stays positional. An id comes first when a function addresses a specific character/part/anchor. A shape's optional item id is metadata, not a Shiny instance id. All names have the mascot_ prefix. Functions below return typed source components, without touching a registry, opening a viewer or writing files.

| Proposed signature | Result and format field |
|---|---|
| mascot_family(id, name, description, ..., defaults = list()) | Family definition: id/name/description/defaults; no implied parts. |
| mascot_shape(type, geometry, ..., id = NULL, fill = NULL, stroke = NULL, width = 2.5, alpha = 1, outline = FALSE, clip = NULL, lod = NULL, transform = NULL, cap = "round", join = "round") | One item; type becomes shape, geometry contains that shape's required keys. Named role/paint fills, not literal item colours. NULL optional keys omitted; transform is a finite [x,y,rotate] item transform, cap/join map directly to the format. |
| mascot_part(id, items, ..., parent = "root", at = c(0, 0), rotate = 0, scale = 1, layer = 0, variants = list(), switch = NULL, visible = TRUE, opacity = 1, glow = NULL, keep_upright = FALSE, no_flip = FALSE, lod = NULL) | parts entry; items is a list of shape components; variants are complete item lists. |
| mascot_anchor(id, part, ..., at = c(0, 0), rotate = 0, scale = 1, side = NULL, description = id, variants = list()) | Named anchors entry; arbitrary snake_case id, real owning part checked at final resolution; local position may lie outside silhouette. |
| mascot_face(kit, part, ..., at = c(0, 0), scale = 1, clip = NULL, eyes = list(), mouth = list(), blush = NULL, colours = list(), tune = list(), styles = list(), caps = list(), layer = NULL) | face block; kit is known id or checked embedded kit definition. |
| mascot_mood_definition(name, description, status, ..., fallback = NULL, pose = NULL, face = list(), channels = list(), recolour = list(), items = list(), effects = list(), reduced = NULL) | One moods entry; separate from runtime mascot_mood(name), which selects a mood. |
| mascot_track(channel, keys, ..., mode = "add") | One named typed channel track; keys is a list of key rows; set endpoints use NULL as format null. |
| mascot_gesture_definition(name, description, frames, tracks, ..., needs = character(), fallback = NULL, effects = list()) | One gestures entry; separate from runtime mascot_gesture(name). |
| mascot_palette(id, description, light, ..., dark = NULL) | Named palettes entry; light/dark role-colour maps; dark NULL uses light. |
| mascot_accessory(id, description, anchor, parts, ..., slot = id, colours = list(), lod = NULL) | Named accessory template; local part ids expand under stable prefix on wear. |
| mascot_ground(centre_height, ..., shadow = NULL) | ground block; shadow geometry/role validated. |
| mascot_build_character(id, family, name, description, colours, ground, parts, moods, ..., anchors = list(), face = NULL, gestures = list(), poses = list(), palettes = list(), follows = list(), brand = list(), contrast = list(), modes = list(), outline = NULL, motion = list(), effects = list(), accessories = list(), wear = character(), lod = list(), paints = list(), shapes = list(), pronouns = NULL) | Source mascot_character_spec; combines components and computes requires after resolution, not by guesswork from unmerged fields. |

Geometry uses ordinary named R lists with typed constructors, rather than one helper for every radius/x/y field. This keeps the R surface small while preserving exact format keys. Optional low-level additions must come after dots; dots itself rejects unknown arguments, not an uncontrolled escape hatch. A separate future shape-specific convenience layer may be added only when repeated use justifies it.

Build's family accepts a known family id or checked family definition. parts/moods/anchors/gestures/palettes/accessories accept lists of their constructor results; keyed maps may be used internally but public examples do not rely on class fields. Constructor ids become map keys, with duplicate detection. ground accepts mascot_ground(); outline/motion/poses/paints/shapes use documented typed named-list schemas from the format. Every top-level builder argument has a documented plain-data route; convenience helpers do not alter engine semantics. Existing runtime motion settings is a host-switch helper, not authored animation timing data, and cannot be substituted for build's motion.

## 3. Validation and editing boundary

All constructors start with checkmate checks for each argument, wrapped by with_mascot_asserts() for public experimental exports; cli reports other errors with mascot_error and a specific component class. Arrays/vectors have exact lengths and finite values. Check ids, ranges, enum choices, component classes and duplicate local keys immediately. Check references requiring the assembled character at mascot_check_character(), not prematurely in isolated components. Run one shared empty-dots check. Do not use library(), global options, external side effects or dependencies beyond the existing jsonlite/checkmate/cli path.

mascot_build_character() checks structural types and creates an immutable-by-contract source object; it does not claim every reference is usable. Construction can therefore describe parts before their anchors/fallbacks are resolved. Only the full checker creates mascot_character_data. Since callers can mutate R objects, every consuming boundary rechecks integrity; class membership alone is not proof. Package caches compare resolved content identity. Check failures report a stable code/path and useful fix, rather than stripping unsupported data.

Proposed operations:

| Signature | Contract |
|---|---|
| mascot_read_character(x, ..., from = "id") | from id or file, explicit to avoid filename/id ambiguity; id reads registry, file reads a supplied local path. Returns checked resolved data through the common pipeline. |
| mascot_check_character(x) | Source specification, raw list, checked data or JSON path; bounded parse/resolve/check; returns checked character visibly. Never fixes/recolours silently. |
| mascot_register_character(x) | Requires checked data; explicit session-only id binding, identical-content idempotence, built-in/conflicting-id errors; returns id invisibly. Object route needs no registration. |
| mascot_save_character(x, path, ..., overwrite = FALSE) | Requires checked data and user path; writes complete resolved JSON with embedded family metadata/custom kit definition, validates intended output before replacing; existing file errors unless explicit overwrite. Returns path invisibly. |
| mascot_add_anchor(id, character, anchor, ..., replace = FALSE) | id is the character's identity, must match character; anchor is mascot_anchor(). Copies source/checked data into a new source spec; duplicate name errors unless replaceTRUE. Same-id edits cannot be used against an already registered/mounted id until the caller gives the edited character a new id. |

The last editing convenience is a recommendation to evaluate during internal use, not an essential public0.1.0 export. Initial authoring can supply anchors directly in build. For broader edits, prefer constructors/remix over teaching users private list mutation. save is distinct from later PNG/SVG/video export; it saves character data only. Atomic overwrite uses a temporary file beside the user-supplied destination and rename; failure leaves the original untouched and cleans only its own temporary file. A denied filesystem write is reported with the exact path, never worked around elsewhere. Save/read round-trips preserve values, identity, family metadata and the checked palette_sources origin map without live donor/family-default links. This map is produced by resolution, not by mutating constructor fields.

## 4. Complete small character built in R

This is a proposed end-to-end example for the future authoring API. In0.1.0 these constructors are internal and the example is an internal acceptance scenario, not promised copy-and-run public code. The five mood definitions are explicit; family defaults supply safe nod/wave-to-rock fallbacks without adding arms. The screen kit and family are shipped data defined by engine sections4.2 and4.5; the latter supplies the exact source gestures and palette defaults, not the empty-default resolved metadata. Test the completed example only after those implementations exist.

```r
shell <- mascot_shape(
  "round_rect", list(x = -45, y = -40, w = 90, h = 80, r = 12),
  id = "shell", fill = "body", outline = TRUE
)
visor <- mascot_shape(
  "round_rect", list(x = -32, y = -25, w = 64, h = 36, r = 8),
  id = "visor", fill = "screen"
)
body <- mascot_part("head", list(shell, visor), at = c(0, -60), layer = 10)
badge_pin <- mascot_anchor(
  "badge", "head", at = c(25, 24),
  description = "Attachment point for a small badge."
)
badge <- mascot_part(
  "badge_disc",
  list(mascot_shape("circle", list(x = 0, y = 0, r = 5), fill = "accent")),
  parent = "head", at = c(25, 24), layer = 11
)
moods <- list(
  mascot_mood_definition("idle", "At rest.", "Ready",
    face = list(eyes = "dot", mouth = "smile")),
  mascot_mood_definition("thinking", "Working on a task.", "Working",
    face = list(eyes = "scan", mouth = "flat")),
  mascot_mood_definition("happy", "A task went well.", "Done",
    face = list(eyes = "arc", mouth = "wide")),
  mascot_mood_definition("worried", "Something needs attention.", "Check the result",
    face = list(eyes = "slant", mouth = "wavy")),
  mascot_mood_definition("celebrating", "A large task finished.", "Finished",
    face = list(eyes = "star", mouth = "wide"))
)
greet <- mascot_gesture_definition(
  "greet", "A brief greeting tilt.", 18,
  list(mascot_track("head.rotate", list(c(0, 0), c(0.3, 0.08), c(1, 0))))
)
draft <- mascot_build_character(
  "study_bot", "visorfolk", "Study Bot", "A small screen-faced study helper.",
  list(body = "#3f82ff", outline = "#1b1230", screen = "#06232a",
    feature = "#7cffe0", accent = "#ffc400"),
  mascot_ground(60), list(body, badge), moods,
  anchors = list(badge_pin),
  face = mascot_face("screen", "head", at = c(0, -7), clip = "head.visor",
    eyes = list(y = -4, spacing = 13), mouth = list(y = 8)),
  gestures = list(greet),
  palettes = list(mascot_palette("sea_glass", "My darker screen.",
    list(screen = "#051b20"))),
  outline = list(width = 2.5, colour = "outline"),
  contrast = list(list(fg = "feature", bg = "screen", min = 3,
    where = "screen face")),
  lod = list(micro = list(hide = "badge_disc", glow = FALSE))
)
character <- mascot_check_character(draft)
page <- mascot_preview(character = character)
mascot_save_character(character, file.path(tempdir(), "study_bot.json"))
restored <- mascot_read_character(file.path(tempdir(), "study_bot.json"), from = "file")
mascot("helper", character = restored)
# In a Shiny server: update_mascot("helper", gesture = "greet")
```

The badge part is deliberately placed explicitly, while badge_pin demonstrates a custom reusable attachment point. Replacing that part with a checked accessory attached to badge uses the same position without inventing an automatic fitter. Screen emission is suppressed at micro; no particles/ring pulse is required. The screen kit has no visible pupils, so host gaze is a no-op for these glyphs. It inherits no secret body parts. R acceptance must check family merge, five core states, final requires, all kit-used roles, round-trip equality, optional-argument naming and preview/mount before anyone calls this example executable.

## 5. Later experimental remix

Proposed signature: mascot_remix(id, character, ..., family = NULL, name = NULL, description = NULL, colours = NULL, face = NULL, parts = NULL, anchors = NULL, gestures = NULL, palettes = NULL, accessories = NULL, wear = NULL, mappings = list()). id is a new explicit character id, character is a checked donor/id/helper; final family defaults to the donor's family and remains mandatory. NULL leaves a source property unchanged in this copying operation; empty lists clear optional component maps, subject to final validity. No same-id cosmetic updates disguised as a new character, and no content-hash identity chosen silently. A new id makes the saved identity deliberate and reproducible.

First experimental scope is checked substitutions of colours/palettes, face kit/style, accessories and compatible gestures; supplied parts is reserved for later full body/limb composition and errors until supported. User anchors on real parts are allowed. Components identify required anchors/roles/parts/capabilities; mappings explicitly map donor names to receiver names, with no ambiguous partial mapping. Nested ids are rewritten deterministically; duplicate ids/slot clashes/missing roles/unsafe capability errors are shown before save. A palette is not transferred by raw role names when the destination uses different roles. A face needs a compatible bounding region/background; an anchor alone cannot make an oversized face fit. Family defaults fill missing non-anatomy values, then the full checker runs again.

Example idea, not a claim of present support: keep a Hexonian body, add a screen panel and compatible screen face, apply a mapped water palette and attach a cap to a user-defined crown anchor. Keep one final family or choose a new checked family. Do not import the donor's full family or live inheritance graph. The builder should show compatible choices, required explicit adaptations and unsupported combinations separately, and preview all five moods/modes/sizes before saving. Geometry fit still needs visual inspection; structural checks do not prove good art.

## 6. Reuse, release and acceptance

| Consumer | Reuses | Additional responsibility |
|---|---|---|
| R script | All constructors/check/save | Explicit supplied file path; developer decides appearance. |
| Separate builder app | Same source objects/checker, constructor-backed edits | Controls for parts/anchors/roles and clear compatibility feedback; never a second renderer/schema. |
| User's AI skill | Same format and functions | Agent generates R/spec locally, checks, previews and asks the user to judge appearance; package never makes model calls. |
| Package built-ins | Same internal read/check path | Whole fixtures, near-look/palette approval and published resource limits. |

0.1.0: internal family/shape/part/anchor/face/mood/gesture/palette/build/read/check/register/save machinery used by built-ins and representative fixtures; object acceptance integrated, not advertised as stable public authoring. 0.1.x: selected constructors and operations may be exported experimentally after internal evidence; this is a plan, not a guaranteed release assignment for every function. Full remix/component catalogue and builder app can follow later. Automatic fitting, arbitrary anatomy swapping and future runtime capabilities are not smuggled into the release.

Acceptance before export: every constructor assertion/empty-dots case, duplicate ids, unknown target/role, fallback cycles, missing needed anatomy, user anchor transforms/variants/hidden parents, protected built-in id, mutated checked object, save overwrite/failure cleanup, standalone round-trip, constructor-to-format equality for a transformed tucked foot with explicit cap/join and a face layer above an intervening part, family palette provenance round-trip, two simultaneous mascots, later remix identity, and final studio/roxygen/NEWS updates. Structural validity is separate from visuals/performance. These are future tests; none was run for this document.

## 7. Recommendations needing review

The broad authoring routes, mandatory family and custom anchors are agreed. The founder approved focused preview and removal of its inert placement/click arguments on 2026-10-14. Exact constructor names, the selector-versus-constructor separation, explicit remix id, detailed preview grid and first experimental export set remain recommendations for review. New exported names must be checked against base R, shiny, bslib and ggplot2 in the implementation environment before release; no R was run here. The future loader must not infer source kind from a string that might be both a filename and an id.
