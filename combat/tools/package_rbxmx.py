"""Build portable Roblox XML instances from Blender-baked joint samples.

This script does not publish assets and never assigns an AnimationId.
Individual KeyframeSequences and the complete import package are generated.
"""
from pathlib import Path
from xml.etree import ElementTree as ET
import json

ROOT = Path(__file__).resolve().parents[2]
COMBAT = ROOT / "combat"
BAKED = COMBAT / "assets/animations/r15/baked"
RIG = json.loads((COMBAT / "assets/blender/rig/R15_joint_schema.json").read_text())
JOINTS = RIG["joints"]
CHILDREN = {}
for joint in JOINTS:
    CHILDREN.setdefault(joint["parent"], []).append(joint["name"])


def item(class_name, name, parent):
    node = ET.SubElement(parent, "Item", {"class": class_name, "referent": "null"})
    props = ET.SubElement(node, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    return node, props


def cframe(props, numbers):
    frame = ET.SubElement(props, "CoordinateFrame", {"name": "CFrame"})
    fields = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    for field, value in zip(fields, numbers):
        ET.SubElement(frame, field).text = str(value)


def pose_node(name, parent, transforms):
    node, props = item("Pose", name, parent)
    cframe(props, [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1] if name == "HumanoidRootPart" else transforms[name])
    for child in CHILDREN.get(name, []):
        pose_node(child, node, transforms)


def sequence_node(data, parent):
    node, props = item("KeyframeSequence", data["name"], parent)
    ET.SubElement(props, "bool", {"name": "Loop"}).text = "true" if data["loop"] else "false"
    # Verified against the connected Studio Enum on 2026-10-13: Idle=0, Action=2.
    ET.SubElement(props, "token", {"name": "Priority"}).text = "0" if data["priority"] == "Idle" else "2"
    markers = {}
    for name, seconds in data["markers"].items():
        frame_number = round(seconds*30)
        markers.setdefault(frame_number, []).append(name)
    for index, frame in enumerate(data["frames"]):
        key, key_props = item("Keyframe", f"Frame_{index:03d}", node)
        ET.SubElement(key_props, "float", {"name": "Time"}).text = str(frame["time"])
        pose_node("HumanoidRootPart", key, frame["poses"])
        for marker_name in markers.get(index, []):
            _, marker_props = item("KeyframeMarker", marker_name, key)
            ET.SubElement(marker_props, "string", {"name": "Value"}).text = ""
    return node


def root():
    node = ET.Element("roblox", {"version": "4"})
    ET.SubElement(node, "External").text = "null"
    ET.SubElement(node, "External").text = "nil"
    return node


def save_xml(node, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(node).write(path, encoding="utf-8", xml_declaration=True)


def script_node(path, class_name, parent):
    node, props = item(class_name, path.name.split(".")[0], parent)
    ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = path.read_text(encoding="utf-8")
    return node


package = root()
bundle, _ = item("Folder", "CombatFoundation_Import", package)
shared, _ = item("Folder", "Shared", bundle)
animations, _ = item("Folder", "Animations", bundle)
server, _ = item("Folder", "Server", bundle)
client, _ = item("Folder", "Client", bundle)
item("RemoteEvent", "CombatRemote", bundle)
for path in sorted((COMBAT / "src/shared").glob("*.luau")):
    script_node(path, "ModuleScript", shared)
for path in sorted((COMBAT / "src/server").glob("*.luau")):
    script_node(path, "Script" if ".server." in path.name else "ModuleScript", server)
for path in sorted((COMBAT / "src/client").glob("*.luau")):
    script_node(path, "LocalScript", client)

for path in sorted(BAKED.glob("*.json")):
    data = json.loads(path.read_text())
    sequence_node(data, animations)
    standalone = root()
    sequence_node(data, standalone)
    if data["name"] == "CombatIdle":
        output = COMBAT / "assets/animations/r15/combat_idle" / (data["name"] + ".rbxmx")
    elif data["name"].startswith("Roll"):
        output = COMBAT / "assets/animations/r15/dodge" / (data["name"] + ".rbxmx")
    else:
        output = COMBAT / "assets/animations/r15/straight_sword" / (data["name"] + ".rbxmx")
    save_xml(standalone, output)
    print("KFS", data["name"], output.stat().st_size)

package_path = COMBAT / "CombatFoundation_Import.rbxmx"
save_xml(package, package_path)
print("PACKAGE", package_path, package_path.stat().st_size)
