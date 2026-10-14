# Animation pipeline

## Current avatar pass — prototype 2.5

The current stance fixes the high, inward hand targets and the donor-to-R15 anatomical arm axis mismatch. The free hand follows the forearm. `assets/weapon/r15_hand_grip.json` records the standard R15 palm frame measured in Studio; Blender solves the weapon hand part around this grip, not around the imported bone axes. WeaponVisual resolves each equipped avatar's RightGripAttachment. Preview/runtime blade and floor checks use the same frame. Updated roll takeoff/landing poses lower the weapon with the crouch. The current tests are recorded at the top of TEST_REPORT.md; older eight-clip checks below are historical.

There are now twelve editable Blender Actions, including Block, Parry, Stagger and GuardBroken. Use `tools/write_asset_manifest.py` for the exact file inventory. Original roll positions and R2 wind-up were revised; R1_2 recovery now keeps the blade farther forward of the torso. Defenses are authored project reconstructions, not measurements from an isolated DS3 parry recording.

Studio bakes compensate root translation scaling using SourceAuthoredHipHeight metadata because the AuthoredHipHeight property is protected from game scripts. The importer writes the actual property in Edit mode; the runtime reads its NumberValue metadata. Body proportions are applied after appearance loading, with a retry on CharacterAppearanceLoaded. See AVATAR_COMPATIBILITY.md for the body-box solver, physical clearance values and untested clothing cases.

Run `tools/qa_avatar_geometry.luau` in Edit for five body/scale profiles and intermediate-pose checks. Run `tools/qa_visual_playback.luau` in Client Play for real normal-speed playback. The latter restores its temporary root anchor after the check. Blender validation still evaluates actual source mesh vertices and rigid grip, rather than accepting keyframe presence as proof of visual quality.

## Source and mapping

`assets/blender/animations/StraightSword_R15.blend` stores all twelve editable Actions: `CombatIdle`, `SwordR1_1`, `SwordR1_2`, `SwordR2`, four rolls, `Block`, `Parry`, `Stagger` and `GuardBroken`. Its rig was adapted from the repository's AshenOath donor without changing the game R15 hierarchy. The source joint schema is retained in `assets/blender/rig/R15_joint_schema.json`. A hand constraint drives the sword during Blender review. WeaponVisual attaches the same project mesh through the avatar's native palm frame. The donor and standard export retain separate joint schemas.

`tools/author_blender.py` opens the donor and creates editable poses on a 30 FPS authoring timeline. It exports canonical R15 transforms at 60 samples per second into `assets/animations/r15/baked/*.json`, preserving the authored action lengths and marker times. `R15_joint_schema.json` describes the donor's rotated FBX joint frames; `R15_standard_joint_schema.json` describes a fresh default R15 created in Studio. Export converts part-relative rotations into the target joint frames instead of copying the donor's Motor6D Transform. `tools/package_rbxmx.py` creates real `KeyframeSequence`/`Keyframe`/`Pose`/`KeyframeMarker` XML. Each key also carries a `SourceGroundClearance` NumberValue used by the Studio avatar preview bake.

The sword is rigidly attached to the Blender hand through `Sword grip / rigid hand anchor` and the prop's `Rigid sword grip / source of truth` constraint. The paired PROP Actions remain editable bake snapshots, while the constraint keeps the grip exact between keys. `assets/weapon/weapon_grip.json` and `src/shared/WeaponVisualConfig.luau` are generated from the measured R15 palm reference. `Visual.forCharacter` substitutes the actual avatar's attachment. The verified Roblox scale is X=0.62, Y=0.68, Z=0.86.

The current iteration adds a low one-hand guard, visible steps in both R1 clips and R2, intermediate roll takeoff/landing poses, a controlled roll ground-contact pass and clamped location curves. Front, side, back and approximate third-person camera renders of all eight clips were inspected. The rear view showed the R1_2 and R2 blades becoming foreshortened near contact; this remains a visual feedback risk. The floor analyzer samples the evaluated character and prop meshes on all 30 FPS frames; no sampled penetration remains. The R1_1 to R1_2 start pose and all action end poses were checked against the baked joint transforms. These checks do not certify subjective quality, foot sliding during physical travel, or compatibility with every player avatar. The Blender file remains the editable source; later hand edits in Blender require a compatible bake instead of rerunning this generator over them.

## Studio validation already performed

The import script constructed eight real KeyframeSequences with marker instances in an existing Studio place. The updated eight clips were staged from baked JSON in the same place, with the prior sequences moved into an `AnimationBackup_*` folder. In Play Solo, a standard R15 `Animator` loaded the combat idle, R1 and backward roll tracks. The project sword mesh attached on spawn, and its `Motor6D` followed the right hand. The Blender donor body and the player's avatar body have different silhouettes, so the Studio view remains a separate visual QA gate. The standalone `.rbxmx` files have not been opened in a second project. No Roblox animation assets have been published.

## Sword in hand for Studio review

The existing `AshenOath_Greatsword` MeshPart is used. In the current old Coliseum place, the test script finds it at `ServerStorage/blender666/Assets/AshenOath_Greatsword`. In a separate R15 test place, copy that unscaled source Model into `ServerStorage` as `CombatTestSwordTemplate`. Put `assets/weapon/CombatTestSwordScript.rbxmx` in `ServerScriptService`, or create a Script there from `tools/CombatTestSword.server.luau`. The script scales and clones the source, creates a noncolliding `Motor6D` at the right hand, and replaces only its own previous test copy on respawn. No map geometry is required. `StraightSword_Prototype.fbx` is already scaled; importing it as the template would require adjusting or removing the script's scale step and verifying its hilt origin.

The Studio test confirmed the mesh ID `rbxassetid://139047510233988` already present in this project; this is a weapon mesh ID, not an AnimationId. The joint uses `WeaponVisualConfig.forCharacter` and the mesh's scaled RightGrip attachment. The scaled mesh is approximately 0.938 × 3.203 × 0.325 studs. Install the foundation's shared modules before the standalone test script. The repository copy and `.rbxmx` are the durable source files.

## Avatar preview and verification — 2026-10-14

`R15PreviewRetarget` clones a source sequence once per character in Studio, reads its actual joint frames and body dimensions, then bakes root-pose height corrections. It accepts Motor6D and AnimationConstraint rigs. Roblox's current R15 joint system uses AnimationConstraint; see the [official class documentation](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint). This preview changes LowerTorso animation data, never teleports HumanoidRootPart. Canonical export and avatar preview use a 0.03-stud body bounding-box clearance to absorb interpolation/constraint settling, while preserving the source roll's larger contact clearance where needed. This is a project QA margin, not a DS3 value.

The client waits for appearance loading before caching tracks, starts CombatIdle at Movement priority while standing, and yields to default locomotion when moving. Repeated identical marker signals at the same track time are gated before visual cue dispatch. The server action timeline still owns damage and invulnerability.

Run `blender -b --python-exit-code 1 --python combat/tools/validate_blender.py` to inspect source mesh clearance and rigid grip at 60 FPS, plus target skeleton forward kinematics. Run `python combat/tools/validate_assets.py` after packaging. The final Play Solo test played all eight clips at normal speed on the current avatar, with positive sampled body and sword clearance. These results do not certify other avatar proportions, slopes, moving-root foot contact or published animation playback. Published clips require approval for their intended RigProfile; the per-avatar bake here is Studio-only.

## Required next animation pass

The donor `AshenOath_R15.blend` contains older `WalkForward`, `WalkBackward`, `StrafeLeft`, `StrafeRight`, `RunForward`, guard and parry Actions. Front/side inspection found a two-hand upright greatsword pose and very small leg changes in the locomotion loops. They do not match this one-hand straight-sword set or solve visible foot sliding, so they were left in the donor source and were not presented as finished combat locomotion. Their original files remain untouched.

1. Find unobstructed movement references and document precise visible key poses. The supplied longsword clip is partly obscured; see [ANIMATION_REFERENCE_BREAKDOWN.md](ANIMATION_REFERENCE_BREAKDOWN.md).
2. Review the current clips from back and gameplay camera views at full and reduced speed, then refine foot planting, elbow continuity and sword alignment where the live R15 view disagrees with the Blender donor.
3. Continue refining the four roll variants, then author combat locomotion, block, parry and reactions as real Actions before enabling their visuals in production.
4. Export/bake, reimport into a clean R15 place, check markers and priority, then publish approved clips under the owning Roblox account/group. Put only verified IDs in `AnimationRegistry`.

The current `CombatConfig` and Blender clip lengths/markers are aligned to authored frames at 30 FPS. These numbers are project prototypes, not measured Dark Souls III parameters. Roblox root movement is driven separately by the server action controller.
