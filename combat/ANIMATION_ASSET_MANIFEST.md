# Animation asset manifest

Version: `prototype-2.3`, 2026-10-14. Export profile: canonical standard R15 joint frames, with an editable donor rig in Blender. Source: `assets/blender/animations/StraightSword_R15.blend`. Published Roblox Animation Asset IDs: **none**. `AnimationRegistry` deliberately contains `nil` for every Asset ID. Source Actions use 30 FPS; portable sequences bake at 60 samples/second: Idle 121 samples, R1_1 57, R1_2 59, R2 87 and each roll 51. Durations and gameplay markers remain unchanged.

| Semantic name | Source Action | Portable KeyframeSequence | Length at 30 FPS | Priority / loop | Timeline markers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| CombatIdle | CombatIdle | `assets/animations/r15/combat_idle/CombatIdle.rbxmx` | 60/30 s | Idle / yes | none | Low guard revised; Blender front/side and Studio playback checked; avatar QA pending |
| SwordR1_1 | SwordR1_1 | `assets/animations/r15/straight_sword/SwordR1_1.rbxmx` | 28/30 s | Action / no | AttackStart, HitStart, HitEnd, ComboOpen, ComboClose, RecoveryEnd | Step, pelvis, contact and recovery revised; Studio playback checked; elbow and foot QA pending |
| SwordR1_2 | SwordR1_2 | `assets/animations/r15/straight_sword/SwordR1_2.rbxmx` | 29/30 s | Action / no | AttackStart, HitStart, HitEnd, ComboOpen, ComboClose, RecoveryEnd | Passing step and combo seam revised; elbow continuity QA pending |
| SwordR2 | SwordR2 | `assets/animations/r15/straight_sword/SwordR2.rbxmx` | 43/30 s | Action / no | AttackStart, HitStart, HitEnd, RecoveryEnd | Weight shift and recovery step revised; live sword alignment QA pending |
| RollForward / Backward / Left / Right | matching editable Actions | `assets/animations/r15/dodge/Roll*.rbxmx` | 25/30 s each | Action / no | IFrameStart, IFrameEnd, RecoveryEnd | Ground clearance and takeoff/landing revised; all frames floor sampled; avatar QA pending |
| Block / Parry / Stagger | none | none | — | Action | planned ParryActiveStart, ParryActiveEnd | UNAUTHORED |

The individual JSON bake files are in `assets/animations/r15/baked/`. The training sword mesh is `assets/weapon/StraightSword_Prototype.fbx`; the project's existing uploaded source MeshPart has the verified mesh ID `139047510233988`. The optional sword test script is `assets/weapon/CombatTestSwordScript.rbxmx`. This number is a mesh ID only. The `.blend` and `.fbx` paths are configured for Git LFS; verify uploaded LFS objects after pushing. XML package reimport in another place is **NOT TESTED**.
