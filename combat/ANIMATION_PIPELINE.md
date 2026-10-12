# Animation pipeline

## Source and mapping

`assets/blender/animations/StraightSword_R15.blend` stores the editable `CombatIdle`, `SwordR1_1`, `SwordR1_2`, `SwordR2` and four directional roll Actions. Its R15-compatible rig was adapted from the repository's existing AshenOath donor rig without changing the game R15 hierarchy. The joint schema is retained in `assets/blender/rig/R15_joint_schema.json`. A paired prop Action drives the sword during Blender review. `tools/CombatTestSword.server.luau` attaches the project's existing sword mesh to a player R15 hand for Studio silhouette tests; that weld is a visual test attachment, not a claim that the paired Blender prop motion is reproduced exactly in game.

`tools/author_blender.py` opens the donor, creates key poses and interpolated curves in Blender, then bakes R15 joint transforms at 30 FPS into `assets/animations/r15/baked/*.json`. `tools/package_rbxmx.py` converts the samples into Roblox `KeyframeSequence`/`Keyframe`/`Pose`/`KeyframeMarker` XML. The resulting individual files are in `assets/animations/r15/combat_idle`, `straight_sword` and `dodge`. `CombatFoundation_Import.rbxmx` bundles those clips and the runtime scripts.

The current iteration adds a low one-hand guard, visible steps in both R1 clips and R2, intermediate roll takeoff/landing poses, a controlled roll ground-contact pass and clamped location curves. Front, side, back and approximate third-person camera renders of all eight clips were inspected. The rear view showed the R1_2 and R2 blades becoming foreshortened near contact; this remains a visual feedback risk. The floor analyzer samples the evaluated character and prop meshes on all 30 FPS frames; no sampled penetration remains. The R1_1 to R1_2 start pose and all action end poses were checked against the baked joint transforms. These checks do not certify subjective quality, foot sliding during physical travel, or compatibility with every player avatar. The Blender file remains the editable source; later hand edits in Blender require a compatible bake instead of rerunning this generator over them.

## Studio validation already performed

The import script constructed eight real KeyframeSequences with marker instances in an existing Studio place. The updated eight clips were staged from baked JSON in the same place, with the prior sequences moved into an `AnimationBackup_*` folder. In Play Solo, a standard R15 `Animator` loaded the combat idle, R1 and backward roll tracks. The project sword mesh attached on spawn, and its `Motor6D` followed the right hand. The Blender donor body and the player's avatar body have different silhouettes, so the Studio view remains a separate visual QA gate. The standalone `.rbxmx` files have not been opened in a second project. No Roblox animation assets have been published.

## Sword in hand for Studio review

The existing `AshenOath_Greatsword` MeshPart is used. In the current old Coliseum place, the test script finds it at `ServerStorage/blender666/Assets/AshenOath_Greatsword`. In a separate R15 test place, copy that unscaled source Model into `ServerStorage` as `CombatTestSwordTemplate`. Put `assets/weapon/CombatTestSwordScript.rbxmx` in `ServerScriptService`, or create a Script there from `tools/CombatTestSword.server.luau`. The script scales and clones the source, creates a noncolliding `Motor6D` at the right hand, and replaces only its own previous test copy on respawn. No map geometry is required. `StraightSword_Prototype.fbx` is already scaled; importing it as the template would require adjusting or removing the script's scale step and verifying its hilt origin.

The Studio test confirmed the mesh ID `rbxassetid://139047510233988` already present in this project; this is a weapon mesh ID, not an AnimationId. The test weld uses a fixed compromise grip for a standard R15 avatar. It is useful for seeing whether a pose hides or clips the blade, but final weapon alignment needs per-avatar and per-action review. The script has been installed in the open Studio Edit session; the repository copy and `.rbxmx` are the durable source files.

## Required next animation pass

The donor `AshenOath_R15.blend` contains older `WalkForward`, `WalkBackward`, `StrafeLeft`, `StrafeRight`, `RunForward`, guard and parry Actions. Front/side inspection found a two-hand upright greatsword pose and very small leg changes in the locomotion loops. They do not match this one-hand straight-sword set or solve visible foot sliding, so they were left in the donor source and were not presented as finished combat locomotion. Their original files remain untouched.

1. Find unobstructed movement references and document precise visible key poses. The supplied longsword clip is partly obscured; see [ANIMATION_REFERENCE_BREAKDOWN.md](ANIMATION_REFERENCE_BREAKDOWN.md).
2. Review the current clips from back and gameplay camera views at full and reduced speed, then refine foot planting, elbow continuity and sword alignment where the live R15 view disagrees with the Blender donor.
3. Continue refining the four roll variants, then author combat locomotion, block, parry and reactions as real Actions before enabling their visuals in production.
4. Export/bake, reimport into a clean R15 place, check markers and priority, then publish approved clips under the owning Roblox account/group. Put only verified IDs in `AnimationRegistry`.

The current `CombatConfig` and Blender clip lengths/markers are aligned to authored frames at 30 FPS. These numbers are project prototypes, not measured Dark Souls III parameters. Roblox root movement is driven separately by the server action controller.
