# Combat installation and saved files

Transfer to the newer map is deferred at the user's request. This pass does not perform a map transfer. The steps below remain an optional reference.

For the current scene, WeaponVisual replaces the disabled legacy CombatTestSword harness. The registered unscaled source template lives in ServerStorage/CombatWeaponTemplates/StraightSword. The separately saved `assets/weapon/CombatWeaponTemplate.rbxmx` contains the same verified mesh/texture references, but local XML reimport still needs manual verification. Do not scale this template before WeaponVisual applies its scale.

The portable bundle now contains nine shared modules, five server scripts/modules, three LocalScripts and twelve animation sources. `BladeTrajectory` belongs beside `CombatService` in ServerScriptService/CombatFoundation and uses the shared retarget/clearance/grip modules. The initial HTTP importer includes these files; the update importer stages replacements and preserves existing foundation sources in dated backup folders. The rest of the map is not part of either importer. Published IDs and DataStore access still require testing in a published experience.

Do this on a copy or isolated Git branch of the newer place. The combat folder has no map dependency and must not replace `Workspace` or the newer Coliseum geometry.

1. Merge only `combat/`, `.gitattributes` and `.gitignore` into the newer repository. Keep its existing place file, Workspace layout and other scripts.
2. Back up existing scripts and animation objects if names overlap. Inspect current input bindings and combat services before enabling this prototype. Do not run both combat controllers for the same character.
3. In Studio Edit mode, import the `Shared`, `Server` and `Client` sources under the paths expected by `tools/import_studio.luau`. The script expects `ReplicatedStorage.CombatFoundation`, `ServerScriptService.CombatFoundation` and `StarterPlayer.StarterPlayerScripts.CombatClient`. It refuses to overwrite an existing CombatFoundation install. The script can fetch the files from a localhost HTTP server rooted at `combat/`; check `HttpEnabled` and restore it after import.
4. Import all twelve KeyframeSequences under `ReplicatedStorage.CombatFoundation.Animations`. The provided importer constructs them from the baked JSON, retaining SourceAuthoredHipHeight and SourceGroundClearance metadata. The server compiles its attack paths from these same sources after final appearance loads; missing sources/joints keep CombatHitReady false. The generated `.rbxmx` package is an alternate transfer artifact, but independent reimport has not yet been verified.
5. Test a standard R15 avatar in Play Solo, then test two clients with network emulation. Confirm CombatHitReady after appearance loading, blade contact and cover obstruction, stamina, combo including a step that crosses chainAt, roll invulnerability, death/respawn and animation markers. Check that activeEnd is processed once and a parry stops queued continuation. Clothing/accessories do not enlarge the body-box hurtboxes. Two-player latency/rewind remain unverified; publish approved clips to the game's owner/group and update only verified Asset IDs before a release test.
6. Add the visible sword using the project's chosen attachment/equip system after checking grip alignment in Studio. The FBX is a prototype prop, not a finished equipped weapon.

Do not commit a modified old `.rbxl` merely to transfer this module. No map file is included in this combat package.
