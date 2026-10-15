# R1a reference drawing counts

Status: accounting-review fixes, 2026-10-15; [#287](https://github.com/insightsurge/mascot/issues/287), under [#278](https://github.com/insightsurge/mascot/issues/278). Operation manifest 2 / policy 2 are candidate contracts; this is not format freeze, R/JS reproduction, rendering, timing or CRAN evidence.

## Method and compatibility

[operations.json](operations.json) defines the shared policy. [budget.py](budget.py) computes a **separable componentwise upper bound** using only the Python standard library; [budgets.json](budgets.json) records twelve rows and per-component proofs. It sums local part maxima, the maximum per exclusive accessory slot, the face bound, ground and concurrent effects; blur takes a maximum. Same-part clips use that part's selected variant; cross-component clip targets use their largest band-resolved geometry. Clip bounds are cached; face styles are maximised without a joint style product.

This replaces exact joint enumeration, not just its implementation. A local proof can use a different target variant from another component. The integers are conservative bounds, not guaranteed attainable joint-frame maxima. For example, a two-variant clip-target probe has exact joint path work 21 but a separable bound 23. Different metrics also have different component choices. This can reject a file whose actual joint frames would fit; do not quietly substitute a different, tighter integer algorithm in R or JS.

Counting changes increment operation_manifest_version; ceiling changes increment policy_version. Current version 2 replaces an unfrozen design. After freeze, format v1 keeps its frozen accounting/admission semantics: ceilings may rise, not fall; changed counts require a new format version or an explicit compatible old-admission path. Existing format_version remains 1. Per-band drawing caps are unchanged. Policy 2 adds a pre-freeze input bound of 256 effect triggers per gesture, matching the existing 256-track ceiling, plus diagnostic/compatibility metadata. The source policy still distinguishes candidate caps from measured performance.

## Results

| Character | Band | Parts | Items | Passes | Numbers | Clips | Gradients | Emitters | Blur | Glow area upper bound |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| tessa | full | 6 | 42 | 57 | 357 | 2 | 0 | 0 | 0 | 0.0 |
| tessa | small | 6 | 42 | 57 | 357 | 2 | 0 | 0 | 0 | 0.0 |
| tessa | micro | 5 | 29 | 41 | 272 | 2 | 0 | 0 | 0 | 0.0 |
| alpha_visor | full | 17 | 37 | 78 | 329 | 2 | 3 | 4 | 10 | 0.183365926996 |
| alpha_visor | small | 17 | 35 | 76 | 288 | 1 | 2 | 4 | 10 | 0.183365926996 |
| alpha_visor | micro | 5 | 16 | 24 | 164 | 1 | 2 | 0 | 0 | 0.0 |
| study_bot | full | 2 | 8 | 16 | 71 | 1 | 0 | 3 | 3 | 0.099225793397 |
| study_bot | small | 2 | 8 | 16 | 71 | 1 | 0 | 3 | 3 | 0.099225793397 |
| study_bot | micro | 1 | 7 | 9 | 66 | 1 | 0 | 0 | 0 | 0.0 |
| anchor_probe | full | 2 | 2 | 3 | 9 | 0 | 0 | 0 | 0 | 0.0 |
| anchor_probe | small | 2 | 2 | 3 | 9 | 0 | 0 | 0 | 0 | 0.0 |
| anchor_probe | micro | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0 |

The table fits the unchanged full/small/micro caps: items 160/90/30, passes 320/180/60, numbers 1500/900/300, clips 12/6/2, gradients 16/8/2, emitters 8/4/0, blur 16/10/0, and glow area 1/0.5/0. It does not establish full semantic validity or accept every construct in the format.

Compared with accounting version 1, alpha_visor passes are 78/76/24 rather than 75/73/24; Study Bot passes are 16/16/9 rather than 13/13/9. Solid emission no longer repeats a source gradient: alpha_visor gradients are 2/1/2 rather than 3/2/2. Its authored glow area bound is 0.183365926996 rather than 0.151180878460; Study Bot's is 0.099225793397 rather than 0.067040744860. Tessa and Anchor Probe metric rows are unchanged. Counter proofs and the method/version metadata changed throughout the certificate.

## Rules repaired

- Kit effect items and reduced_items forbid clip, since shared kit definitions cannot bind character-specific item ids. The reference refuses the former silently undercounted example.
- A trigger is a separate effect instance. Count all possibly overlapping instances plus any held mood effect, maximising over one playable gesture/change. A conservative sum of all triggers in that selected action is allowed; never deduplicate by name or anchor. Reference trigger/track-effect support is still explicitly refused.
- Explicit band variants win over rest, pose, mood, tracks and switches; anchors follow the final variant. This was already in proposal pipeline 2.3 and is now local to the extracted 3.10 contract too.
- Normal fills/strokes/outlines are separate passes. A named emitter/glyph adds one blur operation per compatible paint group; fill and stroke never merge. Subpaths merge only with matching operation/alpha and stroke width/cap/join. Each blurred operation has its own conservative rectangle contribution. Uniform solid emission replaces source paints and uses no source gradient invocation. Emission-only geometry contributes an item and its operands.
- Resolve face style replacement then tune; consider all reachable normal/reduced item paint, opacity, visibility and variant values. Zero at rest is not proof of zero everywhere. Accessory LOD follows ordinary band rules. Visible empty pivots count; transform-only clip owner/ancestor closures count once. Unsupported reference cases fail instead of counting as free.
- Idle breathing multiplies scale by a factor bounded by 1 ± breathe. Built-in hop is lift-only height*sin(pi*u); squash needs explicit bounded tracks. Attachment bounds include anchor and variant-anchor scales; attachment glow remains outside this reference profile.
- Faceless characters cannot map/trigger kit effects, but may animate ordinary parts. Outgoing swap content is a cached bitmap; incoming drawing plus at most two host drawImage composite passes is the separately stated swap workload.

## Tessa's earlier micro correction remains

Before accounting version 1, hiding only wear_bow_ornament left the alternative clip visible: 33 items, 46 passes, 292 numbers. Hiding wear_clip_ornament too gives 29 items, 41 passes, 272 numbers. The source fixture is unchanged in this reconciliation. Bow and clip remain one exclusive slot. Micro/near-look visual approval is still separate.

Anchor Probe intentionally hides its owner and attached badge at micro; zero is the expected visibility probe, not useful finished artwork. Status/host acceptance is separate. It is not a shipped character.

## Glow area and runtime

The reference uses the enclosing-circle/ancestor-scale bound, including stroke extent, with six blur radii added to the diameter. Sum its squared area per compatible blurred operation, divide by 90000 and round outward to 12 decimal places. Clipping does not trim the certificate. Numeric transform extrema and multiplicative breathing are included; independent extrema need not be simultaneous. This is not the exact raster rectangle or a frame-fit/contrast proof. A rotation-aware box may tighten it only with a proved reachable rotation interval; the unrotated box in the review is not enough by itself.

External root/part/face scaling needs the same live bound before acceptance. Small-band root-scale-16 bounds are 11.486171189927 for alpha_visor and 8.792938998825 for Study Bot, above 0.5. These do not prove actual raster overrun. Reject an entire resource-sensitive update atomically when its bound fails unless a tighter proved bound passes; never silently clamp or drop glow. No runtime guard was run here. This does not approve Q1/U1/I1.

Full has no CSS-width cap. Normalised area cancels width/DPR, while actual backing pixels and blur allocation grow with them; arbitrary large canvases are not covered by E5c's eventual reference profile. Two swap buffers are a count bound, not an absolute pixel-memory guarantee.

## Supported reference scope

Four resolved recipes and the documented hand probes are supported. The counter still refuses replacement/tuned faces, mood items/reduced overrides, structural opacity/visibility/variant tracks, default-invisible/zero-opacity reachability, accessory-level LOD, hidden clip-owner closures, cross-owner face clips, attachment glow, transformed-ref/miter glow bounds, glowing ellipse eyes/lashes, and gesture-triggered/track effects. Those refusals are not a claim that the full grammar forbids those otherwise supported constructs. Full R1c/JS must implement their rules before accepting them. Unequal-cost switch variants no longer require the old correlation refusal: local variant maxima cover them conservatively.

## Re-run and evidence

```sh
python3 -I docs/character-format/check.py
python3 -I docs/character-format/budget.py --check
python3 -I docs/character-format/budget.py --self-test
python3 -I -O docs/character-format/check.py
python3 -I -O docs/character-format/budget.py --check
python3 -I -O docs/character-format/budget.py --self-test
```

--check is read-only and fails on drift, unsupported constructs or an over-budget reference row. --write is deliberate regeneration and validates bounds **before writing**, so a rejected reference cannot replace the prior certificate. Budget diagnostics use code budget at JSON root $, with explicit band, metric and component choices; there is no authored lod.full field.

Observed self-test: 59 cases, including 27 counter/band overrun probes and review regressions. Seven scratch planted defects each fail non-zero; an over-budget --write preserves the old certificate. A differential scratch run found equal counts for 100 seeded independent-variant cases against the old exhaustive counter, and demonstrated the 21-versus-23 clip conservatism. A 64-part/two-variant reference probe evaluates 128 local body choices; this is not renderer/E5c evidence. Boundary probes are not complete semantic rejection fixtures for the future package validator.

## Before freeze / package follow-up

Full picked-character and both robot fixtures, independent R/JS reproduction, complete semantic per-counter/band rejection fixtures, and actual rendering/E5c remain. The review's rough sketches show pressure on micro and small glow; they do not justify automatic cap increases. A proposed small emitter cap of 6 would still reject its 7-emitter robot sketch. Full blur 16 is already usable with small glow disabled. Keep the current drawing caps until the founder reviews real fixtures/E5c; decide extra band glint/lid-edge/blush/effect/shadow controls, shared eye-clip semantics and the absolute backing-pixel envelope separately. No format freeze is claimed.

The source changes require these copies on feat/character-foundation, per docs/character-parser.md:

| Changed source | Package copy to update later | Rule |
|---|---|---|
| limits.json | inst/format/policy-v1.json | Same data except remove evidence and preserve the package's own status; keep format_version 1, update policy/accounting versions, trigger cap and metadata. |
| budgets.json | tests/testthat/fixtures/format/work-expected.json | Copy identically, including new bounds, proof structure and versions. |

No character/kit fixtures changed; their package copies need no refresh for this task. No operations.json or core-contract package copy is listed in that table. Copying data alone is insufficient: wire the trigger cap and effect-clip rule into schema/semantics (inst/format/character-v1.json currently uses ordinary item definitions for kit effects and has no gesture-effects input_limit), align R/character-work.R with emitted paint groups/solid gradients and the common bound policy, and rerun the character-work tests. That branch was read only and remains outside this task.
