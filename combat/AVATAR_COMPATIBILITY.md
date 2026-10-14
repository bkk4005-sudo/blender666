# Avatar compatibility — prototype 2.5

Current palm/stance pass: the donor's splayed upper/lower arm and free-hand rest axes are calibrated to the canonical R15 anatomical axes during export. Blender authors the weapon hand around the measured standard RightGripAttachment; equipment, preview clearance and runtime clearance use `WeaponVisualConfig.forCharacter(character)` to resolve each avatar's native palm frame. The final matrix `tests/avatar_geometry_palm_grip_2026_10_14.json` has zero intersections in 15,660 samples. All five profiles need zero shoulder correction during idle. The physical playback test measures the actual hilt/palm world frames with position error below 0.000009 stud across all twelve clips. Clothing and accessories are still excluded from geometric coverage.

Latest roll/arm iteration: anatomical arm planes replace singular shortest-arc twists. The conservative blade clearance margin is now 0.12 stud, with a bounded ±30-degree wrist fallback when shoulder motion alone cannot clear a thick body. The wrist and shoulder overlays are restored before Animator reevaluation. The final five-profile matrix in `tests/avatar_geometry_roll_polish_2026_10_14.json` has no sampled intersections; the older test results below remain historical.

## Implemented

The server equips one noncolliding, massless sword MeshPart through one Motor6D on RightHand after character appearance has loaded. Respawn removes the old character assembly naturally. The production script replaces the optional Studio test script; run only one equip script. Templates with extra unconnected parts are rejected. The hand-to-hilt frame comes from the avatar's RightGripAttachment, with the measured standard frame as a fallback if the attachment is absent. Visual mesh scale does not increase server damage or reach.

Studio sequences are baked once per character for its real Motor6D or AnimationConstraint frames and part dimensions. SourceAuthoredHipHeight records the exported height: 2.192423105239868, measured on the canonical Studio R15. AuthoredHipHeight itself has restricted API security, so game code reads this metadata and compensates root translations instead of accessing the protected property.

BladeClearance rotates the right shoulder while preserving joint offsets, limb lengths, wrist grip and weapon size. It prefers small, continuous corrections and reports unresolved intersections. A 0.12-stud conservative body-box margin covers interpolation. Each client renders the overlay for every equipped player it observes; Transform changes are not trusted for combat damage. AvatarGroundClearance adds visual root-joint clearance during action states. HumanoidRootPart is never teleported by these modules.

The Studio bake uses HipHeight plus half the root height as its standing reference. Its 0.07-stud clearance and smoothly faded extra roll margin are project safety values, not DS3 measurements. They are bounding-box checks, not triangle-level collision or foot IK.

## Verified coverage

`tests/avatar_geometry_2026_10_14.json`: 12 clips × 5 R15 body/scale profiles. Every keyed pose plus three interpolated poses per interval was checked (240 samples/second). No blade-centreline intersections with the checked body boxes remained. Profiles: standard default, tall narrow, short wide, current project body, tall narrow project body. Some project-body poses require corrections up to 60 degrees, which still require silhouette review.

`tests/visual_playback_adaptive_2026_10_14.json`: real Animator playback at normal speed on the current player avatar, physical joints and rigid sword. All twelve clips kept positive body and sword floor bounds in the final pass; measured grip position error was zero in that sample set. Raw end markers can repeat; CombatClient deduplicates effects. This does not replace two-player observer testing.

## Remaining coverage

NOT TESTED: arbitrary marketplace bodies, layered clothing, very large hair/accessories, dynamic avatar replacement during an action, slopes/stairs, published animations, two-player observer playback or low-end-device performance. R6/custom rigs require their own profile. Clothing and accessories are preserved; the solver checks body boxes and the blade centreline rather than their detailed visible surfaces. A universal no-clipping guarantee for all user geometry has not been established.

Published AnimationIds remain nil. Release playback cannot be enabled until the owner publishes the clips and verifies access for the experience.

API references: [AnimationConstraint and PreSimulation overlays](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint), [Humanoid HipHeight](https://create.roblox.com/docs/reference/engine/classes/Humanoid/HipHeight).
