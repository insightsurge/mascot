# Design review corrections, 2026-10-14

Design-only response to the review at `review/revised-design` commit 0526efb, against design 95afd34 and current-code comparison baseline main ace06f5. The independent verdict was **build after fixes**. This record does not change that verdict to an implementation pass; the revised contracts need a focused recheck before R1a is signed off. No package code changed.

Read the three revised proposals, then use the original finding ids below. "Addressed" means a document/example correction; runtime acceptance remains in the build plan.

| Finding | Disposition and correction | Where |
|---|---|---|
| H1 | Confirmed. Corrected worried/sad versus determined/angry/frown directions and widths; numeric assertions cover all five slopes. | Engine3.12,3.19,4.1; static check |
| M1 | Confirmed with one correction: today's sparkle has four tips/eight vertices, not eight tips. Added typed eye/lid outlines, independent lash geometry, pupil offsets, aligned highlights, blush defaults/roles and restored effect details. Remaining intentional differences are labelled for visual approval. | Engine3.12,3.19,4.1,4.3 |
| M2 | Confirmed. Defined mouth box as half-size, geometry mapping and face-unit strokes; restricted primitives and restored current mouth proportions. Circular arcs use explicit cubic approximations requiring near-look approval. | Engine3.12,3.19,4.1 |
| M3 | Confirmed. Materialised both family palettes/provenance in alpha_visor. A missing inherited role errors unless the source explicitly opts out of that palette; resolved output contains no opt-out nulls. | Engine4.4,5; builder2 |
| M4 | Confirmed contract gap. Separate ordered pending intent from accepted checkpoint; bounded private acknowledgements remove rejected whole patches from replay. Defined overflow, remount groups and gesture revisions; added U1 integration work. This is a proposed protocol, not an implemented server-cache fix. | Engine3.16,9; API8 |
| M5 | Confirmed. Named specific catchable errors/warnings and payloads while retaining decided base/update/contrast classes. | API1; engine6 |
| M6 | Confirmed ambiguity. Registry is process-wide, explicit app-start-up/development use; registration rejects an active reactive domain. Per-visitor data uses checked objects directly. | Engine5; builder3 |
| M7 | Confirmed. Added five representative-case units, explicit CHOICE/FREEZE, separate picked-character units and U1. I1 depends on checked data R2, not constructor B1. Robot picker can inspect fixture objects before promotion, avoiding a cycle. | Engine9,10 |
| M8 | Confirmed measurement gap; narrowed the blanket raster/throttling claim. Added presentation traces alongside JS duration, declared provisional presentation thresholds and defined the 300x300 frame/area. Real hardware/phone work remains unmeasured. | Engine2.4,3.0,9 |
| M9 | Confirmed. Every resolved/saved face embeds a complete matching kit definition, including built-ins. Reads never substitute the current package kit; version1 operation semantics remain frozen. | Engine3.12,4,5; builder3 |
| M10 | Accepted as a coupling problem, rather than an inferred-anchor bug: needs already named parts explicitly. Restricted family gestures to root channels. Study Bot declares its own anatomy candidates/fallbacks. | Engine4.5,5; builder4 |
| M11 | Confirmed. Key rows are lists; schema decides arrays/scalars/nulls; mode=NULL derives numeric-add versus discrete-set. Example includes local fallback candidates. | Builder2,4 |
| L1 | Confirmed. Removed invalid frames from progress/pulse examples; fixed operation/mode pairs, required closed/default styles and static no-gaze screen semantics. | Engine3.12,4 |
| L2 | Confirmed. Added colour_descriptions to top-level fields and builder, with family default support. | Engine3.1,5; builder2 |
| L3 | Accepted naming improvements. Component constructors use id; anchor editor accepts object+anchor without a duplicate id. Listings explain callable keys versus display names. Settled runtime selector names remain unchanged. | Builder2,3; API11 |
| L4 | Partially accepted. Made optional listing filters named-only and explained original versus preset=NULL. Retained intentional shared/concrete listing defaults, checked-object acceptance and built_in provenance: these implement the agreed internal object/registry route, not empty placeholder columns or public stable constructors. | API10,11 |
| L5 | Accepted intended behaviour; current character label already uses character display name, while mood name is an id. Future label uses display name plus shown status. No current R code changed. | Engine3.16,8 |
| L6 | Confirmed ambiguity. Contrast uses explicit role/page pairs and optional declared bg_paint, with conservative gradient/alpha bounds; unmodelled overlaps remain unverified. | Engine3.2,6 |
| L7 | Confirmed. One shared inset clip per ellipse eye covers pupil/iris/glints/lid fill/edge; outer face clips count separately. | Engine2.4,3.12 |
| L8 | Confirmed process gaps. Named future engine-visual workflow/rules exception, pinned container on CI host, repository-root strict runner, immutable image archives plus small reviewed PNG/manifest set, and old ace06f5 capture before E1. | Engine9 |
| L9 | Accepted. Development R warning for names absent from the known catalogue when target is unknown; informational, never a rejection of a potentially valid custom target. | Engine8; API1 |
| L10 | Confirmed missing fit rule, not proven alpha_visor overflow. Declared frame/ground, conservative authored reachable bounds and the limit of arbitrary external transforms. Actual extents remain implementation evidence. | Engine3.0,6 |

Additional API adjustments: the preview includes representatives of missing full/small/micro bands and defines responsive-size handling; explicit bs_theme brand leaders share explicit-colour precedence. The founder's approved preview scope and retained-preset fallback remain unchanged. Bubble replacement and later Quarto naming recommendations are not promoted to decisions.

The review's availability note read the main comparison baseline as a branch-parent claim. The header now makes the distinction explicit; history has not been rewritten. Review branch and original commit remain independent.

## Static checks and limits

Run from the design repository root:

```sh
python3 -I docs/reviews/2026-10-14-design-contract-check.py
```

The supporting script fails non-zero on the listed assertions: five duplicate-free JSON blocks; selected brow/face/mouth values; embedded-kit equality; family palette/provenance equality; root-only family tracks; parent/anchor/core-mood and track endpoint checks; constructor example text; 35-node dependency graph cycle detection; whitespace. Three planted-defect probes (reversed brow, dependency cycle, duplicate JSON key) each returned exit1 as required. It is a bounded document check, not the proposed full validator.

The original review script was also rerun against the changed proposal: all five blocks parse; Tessa and alpha_visor have no reported reference problems; all five slanted brows now match the current direction. That script prints diagnostics without enforcing a failing exit status, so its output was inspected.

No R, package gates, renderer, screenshot harness, engine performance, physical-phone measurements, CI or tarball checks ran. Added grammar and work expansion need implementation checks; screenshots/contrast/budget acceptance and the robot choice remain outstanding. The interactive report is an explanation aid, not runtime proof.
