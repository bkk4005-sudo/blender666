# Test report — 2026-10-13

Scope: local Blender 5.2 and one connected Roblox Studio instance using the old Coliseum in Play Solo. This is a prototype test, not release certification. Prototype balance timings are authored values, not Dark Souls III measurements.

| Check | Result | Evidence / limit |
| --- | --- | --- |
| Blender source generation | PASS | Four editable Actions saved in `StraightSword_R15.blend`; script reported 61, 29, 30 and 44 sampled frames, max leg extension 0 and near-zero grip solver error. These numeric checks do not prove visual quality. |
| Individual KFS generation | PASS offline | `tools/validate_assets.py` parsed four `.rbxmx` files and the bundle, confirming R15 pose names, frame times, marker sets and the Studio-verified priority tokens. Independent Studio reimport of these XML files is NOT TESTED. |
| Studio import from JSON | PASS | In Edit mode the importer created three shared modules, two server scripts and four KeyframeSequences. After rebuilding, it was reimported and all four clip lengths and marker times were queried from actual Studio instances. |
| R15 animation playback | PASS basic | During Play Solo `SwordR1_1` loaded on the standard R15 Animator and played with Action priority and a reported length of 0.9333 s. Joint mapping at runtime is plausible; movement polish is NOT VERIFIED. |
| R1 hit and dummy | PASS basic | A temporary static R15 dummy with `CombatDummy=true` at approximately 5 studs took one 22-damage R1 hit. The dummy was removed from the Play session. |
| R1 combo buffer | PASS basic | A second R1 request during the buffer started `SwordR1_2`; stamina decreased for both actions. Visual transition polish is NOT VERIFIED. |
| Roll displacement/cleanup | PASS basic | A Play Solo forward roll entered Rolling, moved about 12.5 studs and removed its temporary LinearVelocity on completion. Roll body animation does not exist. |
| R2 startup, marker, miss recovery | PASS basic | Play Solo R2 spent 34 stamina, entered AttackActive, played a 1.4333 s track, fired `HitStart` and `RecoveryEnd` client marker signals, then returned to Idle with no target. Hit damage and sword alignment remain NOT TESTED. |
| I-frame strike timing | NOT TESTED | Requires a second actor or deterministic test harness. |
| Block/parry/guard break | NOT TESTED | Server logic exists, visual clips missing. |
| Two players, latency, replay abuse | NOT TESTED | Play Solo only. |
| Lock-on locomotion and camera | NOT TESTED | Needs target/movement review with actual input. |
| Second-map integration | NOT TESTED | New Coliseum place is not present in this checkout. |
| Published AnimationIds | NOT TESTED | No assets were published, and no IDs were invented. |

Visual review of front/side Blender renders found readable wind-up silhouettes, but the first R1 contact passes close to the chest and leg/weight shifts still feel stiff. This remains a first pass. Roll, locomotion and defensive Actions must be authored before a credible PvP quality gate. The old `.rbxl` on disk was left unchanged.
