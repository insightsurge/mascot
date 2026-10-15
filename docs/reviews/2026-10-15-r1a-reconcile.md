# R1a accounting reconciliation (2026-10-15)

Tracker: [#287](https://github.com/insightsurge/mascot/issues/287), under #278 → #3 → #11 → #1. Scope: documentation/reference accounting on design/engine-format. No package code or writes to feat/character-foundation. **Fixes delivered; format freeze is not claimed.**

Source: review/r1a-accounting, docs/reviews/2026-10-15-r1a-accounting.md and its adjacent probe. Its accounting inputs at 918893f match the pre-fix 1302ddc checkpoint. The original probe ran unchanged on a scratch copy before edits and reproduced the counts. Here the 8/10/12 binary-variant-part timings were 0.02/0.10/0.47 seconds; those are reference-tool observations on this machine, not renderer/phone measurements.

## Findings verified

| Id | Verdict | Evidence, correction and remaining scope |
|---|---|---|
| H1 | confirmed | Old budget.py body_options/effects calls item() without clip(); operations.json expansion.effects omits ownership. The original probe shows clipped Tessa still at micro 2 clips/272 numbers, despite three extra 36-number clip invocations (5/380). Kit effect items/reduced_items now forbid character-specific clips; new budget.py:99 rejects them. The regression and planted guard removal prove refusal. |
| H2 | partly right | Instance accounting was missing. Fixed: separate trigger instances, held effect plus possibly overlapping triggers, maximum over one playable action; summing that action's triggers is a safe bound. Added a dedicated 256-trigger input ceiling (policy 2); existing byte/node bounds already bounded input globally. The stated 60-frame gesture with 30-frame effects at frames 0,6,12,18,24,30 has at most 5 nonterminal triggered instances + 1 held = 6, not 7; terminal track opacity is zero. A sum-all-triggers bound of 7 is conservative. Reference triggers/track effects remain explicitly refused, not implemented. |
| H3 | partly right | Extracted contract 3.10 omitted precedence, but proposal 2.3 step 4 already explicitly makes the band win over switch and mood/track. Added that same rule locally to proposal/core 3.10; anchors follow the final variant. Existing counter behaviour remains: 7 full items, 2 small with the default band variant. Planted omission of band selection fails. |
| M1 | confirmed | Old glow() adds one paint pass per group even for fill+stroke. Now count compatible emitted paint operations separately; merge only equal operation/alpha and stroke width/cap/join. Each blurred operation gets an area contribution. A filled-and-stroked glyph has two shadow operations. Worst held styles give alpha_visor passes 78/76/24 and Study Bot 16/16/9; the review's star-eye/wide-mouth example is valid but not the largest combination. |
| M2 | confirmed | Normative reachability gaps were real; reference refusals protected existing certificates. Rules now resolve styles then tune, consider normal/reduced item paints and structural tracks, suppress alpha only when zero in every reachable state, and apply accessory LOD consistently. Generic R1c/JS support remains outstanding; retained refusals are not reported as implementation fixes. |
| M3 | partly right | Hop/breathing semantics needed definition, but attachment-glow undercount is not demonstrated because the reference refuses it. Defined lift-only hop (height*sin(pi*u), no squash), multiplicative breathing and attachment anchor/variant-anchor scale factors. Hand arithmetic gives 0.5*(1+0.012)=0.506. Attachment-glow implementation/reproduction remains outside the reference profile. |
| M4 | confirmed | Old body_options() takes the product of slots and part variants: reproduced 256/1024/4096 states. Replaced with local part maxima, maximum per slot, separable face styles and cached clip-target bounds. A 64-part/two-variant probe evaluates 128 body choices. 100 seeded independent-variant cases equal the old exhaustive counts; a coupled clip case intentionally bounds 21 exact numbers by 23. Certificates now say conservative integer bounds, not exact joint maxima. |
| L1 | confirmed | Old parts wording differs from the counter for empty pivots. Visible parts with visible ancestors count, including empty pivots; root/pseudo-groups do not. Transform-only clip owners/ancestors count once. Reference hidden clip-owner closure remains refused. Empty-pivot regression and planted removal behave correctly. |
| L2 | partly right | Private-canvas/captured-outgoing swaps were required already, but frame accounting was not explicit. Now outgoing is a cached bitmap; incoming draw-list plus at most two host drawImage composite calls is the separate swap workload. Two backing images do not imply fixed pixel memory. No swap renderer run. |
| L3 | confirmed | Faceless top-level kit-effect maps were silently omitted by the reference. It now rejects them; contract forbids faceless kit maps/triggers. Faceless characters may animate ordinary parts. |
| L4 | confirmed | Full has no CSS-width cap; backing blur grows as blur*width/300*DPR. This is an allocation/performance envelope gap, not a wrong logical counter. Documented that normalised counts/area cannot promise arbitrary-size pixel performance. Absolute backing-pixel limits remain a founder/E5c decision; no arbitrary width cap imposed. |

## Related findings in the repaired path

| Id | Verdict | Evidence / fix |
|---|---|---|
| N1 | confirmed | Glow colour is a solid role (contract 3.8), but old glow() counts the first source gradient again. Solid emission uses its own colour and no source gradient invocation. Alpha_visor gradients change 3/2/2 → 2/1/2. Normal repeated-gradient counts remain. |
| N2 | confirmed | Old body_options() skips zero-normal-paint shapes before checking emission, despite the manifest allowing emission-only items. Removing the lamp's normal paints gives old 3 emitters/36 items versus fixed 4/37. Emission-only geometry now contributes an item, operands and an emitted fill mask; zero-alpha emission still suppresses. |

## Q2: limits and controls

| Review item | Verdict | Reconciliation |
|---|---|---|
| Sketch headline/table | partly right | Table values reproduce. Robot passes micro: four character types fail there, not all five. Whole-silhouette flame also exceeds full area. Rough sketches are neither finished fixtures nor performance evidence. |
| Q2.1 clips | partly right | Classic eyes use both micro clips; more clipping pressures the cap. A shared two-eye clip needs proof for independent styles, gaze and draw ordering. Keep per-eye clips/cap 2; defer shared clipping or cap 4 to real fixtures/visual review. |
| Q2.2 items/numbers/face flags | partly right | Sketch pressure is real; negligible path-number cost at 24 px is unmeasured. No automatic 40-item/600-number increase or new glint/lid-edge/blush flags; founder decides after real fixtures/E5c. |
| Q2.3 small emitters | partly right | Five face glyph emitters exceed small 4; robot plus lamp/antenna has 7. Suggested cap 6 would still fail it. Keep the candidate cap pending artwork/control or measured policy choices. |
| Q2.4 band blur | partly right | Blur above 10 cannot remain enabled at small, but full 16 is usable: checked full blur 16 with existing small glow=false, giving small blur 0. Per-band blur is an optional new authoring control, not a counting correction. |
| Q2.5 area | partly right | Circle 1.021 versus unrotated box 0.581 reproduces. The circle is safe but loose; an unrotated box is not a motion proof. Retained the conservative bound; tighter rotation-aware proof and small/full ratios remain choices. |
| Q2.6 gradients | confirmed | Flame sketch uses 3 micro gradients against 2. Existing band variants can flatten a layer; keep candidate cap pending a real fixture. |
| Q2.7 parts | confirmed | Robot small 22/40 and fox micro 10/16 fit. No part-cap increase needed. |

## Q3: before freeze

| Item | Status after reconciliation |
|---|---|
| Q3.1 rules | Written corrections delivered; unsupported reference constructs still refuse. Full-format implementation not claimed. |
| Q3.2 shared method | Delivered separable bounds; R/JS must reproduce the identical integer policy. |
| Q3.3 band controls/shared clip | Founder choice remains; no unreviewed grammar expansion or drawing-cap raise. |
| Q3.4 budget fixtures | Chosen code budget, JSON root path $, explicit band/metric/component-proof fix. Root exists even for full; lod.full does not. Added 27 accounting boundary probes (nine metrics × three bands); complete semantically valid package rejection fixtures/first-diagnostic verification remain R1c work. |
| Q3.5 complete picked-character/robot fixtures | Still required; in-memory sketches do not substitute. No artwork generated. |
| Q3.6 compatibility | Manifest/accounting 2, policy 2, still format 1. After freeze, ceilings may rise but not fall for frozen admission semantics; changed counting needs a new format version or compatible old-admission path. Current changes are explicitly pre-freeze. |
| Q3.7 runtime guard | Contract chooses atomic rejection of the whole resource-sensitive update if its supported bound fails, unless tighter proof passes; no silent clamp/glow drop. Implementation/runtime evidence remain owed. |
| Q3.8 independent reproduction | Outstanding. Data copies below are necessary but insufficient; no edits to that branch or claims its current tests pass against new data. |

## Changes

- operations.json: manifest 2; instance, emitted paint-group, reachability, active-part, band, scale, swap and compatibility rules.
- budget.py: separable part/slot/face bounds and cached clip geometry; no global variant/slot/style product; effect-clip/faceless refusals; emitted-paint/gradient/emission-only fixes; root/band diagnostics; rejection before --write; 59 self-tests including 27 boundary probes.
- budgets.json: regenerated twelve rows/component proofs and scale stress under version 2. Tessa/Anchor Probe metrics unchanged. Alpha_visor passes 75/73/24 → 78/76/24, gradients 3/2/2 → 2/1/2, area 0.151180878460 → 0.183365926996. Study Bot passes 13/13/9 → 16/16/9, area 0.067040744860 → 0.099225793397. All rows fit.
- limits.json: policy 2, manifest link, 256 effect triggers per gesture, compatibility/diagnostic metadata and upper-bound evidence. Per-band drawing caps unchanged.
- work-counts.md: current method/results, supported scope, losses, remaining freeze tasks and package copies; earlier Tessa 33→29 correction preserved.
- contract.md/engine-format-proposal.md: synchronised normative blocks. check.py: paired versions, new input cap and method checks. No character/kit fixtures, package code, Q1 design or build prerequisites changed.

## Package copies: list only, not changed

Checked docs/character-parser.md on feat/character-foundation at 9b850ce9a090c6e0ee54e3772d305d8eedd863cc.

| Changed design source | Required package copy | Rule |
|---|---|---|
| docs/character-format/limits.json | inst/format/policy-v1.json | Same data without evidence; retain package's own status. Include new versions, trigger cap and metadata; format_version stays 1. |
| docs/character-format/budgets.json | tests/testthat/fixtures/format/work-expected.json | Identical copy, including maxima, component proofs and version/method fields. |

No character/kit/source fixture changed, so their listed copies need no refresh. No operations.json or contract.md package copy is listed. Data copying alone is insufficient: inst/format/character-v1.json currently has no input_limit on gesture effects and reuses ordinary clipped items for kit effects; wire in the new cap and clip prohibition. R/character-work.R already uses local variant bounds but needs emitted paint/gradient/common-policy alignment; test-character-work.R compares every reference metric. Rerun the character tests after updates. That branch was read only.

## Evidence and limits

Original review probe: exit 0 on unchanged scratch checkpoint. Differential scratch checks: 100 seeded independent-variant cases match old exhaustive counts; coupled clip exact 21 versus bound 23; 64 binary-variant parts evaluate 128 local choices; H2 arithmetic gives 6 simultaneous visible instances including the held one; full blur 16 works with small glow off; emission-only lamp regression reproduced.

Seven planted defects each fail exit 1: removed effect-clip guard, one emission pass, ignored band variant, dropped empty pivot, stale certificate, wrong manifest version, over-budget --write. The last preserves the old certificate. These are reference-tool checks, not R/JS/renderer evidence. Final checker/gate/publication results are appended below and in the shared handoff.

Tests/full/lint modes, new R1c/JS implementation, renderer/site/browser, frame-fit, phone/performance, CI and release/tarball checks are outside this documentation/accounting task. A package-baseline fast pass is not implementation evidence for the revised accounting.

## Founder follow-up

Recommendation: keep drawing caps unchanged until full picked-character/both-robot fixtures and E5c reveal actual needs. A reader adding clipped hair at 24 px hits the classic face's two-clip cap; judge that real artwork before choosing simplification, extra band controls or higher caps.

Decisions still ahead: extra band face/effect/shadow/blur controls and shared-eye-clip semantics; drawing caps after complete fixtures; absolute CSS-width/DPR/backing-pixel envelope after E5c. Independent full R/JS reproduction and complete rejection fixtures are required checks. Freeze only after those prerequisites; no approval request blocks these delivered fixes.

## Final observed results

All six commands exited 0: check.py, budget.py --check and budget.py --self-test, normally and under python3 -I -O. Core checks report four synchronised blocks, eight reference/fourteen deliberately invalid files; accounting reports twelve recomputed rows within caps; self-tests report 59 cases. Seven planted faults fail non-zero as intended. Positive hand checks remain: open ellipse eye 9 items/10 passes/49 numbers including its inset clip; Tessa micro 29/41/272; repeated refs and exclusive slots are checked separately.

Fast gate ran on a temporary copy to protect both worktrees; exit 0. Normalised summary (timings/local library path omitted):

```text
PASS tools
PASS air
PASS biome: 8 files
PASS docs
PASS lintr
PASS value: 20 exported functions
PASS spelling
PASS check_fast: 0 errors, 0 warnings, 0 notes
All steps passed (0 skipped).
```

The package-code diff is empty. Foundation local/remote refs remain 9b850ce9a090c6e0ee54e3772d305d8eedd863cc after refresh; no writes were made there. Publication hash and shared-handoff check are recorded in the local review card after commit/push.
