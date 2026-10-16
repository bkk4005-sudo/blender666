"""Compact real Studio telemetry; does not execute or certify a multiplayer test.

Usage: python combat/tools/analyse_pvp.py raw.json [more.json ...] --output-dir combat/tests
Input sampling is normally 50-67 ms; continuity counts describe sampled frames,
not every rendered frame. Raw data and its SHA256 remain the primary evidence.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import statistics

COMBAT = Path(__file__).resolve().parents[1]


def number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def percentile(values, fraction):
    ordered = sorted(values)
    index = (len(ordered) - 1) * fraction
    lo, hi = math.floor(index), math.ceil(index)
    return ordered[lo] + (ordered[hi] - ordered[lo]) * (index - lo)


def distribution(values):
    values = [float(v) for v in values if number(v)]
    if not values:
        return {"count": 0}
    return {"count": len(values), "minMs": round(min(values) * 1000, 3),
            "medianMs": round(statistics.median(values) * 1000, 3),
            "maxMs": round(max(values) * 1000, 3),
            "p95AbsMs": round(percentile([abs(v) for v in values], .95) * 1000, 3),
            "maxAbsMs": round(max(abs(v) for v in values) * 1000, 3)}


def project_timings():
    data = json.loads((COMBAT / "config/action_pacing.json").read_text(encoding="utf-8"))
    fps = data["authoringFPS"]
    return data["version"], {name: {"duration": clip["durationFrame"] / fps,
        **{key: [v / fps for v in value] if isinstance(value, list) else value / fps
           for key, value in clip.get("runtimeFrames", {}).items()}}
        for name, clip in data["clips"].items()}


def native_kind(name):
    if name == "SwordR1_1":
        return "R1"
    if name == "SwordR2":
        return "R2"
    if name.startswith("Roll"):
        return "Roll"
    return name


def identities(clients, real_players):
    names, normalized = {}, {}
    for key, client in clients.items():
        actor = str(client.get("userId", key))
        normalized[actor] = client
        names[key] = actor
        if client.get("player"):
            names[client["player"]] = actor
    for player in real_players:
        names[player["name"]] = str(player["userId"])
    return names, normalized


def accepted_actions(case, names, clients):
    rows, by_key = [], {}
    for source in case.get("started", []):
        actor = str(source.get("userId", names.get(source.get("owner", ""), source.get("owner", ""))))
        name, started = source.get("action", source.get("name")), source.get("started")
        if not name or not number(started):
            continue
        row = {"actor": actor, "name": name, "started": started,
               "serverRecord": source, "evidence": "server start instrumentation", "deliveries": {}}
        rows.append(row)
        by_key[(actor, name, started)] = row
    # Reactions can bypass start(); their genuine server RemoteEvent payload is
    # still evidence. Include every new serial instead of silently dropping it.
    for client_id, client in clients.items():
        for event in client.get("events", []):
            if event.get("event") != "Started" or not number(event.get("started")):
                continue
            actor = names.get(str(event.get("owner")), str(event.get("owner")))
            key = (actor, event.get("name"), event["started"])
            row = by_key.get(key)
            if row is None:
                row = {"actor": actor, "name": event.get("name"), "started": event["started"],
                       "evidence": "server Started payload observed on real client; no start wrapper record",
                       "deliveries": {}}
                rows.append(row)
                by_key[key] = row
            row["deliveries"][client_id] = event
            for field in ("serial", "sequence", "character"):
                if field in event:
                    row[field] = event[field]
    return sorted(rows, key=lambda row: (row["started"], row["actor"]))


def termination(case, row, actions, timing):
    duration = timing.get(row["name"], {}).get("duration")
    if duration is None:
        return None, "duration_unavailable", False
    end, reason = row["started"] + duration, "natural_duration"
    for other in actions:
        if other["actor"] == row["actor"] and row["started"] < other["started"] < end:
            end, reason = other["started"], "superseded_by_" + str(other["name"])
    deaths = [d["at"] for d in case.get("deaths", []) if str(d.get("userId")) == row["actor"] and number(d.get("at"))]
    deaths += [e["at"] for e in case.get("healthEvents", [])
               if str(e.get("userId")) == row["actor"] and number(e.get("at"))
               and number(e.get("after")) and e["after"] <= 0]
    for died in deaths:
        if row["started"] <= died < end:
            end, reason = died, "death_interrupted"
    if number(case.get("t0")) and number(case.get("duration")):
        observed_end = case["t0"] + case["duration"]
        if observed_end < end:
            return observed_end, "observation_ended", True
    return end, reason, False


def aggregate_contacts(rows):
    grouped = {}
    for row in rows:
        key = (str(row.get("attackerUserId")), str(row.get("targetUserId", row.get("targetKey"))),
               row.get("action"), row.get("started"), row.get("defenderAction"), row.get("returned"))
        entry = grouped.setdefault(key, {"attacker": key[0], "target": key[1], "action": key[2],
            "started": key[3], "defenderAction": key[4], "returned": key[5], "count": 0,
            "firstAt": row.get("at"), "lastAt": row.get("at"), "defenderElapsed": []})
        entry["count"] += 1
        if number(row.get("at")):
            entry["lastAt"] = max(entry["lastAt"], row["at"]) if number(entry["lastAt"]) else row["at"]
        if number(row.get("defenderElapsed")):
            entry["defenderElapsed"].append(row["defenderElapsed"])
    result = []
    for entry in grouped.values():
        elapsed = entry.pop("defenderElapsed")
        if elapsed:
            entry["defenderElapsedRangeSeconds"] = [min(elapsed), max(elapsed)]
        result.append(entry)
    return result


def associate_plays(actions, clients):
    mapped, unassigned = defaultdict(list), defaultdict(list)
    for actor, client in clients.items():
        for play in client.get("playEvents", []):
            at, name = play.get("at"), play.get("name")
            if not number(at):
                unassigned[actor].append(play)
                continue
            candidates = [r for r in actions if r["actor"] == actor and r["name"] == name]
            previous = [r for r in candidates if r["started"] <= at and r.get("windowEnd") is not None and at <= r["windowEnd"]]
            # Predictions begin before server receipt; native commands identify
            # that lead. Do not attribute a new request to the old clip's fade.
            commands = [c for c in client.get("inputs", []) if c.get("ok") is not False and number(c.get("at"))
                        and 0 <= at - c["at"] <= .15 and native_kind(name) == native_kind(c.get("action", ""))]
            future = [r for r in candidates if r["started"] > at]
            selected = max(previous, key=lambda r: r["started"]) if previous else None
            if future and commands:
                command_at = max(c["at"] for c in commands)
                if selected is None or command_at > selected["started"] + .15:
                    selected = min(future, key=lambda r: r["started"])
            if selected is None and len(candidates) == 1 and at < candidates[0]["started"]:
                selected = candidates[0]
            if selected is None:
                unassigned[actor].append(play)
            else:
                mapped[id(selected)].append(play)
    return mapped, dict(unassigned)


def sampled_presentation(row, client, role, timing):
    end = row["windowEnd"]
    delivery = row["deliveries"].get(row["actor"] if role == "owner" else client["_id"])
    receipt = delivery.get("at") if delivery else None
    offsets, settled, gaps, backsteps = [], [], [], []
    selected_samples = []
    first_weighted, maximum_concurrent, previous = None, 0, None
    competing, speeds = Counter(), []
    side = "own" if role == "owner" else "peer"
    action_ids = {t.get("id") for s in client.get("samples", [])
                  if number(s.get("at")) and end is not None and row["started"] <= s["at"] < end
                  for t in s.get(side, []) if t.get("name") == row["name"] and t.get("id")}
    if role == "owner":
        action_ids.update(p.get("id") for p in row.get("ownerPlayEvents", []) if p.get("id"))
    duplicate_ids, alias_names = {}, Counter()
    maximum_same_id, duplicate_samples = 0, 0
    for sample in client.get("samples", []):
        at = sample.get("at")
        if not number(at) or end is None or not row["started"] <= at < end:
            continue
        weighted = [t for t in sample.get(side, []) if number(t.get("weight")) and t["weight"] > .05]
        # Native replicas can be named "Animation" while our preview track has
        # the semantic name. Count exact-ID duplicates BEFORE any name filter.
        by_id = defaultdict(list)
        for track in weighted:
            if track.get("id"):
                by_id[track["id"]].append(track)
        duplicated = False
        for asset_id, same_id in by_id.items():
            maximum_same_id = max(maximum_same_id, len(same_id))
            if len(same_id) > 1:
                duplicated = True
                group = duplicate_ids.setdefault(asset_id, {"id": asset_id, "sampleCount": 0,
                    "maximumConcurrent": 0, "names": {}, "firstAt": at, "lastAt": at})
                group["sampleCount"] += 1
                group["maximumConcurrent"] = max(group["maximumConcurrent"], len(same_id))
                group["lastAt"] = at
                for track in same_id:
                    name = str(track.get("name"))
                    group["names"][name] = group["names"].get(name, 0) + 1
        duplicate_samples += duplicated
        tracks = [t for t in weighted if t.get("name") == row["name"] or t.get("id") in action_ids]
        for track in tracks:
            if track.get("name") != row["name"]:
                alias_names[str(track.get("name"))] += 1
        maximum_concurrent = max(maximum_concurrent, len(tracks))
        after_receipt = receipt is not None and at >= receipt + .05
        if not tracks and after_receipt:
            gaps.append(at)
        if tracks:
            first_weighted = at if first_weighted is None else first_weighted
            # Report all visible competing clips; priority determines whether
            # a foreign clip could override an Action4 roll.
            for other in weighted:
                if other.get("name") != row["name"] and other.get("id") not in action_ids:
                    competing[str(other.get("name")) + ":" + str(other.get("priority"))] += 1
            primary = max(tracks, key=lambda track: track["weight"])
            if previous and primary.get("id") == previous["id"] and primary["time"] < previous["time"] - .01:
                backsteps.append({"at": at, "seconds": previous["time"] - primary["time"]})
            previous = primary
        for track in tracks:
            if number(track.get("time")):
                offset = track["time"] - (at - row["started"])
                if receipt is not None and at >= receipt:
                    offsets.append(offset)
                    if at >= receipt + .5:
                        settled.append(offset)
            if number(track.get("speed")):
                speeds.append(track["speed"])
        selected_samples.append(sample)
    result = {"client": client["_id"], "role": role, "sampleCountInAcceptedWindow": len(selected_samples),
        "weightedSampleCount": sum(bool([t for t in s.get(side, [])
            if (t.get("name") == row["name"] or t.get("id") in action_ids) and t.get("weight", 0) > .05]) for s in selected_samples),
        "phaseTrackMinusServer": distribution(offsets), "phaseAfterAckPlus500ms": distribution(settled),
        "maxConcurrentWeightedSameClip": maximum_concurrent, "missingSamplesAfterReceiptPlus50ms": len(gaps),
        "timeBackstepsOver10ms": backsteps, "competingWeightedClips": dict(competing)}
    result.update(maxConcurrentWeightedSameAssetId=maximum_same_id,
        exactAssetIdDuplicateSampleCount=duplicate_samples,
        exactAssetIdDuplicates=list(duplicate_ids.values()), nativeAliasTrackNames=dict(alias_names))
    if duplicate_samples and backsteps:
        result["backstepScope"] = "Primary track selection is ambiguous when multiple same-ID tracks have different positions; no unique track-instance identity was captured."
    if receipt is not None:
        result["startedDeliveryMs"] = round((receipt - row["started"]) * 1000, 3)
    if first_weighted is not None:
        result["firstWeightedSampleAfterServerMs"] = round((first_weighted - row["started"]) * 1000, 3)
    if gaps:
        result["missingSampleAtRange"] = [min(gaps), max(gaps)]
    if speeds:
        result["observedSpeedRange"] = [min(speeds), max(speeds)]
    if row["name"].startswith("Roll"):
        result["rollContinuityScope"] = "Sampled accepted roll after event delivery; clipped at death/reaction/next action. Not every rendered frame."
        result["possibleAction4OverrideSamples"] = sum(v for k, v in competing.items() if k.endswith(":Action4"))
    return result


def compact_case(case, real_players, timing):
    names, clients = identities(case.get("clients", {}), real_players)
    actions = accepted_actions(case, names, clients)
    for row in actions:
        row["windowEnd"], row["endReason"], row["windowCensored"] = termination(case, row, actions, timing)
    plays, unassigned = associate_plays(actions, clients)
    analysis = []
    for row in actions:
        own = clients.get(row["actor"])
        row["ownerPlayEvents"] = plays.get(id(row), [])
        row["ownerPlayCount"] = len(row["ownerPlayEvents"])
        row["additionalOwnerPlays"] = max(0, row["ownerPlayCount"] - 1)
        row["ownerPlaybackClassification"] = ("death_interrupted" if row["endReason"] == "death_interrupted"
            else "observation_censored" if row["windowCensored"] else "duplicate_plays" if row["additionalOwnerPlays"]
            else "single_play" if row["ownerPlayCount"] else "no_recorded_play")
        if own:
            kind = native_kind(row["name"])
            commands = [c for c in own.get("inputs", []) if native_kind(c.get("action", "")) == kind]
            if row["ownerPlayEvents"] and commands and row["name"] != "SwordR1_2":
                play_at = row["ownerPlayEvents"][0]["at"]
                preceding = [c["at"] for c in commands if number(c.get("at")) and c["at"] <= play_at]
                if preceding:
                    row["inputToFirstPlayMs"] = round((play_at - max(preceding)) * 1000, 3)
        row["presentation"] = []
        for actor, client in clients.items():
            client = {**client, "_id": actor}
            row["presentation"].append(sampled_presentation(row, client, "owner" if actor == row["actor"] else "observer", timing))
        analysis.append(row)
    damages = case.get("damageAttempts", [])
    positive = [r for r in damages if number(r.get("before")) and number(r.get("after")) and r["after"] < r["before"]]
    rejected = [r for r in damages if r.get("returned") is False]
    no_loss = [r for r in damages if r.get("returned") is True and r not in positive]
    keep = ("id", "label", "status", "expect", "checks", "failures", "inconclusive", "instrumentationErrors",
            "setup", "t0", "duration", "inputs", "received", "started", "pings", "finalHealth", "healthEvents",
            "deaths", "lethalFrames", "lifecycle", "cleanup", "respawn", "restored", "moving")
    result = {key: case[key] for key in keep if key in case}
    result.update(positiveDamage=positive, rejectedContacts=aggregate_contacts(rejected),
        acceptedNoHealthLoss=aggregate_contacts(no_loss), acceptedActionAnalysis=analysis,
        unassignedOwnerPlayEvents=unassigned)
    result["clients"] = {actor: {key: client[key] for key in (
        "userId", "player", "received", "t0", "inputs", "playEvents", "peerPlayEvents", "events", "logs", "error",
        "healthEvents", "startPosition", "endPosition", "finalState", "restored", "lifecycle", "cleanup", "bindingEvents", "animationFrames") if key in client}
        for actor, client in clients.items()}
    return result


def analyse(path):
    raw_bytes = path.read_bytes()
    raw = json.loads(raw_bytes)
    version, timing = project_timings()
    real_players = raw.get("realPlayers", [])
    cases = raw.get("cases", [raw])
    keep = ("kind", "completed", "summary", "errors", "scope", "authority", "realPlayers", "lagLabel", "network", "requests",
            "configuredNetwork", "appliedNetwork", "pacingVersion", "ready", "pings", "finishedAt", "lifecycle", "cleanup", "health")
    result = {key: raw[key] for key in keep if key in raw}
    result["analysis"] = {"rawFile": str(path.resolve()), "rawSha256": hashlib.sha256(raw_bytes).hexdigest(),
        "timingReference": "combat/config/action_pacing.json", "timingReferenceVersion": version,
        "timingVersionMatchesRaw": raw.get("pacingVersion") == version if raw.get("pacingVersion") else "UNRECORDED",
        "testedRevision": raw.get("testedRevision", raw.get("commit", "UNRECORDED")),
        "scope": "Analysis of recorded real telemetry. Original test statuses retained; analysis does not create new PASS claims.",
        "phaseDefinition": "Visible track (weight >0.05) TimePosition minus sample server-clock elapsed, at/after that client's Started receipt and within the accepted action interval; positive means visual lead. Multiple visible tracks are reported individually, not averaged by weight.",
        "settlingScope": "Separate metrics after received Started +500ms; empty windows do not prove settling.",
        "missingTrackScope": "Missing-track counts begin at Started receipt +50ms. Zero does not claim that the observer rendered the action before its delayed Started packet arrived, or that owner prediction had no anticipation hold.",
        "samplingLimit": "Phase/continuity telemetry is normally 50-67ms; gaps count samples, not every rendered frame. When present, animationFrames independently checks same-ID duplicates at each PreSimulation after animation evaluation; it does not contain per-frame poses. Client playEvents record the owner's Animator unless peerPlayEvents is explicitly present.",
        "deathScope": "Intervals stop at actual HP0/death or newer accepted action; early death is not a missing full-length clip failure."}
    result["echoRoundTrip"] = distribution([p.get("roundTripSeconds") for p in raw.get("pings", [])])
    result["cases"] = [compact_case(c, real_players, timing) for c in cases]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", nargs="+", type=Path)
    parser.add_argument("--output-dir", type=Path, help="Default: each input's directory")
    args = parser.parse_args()
    for source in args.raw:
        result = analyse(source)
        directory = args.output_dir or source.parent
        directory.mkdir(parents=True, exist_ok=True)
        target = directory / (source.stem + "_summary.json")
        target.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
        duplicates = sum(a["additionalOwnerPlays"] for c in result["cases"] for a in c["acceptedActionAnalysis"])
        print(json.dumps({"input": str(source), "output": str(target), "cases": len(result["cases"]),
            "recordedTestSummary": result.get("summary"), "additionalOwnerPlays": duplicates}, ensure_ascii=False))


if __name__ == "__main__":
    main()
