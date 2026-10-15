"""Archive recorded traces and index results; never creates test PASS claims."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
finals = (
    "final0_focus_20261016", "final150_focus_20261016",
    "final300_attacks_20261016", "final300_exchanges_20261016",
    "final300_rolls_20261016", "final300_lethal_retry_20261016",
)
before = (
    "pvp_probe_r1_before", "pvp_probe_300_before", "baseline_attacks_after",
    "delay150_attacks_after", "delay300_attacks_after",
)
archive = root / "tests/pvp_raw_2026_10_16.zip"
members = []
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
    for name in finals + before:
        path = root / "review" / (name + ".json")
        raw = path.read_bytes()
        bundle.write(path, path.name)
        members.append({"file": path.name, "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(), "finalSource": name in finals})

groups, total = {}, Counter()
for name in finals:
    report = json.loads((root / "review" / (name + ".json")).read_bytes())
    delay = str(report["appliedNetwork"]["InboundNetworkMinDelayMs"])
    group = groups.setdefault(delay, {"inboundMinMs": int(delay),
        "outboundMinMs": report["appliedNetwork"]["OutboundNetworkMinDelayMs"],
        "statuses": Counter(), "echoSeconds": [], "attempts": [],
        "ownerAnimationFrames": 0, "observerAnimationFrames": 0,
        "ownerDuplicateFrames": 0, "observerDuplicateFrames": 0})
    group["echoSeconds"].extend(row["roundTripSeconds"] for row in report["pings"])
    assert report["completed"] and not report["errors"], name
    for case in report["cases"]:
        checks = case["checks"]
        group["statuses"][case["status"]] += 1
        total[case["status"]] += 1
        group["attempts"].append({"report": name + "_summary.json", "case": case["id"],
            "status": case["status"], "checks": checks,
            "failures": case["failures"], "inconclusive": case["inconclusive"]})
        for target, source in (("ownerAnimationFrames", "ownerAnimationFrames"),
            ("observerAnimationFrames", "observerAnimationFrames"),
            ("ownerDuplicateFrames", "ownerAnimationDuplicateFrames"),
            ("observerDuplicateFrames", "observerAnimationDuplicateFrames")):
            group[target] += checks[source]
for group in groups.values():
    pings = group.pop("echoSeconds")
    group["echoRoundTripMs"] = {"count": len(pings), "min": min(pings)*1000, "max": max(pings)*1000}
    group["statuses"] = dict(group["statuses"])

result = {"date": "2026-10-16", "scope": "Recorded two-Player Studio tests through native bindings. Contact fixtures are anchored; free-roll cases are unanchored. No moving-duel, jitter/loss, rewind or published-asset certification.",
    "attemptStatuses": dict(total), "profiles": groups,
    "sourceEvidence": "installed_pvp_sources_2026_10_16.json",
    "packageEvidence": "package_pvp_2026_10_16.json",
    "rawArchive": {"file": archive.name, "bytes": archive.stat().st_size,
        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "members": members},
    "beforeSourceWarning": "Archived pre-fix reports used weaker animation gates. Their old PASS labels do not prove exclusive playback. Reanalysis exposes duplicate IDs and replay events; only finalSource members use the final controller and observer."}
(root / "tests/pvp_2026_10_16.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"statuses": dict(total), "profiles": {key: {k: v for k, v in group.items() if k != "attempts"} for key, group in groups.items()}, "archiveBytes": archive.stat().st_size}))
