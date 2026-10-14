# R1a reference drawing counts

Status: operation accounting and reference certificates, 2026-10-14; [#278](https://github.com/insightsurge/mascot/issues/278). Candidate implementation contract, pending independent accounting review and R1c/JS reproduction. These are logical work counters, not timings, screenshot results or CRAN evidence.

## What this adds

[operations.json](operations.json) fixes numeric operand counts and expansion rules. [budget.py](budget.py) calculates the supported reference profile using only the Python standard library; [budgets.json](budgets.json) records twelve rows with a separate witness for each metric. [limits.json](limits.json) is unchanged in its numeric limits. Kits/families have no independent frame budget; Study Bot’s source points to its explicit expected resolved snapshot rather than pretending defaults are already resolved.

Eight counters are exact componentwise maxima over the supported structural states. Glow rectangle area is explicitly a conservative upper bound over authored transforms. Different columns can have different witnesses; the table is not one invented all-maximum frame. Counters must not deduplicate repeated refs, double-count mutually exclusive accessory/variant choices, or confuse a clip-only target with another painted item. A lid edge is its own item/path; sclera fill and outline reuse one geometry with two passes. Geometry operands include resolved constants; transformations/style parameters are separate from the path-number counter.

## Results

| Character | Band | Parts | Items | Passes | Numbers | Clips | Gradients | Emitters | Blur | Glow area upper bound |
|---|---|---|---|---|---|---|---|---|---|---|
| tessa | full | 6 | 42 | 57 | 357 | 2 | 0 | 0 | 0 | 0.0 |
| tessa | small | 6 | 42 | 57 | 357 | 2 | 0 | 0 | 0 | 0.0 |
| tessa | micro | 5 | 29 | 41 | 272 | 2 | 0 | 0 | 0 | 0.0 |
| alpha_visor | full | 17 | 37 | 75 | 329 | 2 | 3 | 4 | 10 | 0.15118087846 |
| alpha_visor | small | 17 | 35 | 73 | 288 | 1 | 2 | 4 | 10 | 0.15118087846 |
| alpha_visor | micro | 5 | 16 | 24 | 164 | 1 | 2 | 0 | 0 | 0.0 |
| study_bot | full | 2 | 8 | 13 | 71 | 1 | 0 | 3 | 3 | 0.06704074486 |
| study_bot | small | 2 | 8 | 13 | 71 | 1 | 0 | 3 | 3 | 0.06704074486 |
| study_bot | micro | 1 | 7 | 9 | 66 | 1 | 0 | 0 | 0 | 0.0 |
| anchor_probe | full | 2 | 2 | 3 | 9 | 0 | 0 | 0 | 0 | 0.0 |
| anchor_probe | small | 2 | 2 | 3 | 9 | 0 | 0 | 0 | 0 | 0.0 |
| anchor_probe | micro | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0 |

The current limits allow at most 160/90/30 items, 320/180/60 paint passes, 1500/900/300 path numbers, 12/6/2 clips, 16/8/2 gradient uses and 8/4/0 emitters at full/small/micro. Glow blur limits are 16/10/0; rectangle-area ratios are 1/0.5/0. The table is within these limits under this reference accounting policy. This does not establish complete character validity.

Anchor Probe intentionally hides its owner and attached badge at micro: zero painted items is the expected visibility case, not a useful finished micro artwork. Its status text remains part of the separate host acceptance. It is not a shipped character.

## Failure found and corrected

Before this calculation, Tessa’s micro policy hid wear_bow_ornament only. Selecting the alternative clip kept four ornament items. The maximal micro combination comprised 9 body/limb items + 4 clip items + 12 ellipse-eye items + 2 blush items + 2 mouth items + 3 mapped effect items + 1 ground shadow = 33, above 30. The old state also used 46 passes and 292 path numbers. This was a real failure of the proposed fixture under the new explicit accounting rules, not a timing measurement.

The recipe now also hides wear_clip_ornament at micro, matching the existing bow rule. Its maximal micro counts are 29 items, 41 passes and 272 path numbers. Full/small geometry, the kit and numeric limits are unchanged. Bow and clip share one slot: their full-band alternatives are never added together. Independent near-look/micro visual review remains necessary; no picture was rendered.

## Glow and runtime transforms

For each emitting item/glyph, a control-point/primitive box (including round/bevel strokes) gives an enclosing-circle diameter. Multiply it by the product of ancestor maximum scale norms and applicable face scale. The circle remains a bound under rotation, reflection and non-uniform scaling. Add six blur radii to that side, square, sum and divide by 90000. The output is rounded outward; clip trimming is not used to make it look cheaper. This is intentionally conservative. Native blur units remain the reviewed blur*CSS_width/300*DPR rule; normalising area cancels CSS width/DPR.

Scale bounds cover the current authored resting scales, poses, mood channels, numeric gesture key extrema and idle breathing. The supported easings have no overshoot; only one gesture/change runs at a time. The reference counter rejects constructs whose required bound it does not implement, including glowing ellipse eyes/lashes, attachment glow, miter-emitter bounds and extra gesture-triggered/track effects. R1c must handle the full format before accepting those cases. Conservative frame-fit/contrast checks remain separate and are not computed by these certificates.

An arbitrary live external root/part/face scale is not covered by this authored certificate. Small-band scale16 stress certificates exceed 0.5 for alpha_visor and Study Bot; the same upper-bound policy must refuse acceptance or establish a tighter bound. This does not prove actual raster overrun, and it is not an executed runtime rejection. The future runtime boundary must check resource-sensitive transforms atomically before applying them; excluding external transforms from the authored-fit promise does not exempt them from resource limits. The exact guard implementation remains later work and does not change Q1/U1/I1 approval.

## Reachability and limits of this reference calculation

All declared left/right eye choices, brow/mouth styles, positive lid/blush, declared effects and legal accessory-slot choices are considered, along with part variants. Automatic blink’s closed style is among those choices; gaze changes positions within fixed clips but not these discrete counters. Iris is enabled only when its role is authored and permitted by the band. Hidden ancestors suppress attachments. Small and micro each resolve from full data, never from the previous band.

Numeric motion in the current four recipes changes transforms, not structural counts. Threshold variants in Tessa have equal counters; the counter checks that equality before treating their choices independently. New correlated threshold costs, discrete animation topology, replacement/tuned faces, cross-owner face clips, clip-only active-part closures and unsupported effect constructs fail rather than being silently assigned passing totals. Current canonical rows do not exercise every format operation. Hidden-target clip geometry and repeated refs have small direct accounting cases; a general graph implementation and runtime behaviour remain R1c/E1/E2 work.

The area bound may combine scale maxima not reached simultaneously; it is a conservative certificate, never described as the exact maximum raster rectangle. The integer maxima have legal held-control witnesses for these recipes; absent fallback anatomy is not expanded. Saved kit snapshots determine the styles, rather than today’s package lookup. No universal N×M compatibility or performance claim follows from these counts.

## Re-run

From the repository root:

```sh
python3 -I docs/character-format/budget.py --check
python3 -I docs/character-format/budget.py --self-test
python3 -I -O docs/character-format/budget.py --check
python3 -I docs/character-format/check.py
```

--check reads without writing and fails on stale certificates, unsupported counting constructs or any limit overrun. --write is an explicit documentation regeneration action: it still fails on over-budget rows; review the JSON/witness diff before accepting a change. --self-test includes the old Tessa clip failure and hand-calculated primitives/glyphs. None calls R, a browser or the package engine.

Before R1a acceptance, independently review operand definitions, expansion/ownership, held-control reachability, the clip simplification and the conservative area/runtime-guard boundary. R1c must independently reproduce the certificates and establish complete input/semantic validity. T1 still needs a named retained store/owner and locked visual profile. Actual renderer, appearance, performance, transport, gates, CI and tarball checks remain unrun. Other picked character fixtures and both robots are still required before format freeze.

R1c correction (2026-10-14): Tessa now declares `clip` in `requires`, since classic ellipse eyes expand to two shared inset clips. This is a declaration correction; all per-band metric totals remain unchanged.
