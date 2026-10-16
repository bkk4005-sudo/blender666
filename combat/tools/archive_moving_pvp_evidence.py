"""Index and archive observed moving-player tests, including failed attempts.

Run after exporting the named Studio JSON reports into combat/review/. This
does not execute tests, repair their statuses, or certify visual polish.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RUNS = {
    "moving0_probe_20261016": "before_fix_and_fixture_calibration",
    "moving150_rolls_probe_20261016": "before_fix_and_fixture_calibration",
    "moving300_windup_before_20261016": "before_fix_and_fixture_calibration",
    "moving300_prediction_after_20261016": "final_movement_code_earlier_contact_gate",
    "moving300_hits_after_20261016": "final_movement_code_earlier_contact_gate",
    "moving300_sides_reject_20261016": "final_movement_code_earlier_contact_gate",
    "moving300_entry_cross_20261016": "final_movement_code_strict_contact_gate",
    "moving300_visual_after_20261016": "rejected_experiment_NOT_SHIPPED",
    "moving0_final_20261016": "final_movement_code_strict_contact_gate",
    "moving0_backward_retry_20261016": "final_movement_code_strict_contact_gate",
    "moving150_final_20261016": "final_movement_code_strict_contact_gate",
    "moving50_entry_cross_20261016": "final_movement_code_strict_contact_gate",
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    archive = ROOT / "tests/moving_pvp_raw_2026_10_16.zip"
    reports, members, totals = [], [], {}
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for name, category in RUNS.items():
            path = ROOT / "review" / (name + ".json")
            raw = path.read_bytes()
            data = json.loads(raw)
            assert data["completed"] and not data["errors"], name
            bundle.write(path, path.name)
            member = {"file": path.name, "bytes": len(raw), "sha256": sha(raw), "category": category}
            members.append(member)
            echo = [p["roundTripSeconds"] * 1000 for p in data["pings"]]
            cases = []
            for case in data["cases"]:
                row = {key: case[key] for key in ("id", "status", "expect", "moving", "failures", "inconclusive", "checks")}
                cases.append(row)
                totals.setdefault(category, Counter())[case["status"]] += 1
            reports.append({**member, "testedRevision": data.get("testedRevision"),
                "appliedNetwork": data["appliedNetwork"], "summary": data["summary"],
                "echoRoundTripMs": {"count": len(echo), "min": min(echo), "max": max(echo)},
                "cases": cases})
    result = {"date": "2026-10-16", "scope": "Two genuine moving clients with native movement/combat input; unanchored player-owned roots. All recorded attempts retained, including calibration failures and a rejected visual experiment.",
        "status": "NOT_RELEASE_CERTIFIED", "totalsByCategory": {k: dict(v) for k, v in totals.items()},
        "sourceEvidence": "installed_moving_sources_2026_10_16.json",
        "packageEvidence": "package_moving_2026_10_16.json",
        "reports": reports, "rawArchive": {"file": archive.name, "bytes": archive.stat().st_size,
            "sha256": sha(archive.read_bytes()), "members": members},
        "limits": [
            "Earlier contact gates establish server damage and weighted clips, not necessarily blade/body overlap on both clients. Strict-gate reports retain their actual failures.",
            "Client visual contact is sampled blade centreline versus inflated body oriented boxes, not mesh contact or a human animation review. The strict gate requires contact within 150ms of the server damage timestamp on both clients.",
            "Fast incoming/crossing targets at measured echo RTT around 133-650ms can receive valid server contact without visible contact on the attacker's delayed view. Network rewind and synchronized movement simulation are not implemented.",
            "The rejected root-joint visual offset experiment is archived for diagnosis; its production files were restored before the final runs.",
            "Passing controlled inputs do not certify all avatars, Internet connections, obstacles, slopes, devices or published AnimationId permissions.",
        ]}
    target = ROOT / "tests/moving_pvp_2026_10_16.json"
    target.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({"index": str(target), "archiveBytes": archive.stat().st_size,
        "totalsByCategory": result["totalsByCategory"]}))


if __name__ == "__main__":
    main()
