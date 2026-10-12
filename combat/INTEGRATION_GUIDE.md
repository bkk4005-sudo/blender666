# Integrate into the newer Coliseum

Do this on a copy or isolated Git branch of the newer place. The combat folder has no map dependency and must not replace `Workspace` or the newer Coliseum geometry.

1. Merge only `combat/`, `.gitattributes` and `.gitignore` into the newer repository. Keep its existing place file, Workspace layout and other scripts.
2. Back up existing scripts and animation objects if names overlap. Inspect current input bindings and combat services before enabling this prototype. Do not run both combat controllers for the same character.
3. In Studio Edit mode, import the `Shared`, `Server` and `Client` sources under the paths expected by `tools/import_studio.luau`. The script expects `ReplicatedStorage.CombatFoundation`, `ServerScriptService.CombatFoundation` and `StarterPlayer.StarterPlayerScripts.CombatClient`. It refuses to overwrite an existing CombatFoundation install. The script can fetch the files from a localhost HTTP server rooted at `combat/`; check `HttpEnabled` and restore it after import.
4. Import the four KeyframeSequences under `ReplicatedStorage.CombatFoundation.Animations`. The provided importer constructs them from the baked JSON. The generated `.rbxmx` package is an alternate transfer artifact, but independent reimport has not yet been verified.
5. Test a standard R15 avatar in Play Solo, then test two clients with network emulation. Verify damage, stamina, combo, roll invulnerability, death/respawn, and animation markers. Publish approved clips to the game's owner/group and update only verified Asset IDs.
6. Add the visible sword using the project's chosen attachment/equip system after checking grip alignment in Studio. The FBX is a prototype prop, not a finished equipped weapon.

Do not commit a modified old `.rbxl` merely to transfer this module. No map file is included in this combat package.
