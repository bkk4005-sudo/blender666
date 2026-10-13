"""Evaluate the saved source and canonical R15 export; run with Blender -b."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector

combat = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(combat / "assets/blender/animations/StraightSword_R15.blend"))
rig = bpy.data.objects["R15_Combat_Rig"]
prop = bpy.data.objects["Sword motion / paired PROP actions"]
sword = bpy.data.objects["StraightSword_Prototype"]
scene = bpy.context.scene
source = json.loads((combat / "assets/blender/rig/R15_joint_schema.json").read_text())
target = json.loads((combat / "assets/blender/rig/R15_standard_joint_schema.json").read_text())
weapon = json.loads((combat / "assets/weapon/weapon_grip.json").read_text())
axis = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

def matrix(values):
    result = Matrix.Identity(4)
    result.translation = Vector(values[:3])
    for row in range(3):
        for col in range(3): result[row][col] = values[3 + row * 3 + col]
    return result

def converted(value):
    return axis @ value @ axis.inverted()

def mesh_floor(obj, graph):
    evaluated = obj.evaluated_get(graph)
    mesh = evaluated.to_mesh()
    low = min((evaluated.matrix_world @ v.co).z for v in mesh.vertices)
    evaluated.to_mesh_clear()
    return low

def box_floor(frame, size):
    return min((frame @ Vector((x * size[0] / 2, y * size[1] / 2, z * size[2] / 2))).y
               for x in (-1, 1) for y in (-1, 1) for z in (-1, 1))

hand_rest = matrix(next(j["rest"] for j in source["joints"] if j["name"] == "RightHand"))
hand_bone_rest = converted(rig.data.bones["RightHand"].matrix_local)
grip = matrix(weapon["handToHilt"])
target_ground = min(box_floor(matrix(j["rest"]), j["size"]) for j in target["joints"])
report = {}
for path in sorted((combat / "assets/animations/r15/baked").glob("*.json")):
    data = json.loads(path.read_text())
    name = data["name"]
    rig.animation_data.action = bpy.data.actions[name]
    prop.animation_data.action = bpy.data.actions["PROP__" + name]
    body_low, sword_low, grip_error, grip_angle = math.inf, math.inf, 0, 0
    for sample in range(round(data["duration"] * 60) + 1):
        frame = 1 + sample / 2
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        graph = bpy.context.evaluated_depsgraph_get()
        body_low = min(body_low, *(mesh_floor(bpy.data.objects[n], graph) for n in source["bodyNames"]))
        sword_low = min(sword_low, mesh_floor(sword, graph))
        hand = converted(rig.matrix_world @ rig.pose.bones["RightHand"].matrix) @ hand_bone_rest.inverted() @ hand_rest
        expected = hand @ grip
        actual = converted(prop.matrix_world)
        grip_error = max(grip_error, (expected.translation - actual.translation).length)
        grip_angle = max(grip_angle, math.degrees(expected.to_quaternion().rotation_difference(actual.to_quaternion()).angle))
    target_body, target_sword = math.inf, math.inf
    for sample in data["frames"]:
        posed = {"HumanoidRootPart": matrix(target["rootRest"])}
        for joint in target["joints"]:
            n = joint["name"]
            posed[n] = posed[joint["parent"]] @ matrix(joint["c0"]) @ matrix(sample["poses"][n]) @ matrix(joint["c1"]).inverted()
        minimum = min(box_floor(posed[j["name"]], j["size"]) for j in target["joints"])
        blade = posed["RightHand"] @ grip @ Matrix.Translation(Vector((0, 1.195 * 0.68, 0)))
        blade_minimum = box_floor(blade, (1.51340294 * 0.62, 4.71 * 0.68, 0.37736732 * 0.86))
        target_body = min(target_body, minimum - target_ground)
        target_sword = min(target_sword, blade_minimum - target_ground)
        assert minimum >= target_ground + sample["groundClearance"] - 0.0001, name
        assert blade_minimum >= target_ground + 0.003 - 0.0001, name
    report[name] = dict(sourceBodyFloor=body_low, sourceSwordFloor=sword_low,
                        handGripError=grip_error, handGripAngleDegrees=grip_angle,
                        targetBodyClearance=target_body, targetSwordClearance=target_sword)
    print("QA", name, json.dumps(report[name]), flush=True)
(combat / "review").mkdir(exist_ok=True)
(combat / "review/blender_validation.json").write_text(json.dumps(report, indent=2))
assert all(v["handGripError"] < 0.02 and v["handGripAngleDegrees"] < 2 for v in report.values()), "Grip interpolation drift"
assert all(v["sourceBodyFloor"] >= -0.015 and v["sourceSwordFloor"] >= -0.015 for v in report.values()), "Source inter-frame floor penetration"
print("PASS source 60 FPS inspection and canonical R15 FK")
