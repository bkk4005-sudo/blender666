# Test report — 2026-10-13

Scope: local Blender 5.2 and one connected Roblox Studio instance using the old Coliseum in Play Solo. This is a prototype test, not release certification. Prototype balance timings are authored values, not Dark Souls III measurements.

| Check | Result | Evidence / limit |
| --- | --- | --- |
| Blender source generation | PASS | Eight editable Actions saved in `StraightSword_R15.blend`; roll clips each bake 26 samples, and the script reported max leg extension 0 and near-zero grip solver error. These numeric checks do not prove visual quality. |
| Individual KFS generation | PASS offline | `tools/validate_assets.py` parsed eight `.rbxmx` files and the bundle, confirming R15 pose names, frame times, marker sets and the Studio-verified priority tokens. Independent Studio reimport of these XML files is NOT TESTED. |
| Studio import from JSON | PASS | In Edit mode the importer created three shared modules, two server scripts and eight KeyframeSequences. The previous prototype installation was confirmed unchanged before replacing it. |
| R15 animation playback | PASS basic | During Play Solo `SwordR1_1` loaded on the standard R15 Animator and played with Action priority and a reported length of 0.9333 s. Joint mapping at runtime is plausible; movement polish is NOT VERIFIED. |
| R1 hit and dummy | PASS basic | A temporary static R15 dummy with `CombatDummy=true` at approximately 5 studs took one 22-damage R1 hit. The dummy was removed from the Play session. |
| R1 combo buffer | PASS basic | A second R1 request during the buffer started `SwordR1_2`; stamina decreased for both actions. Visual transition polish is NOT VERIFIED. |
| Four roll directions | PASS basic | In Play Solo each directional roll started its own 0.8333 s R15 AnimationTrack and returned to Idle. Sampled backward/left/right movement was approximately 11 studs in the expected relative directions. `IFrameStart` fired. Root movement now uses bounded acceleration/deceleration. Visual polish remains pending. |
| Server i-frame window | PASS controlled Play test | A temporary server test invoked damage at 0.25 s into a forward roll: health stayed 100. The same damage after the window reduced health to 78. Test service and temporary attacker model were destroyed. |
| Respawn input sequence | PASS Play test | Sequence 100 started R1, the character died and respawned, and sequence 101 started a new R1. Server sequence state now survives character replacement. |
| Obstruction check | PASS controlled Play test | A temporary wall between attacker and a 5-stud dummy kept health at 100; removing the wall allowed the sampled sword sweep to deal 22 damage. Temporary test objects were destroyed. |
| R2 startup, marker, miss recovery | PASS basic | Play Solo R2 spent 34 stamina, entered AttackActive, played a 1.4333 s track, fired `HitStart` and `RecoveryEnd` client marker signals, then returned to Idle with no target. Hit damage and sword alignment remain NOT TESTED. |
| I-frame strike timing with real opponent | NOT TESTED | The controlled server timing test passed; an actual two-player hit exchange remains untested. |
| Block/parry/guard break | NOT TESTED | Server logic exists, visual clips missing. |
| Two players, latency, replay abuse | NOT TESTED | Play Solo only; the sequence test above does not substitute for hostile remote replay or network emulation. |
| Lock-on locomotion and camera | NOT TESTED | Needs target/movement review with actual input. |
| Second-map integration | NOT TESTED | New Coliseum place is not present in this checkout. |
| Published AnimationIds | NOT TESTED | No assets were published, and no IDs were invented. |

Visual review of front/side Blender renders found readable wind-up silhouettes, but the first R1 contact passes close to the chest and leg/weight shifts still feel stiff. The first roll pass put the sword into the floor; a revised blade orientation removed the obvious penetration in inspected key poses. The R15 tumble still needs hand polish and clean comparison footage. Locomotion and defensive Actions remain missing before a credible PvP quality gate. The old `.rbxl` on disk was left unchanged.
