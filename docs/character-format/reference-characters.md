# Picked character references

Issue [#289](https://github.com/insightsurge/mascot/issues/289), parent [#278](https://github.com/insightsurge/mascot/issues/278). Six additional resolved reference candidates exercise the existing v1 grammar. They do not install package built-ins or approve the format freeze. Existing Tessa and alpha_visor proposal examples remain unchanged.

## Source and status

The picked improved water drawing and round-5 roster are the translation sources. The founder’s recorded outline, palette and roster choices take precedence. Each fixture records relevant fidelity limits in `note`; local side-by-side previews retain the original drawings for review. All six use slim dark outlines. Cinder occupies the fire slot formerly planned for Ojas.

| Character | Reference status | Fidelity / remaining visual work |
|---|---|---|
| Neer | Selected checks and three budgets pass; visual approval pending | Exact crest controls at all held moods, source curl/shell/face/arms and palette. No background wave. Continuous crest flex, screen caustics and particle droplets omitted. Micro omits the inner band to retain two eye clips. |
| Sela | Selected checks and three budgets pass; visual approval pending | Picked magenta hex, purple bob/fringe/star clasp and time blocks. Honeycomb and strands simplified/omitted; overlap is a static mood variant. Hair/body lag is not yet authored as coordinated tracks. |
| Brim | Selected checks and three budgets pass; visual approval pending | Squat saffron hex, teal cap/waistcoat, nose, two-piece moustache and card. Smile shapes use discrete variants; native dashed stroke and continuous moustache deformation unavailable. Cap/arm coordination remains authoring work. |
| Iso | Selected checks and three budgets pass; visual approval pending | Picked tall hex/quiff, untinted wire glasses, jacket, chart and divider. Founder’s round-2 slate/copper palette applied; the left source deliberately retains round-5 colours. Grid/curve/tool details are simplified static data. |
| Knurl | Selected checks and three budgets pass; visual approval pending | Wheel, trapezoid chassis, tilted visor, socket stub, upright spanner/clamp and mood lamp retained. Removed an unpicked star-eye style; restored source eye arcs, glints and visible spanner contours. Screen blend, pulse, spring and particles omitted. |
| Cinder | Selected checks and three budgets pass; visual approval pending | Restored source flame and mask, exact flame/arm geometry sampled for each held mood at t=1.1, blue thinking core, static worried smoke/sweat. No rigid-stretch substitute for the held flame shapes. Continuous flame rebuilding, source glow and spark fountain omitted. |

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
| sela | full | 12 | 49 | 78 | 510 | 4 | 6 | 1 | 8 | 0.239110298957 |
| sela | small | 12 | 49 | 78 | 510 | 4 | 6 | 1 | 8 | 0.239110298957 |
| sela | micro | 4 | 19 | 26 | 201 | 2 | 0 | 0 | 0 | 0.0 |
| brim | full | 11 | 51 | 76 | 717 | 8 | 10 | 1 | 8 | 0.235585462672 |
| brim | small | 11 | 47 | 72 | 507 | 4 | 6 | 1 | 8 | 0.235585462672 |
| brim | micro | 5 | 21 | 28 | 180 | 2 | 0 | 0 | 0 | 0.0 |
| iso | full | 12 | 62 | 87 | 888 | 10 | 5 | 1 | 8 | 0.44436270795 |
| iso | small | 12 | 54 | 79 | 668 | 6 | 5 | 1 | 8 | 0.44436270795 |
| iso | micro | 4 | 21 | 28 | 206 | 2 | 1 | 0 | 0 | 0.0 |
| knurl | full | 10 | 53 | 95 | 582 | 8 | 8 | 6 | 8 | 0.254539768301 |
| knurl | small | 10 | 44 | 84 | 444 | 6 | 6 | 4 | 8 | 0.21206248478 |
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

`preview.py` is a development-only static SVG illustrator. It renders the six candidates’ shape/paint/clip/part/face operations, upright transforms and static effect selections. It is not the package renderer, an animation scheduler or a validator. Glow is illustrative SVG blur, not canonical Canvas raster evidence. No contrast, conservative frame-fit, runtime, save/read or performance acceptance follows from these previews. Full validator checks and visual approval remain required.
