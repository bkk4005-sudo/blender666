# R15 straight sword combat foundation

Status: **prototype for an R15 playtest, not release ready**. The existing Coliseum place and its map assets were not changed on disk. This folder is portable; it contains the Luau sources, editable Blender Actions, baked joint data, Roblox KeyframeSequences and an import package.

## Implemented in this pass

Latest: rolls have exclusive Action4 priority and immediately block attack/parry/extra-roll prediction. A late acknowledgement does not cut a predicted roll; valid server rejection can cancel it. Combo input queues server-side without prematurely swapping the first swing. Blender arm bend planes and roll landing/rise were reworked; latest evidence is in TEST_REPORT.md.

- Twelve original editable Blender clips: idle, two R1 swings, R2, four rolls, block, parry, stagger and guard break. This pass improves weapon clearance, heavy wind-up and roll wrist orientation.
- Server-authoritative R1, buffered second R1, R2, stamina, four directional roll motions with timed invulnerability, block/parry state handling and a sampled sword arc hit query. The client cannot name a hit target or set damage. Attack advances and rolls use horizontal-plane velocity, leaving vertical gravity active.
- Studio previews use real KeyframeSequences and marker signals. `WeaponVisual.server.luau` equips the existing sword through one rigid hand joint after appearance loads. Its unscaled template belongs in `ServerStorage/CombatWeaponTemplates/StraightSword`. Published AnimationIds remain absent.
- Canonical R15 export corrects the donor's imported joint axes. Studio preview bakes the poses for the actual avatar's joint frames and body dimensions. The sword grip is generated from Blender, and all eight clips were checked at normal speed on the current player avatar.
- Avatar preview bakes account for joint frames, body dimensions, HipHeight and Animator translation scaling. A client visual overlay supports Motor6D and AnimationConstraint on each observed equipped player. It adjusts shoulder and action ground clearance without changing the root's physical trajectory.
- Keyboard/mouse bindings can be edited in the in-game «Управление» panel. Validated preferences use `CombatInputBindings_v1`; unpublished Studio sessions fall back to session settings with an explicit UI message.
- Target-facing lock-on camera and movement prototype.

## Current limits

The rolls and defensive clips are original reconstructions, not extracted DS3 data. The combat arc remains an approximate server query rather than a verified sweep of the adapted blade. Arbitrary layered clothing, hair, accessories and every marketplace body are not guaranteed clear by a body-box test. Some tested proportions require substantial shoulder correction; their silhouettes still need review. Two-player latency, published animations and persistent settings round trips remain untested. Default locomotion still needs dedicated combat clips. See TEST_REPORT.md and AVATAR_COMPATIBILITY.md.

## Build

From the repository root, run Blender 5.2 with `-b --python combat/tools/author_blender.py`, then run `python combat/tools/package_rbxmx.py`. The Blender authoring script reads the existing R15 rig as a donor and writes only under `combat/`. Do not edit the old map to build assets. In Studio, run `combat/tools/import_studio.luau` in Edit mode with a localhost HTTP server rooted at `combat/`, or inspect `CombatFoundation_Import.rbxmx` as a portable package. The XML package has not yet been independently reimported; use the verified import script for testing.

Defaults: Mouse1 R1, Mouse2 R2, Space roll, F hold block, E parry, Shift hold sprint, Q lock-on. Use «Управление» to rebind or reset them. Duplicate assignments and WASD conflicts are rejected. Menus, chat focus and window focus loss release held actions. WASD chooses a camera-relative roll direction, checked by the server.
