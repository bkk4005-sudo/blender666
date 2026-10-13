"""Keep the asset inventory synchronized with actual generated clips."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rows = []
for path in sorted((root / "assets/animations/r15/baked").glob("*.json")):
    clip = json.loads(path.read_text())
    name = clip["name"]
    folder = "combat_idle" if name == "CombatIdle" else "dodge" if name.startswith("Roll") else "defensive" if name in ("Block", "Parry") else "reactions" if name in ("Stagger", "GuardBroken") else "straight_sword"
    rows.append(f"| {name} | {name} | `assets/animations/r15/{folder}/{name}.rbxmx` | {clip['duration']:.6f} s | {len(clip['frames'])} | {clip['priority']} / {clip['loop']} | {', '.join(clip['markers']) or 'none'} | unpublished; visual iteration |")
text = """# Animation asset manifest

Version: prototype-2.4, 2026-10-14. All twelve editable Actions live in `assets/blender/animations/StraightSword_R15.blend`, authored at 30 FPS and baked at 60 samples/second. All animation Asset IDs are **nil**. Original project reconstructions; no timings below are claimed to be measured DS3 values. Export profile: canonical standard R15, authored HipHeight 2.192423105239868 (measured in Studio).

| Semantic name | Blender Action | Portable source | Duration | Samples | Priority / loop | Real markers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
""" + "\n".join(rows) + """

The JSON bakes under `assets/animations/r15/baked/` and all KeyframeSequences are generated from the saved Blender Actions. `AnimationRegistry` uses the semantic names above. Rig compatibility and current QA limits are in AVATAR_COMPATIBILITY.md. Parry active timings remain project values 0.18–0.34 s, quantized to the nearest bake sample for visual markers; server rules use the exact configured values.

## Sword assets

- `assets/weapon/StraightSword_Prototype.fbx`: scaled original project sword geometry.
- `assets/weapon/CombatWeaponTemplate.rbxmx`: **unscaled** single-MeshPart template. Place as `ServerStorage/CombatWeaponTemplates/StraightSword`; WeaponVisual applies scale once. Existing uploaded mesh ID: 139047510233988. Verified project SurfaceAppearance IDs: color 136130758953102, normal 139522448011869, metalness 97914543082669, roughness 104238439149413. These are mesh/texture IDs, not animation IDs.
- `assets/weapon/weapon_grip.json` and `src/shared/WeaponVisualConfig.luau`: generated rigid grip frame.
- `assets/weapon/CombatTestSwordScript.rbxmx`: legacy Studio-only test harness, disabled in the current scene after installing WeaponVisual. Do not run both equip scripts.

Git LFS tracks .blend and .fbx. Local XML reimport is NOT TESTED: the connected execution context cannot call InsertService.LoadLocalAsset (RobloxScript capability). Existing native instance installation and source-to-XML checks pass; separate manual XML import must still be verified.
"""
(root / "ANIMATION_ASSET_MANIFEST.md").write_text(text, encoding="utf-8")
print("Manifest:", len(rows), "clips")
