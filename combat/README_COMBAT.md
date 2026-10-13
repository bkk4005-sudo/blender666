# R15 straight sword combat foundation

Status: **prototype for an R15 playtest, not release ready**. The existing Coliseum place and its map assets were not changed on disk. This folder is portable; it contains the Luau sources, editable Blender Actions, baked joint data, Roblox KeyframeSequences and an import package.

## Implemented in this pass

- Eight original R15 clips: `CombatIdle`, `SwordR1_1`, `SwordR1_2`, `SwordR2`, and four directional rolls. They were authored in Blender 5.2 as editable Actions and converted to KeyframeSequences. This iteration revises the low guard, attack steps and roll ground contact; final avatar visual QA remains open.
- Server-authoritative R1, buffered second R1, R2, stamina, four directional roll motions with timed invulnerability, block/parry state handling and a sampled sword arc hit query. The client cannot name a hit target or set damage. Attack advances and rolls use horizontal-plane velocity, leaving vertical gravity active.
- Local animation preview in Studio through `KeyframeSequenceProvider`, with marker signals for visual effects. The project's existing sword mesh can be attached to a player R15 hand using the test script in `tools/CombatTestSword.server.luau`. Published AnimationIds are intentionally absent.
- Canonical R15 export corrects the donor's imported joint axes. Studio preview bakes the poses for the actual avatar's joint frames and body dimensions. The sword grip is generated from Blender, and all eight clips were checked at normal speed on the current player avatar.
- Target-facing lock-on camera and movement prototype. Keyboard and mouse only.

## Current limits

The directional rolls are an original reconstruction because the inspected footage did not expose clean medium-roll source frames. Block, parry and stagger animations have **not** been authored. The sword attachment is for visual testing; the combat arc is an approximate server query, not a verified sweep of the visible blade. The live player avatar does not match the Blender donor silhouette in every pose. No two-player network-delay test or published-animation test has been run. The existing R15's default locomotion still needs a dedicated combat locomotion set. See [TEST_REPORT.md](TEST_REPORT.md) and [ANIMATION_ASSET_MANIFEST.md](ANIMATION_ASSET_MANIFEST.md).

## Build

From the repository root, run Blender 5.2 with `-b --python combat/tools/author_blender.py`, then run `python combat/tools/package_rbxmx.py`. The Blender authoring script reads the existing R15 rig as a donor and writes only under `combat/`. Do not edit the old map to build assets. In Studio, run `combat/tools/import_studio.luau` in Edit mode with a localhost HTTP server rooted at `combat/`, or inspect `CombatFoundation_Import.rbxmx` as a portable package. The XML package has not yet been independently reimported; use the verified import script for testing.

Prototype controls: Mouse1 R1, Mouse2 R2, Space roll, F block, E parry, Shift sprint, Q lock-on. WASD selects a camera-relative roll direction; the server checks the sent world vector against the requested roll animation. These bindings may conflict with an existing project's controls and must be integrated explicitly.
