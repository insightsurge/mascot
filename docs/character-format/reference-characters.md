# Picked character references

Issues [#289](https://github.com/insightsurge/mascot/issues/289) and [#291](https://github.com/insightsurge/mascot/issues/291), parent [#278](https://github.com/insightsurge/mascot/issues/278). Six additional resolved reference candidates exercise the existing v1 grammar. They do not install package built-ins or approve the format freeze. Existing Tessa and alpha_visor proposal examples remain unchanged.

## Source and status

Structural acceptance is the package’s R `character_format_check()` for every reference file; the Python tools perform selected checks and counting only. Neer and Knurl are checked with `builtin = TRUE`; the other four use `FALSE`.

The picked improved water drawing and round-5 roster are the translation sources. The founder’s recorded outline, palette and roster choices take precedence. Each fixture records relevant fidelity limits in `note`; local side-by-side previews retain the original drawings for review. All six use slim dark outlines. Cinder occupies the fire slot formerly planned for Ojas.

| Character | Reference status | Fidelity / remaining visual work |
|---|---|---|
| Neer | R checker and three budgets pass; visual approval pending | Exact crest controls at all held moods, source curl/shell/face/arms and palette. No background wave. Continuous crest flex, screen caustics and particle droplets omitted. Micro omits the inner band to retain two eye clips. |
| Sela | R checker and three budgets pass; visual approval pending | Picked magenta hex, purple bob/fringe/star clasp and time blocks. Honeycomb and strands simplified/omitted; overlap is a static mood variant. Hair/body lag is not yet authored as coordinated tracks. |
| Brim | R checker and three budgets pass; visual approval pending | Squat saffron hex, teal cap/waistcoat, nose, two-piece moustache and card. Smile shapes use discrete variants; native dashed stroke and continuous moustache deformation unavailable. Cap/arm coordination remains authoring work. |
| Iso | R checker and three budgets pass; visual approval pending | Picked tall hex/quiff, untinted wire glasses, jacket, chart and divider. Founder’s round-2 slate/copper palette applied; the left source deliberately retains round-5 colours. Grid/curve/tool details are simplified static data. |
| Knurl | R checker and three budgets pass; visual approval pending | Wheel, trapezoid chassis, tilted visor, socket stub, upright spanner/clamp and mood lamp retained. Removed an unpicked star-eye style; restored source eye arcs, glints and visible spanner contours. Screen blend, pulse, spring and particles omitted. |
| Cinder | R checker and three budgets pass; visual approval pending | Restored source flame and mask, exact flame/arm geometry sampled for each held mood at t=1.1, blue thinking core, static worried smoke/sweat. No rigid-stretch substitute for the held flame shapes. Continuous flame rebuilding, source glow and spark fountain omitted. |

## RC-01 authoring corrections

All six files pass the package R checker in file mode. The checker, grammar and limits are unchanged. The changes work with either pending decision on gradient strokes and glow-alpha defaults: strokes remain flat colour roles and glow alpha is explicit.

- Neer’s full-band bounds were x −27.06168…324.5133, y 58.02964…314.7551. Geometry-isolation probes identified the left arm as the left/bottom driver and the right arm as the right driver. Uniform figure scale 0.60 (from 0.72) and origin [−120, −218] retain the original geometry and every held arm angle with room for the complete motion envelope. A contrast pair now declares dark pupils on opaque eye whites for built-in checking.
- Sela and Iso drop outlines from open polylines, retaining detail strokes. Sela removes a stale small-band `body.bevel` reference and shifts left by 5 units to fit card glow plus root motion. Iso names the existing arm highlights for its size rules and uses uniform scale 0.64 with origin [−119, −225.28] to fit chart glow and divider motion.
- Brim’s embedded sweat effect includes `op: "sweat_drop"` and origin [0, 0], keeping its source-shaped items and progress behaviour. A 3-unit right shift fits the left-arm envelope.
- Knurl declares glow alpha 1, removes open-polyline outlines and the stale `wheel.tyre_ticks` hide reference, and includes the declared lamp emitter in its micro variant (its item is full/small only; micro glow remains off). Uniform scale 0.56 with origin [−120, −216.8] fits the full tool-pose and gesture envelope without changing their geometry or angles.
- Cinder adds a closed eye style matching its happy arcs. Iso and Cinder normalise tongue ellipse coordinates to their mouth boxes, removing oversized ellipses below their faces. Cinder lowers its worried smoke by 42 source units, shifts the figure down 5 design units, and makes flare a lift-only gesture, preserving the held flame shapes rather than stretching about the source origin.

The affected static previews were regenerated and inspected across all five moods. The added padding changes apparent size for Neer, Iso and Knurl; their proportions, geometry, colours and props are retained. Founder visual approval remains pending. The Python budget table below is recomputed separately and is not an independent reproduction of R accounting.

## Format-freeze gaps

1. **Continuous shape deformation has no v1 numeric geometry binding.** Neer’s crest controls and Cinder’s flame width/height/lean/wobble are source formulas. Exact held-mood samples are legal variants; neither shape interpolation nor a live formula solver is implemented. Brim’s smile-driven moustache controls have the same distinction. Root or part rotation is not labelled a replacement for crest flex or flame deformation.
2. **Compositing modes are absent.** Water caustics, CRT glare/emission and flame soft light use `screen` or additive drawing. Ordinary alpha paint and budgeted glow are supported, but they do not reproduce those compositing operations.
3. **Particle emitters and live procedural systems are absent.** Droplets, fountains, drifting sparks/smoke, repeated rings, and spring formulas cannot be submitted as executable recipes. A finite still, a bounded explicit track, or offline-generated geometry is possible; none implies the source continuous system exists. Cinder’s worried smoke is explicitly one held still.
4. **Gradient stroke grammar is inconsistent.** Contract 3.5 types `stroke` as a role; resource prose and the accounting counter mention gradient stroke invocations. Brim/Iso delegate files used a paint object there, which the selected checker did not reject. Integration replaced those fields with a legal flat source rim role. Freeze must either keep role-only strokes or explicitly specify gradient strokes; this task changes neither grammar nor limits.
5. **Exact source blur can exceed resource limits.** Cinder uses source blur 28 at the 400-unit scale: `28 * 0.72 = 20.16` design units, above full 16 and small 10. A separate source-fill probe yields conservative inflated-area bound 1.988681533314, above 1.0 / 0.5. That is the reference tool’s sufficient upper bound, not measured raster area or proof that no tighter area bound exists. Cinder’s whole-body glow is omitted, rather than clamped. Micro glow remains zero.
6. **The face grammar fixes some details.** Ellipse-eye irises take a colour role, not a radial paint; the pupil is fixed at 0.65 of iris radius (source uses 0.52). Open-mouth items have no nested clip for source tongue/teeth clipping. The fixtures retain near-looking supported faces and state those losses; they are not pixel-equivalent faces.

Not intrinsic grammar gaps: coordinated cap/hand tracks, hair lag encoded as finite tracks, fixed hatch segments, precomputed grids/strands/grain, static glints, and static overlap shapes. Some are omitted or simplified here. Dense source textures can also meet resource limits before geometry support runs out. These authoring omissions need visual review; they must not be counted as evidence that the format cannot express an ordinary path. The reference counter’s refusal of `face.styles`/`tune`, `mood.items`/`reduced`, extra track channels and some glow proofs is a tooling limitation, not absence of those contract fields.

## Expanded budget rows

| Character | Band | Parts | Items | Passes | Numbers | Clips | Gradients | Emitters | Blur | Area bound |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| neer | full | 9 | 45 | 62 | 631 | 6 | 3 | 0 | 0 | 0.0 |
| neer | small | 8 | 41 | 58 | 546 | 5 | 3 | 0 | 0 | 0.0 |
| neer | micro | 3 | 17 | 22 | 157 | 2 | 1 | 0 | 0 | 0.0 |
| sela | full | 12 | 49 | 74 | 510 | 4 | 6 | 1 | 8 | 0.239110298957 |
| sela | small | 12 | 49 | 74 | 510 | 4 | 6 | 1 | 8 | 0.239110298957 |
| sela | micro | 4 | 19 | 26 | 201 | 2 | 0 | 0 | 0 | 0.0 |
| brim | full | 11 | 51 | 76 | 717 | 8 | 10 | 1 | 8 | 0.235585462672 |
| brim | small | 11 | 47 | 72 | 507 | 4 | 6 | 1 | 8 | 0.235585462672 |
| brim | micro | 5 | 21 | 28 | 180 | 2 | 0 | 0 | 0 | 0.0 |
| iso | full | 12 | 62 | 83 | 888 | 10 | 5 | 1 | 8 | 0.381528179096 |
| iso | small | 12 | 54 | 75 | 668 | 6 | 5 | 1 | 8 | 0.381528179096 |
| iso | micro | 4 | 21 | 28 | 206 | 2 | 1 | 0 | 0 | 0.0 |
| knurl | full | 10 | 53 | 89 | 582 | 8 | 8 | 6 | 8 | 0.205761427877 |
| knurl | small | 10 | 44 | 78 | 444 | 6 | 6 | 4 | 8 | 0.171372798894 |
| knurl | micro | 4 | 10 | 17 | 139 | 1 | 0 | 0 | 0 | 0.0 |
| cinder | full | 13 | 46 | 61 | 525 | 6 | 7 | 0 | 0 | 0.0 |
| cinder | small | 12 | 40 | 52 | 411 | 3 | 7 | 0 | 0 | 0.0 |
| cinder | micro | 5 | 18 | 22 | 165 | 2 | 0 | 0 | 0 | 0.0 |

All eighteen new rows fit the unchanged limits. These are separable componentwise upper bounds, with conservative authored glow-area certificates; witnesses need not be one jointly reachable frame. The twelve earlier rows are data-identical to the previous certificate. The manifest now drives the resolved inventory (ten characters, thirty rows), with confined certificate paths and duplicate-id checks.

## Reproduce

```sh
python3 -I docs/character-format/check.py
python3 -I docs/character-format/budget.py
python3 -I docs/character-format/budget.py --self-test
python3 -I docs/character-format/preview.py docs/character-format/fixtures/characters/neer.json /tmp/neer.svg worried small
```

`preview.py` is a development-only static SVG illustrator. It renders the six candidates’ shape/paint/clip/part/face operations, upright transforms and static effect selections. It is not the package renderer, an animation scheduler or a validator. Glow is illustrative SVG blur, not canonical Canvas raster evidence. No contrast, conservative frame-fit, runtime, save/read or performance acceptance follows from these previews. R structural acceptance is recorded above; canonical runtime rendering and founder visual approval remain required.
