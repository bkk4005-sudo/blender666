# Real two-client combat QA

This document specifies tests; it does not declare their results. A row requires
a saved multiplayer report from the matching current harness and combat version.
It uses two actual `Player` instances and separate client DataModels. Generated
Humanoid fixtures, solo Play and successful remote acknowledgements do not prove
this matrix.

Executed subsets, source evidence and results are recorded in `../TEST_REPORT.md`
and `../tests/pvp_2026_10_16.json`. The full available matrix below is a reproduction
catalogue; the report identifies exactly which cases ran under each delay.

## Installation and protocol

Install only temporary `CombatPvPQA` RemoteEvent, `qa_pvp_server.server.luau` and
`qa_pvp_client.client.luau` alongside the existing foundation. Launch with
`StudioTestService:ExecuteMultiplayerTestAsync(2, args)` from the Edit plugin
context. Server calls `EndTest(JSON string)`; it delegates production methods
without changing their returns. See the [official StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

Arguments: `runToken="CombatPvPQA"`, `probe=true` for one first R1 case,
`lagLabel="baseline"|"150ms"|"300ms"`, optional `networkSettings` describing
the requested configuration, and `appliedNetwork` containing the **actual plugin
read-back** of all seven simulation properties. Optional `cases={...}` selects a subset.
`center={x,y,z}` may name the current arena spawn; the server verifies actual flat
ground and adds each real R15 Humanoid's root/hip clearance.

Ready requires two real clients with twelve preview tracks, server `CombatHitReady`
and native VirtualInput available. Client sends `Ready` again for a completed new
avatar after respawn. Observer-cache counts are preserved as observed; missing
observer playback cannot be excused by a successful owner Ready packet.
Cases provide per-recipient inputs and a future server-clock `t0` (two seconds
ahead), so delayed schedule delivery is distinct from delayed combat requests.
The QA channel carries schedules/observations; combat enters through native mouse
and keyboard input, production bindings and the production CombatRemote.

## Matrix

Repeat this matrix separately under baseline, 150 ms and 300 ms Studio network
simulation. The label alone is not evidence that delay was applied. Preserve
directional settings read-back, raw `GetNetworkPing()` seconds, actual input
times, listener receive times and server-approved action timestamps.

| Case ID | Setup and actual input | Required evidence |
| --- | --- | --- |
| `r1_from_a`, `r1_from_b` | R1 in each direction; roots 3.2 studs apart | Approved R1, real other-player health decrease, one damage/action, weighted owner and observer clip |
| `r2_from_a`, `r2_from_b` | R2 in each direction | Approved distinct R2 and actual hit; correct owner/observer playback |
| `r1_combo_a` | Native R1 at 0 and 0.84 s | Both server-approved R1 clips and both distinct damage events; first hit alone cannot pass |
| `simultaneous_r1`, `simultaneous_r2`, `simultaneous_r1_r2` | Both native inputs scheduled at 0 | Two-way damage; measured server start skew. More than one 30 Hz step is inconclusive as a simultaneous test |
| `roll_inside_b` | A R1 at 0; B roll at 0.23 s | At least one real geometric damage attempt during server i-frames, rejected without damage. A geometric miss alone is inconclusive |
| `roll_early_b` | B roll at 0; A R1 at 0.40 s | Actual hit after i-frames; owner and peer roll/attack tracks |
| `roll_late_b` | A R1 at 0; B roll at 0.95 s | Actual damage precedes accepted roll; no retrospective protection |
| `free_roll_b` | Unanchored B roll at 0 | Real horizontal movement >2 studs and weighted owner/observer roll |
| `free_roll_backward_b` | Unanchored B backward roll at 0; native R1 at 0.32 and R2 at 0.50 s | Actual CAS Begin delivery for both interruption commands; no accepted attacks during roll, owner/observer roll continuity and actual movement |
| `roll_inputs_b` | A R1 at 0; anchored B roll at 0.23, R1 at 0.50 and R2 at 0.73 s | Confirmed server iframe contact plus actual interruption input delivery and exclusive continuous sampled roll |
| `lethal_r1_ab`, `lethal_r1_ba` | HP1 each, native R1 together; positions swapped | Actual opposing lethal contacts in a shared pre-frame snapshot, damage/death resolution, old-character cleanup and actual ready replacement avatars |

Contact cases temporarily anchor real roots for a reproducible contact fixture.
They verify networking of actions, health and animation, **not moving-duel network
ownership**. `free_roll_b` leaves roots unanchored and returns ownership to their
actual players. HP/stamina/position resets are explicit test setup, not combat
successes. Temporary changes occur only in the Play DataModels.

The lethal fixture uses HP1 because normal Humanoid health regeneration remains
enabled during the two-second input countdown. The fairness check uses actual
pre-frame HP, never the nominal setup value. Final HP alone is not a damage
measurement; ordinary regeneration can change it after a confirmed hit.

Current server update first collects validated contacts for all living actors,
then resolves the captured contacts, then advances recovery/combos. This two-phase
contact/health resolution permits legitimate same-update lethal trades while
preserving cancellation of captured attacks after parry, guard break or another
action replacement. A server-owned hit set still prevents duplicate damage to the
same target from the same action.

## Moving-player extension (2026-10-16, later pass)

Pass the decoded array from `qa_pvp_moving_cases.json` as `args.movingCases`.
The optional `args.cases` list still selects case IDs. Use a new `lagLabel`
for every attempt and record the tested revision. For these cases the server
uses unanchored roots, explicitly retains each actual player's network ownership
and resets positions only before the future schedule. The client initializes
its view once, then leaves the native camera/lock-on and production controls
in charge. Movement inputs hold actual W/A/S/D keys for the JSON `hold` duration.
Q, mouse buttons, F and Space use the production default bindings.

| Moving case | Required observation |
| --- | --- |
| `moving_windup_stop` | Held walking stops on local predicted sword input before ACK; action turn limit applies; movement resumes after recovery. Too-short pre-ACK observation is INCONCLUSIVE. |
| `moving_overshoot_miss`, `moving_retreat_miss` | Both players move; no actual health loss after passing beyond reach or retreating. |
| `moving_close_r1`, `moving_heavy_approach` | Both approach and release walking; actual R1/R2 damage and owner/peer playback. |
| `moving_strafe_exchange` | Both strafe/approach and attack; two-way damage. This schedule intentionally staggers inputs 50ms and does not certify exact simultaneous starts. |
| `moving_forward_roll` | Actual approved forward roll and a geometric contact denied inside authoritative i-frames; LMB/RMB reach their production bindings without replacing the roll. A pure miss is insufficient to prove protection. |
| `moving_backward_roll`, `moving_left_roll`, `moving_right_roll` | Approved directional roll, zero damage, real interruption inputs, owner/peer continuity. A geometric miss verifies evasion, not necessarily invulnerability. |
| `moving_rejected_attack` | Native block/attack race, actual sequence-matched rejection and resumed movement. This requires enough delay to keep the block state in flight; absent rejection is INCONCLUSIVE. |
| `moving_target_entry` | Defender moves into an ongoing swing; every actual health loss needs visible blade/body contact on both clients. |
| `moving_close_crossing` | Both hold movement while exchanging attacks; roots may not rise >2 studs without a jump. No damage is required, but every actual damage event must pass both-client contact checks. |

For every moving actor, both the server and owner-client sampled horizontal path
must exceed one stud. At least ten position observations, no anchoring and the
correct actual Player network owner are required. The server records root
position/velocity/facing roughly 15Hz; clients record body/weapon/track state
roughly 20Hz. During active sword poses, client PreSimulation additionally records
actual MeshPart blade endpoints and body-box overlap. This supplements the existing
per-frame exact-ID duplicate check; it is not artistic visual review.

For each positive health loss, the strict gate requires at least two relevant
blade samples and at least one unobstructed blade/body-box contact within 150ms
of the server damage time on **each** client. Body boxes are inflated by 0.18 studs;
accessories/root are excluded. This is a project QA threshold, not a DS3 value.
Inspect the entire active interval when diagnosing a failure. Server and defender
contact alone cannot pass this two-view visual gate.

The backward-roll schedule was advanced from 0.98 to 0.90 seconds after a real
baseline hit at roll elapsed 0.182452, before the configured 0.200-second i-frames.
Directional native input needs a simulation step before Space. The original
failed attempt and passing retry remain archived; gameplay windows are unchanged.

The executed moving results are in `../tests/moving_pvp_2026_10_16.json` and the
complete traces in `../tests/moving_pvp_raw_2026_10_16.zip`. Extract members into
`../review/` and run `archive_moving_pvp_evidence.py` to reproduce the index, or
`analyse_pvp.py review/<member>.json` for detailed phase summaries. A rejected
visual-offset experiment is explicitly archived as NOT SHIPPED. Current moving
target contact disagreement under latency is an open defect, not a passing test.

## General assessment limits

Server approved actions and health are authoritative. Client samples prove
weighted owner/observer tracks by semantic name or the owner's actual animation
ID; a Started packet alone cannot pass animation replication. Samples are at
20 Hz and do not establish absence of every single-frame interruption.

Every client **PreSimulation** frame, after animation evaluation, groups weighted
own/peer tracks at Action priority and above by exact nonempty AnimationId. More
than one track with weight >0.05 for the same ID fails the duplicate gate even
when a native track is named `Animation` and its manual counterpart uses a semantic
name. Reports preserve frame counts, duplicate-frame counts, maximum simultaneous
tracks per ID and up to eight examples. Missing full-frame counters make this
evidence inconclusive. The separate 20 Hz samples still provide clip/time/weight
details; their existing duplicate-sample metrics are retained. Historical reports
from before this gate do not prove exclusive animation playback and require fresh
runs after the fix.

`GetNetworkPing()` is logged as raw seconds without converting it into a claimed
configured one-way delay. `OnServerEvent` observation is listener execution time,
not an exposed transport-layer packet arrival timestamp.

Actual QA Ping/Pong observations record server send time, client receive time and
server return time. They provide real echo round trips including engine scheduling
and simulation. A lag label alone is not latency evidence. Small case batches keep
the original raw frame evidence without relying on a single large EndTest payload.

Lethal fairness fails if both actual players are alive, have active unconsumed
visible lethal contacts against each other in a shared pre-frame snapshot, but
only one is damaged/killed in that update. Without those positive geometric and
timing preconditions the tie test is inconclusive. Role swaps/repeats remain
necessary; a profiles-table iteration order is not a fairness policy.
Read-only lifecycle observations require dead-character combat motion to clear,
old character connections to disconnect and a different ready live avatar to
replace it. A root intentionally anchored by the QA fixture is not a motion leak.
Missing VirtualInput, missing client
reports, unsupported preview replication or inability to launch two clients must
be preserved as failures/limitations, not replaced by synthetic tests.

Server watchdog restores temporary wrappers, connections and root anchoring before
ending the test. Remove the temporary QA scripts and RemoteEvent from Edit after
reports are saved. Preserve the existing map and combat assets.

`qa_pvp_launch.luau` returns a launcher function for the Edit/plugin context. Use
a new `lagLabel` for each attempt; an existing output label is rejected before
changing network settings. It records applied settings, chunks EndTest results
into 60,000-character StringValues and restores the original network settings on
completion or launch error. The 2026-10-16 archive retains the complete final
traces and selected pre-fix traces. Extract it into `combat/review/` before running
`analyse_pvp.py` or `archive_pvp_evidence.py`; both operate on recorded evidence
and do not perform Studio tests.
