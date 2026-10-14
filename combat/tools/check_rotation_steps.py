"""Measure exported local rotation steps; distinguish fast swings from singularities."""
import json
from pathlib import Path
from mathutils import Matrix
root = Path(__file__).resolve().parents[1]
for path in sorted((root / "assets/animations/r15/baked").glob("*.json")):
    data = json.loads(path.read_text())
    highest = []
    for a, b in zip(data["frames"], data["frames"][1:]):
        for name in a["poses"]:
            def quat(values): return Matrix(tuple(tuple(values[3 + r * 3 + c] for c in range(3)) for r in range(3))).to_quaternion()
            angle = quat(a["poses"][name]).rotation_difference(quat(b["poses"][name])).angle * 180 / 3.141592653589793
            angle = min(angle, 360 - angle)
            highest.append((round(angle, 3), name, b["time"]))
    print(data["name"], sorted(highest, reverse=True)[:3], flush=True)
