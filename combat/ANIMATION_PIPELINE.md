# Animation pipeline

## Source and mapping

`assets/blender/animations/StraightSword_R15.blend` stores the editable `CombatIdle`, `SwordR1_1`, `SwordR1_2`, `SwordR2` and four directional roll Actions. Its R15-compatible rig was adapted from the repository's existing AshenOath donor rig without changing the game R15 hierarchy. The joint schema is retained in `assets/blender/rig/R15_joint_schema.json`. A paired prop Action drives the training sword during Blender review; game weapon attachment has not been verified.

`tools/author_blender.py` opens the donor, creates key poses and interpolated curves in Blender, then bakes R15 joint transforms at 30 FPS into `assets/animations/r15/baked/*.json`. `tools/package_rbxmx.py` converts the samples into Roblox `KeyframeSequence`/`Keyframe`/`Pose`/`KeyframeMarker` XML. The resulting individual files are in `assets/animations/r15/combat_idle`, `straight_sword` and `dodge`. `CombatFoundation_Import.rbxmx` bundles those clips and the runtime scripts.

The generated curves and rendered front/side frames were inspected as a first pass. The first roll render showed blade-floor penetration; the grip and sword axis were revised, then rerendered. That is insufficient to certify animation polish or foot contact in live R15 play. The Blender file remains the editable source; the generator is reproducible, but later hand edits in Blender must be exported with a compatible bake process to avoid overwriting them.

## Studio validation already performed

The import script constructed eight real KeyframeSequences with marker instances in an existing Studio place. In Play Solo, a standard R15 `Animator` loaded and played the sword and directional roll tracks through temporary Studio registration. This confirms basic rig mapping and playback only. The standalone `.rbxmx` files have not been opened in a second project. No Roblox assets have been published, so live-client playback outside Studio is unavailable.

## Required next animation pass

1. Find unobstructed movement references and document precise visible key poses. The supplied longsword clip is partly obscured; see [ANIMATION_REFERENCE_BREAKDOWN.md](ANIMATION_REFERENCE_BREAKDOWN.md).
2. In Blender, refine foot planting, hip-to-shoulder delay, grip, sword clearance, follow-through and R1_1 to R1_2 continuity. Review front, side, back and gameplay camera views at full and reduced speed.
3. Polish the four roll variants, then author combat locomotion, block, parry and reactions as real Actions before enabling their visuals in production.
4. Export/bake, reimport into a clean R15 place, check markers and priority, then publish approved clips under the owning Roblox account/group. Put only verified IDs in `AnimationRegistry`.

The current `CombatConfig` and Blender clip lengths/markers are aligned to authored frames at 30 FPS. These numbers are project prototypes, not measured Dark Souls III parameters. Roblox root movement is driven separately by the server action controller.
