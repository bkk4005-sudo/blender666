# Animation asset manifest

Version: `prototype-1`, 2026-10-13. Rig: standard Roblox R15 joint names. Source: `assets/blender/animations/StraightSword_R15.blend`. Published Roblox Asset IDs: **none**. `AnimationRegistry` deliberately contains `nil` for every Asset ID.

| Semantic name | Source Action | Portable KeyframeSequence | Length at 30 FPS | Priority / loop | Timeline markers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| CombatIdle | CombatIdle | `assets/animations/r15/combat_idle/CombatIdle.rbxmx` | 60/30 s | Idle / yes | none | First pass; Studio playback checked |
| SwordR1_1 | SwordR1_1 | `assets/animations/r15/straight_sword/SwordR1_1.rbxmx` | 28/30 s | Action / no | AttackStart, HitStart, HitEnd, ComboOpen, ComboClose, RecoveryEnd | First pass; Studio playback and damage checked |
| SwordR1_2 | SwordR1_2 | `assets/animations/r15/straight_sword/SwordR1_2.rbxmx` | 29/30 s | Action / no | AttackStart, HitStart, HitEnd, ComboOpen, ComboClose, RecoveryEnd | First pass; combo transition checked |
| SwordR2 | SwordR2 | `assets/animations/r15/straight_sword/SwordR2.rbxmx` | 43/30 s | Action / no | AttackStart, HitStart, HitEnd, RecoveryEnd | First pass; visual render only |
| RollForward / Backward / Left / Right | none | none | — | Action / no | planned IFrameStart, IFrameEnd | UNAUTHORED |
| Block / Parry / Stagger | none | none | — | Action | planned ParryActiveStart, ParryActiveEnd | UNAUTHORED |

The individual JSON bake files are in `assets/animations/r15/baked/`. The training sword mesh is `assets/weapon/StraightSword_Prototype.fbx`. The `.blend` and `.fbx` paths are configured for Git LFS; verify uploaded LFS objects after pushing. XML package reimport in another place is **NOT TESTED**.
