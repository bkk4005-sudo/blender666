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
