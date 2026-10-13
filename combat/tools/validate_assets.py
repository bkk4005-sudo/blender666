"""Validate baked R15 clips against the portable KeyframeSequence XML."""
from pathlib import Path
from xml.etree import ElementTree as ET
import json
import math

combat = Path(__file__).resolve().parents[1]
schema = json.loads((combat / "assets/blender/rig/R15_joint_schema.json").read_text())
joint_names = {"HumanoidRootPart", *(joint["name"] for joint in schema["joints"])}
package = ET.parse(combat / "CombatFoundation_Import.rbxmx").getroot()
packaged = {node.find("./Properties/string[@name='Name']").text: node
            for node in package.iter("Item") if node.attrib.get("class") == "KeyframeSequence"}
clips = {}


def sequence_data(node):
    frames = []
    markers = {}
    ground_clearances = []
    for key in node.findall("./Item[@class='Keyframe']"):
        time = float(key.find("./Properties/float[@name='Time']").text)
        poses = {pose.find("./Properties/string[@name='Name']").text
                 for pose in key.iter("Item") if pose.attrib.get("class") == "Pose"}
        assert poses == joint_names, f"R15 pose mismatch at {time}: {poses ^ joint_names}"
        frames.append(time)
        clearance_node = key.find("./Item[@class='NumberValue']/Properties/double[@name='Value']")
        assert clearance_node is not None, "grounding metadata missing"
        ground_clearances.append(float(clearance_node.text))
        for marker in key.findall("./Item[@class='KeyframeMarker']"):
            name = marker.find("./Properties/string[@name='Name']").text
            assert name not in markers, f"duplicate marker {name}"
            markers[name] = time
    return frames, markers, ground_clearances


for path in sorted((combat / "assets/animations/r15/baked").glob("*.json")):
    data = json.loads(path.read_text())
    name = data["name"]
    clips[name] = data
    assert data["exportProfile"] == "R15Standard" and data["sampleRate"] == 60
    folder = "combat_idle" if name == "CombatIdle" else "dodge" if name.startswith("Roll") else "straight_sword"
    xml_path = combat / "assets/animations/r15" / folder / f"{name}.rbxmx"
    root = ET.parse(xml_path).getroot()
    nodes = [node for node in root.findall("Item") if node.attrib.get("class") == "KeyframeSequence"]
    assert len(nodes) == 1 and name in packaged, f"missing sequence {name}"
    for node in [nodes[0], packaged[name]]:
        frames, markers, ground_clearances = sequence_data(node)
        assert len(frames) == len(data["frames"]), f"frame count mismatch {name}"
        assert all(math.isclose(a, b["time"], abs_tol=1e-5) for a, b in zip(frames, data["frames"])), f"frame time mismatch {name}"
        assert all(math.isclose(a, b["groundClearance"], abs_tol=1e-7)
                   for a, b in zip(ground_clearances, data["frames"])), f"grounding metadata mismatch {name}"
        assert set(markers) == set(data["markers"]), f"marker set mismatch {name}"
        assert all(math.isclose(markers[key], value, abs_tol=1 / 60 + 1e-5)
                   for key, value in data["markers"].items()), f"marker time mismatch {name}"
        token = node.find("./Properties/token[@name='Priority']").text
        assert token == ("0" if data["priority"] == "Idle" else "2"), f"priority mismatch {name}"
    print(f"PASS {name}: {len(data['frames'])} frames, {len(data['markers'])} markers")

assert len(packaged) == 8, "unexpected package clip count"
print("PASS portable package structure")

def pose_difference(a, b):
    return max(abs(x - y) for name in a for x, y in zip(a[name], b[name]))

chain_sample = round(0.7 * clips["SwordR1_1"]["sampleRate"])
chain_error = pose_difference(clips["SwordR1_1"]["frames"][chain_sample]["poses"],
                              clips["SwordR1_2"]["frames"][0]["poses"])
assert chain_error < 0.002, f"R1 chain seam mismatch: {chain_error}"
idle_pose = clips["CombatIdle"]["frames"][0]["poses"]
for name, clip in clips.items():
    assert pose_difference(clip["frames"][-1]["poses"], idle_pose) < 0.002, f"Recovery seam mismatch: {name}"
print(f"PASS R1 chain and recovery seams: chain max component difference {chain_error:.7f}")

test_sword = ET.parse(combat / "assets/weapon/CombatTestSwordScript.rbxmx").getroot()
script_nodes = [node for node in test_sword.findall("Item") if node.attrib.get("class") == "Script"]
assert len(script_nodes) == 1, "test sword script missing"
embedded_source = script_nodes[0].find("./Properties/ProtectedString[@name='Source']").text
assert embedded_source == (combat / "tools/CombatTestSword.server.luau").read_text(encoding="utf-8")
print("PASS test sword script package")
