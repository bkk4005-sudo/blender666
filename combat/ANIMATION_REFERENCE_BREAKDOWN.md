# Animation reference breakdown — verified viewing pass

Date: 2026-10-13. These are observations from the accessible YouTube player, not extracted game animation data. Absolute positions are player timestamps. Frame numbers below are **not** original DS3 source frames. The authoring timeline will use 30 FPS, but the source encode frame rate has not been independently verified.

## A — Longsword Moveset (Dark Souls 3)

Source: [Zombie Headz, Longsword Moveset](https://www.youtube.com/watch?v=EPZ1O4erecU), 2:23, player reported 640×360. Viewed in-browser at normal speed and with YouTube single-frame advance, which changed `currentTime` by about 0.0333 s per step. A large title overlay and the shield obscure the sword and left arm. This clip is useful for silhouette and the order of weight shifts, but insufficient for exact joint angles or definitive hit-window measurement.

The inspected interval is **00:21.999–00:24.999** (absolute video time). The following descriptions have MEDIUM or LOW visual confidence and are not proposed gameplay timings:

| Video time | Visible pose / movement | Confidence |
| --- | --- | --- |
| 00:21.999 | Front three-quarter view. Knees flexed, trunk lowered and turned. Weapon arm low; the sword tip is partly hidden. Shield side remains forward. | MEDIUM |
| 00:22.199 | Character more front facing; sword crosses low in front of the hips, shield arm separated outward. Feet keep a wide support base. | MEDIUM |
| 00:22.399 | Trunk and pelvis rotate together; left-side shield hides much of the arm and blade. One leg extends diagonally as mass moves across the stance. | LOW |
| 00:22.599 | Upper body turns, right arm reaches across the chest/shoulder line. This can be read as preparation for another swing, but the sword path is partly obscured. | LOW |
| 00:22.799 | Body drops toward the shield side. Shield occupies the centre of the silhouette; blade location cannot be stated reliably. | LOW |
| 00:22.999–00:23.399 | Sustained low crouch with shield close to the torso and bent knees. No clean sword-contact frame is visible. | MEDIUM for body, LOW for sword |
| 00:23.599–00:23.799 | Weight shifts lower and forward, left arm/shield extends; right-hand weapon remains partly hidden by body and foliage. | LOW |
| 00:23.999 | Torso rises, both arms lift; the shield is high. This is a clear transition in silhouette, but the exact move identity is uncertain. | MEDIUM |
| 00:24.199 | Body turns through the lift; forward foot remains grounded. Shield passes across the front. | MEDIUM |
| 00:24.399–00:24.599 | Upright recovery, shield settles to front side and shoulders square. | MEDIUM |
| 00:24.799–00:24.999 | A further upper-body sweep begins/continues; its weapon and shield silhouettes overlap. Exact attack classification is **UNCONFIRMED**. | LOW |

**Production implication:** Do not trace this interval into a precise R1/R2 pose sheet. A second, unobstructed side or rear view is needed to isolate sword contact, support foot and recovery. This video remains useful for the broad principle that the stance compresses before the upper-body sweep and that return to guard is controlled rather than a snap.

## B — Straight Sword Weapon Art vs Staggered R1 Weapons

Source: [saint_riot, Dark Souls 3 — Straight Sword Weapon Art vs Staggered R1 Weapons](https://www.youtube.com/watch?v=SonPrt8Z9dg), 2:37, player reported 854×480. The video's own description says it demonstrates the straight-sword stance-into-R2 lunge against weapons with staggered R1 attacks. This is a tactical PvP source, not a clean isolated animation showcase.

| Video time | Observed PvP event | Confidence |
| --- | --- | --- |
| 00:34.529 | Red player faces an orange opponent across several body lengths; sword and shield visible, both inside a circular arena. | HIGH |
| 00:39.529 | Red player advances as the opponent maintains separation. Camera remains behind the red player and tracks the duel. | HIGH |
| 00:59.529 | Opponent presents a long weapon at medium range. Red player approaches with shield up and does not yet commit to a visible strike. | HIGH |
| 01:03.598 | Opponent is now farther away; a `324` damage number is visible. The capture alone cannot assign the exact hit frame or cause. Spoken narration mentions rolling twice to escape. | HIGH for separation/number, LOW for causal timing |
| 01:18.598 | Red player runs toward the retreating opponent across the circular floor. The target stays in front; range is actively managed before commitment. | HIGH |

**Production implication:** Support target-facing locomotion, distance checks and punishable recovery. The clip shows why a lunge needs a deliberate startup and bounded reach, but it does **not** establish numeric startup, i-frame or hitbox values for this Roblox project.

## Target animation coverage

| Target | Reference confidence | Next observation needed |
| --- | --- | --- |
| CombatIdle | LOW | Unobstructed idle loop, front and side view. |
| SwordR1_1 | LOW | Identify an isolated one-handed R1 in A and capture nine semantic poses. |
| SwordR1_2 | LOW | Capture its transition directly from R1_1, without returning to idle. |
| SwordR2 | LOW | Isolated heavy attack view with startup, strike and recovery. |
| RollForward/Backward/Left/Right | NOT OBSERVED in inspected intervals | Clean medium-roll reference with visible floor contact. |
| Block/Parry/Stagger | NOT OBSERVED in inspected intervals | Separate clear references. |

All unobserved frames, angles and precise timings remain **ESTIMATED/UNVERIFIED** if prototyped. No DS3 animation files or skeleton data are used.

## C — PvP mechanics and roll categories (additional viewing, 2026-10-13)

Source: [Juutas and EIiitti, DARK SOULS III PvP MECHANICS](https://www.youtube.com/watch?v=lm4IOCkc5n0). The player displayed a 16:12 runtime. At 01:03–01:05, title graphics introduce equipment-load breakpoints for roll speed; at 01:33 a player is running toward an opponent; at 01:37 the controlled player is standing opposite that opponent. The inspected 01:03–01:50 samples do **not** present an unobstructed side-on, frame-steppable medium roll. This source confirms context for different roll categories but cannot support an original DS3 roll pose table, exact roll duration or invulnerability timing. Confidence for roll biomechanics: **LOW**.

### Authored R15 roll reconstruction — ESTIMATED, not DS3 source frames

All numbers below are frames of **our** 30 FPS Blender Action. The forward clip is 25 frames / 0.833 s; its server i-frame window is authored at frames 5–16. The other three directions use the same phase schedule with distinct diagonal shoulder axes. These are project tuning values.

| Own frame | Semantic pose | Body / centre of mass | Legs / support | Arms and sword |
| --- | --- | --- | --- | --- |
| 0 | Standing preparation | Upright combat stance, mass centered | Both feet support | Sword at guard |
| 2 | Centre-of-mass lowering | Hips descend and trunk folds forward | Both knees bend; feet planted | Left arm draws in; blade turns across body |
| 4 | Roll initiation | Body leans into travel and begins diagonal pitch | Rear foot pushes; support transfers forward | Forearms guard head; blade aligns to roll axis |
| 6 | Initial body rotation | Trunk and hips rotate as one mass | Feet leave planted stance and tuck | Sword stays close to torso |
| 9 | Mid-roll entry | Shoulder approaches floor; mass low | Knees fold toward torso | Head turns into chest; blade remains lateral |
| 12 | Mid-roll / back passage | Body inverted around diagonal shoulder axis | Legs above the trunk, compact | Arms protect head; sword passes beside body |
| 15 | Shoulder/back ground passage | Torso crosses low contact | Legs begin to release from tuck | Sword kept laterally clear of floor in Blender review |
| 18 | Recovery contact | Body rises out of rotation | Feet seek the floor | Arms prepare to regain guard |
| 21 | Rising | Trunk nearly upright, mass shifts over feet | Knees absorb landing | Sword returns across body |
| 25 | Standing recovery | Returns to combat stance | Both feet support | Guard restored |

Forward axis: diagonal forward-left shoulder; backward: reverse diagonal; left/right: steeper lateral diagonals. These pose sheets need clean DS3 reference footage and further visual polish. They must not be cited as original game measurements.

## Authored straight-sword pose sheets — ESTIMATED, not DS3 source frames

These frames describe the editable Actions in `StraightSword_R15.blend`. The supplied footage did not reveal an unobstructed original R1/R2 frame sequence. Left/right refer to the R15 mannequin, and support is inferred from the authored foot targets. All three attacks need a side-by-side gameplay-camera review before approval.

### SwordR1_1 — right-to-left horizontal sweep

| Own frame | Phase | Trunk / shoulders / centre of mass | Legs / support | Hands and sword |
| --- | --- | --- | --- | --- |
| 0 | Neutral stance | Mild forward bias, shoulders relaxed | Wide support, both knees soft | Right hand guards low |
| 2 | Anticipation | Upper trunk rotates back | Weight starts to rear foot | Grip retreats |
| 5–7 | Maximum wind-up | Shoulder line turns behind pelvis | Rear foot stabilizes | Sword reaches rear side |
| 9 | Acceleration | Pelvis and trunk unwind | Weight starts toward lead leg | Sword crosses toward target line |
| 10 | Pre-impact | Trunk continues into target | Lead leg absorbs travel | Blade approaches centreline; interpolated sample |
| 11 | Contact / peak swing | Shoulders follow hips | Lead support dominant | Blade crosses attack arc |
| 14 | Follow-through | Trunk turns beyond target | Lead knee flexed | Sword passes far side |
| 21 | Recovery | Hips slow, shoulders resquare | Weight re-centres | Sword held at end of arc for combo transition |
| 28 | Return to stance | Neutral torso and gaze | Both feet support | Guard restored if no combo |

### SwordR1_2 — reverse continuation

| Own frame | Phase | Trunk / shoulders / centre of mass | Legs / support | Hands and sword |
| --- | --- | --- | --- | --- |
| 0 | Continuation stance | Starts from R1_1 end pose, torso already turned | Lead leg loaded | Sword remains on far side |
| 3 | Anticipation | Shoulders begin reverse coil | Weight shifts toward rear | Grip lifts from follow-through |
| 5 | Maximum wind-up | Torso turns toward far shoulder | Rear leg braces | Sword reaches high reverse side |
| 8 | Acceleration | Hips initiate counter-rotation | Weight moves forward | Blade enters reverse arc |
| 10 | Pre-impact | Shoulders chase pelvis | Lead foot receives load | Blade closes on centreline |
| 11 | Contact / peak swing | Trunk crosses attack line | Lead knee bent | Reverse sweep at peak |
| 14 | Follow-through | Upper body continues, controlled | Both feet remain grounded | Sword passes opposite side |
| 19 | Recovery | Rotation decays | Weight re-centres | Grip remains beyond target |
| 29 | Return to stance | Neutral torso | Balanced support | Sword settles to guard |

### SwordR2 — separate heavy overhead strike

| Own frame | Phase | Trunk / shoulders / centre of mass | Legs / support | Hands and sword |
| --- | --- | --- | --- | --- |
| 0 | Neutral stance | Torso prepared | Both feet support | Sword at guard |
| 4 | Anticipation | Hips lower and shoulders draw back | Rear leg loads | Grip begins rising |
| 10–14 | Maximum wind-up | Torso coils, shoulders behind pelvis | Rear support stable | Sword high overhead |
| 17 | Acceleration | Hips initiate forward drive | Weight transfers to lead leg | Blade descends toward target |
| 20 | Pre-impact | Trunk leans into strike | Lead knee absorbs advance | Sword accelerates downward |
| 21 | Contact / peak swing | Shoulders follow pelvis | Lead support dominant | Blade reaches central strike line |
| 25 | Follow-through | Torso pitches beyond contact | Lead leg catches mass | Sword passes lower arc |
| 32–38 | Recovery | Trunk rises slowly, shoulders resquare | Weight returns between feet | Sword lifts out of low finish |
| 43 | Return to stance | Balanced guard | Both feet support | Sword settles to ready position |

The contact labels are visual authoring landmarks. Server hit windows are project tuning values in `CombatConfig.luau`; they are not measurements of these YouTube sources.
