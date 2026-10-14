# R API Decisions for mascot 0.1.0

Design for independent review. Current main `ace06f5`. No code implemented. The founder approved focused preview and missing-retained-preset handling on 2026-10-14; other recommendations remain explicitly identified.

This document proposes the remaining public R API contracts for `mascot` 0.1.0. It defines the stable user-facing interface, recommends canonical defaults to freeze, bounds experimental features, and establishes clean extension points for subsequent releases (such as Quarto shortcodes, character authoring, and custom palettes).

## 1. Standing House Rules

The following conventions govern all exported functions and are the intended public API contract; this static document does not verify implementation:
- **Identity first:** Every function addressing a specific mascot takes `id` as its first parameter (e.g. `mascot(id, ...)`, `update_mascot(id, ...)`).
- **Argument ordering:** Required parameters appear first, followed by `...`, followed by optional named arguments. One-argument helper functions retain their single argument positionally (e.g. `mascot_mood("happy")`, `mascot_status("Ready")`).
- **Strict dots checking:** Every function with `...` executes a shared `abort_dots()` check; unrecognised arguments trigger a `mascot_error` condition naming the offending parameters.
- **Error boundaries and diagnostics:** All functions validate arguments with `checkmate` assertions wrapped in `with_mascot_asserts()`, signalling `mascot_error` or `mascot_warning` via `cli` diagnostic messages.
- **Build-time errors vs runtime resilience:** Construction via UI functions (`mascot()`, helpers) throws immediate errors on invalid arguments. Server updates (`update_mascot()`) warn atomically via `mascot_warning` and leave the mascot unchanged, preventing running apps from crashing on malformed updates.
- **Helper encapsulation:** Constructors, S3 classes, and `format()`/`print()` methods are public API; internal list fields are private implementation details.
- **Data frame listings:** Listing functions return base data frames where the first column is the valid input value for corresponding parameters, the first row is the canonical default where a matching argument default exists, and existing columns/types are immutable. Listings without a selected-value default preserve authored order. New columns are appended only; placeholder columns are prohibited.
- **Naming and syntax:** British English spellings (`minimise`, `colour`) and `snake_case` identifiers throughout (including `update_mascot()`, with no camelCase alias).
- **Semantics of `NULL`:** In UI constructors, `NULL` denotes "none / follow default". In `update_mascot()`, `NULL` means "leave unchanged", while an empty helper invocation (e.g. `mascot_bubble()`) resets that setting to its default.
- **No output/render pair:** mascot renders as standard HTML/tagList; no `mascotOutput()` or `renderMascot()` is exported in 0.1.0 (`shiny::renderUI(mascot(...))` is documented).
- **Atomic updates across assets:** Every implementation PR changing an exported interface must simultaneously update Mascot Studio, documentation, and `NEWS.md`.

### Catchable condition classes (proposed implementation)

Every specific error below also inherits mascot_error; every warning inherits mascot_warning. Preserve already decided mascot_update_ignored and mascot_contrast. R/host diagnostics share stable codes where applicable; browser diagnostics cannot signal an R condition.

| Class | When / useful payload |
|---|---|
| mascot_error_argument | Structural/checkmate argument failure; argument, code, value. |
| mascot_error_choice | Valid type but unsupported enum/name for a known target; argument, choices, value. |
| mascot_error_dots | Unknown dot arguments; names. |
| mascot_error_character | File/component/semantic validation; code, path, value, fix (bounded problem list). |
| mascot_update_ignored | An invalid atomic update to a known target; reason/code; no fields committed. |
| mascot_contrast | User colour promise below required contrast; roles, measured/bounded ratio, minimum. |
| mascot_preset_dropped | Approved retained-preset fallback; preset and incoming character, development mode only. |
| mascot_name_unverified | Development-only unknown-target update name absent from all known catalogue characters; informational, not rejection. |

Test class inheritance and payloads during implementation; these classes are not claimed to exist today. Validators accept custom mood ids on syntax alone when there is no known target. A later known-target failure is not retroactively an R helper failure.

## 2. Shiny Input Bindings & Event Contracts

### Today
In `inst/www/mascot-host.js` (lines 838, 944, 1459, 1554), the client engine delivers four public Shiny inputs through one mascot input binding, using `window.Shiny.setInputValue(..., { priority: 'event' })`:
- `input$<id>_click`: integer count of user activations (clicks, taps, Space/Enter key presses, including menu toggle open/close actions) since mount. Initial value is `NULL`.
- `input$<id>_menu`: character ID of the menu item chosen by the visitor.
- `input$<id>_position`: character corner string (`"bottom-right"`) after snap, or list `{x, y}` in CSS pixels after free drag.
- `input$<id>_minimised`: logical flag indicating whether the mascot is currently minimised.

Documented in `R/click.R`, `R/placement.R`, and `R/popup-menu.R`. The event lifecycle for speech bubbles (`_bubble_closed`, issue #238) is not yet implemented.

### Options
1. **Option A:** Retain the 4 implemented inputs for 0.1.0 runtime; reserve `_bubble_closed` design with a simple reason string.
2. **Option B (Recommended):** Retain the 4 implemented inputs for 0.1.0 runtime. Fully reserve the contract for `input$<id>_bubble_closed` (#238) as a compound object `{reason, serial}`, firing once per visible bubble dismissal.

### Recommendation
Adopt Option B. Keep the 4 implemented inputs in 0.1.0 runtime. Do not revive obsolete `_clicked` or no-menu click semantics (`_click` increments on every button press, including menu opens/closes). Formally reserve the #238 design:
- `input$<id>_bubble_closed` payload is `{reason: "<type>", serial: <integer>}`.
- Allowed reasons: `"close_button"`, `"escape"`, `"timeout"`, `"replaced"`, `"cleared"`.
- Triggered once per visible bubble instance upon dismissal. Teardown on session disconnect or tab close does not fire an event.
- Initial value is `NULL`; input set with `priority: 'event'`.

### Reason
Compound `{reason, serial}` allows reactive apps to distinguish explicit user dismissals from programmatic updates or timeouts without event deduplication bugs. Distinguishing reserved design from 0.1.0 runtime prevents phantom documentation while making the planned boundary explicit.

### Effect on Users
Shiny developers reliably observe clicks and state transitions via standard `shiny::observeEvent(input$<id>_click, ...)` with the documented per-mount counts and repeated-event delivery.

## 3. Visual Preview (`mascot_preview`)

### Today
`R/preview.R` (lines 63-74): `mascot_preview(character = "tessa", ..., mood = NULL, status = NULL, bubble = NULL, size = 160, placement = "inline", theme = NULL, motion = FALSE, click = NULL)`. The comparison grid displays the requested `size` alongside fixed columns of 48, 32, and 24 px (`R/preview.R` line 116). `placement` and `click` are accepted for argument symmetry but are no-ops because the preview is an offline static page.

### Options
1. **Option A:** Retain `placement` and `click` as inert parameters to allow direct `do.call(mascot_preview, args)`.
2. **Option B (Recommended):** Remove `placement` and `click` from `mascot_preview()` before 0.1.0. Display the requested size plus representatives of every size band it does not cover.

### Recommendation
Approved by the founder on 2026-10-14: focus on visual inspection and remove the inert placement/click arguments. The detailed signature and inspection grid below remain the implementation design for independent review:
`mascot_preview(character = "tessa", ..., mood = NULL, status = NULL, bubble = NULL, size = 160, theme = NULL, motion = FALSE)`
- **Purpose:** Offline visual character and mood inspection across light and dark modes, not static image export or Shiny simulation.
- **Grid layout:** Rows represent moods (defaulting to all moods for the selected character). Columns show requested size first, then representatives for missing full/small/micro bands: 160/96/24 px. For requested 120, show 120,160,24; for requested 160, show 160,96,24. Numeric size covers its measured band, not just an equal value. Percentage/responsive sizes retain their requested responsive column and all three fixed columns because the band can change on resize; deduplicate only fixed numeric columns. The acceptance harness always checks 160/96/24 separately.
- **Behaviour:** Constructing the object writes no files and launches no Viewer/browser. Printing the returned `htmltools::browsable` tag list displays the page. The `contrast` attribute (data frame of findings < 3:1) is preserved.

### Reason
`mascot_preview()` cannot simulate floating behaviour or trigger Shiny reactive clicks. Retaining no-op parameters misleads developers. Comparing at 96 px (inspection size) and 24 px (legibility boundary) matches the planned character acceptance sizes; this is a design choice, not measured superiority over 48/32 px cells.

### Effect on Users
Clear, focused API for visual regression checks; no confusing inert parameters.

## 4. Mascot Studio (`mascot_studio`)

### Today
`R/studio.R` (lines 31-40): `mascot_studio(view = "studio", ..., fn = NULL, character = "tessa", run = TRUE)`. The default `character = "tessa"` is explicit on current main. With `run = FALSE`, returns a `shiny.appobj` without modifying global options. Decorated with an experimental lifecycle badge.

### Options
1. **Option A:** Mark `mascot_studio()` stable at 0.1.0.
2. **Option B (Recommended):** Retain `mascot_studio()` with its experimental lifecycle badge at 0.1.0, keeping the character builder separate.

### Recommendation
Adopt Option B. Keep the current signature:
`mascot_studio(view = "studio", ..., fn = NULL, character = "tessa", run = TRUE)`
- `view`: `"studio"` (function playground) or `"examples"` (gallery).
- `fn`: selects a guide function within the studio view.
- `run = FALSE`: returns `shiny.appobj` for headless testing; no global options or environment pollution.
- Experimental interface: retains `@evalRd` experimental badge for 0.1.0.
- Asset creation/remixing tools remain separate (`mascot_builder()` later) and will not be embedded into the consumer studio.

### Reason
The studio is a developer playground and learning tool. As face kits and new characters arrive during 0.1.x, its control panels will evolve. Keeping asset builder tools distinct prevents bloat in the consumer app.

### Effect on Users
Provides a stable invocation pattern for interactive exploration and automated smoke tests while allowing the studio UI to improve over minor releases.

## 5. Experimental Inventory and Stable Core

### Today
Lifecycle status is declared per feature across documentation and roxygen tags:
- `mascot_preview()`: experimental function (`R/preview.R`).
- `mascot_studio()`: experimental interface (`R/studio.R`).
- `mascot_theme(css = ...)`: experimental CSS custom property binding (`R/theme.R`).
- `mascot_placement(drag = "free")`: experimental freeform dragging mode (`R/placement.R`).
- `input$<id>_click`: historically labelled experimental; current source documents its unified count behaviour without an experimental badge. Freezing this input at 0.1.0 is the recommendation below, not an inferred historical lifecycle approval.

### Options
1. **Option A:** Apply a blanket experimental label to the entire package.
2. **Option B (Recommended):** Confine experimental designations strictly to designated advanced capabilities; declare the core API stable.

### Recommendation
Adopt Option B.
- **Stable Core (0.1.0):** `mascot()`, `update_mascot()`, `mascot_mood()`, `mascot_status()`, `mascot_bubble()`, `mascot_size()`, `mascot_placement(drag = "none" | "snap")`, `mascot_action()`, `mascot_popup_menu()`, `mascot_motion_settings()`, `mascot_character()`, and all listing functions. The click lifecycle (`input$<id>_click`, `input$<id>_menu`) is stable core.
- **Documented Experimental (0.1.0):** `mascot_preview()`, `mascot_studio()`, `mascot_theme(css = ...)`, and `mascot_placement(drag = "free")`.
- **Internal / Non-Exported:** Asset authoring functions (`mascot_read_character()`, `mascot_check_character()`, `mascot_register_character()`). Later public authoring constructors (`mascot_build_character()`, `mascot_remix()`) will enter as experimental in 0.1.x/0.2.0.

### Reason
Application authors need clear promises for display and interaction while advanced tooling continues to evolve.

### Effect on Users
Developers can distinguish the proposed stable contract from features whose experimental API may change.

## 6. Frozen Defaults & `NULL` Semantics

### Today
Parameter defaults are implemented across individual files. In `mascot()`, `NULL` signals "none / default". In `update_mascot()`, `NULL` signals "leave unchanged", while empty helper calls reset settings.

### Options
Keep current defaults, or change them before 0.1.0 and document the effects.

### Recommendation
Freeze the following proposed defaults at 0.1.0, separating raw NULL switch defaults from their effective values.

### Reason
One table prevents help and studio controls from drifting.

### Effect on Users
Defaults and reset behaviour become explicit rather than dependent on implementation details.

### Canonical Defaults Table (Proposal for 0.1.0)

| Scope | Parameter | Canonical Default | Notes |
|---|---|---|---|
| `mascot()` | `character` | `"tessa"` | Takes ID string or `mascot_character()` |
| `mascot()` | `mood` | `"idle"` | Five core shared moods guaranteed |
| `mascot()` | `status` | `NULL` | Follows the current mood status text |
| `mascot()` | `bubble` | `NULL` | None / cleared |
| `mascot()` | `size` | `160` | Pixels (CSS px) |
| `mascot()` | `placement` | `"bottom-right"` | Floating corner |
| `mascot()` | `theme` | `NULL` | Character native colours; follows page mode |
| `mascot()` | `motion` | `TRUE` | Follows visitor reduced-motion preference |
| `mascot()` | `click` | `NULL` | Mascot is a non-interactive image |
| `mascot_bubble()` | `duration` | `5` | Seconds; `Inf` keeps open; `NULL` invalid |
| `mascot_bubble()` | `closable` | `TRUE` | Shows close button |
| `mascot_size()` | `small_screen` | `"auto"` | Scales to <= 96 px on screens <= 575.98 px |
| `mascot_placement()` | `minimise` | `TRUE` | Shows minimise control for floating |
| `mascot_placement()` | `drag` | `"none"` | Options: `"none"`, `"snap"`, `"free"` |
| `mascot_theme()` | `mode` | `"auto"` | Detects page/bootstrap theme; falls back to light |
| `mascot_theme()` | `preset` | `NULL` | Character or family colour preset |
| `mascot_theme()` | `css` | `NULL` | Experimental CSS variable mapping |
| `mascot_action()` | `tooltip` | `TRUE` | Shows label in tooltip on hover/focus |
| `mascot_action()` | `disabled` | `FALSE` | Retains button, suppresses clicks |
| `mascot_popup_menu()`| `direction` | `"auto"` | Opens towards available viewport space |
| `mascot_popup_menu()`| `tooltip` | `TRUE` | Shows label in tooltip if label supplied |
| `mascot_motion_settings()` | individual switches/messages | `NULL` | Raw defaults follow `others = TRUE`, so effective switches are TRUE and messages selects all three panels |
| `mascot_motion_settings()` | `others` | `TRUE` | Effective default for every unnamed present/future switch |
| `mascot_preview()`| `size` | `160` | Comparison grid root size |
| `mascot_preview()`| `motion` | `FALSE` | Steady inspection faces by default |
| `mascot_studio()` | `character` | `"tessa"` | Explicit default |
| Helpers | mood `name`, status/bubble `text`, size `size`, placement `position` | `"idle"`, `NULL`, `160`, `"bottom-right"` | The matching primary defaults |
| Theme | `light`, `dark` | `NULL` | No explicit role override |
| Action/menu | `label`, menu `items` | `NULL` | No action/menu until configured |
| Preview | `character`, `mood`, `status`, `bubble`, `theme` | `"tessa"`, `NULL`, `NULL`, `NULL`, `NULL` | NULL mood shows all selected-character moods |
| Studio | `view`, `fn`, `run` | `"studio"`, `NULL`, `TRUE` | fn defaults to mood guide in studio view |
| `update_mascot()` | all change fields; `session` | `NULL`; current reactive domain | NULL change field leaves unchanged; no session outside server is an error |

### `NULL` Semantics Summary
- **UI Constructors (`mascot()`, helpers):** `NULL` means "none" (for bubble, status, click, theme, css) or "follow system default". Supplying invalid `NULL` where a value is mandatory (e.g. `size = NULL`, `duration = NULL`) raises a build-time `mascot_error`.
- **Server Updates (`update_mascot()`):** `NULL` means "leave current state untouched". Supplying an empty helper resets that component to default:
  - `bubble = mascot_bubble()` -> clears speech bubble.
  - `status = mascot_status()` -> restores status text following mood.
  - `theme = mascot_theme()` -> resets character to native colours.
  - `click = mascot_action()` or `mascot_popup_menu()` -> removes button/menu, returning mascot to an image.

## 7. Quarto Shortcode Reservation (0.2.0)

### Today
No shortcode implementation exists in 0.1.0. Ledger Part 4 / R12 establishes that helper options must flatten into top-level shortcode attributes without naming collisions.

### Options
Retain the current narrower contract, or adopt the explicit extension recommended below before 0.1.0. Already settled names/rules are not reopened.

### Recommendation
Reserve the following flattened attribute mapping for Quarto 0.2.0:
- **Direct String Values:** `id`, `character`, `mood`, `status`, `bubble` (plain text string).
- **Layout & Positioning:** `size`, `small_screen`, `position` (from `mascot_placement(position =)`), `minimise`, `drag`.
- **Bubble Controls:** `duration`, `closable`.
- **Menu & Click:** Reserve `menu_direction` (specifically not generic `direction`), `click_label`.
- **Theme & Mode:** `theme` (preset name string), `mode` (`"auto"`, `"light"`, `"dark"`).
- **Motion:** `motion` (`"true"` / `"false"`).

Rich objects and interactive menus are outside this minimal shortcode proposal; this does not prohibit future offline HTML support in Quarto.

### Reason
Naming the shortcode attribute `menu_direction` avoids collisions with future bubble or tooltip directional controls (issues #233, #257).

### Effect on Users
Quarto users gain clean, declarative shortcodes (`{{< mascot character="tessa" mood="happy" bubble="Welcome" position="bottom-right" menu_direction="top" >}}`) with identical semantics to R.

## 8. Shiny Module Contract & Reactive Isolation

### Today
`R/update-mascot.R` (lines 79-84, 312-380) implements namespaced update queueing: UI declares `mascot(ns("helper"))`; server calls `update_mascot("helper")` or `update_mascot(session$ns("helper"))`. `send_update()` strips any existing session prefix, then applies `session$ns(id)` exactly once. Unmounted updates are stored in `session$userData$mascot_updates[[session$ns(id)]]`. On remount, `observeEvent(session$input[[id]])` detects client connection and replays latest state if client revision lags server revision.

### Options
Retain the current narrower contract, or adopt the explicit extension recommended below before 0.1.0. Already settled names/rules are not reopened.

### Recommendation
Formalise and document the complete module contract:
1. **Namespace Isolation:** Both local ID (`"helper"`) and prefixed ID (`session$ns("helper")`) are accepted in server code; the namespace is resolved once. Nested modules isolate cleanly.
2. **Local Input Bindings:** Shiny inputs (`_click`, `_menu`, `_position`, `_minimised`) are published under the full namespaced ID, ensuring `input$helper_click` is accessible locally inside `moduleServer`.
3. **Atomic Queued Updates:** Retain ordered whole patches per session until the mounted target is known. Each patch validates atomically against its then-current character; only accepted patches fold into retained state. The latest accepted early gesture plays once. Never merge unvalidated fields newest-wins. Engine section3.16/U1 defines the private acknowledgement, bounded intent journal and accepted checkpoint.
4. **Remount State Retention:** When dynamic UI (e.g. `renderUI`, tab switches) unmounts and remounts a mascot with the same ID, the accepted checkpoint replays, then pending whole patches in order. Rejected patches are removed entirely and cannot poison future replays; acknowledged gestures never replay. A new mount with a different character revalidates the documented character/mood, theme and independent-field groups, preserving valid independent state.
5. **Mount Counter Reset:** `input$<id>_click` counts activations for the current DOM mount. Upon remount, the click counter resets to initial state.
6. **No Session Leaks:** Shiny update queues/checkpoints live in `session$userData` and are destroyed on session disconnect; state is never persisted across user sessions.

### Reason
Aligns with standard Shiny module encapsulation practices and prevents memory leaks or cross-session state pollution.

### Effect on Users
Mascot integrates seamlessly into complex, modular Shiny applications without custom session bookkeeping.

## 9. Theme Presets & Palette Resolution

### Today
`R/theme.R` (line 83) defines `mascot_theme(..., light = NULL, dark = NULL, mode = "auto", css = NULL)`. Founder decisions on 2026-10-13 settled adding `preset = NULL` to `mascot_theme()` and introducing `mascot_palettes(character = "tessa")`.

### Options
Retain the current narrower contract, or adopt the explicit extension recommended below before 0.1.0. Already settled names/rules are not reopened.

### Recommendation
1. **Preset Parameter:** Update signature to `mascot_theme(..., preset = NULL, light = NULL, dark = NULL, mode = "auto", css = NULL)`.
2. **String Shortcut:** Passing a plain string to `theme = "ocean"` in `mascot()` or `update_mascot()` is strictly an alias for `mascot_theme(preset = "ocean")`. No invented `"inherit"` or `"page"` strings (the default `theme = NULL` already tracks page mode).
3. **Resolution Precedence:**
   - **Priority 1 (Highest):** CSS variables (`css = list(...)`). Invalid/missing CSS variables fall back to baseline colours and log a browser console warning.
   - **Priority 2:** Explicit per-role colour maps (`light = list(...)`, `dark = list(...)`), or brand leaders extracted from a whole `bslib::bs_theme()` supplied as the theme alternative. A bs_theme is not a light/dark map and these alternative forms are not merged.
   - **Priority 3:** Named preset roles (`preset = "..."`).
   - **Priority 4 (Baseline):** Character native default colours.
   Supplied colours are never altered or auto-adjusted; contrast warnings are issued if contrast falls below 3:1.
4. **Resolution Timing:** Presets are resolved at render/update time against the active character registry, not during `mascot_theme()` construction.
5. **Character Swaps & Missing Presets (approved 2026-10-14):** Palette presets are tied to character/family capabilities. If `update_mascot()` swaps a character while retaining a preset that does not exist on the incoming character, the retained preset is dropped while valid explicit role overrides are kept over the incoming baseline. Server-known retained-preset fallback emits an R `mascot_preset_dropped` (inheriting `mascot_warning`) in development mode; deferred browser resolution emits a development diagnostic, not an R condition. If an update explicitly supplies an invalid preset for the target character, the atomic patch is rejected with `mascot_update_ignored` (inheriting `mascot_warning`).

### Reason
Maintains strict separation between theme specification and character assets, ensuring runtime character swaps never crash an active dashboard.

### Effect on Users
Simple, intuitive preset usage (`theme = "ocean"`) with predictable fallback behaviour.

## 10. Character Selection & Identification (`mascot_character`)

### Today
`R/characters.R` (lines 22-32): `mascot_character(name = "tessa")`. The founder settled renaming `name` -> `id` (`mascot_character(id = "tessa")`).

### Options
Retain the current narrower contract, or adopt the explicit extension recommended below before 0.1.0. Already settled names/rules are not reopened.

### Recommendation
1. **Renamed Selector Signature:** `mascot_character(id = "tessa")`.
2. **Selector Only (0.1.0):** In 0.1.0, `mascot_character()` functions purely as a reference/selector object. It does not accept mutation arguments (`name`, `accessories`, `colours`, `voice`).
3. **Per-Instance Styling:** Colours are customised via `theme = mascot_theme(...)`, not by mutating the character object.
4. **Authoring Distinction:** Asset creation/editing will use a dedicated constructor (`mascot_build_character()` unexported in 0.1.0) and later `mascot_remix()`.
5. **Uniform Acceptance:** `mascot()`, `update_mascot()`, and character-taking listing functions accept a character ID string (`"tessa"`), a `mascot_character` helper object, or checked character data through the same validation path. The checked-object route is the agreed internal creator/extension route in0.1.0; constructors, object fields and registration are not promised stable public authoring APIs. Id/helper use remains the documented ordinary user route.
6. **No Runtime Inheritance:** Character inheritance chains are not resolved at runtime (the `extends` field in the format remains reserved).

### Reason
Preserves a clean distinction between selecting a character in consumer UI code and authoring/remixing character assets.

### Effect on Users
Clear, memorable mental model: choose a character with `mascot("helper", character = "tessa")` or `mascot_character("tessa")`; style it with `mascot_theme()`.

## 11. Listings & Introspection Data Frames

### Today
Existing listings return base data frames with varied column layouts (`R/colour-roles.R`, `R/moods.R`, `R/gestures.R`). House rules require immutable schemas, descriptions for every item, and no placeholder columns.

### Options
Retain the current narrower contract, or adopt the explicit extension recommended below before 0.1.0. Already settled names/rules are not reopened.

### Recommendation

#### Detailed Listing Contracts (0.1.0)

| Function | Signature | Columns and types | Ordering / origin |
|---|---|---|---|
| mascot_characters | (..., family = NULL) | id,name,description,family (chr), is_default,built_in (lgl) | Tessa first if present; otherwise stable shipped-member order. is_default is true only for Tessa. built_in has real backing data from internal registry R2. |
| mascot_families | () | id,name,description (chr) | Hexonians first, then stable family order; members via character filter. |
| mascot_anchors | (..., character = "tessa") | name,description,part,side (chr) | Authored anchor order; side l/r or NA. No invented universal bubble anchor/default. |
| mascot_moods | (..., character = NULL) | name,description,status (chr), shared (lgl), fallback (chr) | Core five first, idle first; core fallback NA. Extras follow authored order. NULL selects shared metadata. |
| mascot_gestures | (..., character = NULL) | name,description,fallback (chr), frames (int) | nod then wave, then extras; NULL reports shared nominal nod18/wave30; character-aware frames report the effective playable target duration (for example wave -> rock reports18). fallback retains the declared next candidate or NA, never a self-cycle; it is not inferred from the duration. |
| mascot_colour_roles | (..., character = "tessa") | role,colour,follows,shade (existing chr), then description,brand (chr) | Preserve current columns/types/order. Description from authored metadata or humanised role name; brand comma-separated slot ids or NA. |
| mascot_palettes | (..., character = "tessa") | name,description,source (chr) | Proposed synthetic original row first, meaning native mode colours/no preset overrides; reserve original against user preset ids. source character/family comes from the checked, saved palette_sources map; native applies only to synthetic original. Origin survives standalone save/read and never consults today's family defaults. |

### Listing Rules
- `name` in mood/gesture/palette/anchor rows is the callable permanent component id; `description` is human text. Character/family `name` is their display name and `id` is the callable key.
- All optional character filters are named after dots. NULL remains meaningful for shared mood/gesture metadata; concrete anchors/roles/palettes default to Tessa. These intentional defaults need not be identical.
- `built_in` is real process-registry provenance, not an empty placeholder: shipped rows TRUE, internally registered custom rows FALSE. It is retained under the agreed object/registry route and tested with both kinds.
- The synthetic `original` palette row represents the native state selected by preset=NULL, rather than pretending NULL is a string palette id.
- Output is always a base data frame.
- First column matches the valid argument for corresponding functions.
- First row represents a matching argument default where one exists; anchors/colour-role rows preserve authored order because there is no selected-anchor/role default. Filtered listings do not invent a new global default.
- No empty placeholder columns are exposed today.

### Reason
Ensures strict backwards compatibility for introspecting tools and Mascot Studio while keeping data frame schemas robust.

### Effect on Users
Developers and studio components reliably introspect character capabilities with uniform, tidy data frames.

## 12. Hidden Hooks & Acceptance Checklist (#247)

### Today
`R/styling.R` documents the approved public CSS styling contract:
- **Public Classes:** `.mascot`, `.mascot-status`, `.mascot-bubble`, `.mascot-menu`, `.mascot-tooltip`.
- **Public Custom Properties:** `--mascot-panel-bg`, `--mascot-panel-color`, `--mascot-panel-border`, `--mascot-restore-bg`, `--mascot-restore-fg`, `--mascot-restore-glow`, `--mascot-z-index`.
- **Private Internals:** All `--_mascot-*` custom properties, JavaScript globals (`window.mascot`), data attributes (`data-mascot-*`), and Shiny websocket messages (`mascot:update`) remain private.

### Options
Retain the current narrower contract, or adopt the explicit extension recommended below before 0.1.0. Already settled names/rules are not reopened.

### Recommendation

#### Acceptance Checklist for Implementation Issues (#247)
1. **API Renames:** Update `mascot_character(name =)` to `mascot_character(id =)`. `update_mascot()` is already implemented; retain it and do not repeat that rename.
2. **Preview Cleanup:** Strip `placement` and `click` from `mascot_preview()`; implement requested-size plus missing-band 160/96/24 grid columns.
3. **Listing Enhancements:** Implement `mascot_characters()`, `mascot_families()`, `mascot_anchors()`, `mascot_palettes()`, and update `mascot_colour_roles()` columns.
4. **Theme Presets:** Add `preset = NULL` to `mascot_theme()` and implement string preset resolution.
5. **Documentation & Studio:** Polish all roxygen help pages, update Mascot Studio controls and code generators, and record changes in `NEWS.md`.

### Reason
Make the supported boundary explicit and keep public promises in step with the implementation.

### Effect on Users
Users know which documented hooks are supported and which internals may change.

## 13. Approved Decisions and Remaining Choices

The founder approved choices 2 and 3 on 2026-10-14. Choices 1 and 4 remain later-release recommendations, to settle before their own implementation. Approval records design intent; no behaviour has changed in the current package.

1. **`_bubble_closed` trigger scope on replacement (#238):**
   - *Scenario:* An app calls `update_mascot(id, bubble = "New alert")` while a previous bubble is still visible.
   - *Choice:* Should `_bubble_closed` fire with reason `"replaced"`, or should it only fire on explicit user dismissal (`"close_button"`, `"escape"`, `"timeout"`)?
   - *Recommendation:* Fire with reason `"replaced"`. This allows state-tracking observers to know when an active prompt was superseded without complex timer logic.

2. **Approved: remove `placement` and `click` from `mascot_preview()`:**
   - *Scenario:* A developer passes identical argument lists to `mascot()` and `mascot_preview()` via `do.call()`.
   - *Choice:* Keep inert `placement` and `click` arguments (which do nothing in previews), or remove them for API purity?
   - *Decision (founder, 2026-10-14):* Remove both inert arguments. Preview inspects appearance, moods and sizes; it does not simulate floating placement or Shiny click behaviour. Other proposed preview details remain subject to independent review.

3. **Approved: handle missing retained presets on character swap:**
   - *Scenario:* A mascot styled with `theme = "ocean"` is swapped to a new character that lacks an `"ocean"` palette preset.
   - *Choice:* (A) Drop the preset, revert to the new character's native colours, and warn in development mode; (B) reject the character swap. A family preset of the same name is already included in available merged presets and is not a separate fallback.
   - *Decision (founder, 2026-10-14):* Option A. Drop only the unavailable retained preset, use the incoming character's native baseline, preserve valid explicit overrides and warn through the applicable R/browser boundary. An explicitly supplied invalid incoming preset still rejects the atomic patch.

4. **Quarto shortcode menu direction attribute:**
   - *Scenario:* A Quarto author specifies menu orientation in a shortcode.
   - *Choice:* Use generic `direction="top"` or explicit `menu_direction="top"`?
   - *Recommendation:* Explicit `menu_direction="top"`. This reserves room for future speech bubble or tooltip placement (`bubble_direction`) without syntax collision.
