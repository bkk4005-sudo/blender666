# Combat pacing — prototype 2.6 / deliberate-1

This is authored project tuning after playtest feedback that the actions feel rushed. It is **not** a measurement or exact reproduction of DS3. Source encode FPS and clean isolated source roll/R1 contact timings remain unverified.

| Action | Previous duration | Current duration | Current hit / invulnerability window | Current vulnerable recovery |
| --- | --- | --- | --- | --- |
| R1 first swing | 0.933 s | 1.300 s | hit 0.467–0.733 s | 0.567 s if no combo |
| R1 continuation | 0.967 s | 1.333 s | hit 0.433–0.700 s | 0.633 s |
| R2 | 1.433 s | 1.967 s | hit 0.933–1.300 s | 0.667 s |
| Four rolls | 0.833 s | 1.200 s | i-frames 0.200–0.600 s | 0.600 s after i-frames, including 0.233 s stationary recovery |
| Parry | 0.900 s | 1.100 s | active 0.200–0.367 s | 0.733 s |

Idle breath loop: 3.2 s. Block breath loop: 2.8 s. Stagger: 0.867 s. Guard break: 1.5 s.

R1 input buffers from 0.667 through 0.967 s; its displayed combo window is 0.800–0.967 s. The server changes clips at 0.967 s, at the exact authored continuation pose. Hit-start cadence is about 0.933 s between the two swings, previously about 0.667 s. The second swing ends the combo. A miss retains recovery and stamina cost.

## Movement

Forward roll distance is 8.4 studs; other directions are 7.8 studs. Movement occurs at 0.100–0.967 s, then the planar actuator holds zero horizontal velocity until recovery ends at 1.2 s. The normalized rise/plateau/fall velocity envelope has integral 0.8. Forward peak command speed is 12.115 studs/s (previously 18); lateral/back peak is 11.25 (previously 16.5). Gravity stays active. No HumanoidRootPart teleport is introduced.

R1 advances 1.45 / 1.3 studs; R2 advances 1.8. Walk/sprint/block speeds are 10 / 15 / 5.5. Attack facing limits are 70°/s for R1 and 45°/s for R2, shared by server arc orientation and client lock-on facing.

## Editing

Edit `config/action_pacing.json`. Its `poseFrames` map old **authored project pose indices** to new authored frames at 30 FPS. Individual phases use different mappings; there is no global slow-motion playback multiplier. `tools/author_blender.py` creates editable Actions and 60 Hz bakes using this map and generates `src/shared/CombatPacing.luau`. `tools/pacing.py` can regenerate only the runtime timing module when changing a gameplay field that does not alter the authored pose schedule or markers. AnimationRegistry retains semantic names and no fabricated IDs.

Regenerate the Blender sources/bakes, run `tools/package_rbxmx.py`, `tools/validate_assets.py` and Blender `tools/validate_blender.py`, then update Studio with `tools/update_studio_animations.luau` and restart Play. The runtime module, real markers and source files must be updated together. Published animations require republishing and verified IDs before use.

## Verification and limits

`tests/pacing_runtime_2026_10_14.json` verifies actual installed clip lengths/markers against server phases and integrates commanded motion. `tests/pacing_server_2026_10_14.json` exercises real CombatService methods with isolated synthetic characters: no startup damage, one hit, buffered combo, recovery rejection, longer R2 commitment and all four roll cleanups. `tests/native_input_pacing_2026_10_14.json` observes real mouse/keyboard input and unanchored travel at playback speed 1. Native server-state observation includes Studio event/simulation latency beyond the configured durations; those observations are not DS3 frame measurements.

The hit query remains an approximate server arc. Two-player latency, moving foot contact on slopes and final competitive balance are NOT TESTED. Slower pacing does not by itself certify the PvP system.
