# Tessa visual baselines (T1, #284)

The runner captures five moods at 160/96/24 CSS pixels, light/dark and DPR 1/2: 60 fixed frame-zero canvas
images. It calls the old engine directly at ground origin (150,270), with native colours, on white and
`#212529` backdrops. Old main has no native dark palette override. No text/fonts or remote assets are drawn.
These frames cover resting moods only; moving frames, every gesture/accessory, host queues and swaps remain
later acceptance work. Pictures alone do not prove timing or host behaviour.

## Current evidence

`provisional.json` pins the macOS source files, exact browser executable/build, chromote version, capture
settings, image hashes and archive checksums. These are **non-canonical** and cannot pass `--strict`.
The small PNG set in `reviewed/` comes from old main `ace06f5`. The full archives are cached locally under
`dev/visual-baselines/`, ignored by git and excluded from the source package. Canonical Ubuntu captures and
retained archive publication remain pending. The E1 bridge now routes root placement, feet/body, ground shadow, arms/hands and accessories through parts/geometry. Face and effect painters are reused at their computed part matrices until E3/E4; this is not the complete M1 migration. The live host never loads the adapter or enables its internal switch.

## Reproduce provisional captures

From the repository root, prefix every invocation with the existing development library and disable renv:

```sh
export RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
export R_LIBS=/path/to/the/existing/development/library
python3 tools/visual/visual-baselines.py capture --provisional --source ace06f5 --output dev/visual-baselines/old
python3 tools/visual/visual-baselines.py capture --provisional --source working-tree --adapter --output dev/visual-baselines/adapter
python3 -B tools/visual/visual-baselines.py compare --baseline dev/visual-baselines/old --candidate dev/visual-baselines/adapter --report dev/visual-baselines/comparison-report
python3 tools/visual/visual-baselines.py probe --provisional --source ace06f5 --baseline dev/visual-baselines/old
python3 tools/visual/visual-baselines.py archive --baseline dev/visual-baselines/old
python3 -B tools/visual/test-harness.py
```

Output directories must not exist; captures never replace baselines. A `working-tree:` source label means
uncommitted content; `source_files` pins its exact bytes independently of the parent commit. After a Chrome
update, use a new provisional capture directory and review both sides again. Different runtimes fail comparison.
The runner uses only the existing R library (chromote/jsonlite/checkmate/cli); it installs nothing.

## Canonical profile and manual job

`profile-template.json` is explicitly incomplete, **not a lock**. No canonical claim follows from its presence.
On an Ubuntu 24.04 x86_64 environment, prepare and review `profile-lock.json`, with status `locked` and:

- a pre-provisioned Ubuntu 24.04 image reference pinned by SHA256 digest, containing R, chromote and Python;
- the exact Chrome for Testing build, executable path and SHA256, and exact chromote version;
- existing R library path (`r_library`), font package versions and SHA256 for bundled font files;
- all template capture settings, flags, locale, timezone, sRGB, sizes, DPR, moods, frame, origin and backdrops.

No image, browser version or font checksum is invented here. Commit the reviewed lock before capture.
`CHROMOTE_CHROME` selects the pinned binary; `MASCOT_VISUAL_CONTAINER` must match the lock's container digest.
The runner verifies OS/architecture, fonts, binary, settings and committed lock before drawing. Browser build
and chromote are checked before the first image. The container launcher is responsible for its declared image
identity; the environment variable is an attestation, not a way to infer the running image digest.

The founder requested `engine-visual.yml` on **ubuntu-24.04**, manually triggered only, while private (#113).
It requires that committed profile and pre-provisioned image, installs nothing, captures old main twice,
compares decoded RGBA, rejects a missing-eye defect and uploads a content-addressed archive with checksums.
**Do not trigger it until the founder permits spending Actions minutes.** The workflow must be available on
GitHub's default branch before it can be dispatched; this feature branch does not publish it there.
Before public release (#115), add reviewed engine/character PR triggers and the required visual policy.

Strict comparison additionally requires the pinned archive itself (`--archive-file`, `--archive-sha256`),
matching decoded baseline files and the same committed profile for both captures. Missing/different profile,
missing images/archive, corrupt PNGs, archive mismatch and any decoded RGBA difference fail non-zero.
PNG bytes verify archive integrity; **pixel equality is checked on decoded RGBA**, so compression changes alone
do not cause a drawing mismatch. The independent decoder probes cover all five PNG row filters, RGB alpha
expansion, corruption, absent lock/archive and changed archive contents.

## Retained store and approval

Founder-approved retained store: **insightsurge/mascot, branch `design-assets`**, owner **Harsh Verma**.
Intended path: `visual-baselines/t1/<sha256>.tar.gz`, retrieved at a pinned full assets commit, with SHA256
recorded in the reviewed manifest. Repository read access controls retrieval. Keep archives append-only;
never replace an accepted archive, rewrite history or delete a referenced object. Keep the assets branch and
a local clone/cache as the retained copies; job artifacts expire after 30 days and are transport only.
The named owner handles retention and backup. This policy still needs verification when archives are promoted.

Today only `feat/character-foundation` may be pushed. Provisional archives remain cached; no design-assets
push or canonical promotion is implied. After the manual run, Harsh reviews the images/diffs, retains the
archive on design-assets, verifies retrieval/checksum and records the assets commit before T1 acceptance.
New baselines and near-look changes always need review; no blanket tolerance or automatic regeneration.

## E1 picture reports

`compare --report <new-directory>` writes results.json and index.html, with one old/adapter/magenta-mask picture per frame and an enlarged crop for every differing case. Counts, maximum channel difference and zero-based changed-pixel bounds are measured on exact decoded RGBA. All manifest/image/environment/completeness checks run before report output. Existing report directories are never overwritten; corrupt or incompatible inputs produce no report.

A report does not turn a mismatch into a pass: any differing frame still exits1, with no tolerance or baseline promotion. All pictures are comparison evidence, separate from the original immutable baseline PNGs. See e1-provisional.json for the E1 checkpoint, archive checksums and remaining visual differences. Canonical Ubuntu T1 and independent near-look approval remain pending.
