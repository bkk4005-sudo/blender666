# Animation asset manifest

Version: prototype-2.4, 2026-10-14. All twelve editable Actions live in `assets/blender/animations/StraightSword_R15.blend`, authored at 30 FPS and baked at 60 samples/second. All animation Asset IDs are **nil**. Original project reconstructions; no timings below are claimed to be measured DS3 values. Export profile: canonical standard R15, authored HipHeight 2.192423105239868 (measured in Studio).

| Semantic name | Blender Action | Portable source | Duration | Samples | Priority / loop | Real markers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Block | Block | `assets/animations/r15/defensive/Block.rbxmx` | 1.600000 s | 97 | Action / True | none | unpublished; visual iteration |
| CombatIdle | CombatIdle | `assets/animations/r15/combat_idle/CombatIdle.rbxmx` | 2.000000 s | 121 | Idle / True | none | unpublished; visual iteration |
| GuardBroken | GuardBroken | `assets/animations/r15/reactions/GuardBroken.rbxmx` | 1.166667 s | 71 | Action / False | RecoveryEnd | unpublished; visual iteration |
| Parry | Parry | `assets/animations/r15/defensive/Parry.rbxmx` | 0.900000 s | 55 | Action / False | ParryActiveStart, ParryActiveEnd, RecoveryEnd | unpublished; visual iteration |
| RollBackward | RollBackward | `assets/animations/r15/dodge/RollBackward.rbxmx` | 0.833333 s | 51 | Action / False | IFrameStart, IFrameEnd, RecoveryEnd | unpublished; visual iteration |
| RollForward | RollForward | `assets/animations/r15/dodge/RollForward.rbxmx` | 0.833333 s | 51 | Action / False | IFrameStart, IFrameEnd, RecoveryEnd | unpublished; visual iteration |
| RollLeft | RollLeft | `assets/animations/r15/dodge/RollLeft.rbxmx` | 0.833333 s | 51 | Action / False | IFrameStart, IFrameEnd, RecoveryEnd | unpublished; visual iteration |
| RollRight | RollRight | `assets/animations/r15/dodge/RollRight.rbxmx` | 0.833333 s | 51 | Action / False | IFrameStart, IFrameEnd, RecoveryEnd | unpublished; visual iteration |
| Stagger | Stagger | `assets/animations/r15/reactions/Stagger.rbxmx` | 0.666667 s | 41 | Action / False | RecoveryEnd | unpublished; visual iteration |
| SwordR1_1 | SwordR1_1 | `assets/animations/r15/straight_sword/SwordR1_1.rbxmx` | 0.933333 s | 57 | Action / False | AttackStart, HitStart, HitEnd, ComboOpen, ComboClose, RecoveryEnd | unpublished; visual iteration |
| SwordR1_2 | SwordR1_2 | `assets/animations/r15/straight_sword/SwordR1_2.rbxmx` | 0.966667 s | 59 | Action / False | AttackStart, HitStart, HitEnd, ComboOpen, ComboClose, RecoveryEnd | unpublished; visual iteration |
| SwordR2 | SwordR2 | `assets/animations/r15/straight_sword/SwordR2.rbxmx` | 1.433333 s | 87 | Action / False | AttackStart, HitStart, HitEnd, RecoveryEnd | unpublished; visual iteration |

The JSON bakes under `assets/animations/r15/baked/` and all KeyframeSequences are generated from the saved Blender Actions. `AnimationRegistry` uses the semantic names above. Rig compatibility and current QA limits are in AVATAR_COMPATIBILITY.md. Parry active timings remain project values 0.18–0.34 s, quantized to the nearest bake sample for visual markers; server rules use the exact configured values.

## Sword assets

- `assets/weapon/StraightSword_Prototype.fbx`: scaled original project sword geometry.
- `assets/weapon/CombatWeaponTemplate.rbxmx`: **unscaled** single-MeshPart template. Place as `ServerStorage/CombatWeaponTemplates/StraightSword`; WeaponVisual applies scale once. Existing uploaded mesh ID: 139047510233988. Verified project SurfaceAppearance IDs: color 136130758953102, normal 139522448011869, metalness 97914543082669, roughness 104238439149413. These are mesh/texture IDs, not animation IDs.
- `assets/weapon/weapon_grip.json` and `src/shared/WeaponVisualConfig.luau`: generated rigid grip frame.
- `assets/weapon/CombatTestSwordScript.rbxmx`: legacy Studio-only test harness, disabled in the current scene after installing WeaponVisual. Do not run both equip scripts.

Git LFS tracks .blend and .fbx. Local XML reimport is NOT TESTED: the connected execution context cannot call InsertService.LoadLocalAsset (RobloxScript capability). Existing native instance installation and source-to-XML checks pass; separate manual XML import must still be verified.
