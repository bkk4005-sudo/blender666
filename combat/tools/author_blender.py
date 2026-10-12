"""Author original straight-sword R15 Actions in Blender 5.2.

Run: blender -b --python combat/tools/author_blender.py
The existing official-template R15 mannequin is a rig donor; its file is read-only.
Outputs a separate editable .blend and baked joint samples for Roblox conversion.
This is a first animation pass, not a claim of final visual polish.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion, Euler

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "combat"
SOURCE = ROOT / "AshenColiseum" / "Weapons" / "AshenGreatsword" / "AshenOath_R15.blend"
OUT_BLEND = HERE / "assets" / "blender" / "animations" / "StraightSword_R15.blend"
OUT_DATA = HERE / "assets" / "animations" / "r15" / "baked"
OUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
OUT_DATA.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
scene.render.fps = 30
rig = bpy.data.objects["R15_AshenOath"]
prop = bpy.data.objects["Sword motion / paired PROP actions"]
sword = bpy.data.objects["AshenOath_Greatsword"]
sword.name = "StraightSword_Prototype"
sword.scale.x = 0.62
sword.scale.y = 0.86
sword.scale.z = 0.68
sword["status"] = "Original straight-sword training prop; visual refinement pending."
rig.name = "R15_Combat_Rig"

for ob in [rig, prop]:
    ob.animation_data_create()
    ob.animation_data.action = None
    for track in list(ob.animation_data.nla_tracks):
        ob.animation_data.nla_tracks.remove(track)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

REST = {b.name: b.matrix_local.copy() for b in rig.data.bones}
HEAD = {b.name: b.head_local.copy() for b in rig.data.bones}
TAIL = {b.name: b.tail_local.copy() for b in rig.data.bones}
PARENT = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
ORDER = [b.name for b in rig.data.bones]
LOCAL = {n: REST[PARENT[n]].inverted() @ REST[n] if PARENT[n] else REST[n] for n in ORDER}
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
rig.rotation_mode = "QUATERNION"
prop.rotation_mode = "QUATERNION"

BASE = {
    "p": (-0.10, -0.82, 4.08), "angles": (23, -18, 8),
    "body": (6, 0, -8), "pelvis": (0, 0, 0), "root": (0, 0, -0.19),
    "lf": (0.64, -0.28, 0), "rf": (-0.65, 0.38, 0),
    "footyaw": (-8, 6), "head": (-4, 0, 5), "left_hand": (0.40, -0.18, -1.15),
}


def pose(**changes):
    value = BASE.copy()
    value.update(changes)
    return value


NEUTRAL = pose()
R1_WIND = pose(p=(-0.65, -0.30, 4.43), angles=(66, -91, -12),
               body=(-2, 0, -22), pelvis=(0, 0, -11), root=(-0.05, 0.09, -0.29))
R1_CONTACT = pose(p=(0.14, -1.13, 4.08), angles=(93, 20, 8),
                  body=(14, 0, 15), pelvis=(1, 0, 9), root=(0.04, -0.16, -0.30),
                  lf=(0.64, -0.55, 0))
R1_END = pose(p=(0.53, -0.63, 3.95), angles=(113, 91, 22),
              body=(12, 0, 27), pelvis=(0, 0, 13), root=(0.07, -0.12, -0.27),
              lf=(0.64, -0.55, 0))
R2_WIND = pose(p=(-0.28, -0.22, 5.08), angles=(-44, -29, -4),
               body=(-12, 0, -24), pelvis=(-3, 0, -14), root=(-0.07, 0.11, -0.40),
               rf=(-0.65, 0.45, 0))
R2_CONTACT = pose(p=(0.02, -1.20, 4.10), angles=(100, 8, 3),
                  body=(22, 0, 14), pelvis=(5, 0, 11), root=(0.03, -0.27, -0.44),
                  lf=(0.64, -0.70, 0))
R2_END = pose(p=(0.20, -1.03, 3.54), angles=(150, 12, 2),
              body=(27, 0, 17), pelvis=(6, 0, 13), root=(0.05, -0.21, -0.43),
              lf=(0.64, -0.70, 0))

# Original R15 medium-roll reconstruction. The inspected DS3 footage did not
# expose reliable source frames for a roll, so these are authored project poses.
ROLL_CROUCH = pose(root=(0, 0, -0.62), body=(37, 0, -10), pelvis=(18, 0, -6),
                   lf=(0.54, 0.00, 0), rf=(-0.54, 0.00, 0),
                   p=(-0.16, -0.60, 3.56), angles=(90, 90, 0),
                   left_hand=(0.18, -0.45, -0.48), head=(16, 0, 0))
ROLL_TUCK = pose(root=(0, 0, -0.73), body=(67, 0, -12), pelvis=(34, 0, -8),
                 lf=(0.35, 0.08, 1.48), rf=(-0.35, 0.08, 1.48),
                 p=(-0.05, -0.46, 3.30), angles=(90, 90, 0),
                 left_hand=(0.10, -0.48, -0.28), head=(28, 0, 0))


def roll_clip(name, axis):
    # Keep the blade approximately parallel to the roll axis while inverted.
    blade_yaw = math.degrees(math.atan2(axis[0], -axis[1]))
    def at(t, posture, angle):
        value = posture.copy()
        if 0 < t < 25:
            value["angles"] = (90, blade_yaw, 0)
        value["tumble"] = angle
        return (t / 30, value)
    return dict(name=name, duration=25 / 30, loop=False, priority="Action",
                axis=axis, markers={"IFrameStart": 5 / 30,
                                    "IFrameEnd": 16 / 30,
                                    "RecoveryEnd": 25 / 30},
                keys=[at(0, NEUTRAL, 0), at(2, ROLL_CROUCH, 0),
                      at(4, ROLL_CROUCH, 18), at(6, ROLL_TUCK, 58),
                      at(9, ROLL_TUCK, 112), at(12, ROLL_TUCK, 177),
                      at(15, ROLL_TUCK, 242), at(18, ROLL_CROUCH, 302),
                      at(21, ROLL_CROUCH, 348), at(25, NEUTRAL, 360)])

CLIPS = [
    dict(name="CombatIdle", duration=2.0, loop=True, priority="Idle", markers={},
         keys=[(0, NEUTRAL), (0.5, pose(body=(7, 0, -8), p=(-0.10, -0.82, 4.10))),
               (1, pose(body=(6, 0, -8), p=(-0.10, -0.82, 4.08))),
               (1.5, pose(body=(5, 0, -8), p=(-0.10, -0.82, 4.06))), (2, NEUTRAL)]),
    dict(name="SwordR1_1", duration=28/30, loop=False, priority="Action",
         markers={"AttackStart": 0, "HitStart": 9/30, "HitEnd": 14/30,
                  "ComboOpen": 16/30, "ComboClose": 22/30, "RecoveryEnd": 28/30},
         keys=[(0, NEUTRAL), (0.08, pose(body=(4, 0, -12))),
               (0.16, R1_WIND), (0.23, R1_WIND),
               (0.30, pose(p=(-0.40, -0.86, 4.28), angles=(83, -48, -6),
                           body=(6, 0, -6), pelvis=(0, 0, -3), root=(0, -0.05, -0.32))),
               (0.38, R1_CONTACT), (0.46, R1_END), (0.70, R1_END),
               (28/30, NEUTRAL)]),
    dict(name="SwordR1_2", duration=29/30, loop=False, priority="Action",
         markers={"AttackStart": 0, "HitStart": 8/30, "HitEnd": 14/30,
                  "ComboOpen": 16/30, "ComboClose": 23/30, "RecoveryEnd": 29/30},
         keys=[(0, R1_END), (0.09, pose(p=(0.68, -0.41, 4.12), angles=(72, 115, 25),
                                      body=(2, 0, 31), pelvis=(0, 0, 13))),
               (0.18, pose(p=(0.67, -0.32, 4.31), angles=(70, 124, 28),
                           body=(0, 0, 37), pelvis=(0, 0, 17), root=(0.08, 0.02, -0.29))),
               (0.27, pose(p=(0.31, -0.93, 4.15), angles=(87, 55, 12),
                           body=(9, 0, 13), pelvis=(0, 0, 5), root=(0, -0.07, -0.31))),
               (0.36, pose(p=(-0.30, -1.05, 3.97), angles=(98, -40, -11),
                           body=(13, 0, -20), pelvis=(0, 0, -8), root=(-0.05, -0.16, -0.31))),
               (0.45, pose(p=(-0.62, -0.46, 3.98), angles=(109, -108, -20),
                           body=(9, 0, -30), pelvis=(0, 0, -15), root=(-0.07, -0.11, -0.27))),
               (0.62, pose(p=(-0.60, -0.48, 4.00), angles=(104, -101, -16),
                           body=(8, 0, -22))), (29/30, NEUTRAL)]),
    dict(name="SwordR2", duration=43/30, loop=False, priority="Action",
         markers={"AttackStart": 0, "HitStart": 17/30, "HitEnd": 25/30,
                  "RecoveryEnd": 43/30},
         keys=[(0, NEUTRAL), (0.14, pose(root=(0, 0, -0.34), body=(0, 0, -13))),
               (0.32, R2_WIND), (0.47, R2_WIND),
               (0.58, pose(p=(-0.18, -0.63, 5.02), angles=(15, -8, 0),
                           body=(3, 0, -8), pelvis=(0, 0, -4), root=(0, -0.09, -0.41))),
               (0.69, R2_CONTACT), (0.82, R2_END), (1.06, R2_END),
               (1.25, pose(p=(0.07, -0.89, 3.88), angles=(110, 8, 2),
                           body=(11, 0, 5), root=(0, -0.06, -0.29))), (43/30, NEUTRAL)]),
    roll_clip("RollForward", (0.87, -0.49, 0)),
    roll_clip("RollBackward", (-0.87, 0.49, 0)),
    roll_clip("RollLeft", (0.57, -0.82, 0)),
    roll_clip("RollRight", (0.57, 0.82, 0)),
]


def transform(rot, pos):
    m = rot.to_matrix().to_4x4() if isinstance(rot, Quaternion) else rot.to_4x4()
    m.translation = Vector(pos)
    return m


def orient_bone(name, a, b):
    y = (b-a).normalized()
    rest_y = (TAIL[name]-HEAD[name]).normalized()
    q = rest_y.rotation_difference(y) @ REST[name].to_quaternion()
    return transform(q, a)


def two_bone_joint(a, target, length1, length2, pole):
    delta = target-a
    distance = delta.length
    direction = delta.normalized()
    clamped = min(max(distance, 0.03), length1+length2-0.002)
    pole = Vector(pole)
    lateral = pole - direction*pole.dot(direction)
    if lateral.length < 0.01:
        lateral = Vector((0, 1, 0))-direction*direction.y
    lateral.normalize()
    x = (length1*length1-length2*length2+clamped*clamped)/(2*clamped)
    h = math.sqrt(max(0, length1*length1-x*x))
    return a+direction*x+lateral*h, distance-(length1+length2)


max_leg_extension = 0
max_grip_error = 0


def pose_at(p):
    global max_leg_extension, max_grip_error
    desired = {}
    root_position = Vector((0, 0, 3.13)) + Vector(p["root"])
    lower_rotation = Euler(tuple(math.radians(v) for v in p["pelvis"]), "XYZ").to_matrix()
    upper_rotation = Euler(tuple(math.radians(v) for v in p["body"]), "XYZ").to_matrix()
    desired["Root"] = REST["Root"].copy()
    desired["HumanoidRootNode"] = REST["HumanoidRootNode"].copy()
    desired["LowerTorso"] = transform(lower_rotation @ REST["LowerTorso"].to_3x3(), root_position)
    upper_head = desired["LowerTorso"] @ REST["LowerTorso"].inverted() @ HEAD["UpperTorso"]
    desired["UpperTorso"] = transform(upper_rotation @ REST["UpperTorso"].to_3x3(), upper_head)
    head_position = desired["UpperTorso"] @ REST["UpperTorso"].inverted() @ HEAD["Head"]
    head_rotation = Euler(tuple(math.radians(v) for v in p["head"]), "XYZ").to_matrix()
    desired["Head"] = transform(head_rotation @ REST["Head"].to_3x3(), head_position)
    pitch, yaw, roll = p["angles"]
    sword_rotation = (Quaternion((0, 0, 1), math.radians(yaw))
                      @ Quaternion((1, 0, 0), math.radians(pitch))
                      @ Quaternion((0, 0, 1), math.radians(roll)))
    grip = Vector(p["p"])
    sword_matrix = transform(sword_rotation, grip)
    shoulders = {side: desired["UpperTorso"] @ REST["UpperTorso"].inverted() @ HEAD[side+"UpperArm"]
                 for side in ("Right", "Left")}
    sword_basis = sword_rotation.to_matrix()
    for side, sign in (("Right", -1), ("Left", 1)):
        wrist = grip+sword_basis @ Vector((0, 0.20, 0 if side == "Right" else -0.53))
        if side == "Left":
            wrist = shoulders[side]+Vector(p["left_hand"])
        a = shoulders[side]
        upper, lower, hand = side+"UpperArm", side+"LowerArm", side+"Hand"
        elbow, _ = two_bone_joint(a, wrist, (TAIL[upper]-HEAD[upper]).length,
                         (TAIL[lower]-HEAD[lower]).length, (sign*0.9, 0.20, -0.55))
        desired[upper] = orient_bone(upper, a, elbow)
        desired[lower] = orient_bone(lower, elbow, wrist)
        hand_rotation = sword_basis @ Matrix.Diagonal((1, -1, -1))
        desired[hand] = transform(hand_rotation, wrist) if side == "Right" else orient_bone(
            hand, wrist, wrist+Vector((0, -0.25, -0.1)))
        if side == "Right":
            max_grip_error = max(max_grip_error,
                                 (desired[hand] @ Vector((0, 0.20, 0))-grip).length)
    for side, key, index in (("Left", "lf", 0), ("Right", "rf", 1)):
        upper, lower, foot_name = side+"UpperLeg", side+"LowerLeg", side+"Foot"
        hip = desired["LowerTorso"] @ REST["LowerTorso"].inverted() @ HEAD[upper]
        foot = Vector(p[key]); foot.z += HEAD[foot_name].z
        ankle = foot + (TAIL[lower]-HEAD[foot_name])
        knee, over = two_bone_joint(hip, ankle, (TAIL[upper]-HEAD[upper]).length,
                           (TAIL[lower]-HEAD[lower]).length, (0, -1, 0.04))
        max_leg_extension = max(max_leg_extension, over)
        desired[upper] = orient_bone(upper, hip, knee)
        desired[lower] = orient_bone(lower, knee, ankle)
        foot_rotation = Quaternion((0, 0, 1), math.radians(p["footyaw"][index])) @ REST[foot_name].to_quaternion()
        desired[foot_name] = transform(foot_rotation, foot)
    for name in ORDER:
        parent = PARENT[name]
        local = desired[parent].inverted() @ desired[name] if parent else desired[name]
        rig.pose.bones[name].matrix_basis = LOCAL[name].inverted() @ local
    prop.matrix_world = sword_matrix


def interpolate(a, b, fraction):
    eased = fraction*fraction*(3-2*fraction)
    return {k: tuple(x+(y-x)*eased for x, y in zip(a[k], b[k]))
            if isinstance(a[k], tuple) else a[k]+(b[k]-a[k])*eased for k in a}


def sample(keys, t):
    for (ta, a), (tb, b) in zip(keys, keys[1:]):
        if ta <= t <= tb:
            return interpolate(a, b, (t-ta)/(tb-ta))
    return keys[-1][1]


AXIS = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def converted(matrix):
    return AXIS @ matrix @ AXIS.inverted()


def cframe(matrix):
    return [round(float(v), 7) for v in matrix.translation] + [
        round(float(matrix[r][c]), 8) for r in range(3) for c in range(3)]


rig_data = json.loads((HERE / "assets/blender/rig/R15_joint_schema.json").read_text())
joints = rig_data["joints"]


def matrix_of(values):
    m = Matrix.Identity(4)
    m.translation = Vector(values[:3])
    for r in range(3):
        for c in range(3):
            m[r][c] = values[3+r*3+c]
    return m


rests = {joint["name"]: matrix_of(joint["rest"]) for joint in joints}
rests["HumanoidRootPart"] = matrix_of(rig_data["rootRest"])
bones = {joint["name"]: converted(rig.matrix_world @ rig.data.bones[joint["name"]].matrix_local)
         for joint in joints}
body_parts = [bpy.data.objects[name] for name in rig_data["bodyNames"]]


def body_floor():
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    floor = math.inf
    for original in body_parts:
        evaluated = original.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        matrix = evaluated.matrix_world
        for vertex in mesh.vertices:
            floor = min(floor, (matrix @ vertex.co).z)
        evaluated.to_mesh_clear()
    return floor


for clip in CLIPS:
    name = clip["name"]
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action["loop"] = clip["loop"]
    action["status"] = "FIRST_PASS_REQUIRES_VISUAL_QA"
    rig.animation_data.action = action
    prop_action = bpy.data.actions.new("PROP__"+name)
    prop_action.use_fake_user = True
    prop.animation_data.action = prop_action
    prev_rotation = {}
    prev_object_rotation = None
    prev_prop_rotation = None
    for time, authored_pose in clip["keys"]:
        frame = 1+round(time*30)
        scene.frame_set(frame)
        rig.matrix_world = Matrix.Identity(4)
        pose_at(authored_pose)
        if "tumble" in authored_pose:
            angle = authored_pose["tumble"]
            axis = Vector(clip["axis"]).normalized()
            turn = Quaternion(axis, math.radians(angle))
            pivot = Vector((0, 0, 2.53))
            rotation = turn.to_matrix().to_4x4()
            group = Matrix.Translation(pivot) @ rotation @ Matrix.Translation(-pivot)
            unturned_prop = prop.matrix_world.copy()
            rig.matrix_world = group
            rig.rotation_quaternion = turn
            prop.matrix_world = group @ unturned_prop
            if 0 < angle < 360:
                adjustment = 0.06 - body_floor()
                rig.location.z += adjustment
                prop.location.z += adjustment
            if prev_object_rotation and rig.rotation_quaternion.dot(prev_object_rotation) < 0:
                rig.rotation_quaternion.negate()
            prev_object_rotation = rig.rotation_quaternion.copy()
            rig.keyframe_insert("location", frame=frame, group="Roll root")
            rig.keyframe_insert("rotation_quaternion", frame=frame, group="Roll root")
        if prev_prop_rotation and prop.rotation_quaternion.dot(prev_prop_rotation) < 0:
            prop.rotation_quaternion.negate()
        prev_prop_rotation = prop.rotation_quaternion.copy()
        for pb in rig.pose.bones:
            if pb.name in prev_rotation and pb.rotation_quaternion.dot(prev_rotation[pb.name]) < 0:
                pb.rotation_quaternion.negate()
            prev_rotation[pb.name] = pb.rotation_quaternion.copy()
            pb.keyframe_insert("location", frame=frame, group=pb.name)
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
        prop.keyframe_insert("location", frame=frame)
        prop.keyframe_insert("rotation_quaternion", frame=frame)
    for marker_name, time in clip["markers"].items():
        action.pose_markers.new(marker_name).frame = 1+round(time*30)
    # Bake from the editable Blender Action, not from the authoring pose table.
    frames = []
    for index in range(round(clip["duration"]*30)+1):
        scene.frame_set(1+index)
        bpy.context.view_layer.update()
        posed = {"HumanoidRootPart": rests["HumanoidRootPart"]}
        for joint in joints:
            n = joint["name"]
            posed[n] = converted(rig.matrix_world @ rig.pose.bones[n].matrix) @ bones[n].inverted() @ rests[n]
        transforms = {}
        for joint in joints:
            n, parent = joint["name"], joint["parent"]
            c0, c1 = matrix_of(joint["c0"]), matrix_of(joint["c1"])
            transforms[n] = cframe(c0.inverted() @ posed[parent].inverted() @ posed[n] @ c1)
        frames.append({"time": index/30, "poses": transforms})
    output = {"name": name, "rig": "R15", "duration": clip["duration"],
              "loop": clip["loop"], "priority": clip["priority"],
              "markers": clip["markers"], "frames": frames,
              "sourceBlend": OUT_BLEND.relative_to(ROOT).as_posix(),
              "status": "FIRST_PASS_REQUIRES_VISUAL_QA"}
    (OUT_DATA / (name+".json")).write_text(json.dumps(output, separators=(",", ":")))
    print("AUTHORED", name, len(frames), flush=True)

rig.animation_data.action = bpy.data.actions["CombatIdle"]
prop.animation_data.action = bpy.data.actions["PROP__CombatIdle"]
scene.frame_set(1)
scene["source_status"] = "Straight sword first pass; gameplay balance and visual polish pending."
bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
print("OUTPUT", str(OUT_BLEND), "max_leg_extension", max_leg_extension,
      "max_grip_error", max_grip_error, flush=True)
