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

## Recheck round: 2026-10-14 (ace9181 to corrected design)

Source recheck: review/revised-design commit 50f7d38f4a24571dd70ed9ddd9a2376f56db3dd7, docs/reviews/2026-10-14-design-fixes-recheck.md. Earlier rows above remain the historical first-round record; this section supersedes their named-only listing recommendation and single-revision/raw pre-mount cap design. Source baseline remains main ace06f5.

Verified the claims against the pinned source. The current binding reports mount/revision and does not use its subscription callback; placement uses the stated informational class chain; positional colour-role calls exist in the studio; stroke() defaults to miter. N1 batching and N4 headless presentation effects remain untested runtime hypotheses; the revised contracts explicitly address those risks without claiming a reproduction. No finding was rejected in this round.

The new queue contract distinguishes compacted prospective state before an unknown target from atomic dispatched transactions after the target is known. This intentionally allows independent early state to survive an invalid early mood group, while an invalid known-target patch commits no fields. It does not mark discarded early intent as accepted.

| Id (original recheck order) | Status | Correction | File:line evidence |
|---|---|---|---|
| N1 | Fixed (design) | Cumulative, idempotent snapshots include the full rejection window; server confirmation controls eviction. R issues content tokens; the browser echoes them. Subscription callback, duplicate/out-of-order/lost delivery, derived mood and remount watermarks are explicit. | docs/engine-format-proposal.md:431; :433; :435; :437; docs/r-api-decisions-0.1.0.md:240; :241 |
| N2 | Fixed (design) | Before ready, compact by dependency group and preserve character-change order; 100 same-context calls retain newest values. Limit 20 character segments, not 20 early calls. Frozen groups dispatch in bounded windows; known-target transactions still reject atomically. | docs/engine-format-proposal.md:423; :425; :427; :429; docs/r-api-decisions-0.1.0.md:240 |
| N3 | Fixed | All five character listings take a positional character argument without dots. Existing colour-role callers remain valid; the listing rule and general single-argument exception now agree. | docs/r-api-decisions-0.1.0.md:11; :315; :316; :317; :318; :319; :323 |
| N4 | Fixed (design) | Founder nominates the headed desktop; record model/OS/GPU/browser/refresh/DPR before runs. 30Hz presentation thresholds apply to headed hardware; headless T1 traces are diagnostic only. No device chosen or measured here. | docs/engine-format-proposal.md:91; :93; :4308; :4311 |
| L8 residual | Fixed (design) | Named retained store and responsible owner must be recorded before T1, including retention/retrieval; neither selected here. Added only dev/visual-baselines/ to .gitignore. | docs/engine-format-proposal.md:4313; .gitignore:32 |
| N5 | Fixed | Removed stale family candidate-needs sentence. Family defaults use defined root.rotate/lift/scale_x/scale_y only; no undefined root.x/root.y. Local builder candidates still exercise anatomy fallback. | docs/engine-format-proposal.md:4121; :4229 |
| N6 | Fixed | Prerequisites are split into exact comma-separated tokens and checked against declared units; text prerequisites became R1a/T1 ids. Explicit ValueError checks and non-zero exit replace all assert statements; optimisation cannot remove them. | docs/reviews/2026-10-14-design-contract-check.py:16; :93; :110; :144; docs/engine-format-proposal.md:4276; :4279; :4282; :4285; :4302 |
| N7 | Fixed | Declared visor_glass as bg_paint for the glow/screen pair. Kept the draft display name and recorded that the founder chooses the shipping robot name. No contrast/rendering pass claimed. | docs/engine-format-proposal.md:2734; :2815 |
| N8 | Fixed (design) | Preserved mascot_placement_ignored inheriting mascot_message. Added mascot_error_file with supplied path, read/save operation and code; distinguished argument and malformed-data errors. Builder and engine reference the same condition contract. | docs/r-api-decisions-0.1.0.md:25; :32; :33; docs/r-builder-proposal.md:54; docs/engine-format-proposal.md:4241 |
| M1 residual | Fixed | Set grit and determined item joins to miter in the classic fixture and embedded Tessa copy, preserving current stroke() semantics; migration table records this. | docs/engine-format-proposal.md:467; :911; :976; embedded kit checked for equality by script |

### Commands and observed results

Control, from the design repository root:

```sh
python3 -I docs/reviews/2026-10-14-design-contract-check.py
```

Exit 0: PASS five duplicate-free JSON examples; strict prerequisite tokens; optimisation-safe checks; selected face/mouth/snapshot/provenance/reference/endpoint checks; 35-node acyclic plan. This is a document check, not the future validator.

For each probe, copied docs/ into a fresh tempfile.TemporaryDirectory, changed only its engine proposal as specified below, and ran the exact command from that temporary root. Every temporary copy was removed afterwards; before/after source-document digests matched. The final column is actual process output.

| Planted defect | Exact command in that temporary copy | Exit | Output |
|---|---|---:|---|
| reversed worried brow | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: worried` |
| dependency cycle | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: dependency cycle R1a` |
| duplicate JSON key | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: duplicate JSON key: id` |
| unknown prerequisite | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: unknown prerequisite 'X9' for MR` |
| reversed worried brow under optimisation | `python3 -I -O docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: worried` |

Mutations, each applied once to a fresh copy: worried path M-16 2 L18 10 -> M-16 10 L18 2 (also under -O); R1a prerequisite none -> FREEZE; duplicate the classic id key; append X9 to MR prerequisites. The five probes all exited 1 as required; their outer probe runner exited 0 only after confirming every failure and unchanged source files.

Additional checks: git diff --check exited 0; git check-ignore dev/visual-baselines/probe.png exited 0 and printed that path. Diff reread against N1-N8 and both residuals; substantive fixes are in the proposal/API/checker text, not just this log. Only the six authorised paths changed: the three proposals, this log, the existing checker and the one .gitignore entry.

No R, gates, browser, package/runtime tests, performance, CI or tarball checks ran, per the design-only brief. No engine, protocol or contrast runtime result is claimed. Desktop/phone nominations, the retained baseline store/owner and the robot display name remain explicit future founder choices; no choice is needed to finish this document correction. No PR, merge, force-push or history rewrite.

## Targeted queue review: B1-B4 against 14a2a20 (2026-10-14)

The founder supplied the targeted reply in chat. It permits core implementation while blocking U1/I1 on four queue gaps; no repository review commit was supplied for this reply. Verified against the 14a2a20 text and ace06f5 code: unmount tears down without reporting liveness; mascot() is documented outside a reactive domain and has no session argument; the draft explicitly split early mixed calls; remount ownership was ambiguous. The prior pre-mount atomicity exception and live-window rejection were design mistakes and are withdrawn. Earlier rows remain historical, not the current queue contract.

| Finding (review ids, not build-unit ids) | Design correction and limits | Evidence |
|---|---|---|
| B1 | Full window and absent/unmounted DOM both use the same whole-call buffer. An unmounted lifecycle snapshot precedes teardown; lost notices cannot reject further ordinary updates. Ready reconciles outcomes before draining. Capacity is independent of the 20 issued-revision window. Real unsubscribe/event delivery remains a U1 test. | docs/engine-format-proposal.md:425; :437; :439; docs/r-api-decisions-0.1.0.md:240; :241 |
| B2 | Character-content tokens are issued lazily by R process, so static UI needs no session. mount_token separately identifies emitted UI defaults, scoped to the static template or emitting session; content_token describes the processed prefix. No browser hash or token-only authority to read other sessions. Actual global-UI/two-session acceptance requires R and is not run. | docs/engine-format-proposal.md:441; :443; docs/r-api-decisions-0.1.0.md:240; :241 |
| B3 | Preserve complete immutable original calls and their validation guards. Independent fields coupled to an invalid mood/preset are rejected with the entire call. Different unresolved guards cannot overwrite valid older candidates; sequence order selects surviving values. The earlier independent-field rescue is removed. New explicit guard-bucket resource recommendation below needs Q1 review. | docs/engine-format-proposal.md:423; :427; :429; :431; :433; docs/reviews/2026-10-14-design-contract-check.py:33; :161 |
| B4 | Explicit ownership table: accepted server character wins; otherwise new UI character wins. Define mood, theme/reset, independent and click groups; restore preserves ownership and never replays gestures. UI-baseline mount_token is separate from prefix content_token. Both character outcomes and reset/fallback cases appear in the reference model; real remount remains U1/I1 evidence. | docs/engine-format-proposal.md:449; :453; docs/r-api-decisions-0.1.0.md:241; docs/reviews/2026-10-14-design-contract-check.py:141 |

### Explicit resource/gating recommendations

Keeping only the latest value across different unvalidated predicates would lose an older valid pending call when the newest is invalid. The compactor therefore keeps separate conservative guard buckets. Proposed bound: 20 character segments, 20 distinct unresolved guards per segment, at most 20*(20*F+1)+F buffered whole calls plus 20 issued calls. Ordinary repeated status/core-state or identical-guard updates compact; a genuinely new unresolved context beyond the bound rejects its entire incoming call. This is an additional engineering resource recommendation for Q1, rather than approval to weaken atomicity. The review suggested only a character-segment cap; this design adds the explicit guard cap needed to bound distinct uncertain validation histories. No founder approval is inferred for the number.

Guard equivalence is conservative and R-only; JS sees original calls. Supersession is safe only inside an identical validation context, or for independently valid assignments. The model deliberately checks a fully superseded earlier valid preset followed by an invalid different preset. Guard compilation, anchor-failure recovery, token issuance and Shiny lifecycle/transport are outside this limited model and need actual implementation tests.

Q1 is a new review-only gate before U1; I1 already depends on U1. Core format/validator/engine/harness/builder/fixtures retain their own prerequisites and do not wait for Q1. Actual baseline store/owner selection stays mandatory before T1, while R1a records the requirement so unrelated validator work is not blocked on that later choice. No package build starts in this design correction.

### Commands actually run

From the design repository root, both commands exited 0:

```sh
python3 -I docs/reviews/2026-10-14-design-contract-check.py
python3 -I -O docs/reviews/2026-10-14-design-contract-check.py
```

Each reports 16 selected Python queue/atomicity/precedence model cases, five duplicate-free JSON examples and a 36-node acyclic build plan. These are reference-model/document checks, not package/runtime passes. git diff --check exited 0.

Fresh temporary docs copies still detect the original five planted defects (reversed brow, cycle, duplicate id, unknown X9, reversed brow under -O), each exit1 with the same commands as the preceding round; source digests unchanged. Four additional temporary checker mutations demonstrate that the reference-model checks can fail:

| Planted model defect | Command in fresh temporary copy | Exit | Observed output |
|---|---|---:|---|
| drop buffered calls under full-window pressure | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: full window lost buffered state` |
| accept an invalid preset mixed call | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: invalid preset leaked coupled bubble` |
| merge different unresolved guards | `python3 -I docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: new invalid guard erased a valid older pending candidate` |
| ignore server character ownership | `python3 -I -O docs/reviews/2026-10-14-design-contract-check.py` | 1 | `FAIL: server character lost remount precedence` |

The 16 model cases cover 1000 stalled status updates, atomic preset/mood rejection with coupled fields, valid unrelated calls, complete guards after field overwrites, older valid candidates, repeated identical guards, character/guard capacity rejection and reuse, immutable originals, lifecycle ordering, both character precedence outcomes, mood fallback, explicit reset and no gesture replay.

No R, gates, browser, actual input binding, renderer, performance, CI or tarball tests ran. Process/static-UI issuance and real Shiny delivery remain unverified. U1/I1 remain blocked on independent Q1 approval of these revised contracts and the guard-bound recommendation; this log does not grant that approval. Four tracked design files changed: engine proposal, API decisions, existing checker and this appended log; all earlier log bytes are preserved. No public input/API export, package code, dependency or asset changed.
