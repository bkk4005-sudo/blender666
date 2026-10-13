"""Author original straight-sword R15 Actions in Blender 5.2.

Run: blender -b --python combat/tools/author_blender.py
The existing official-template R15 mannequin is a rig donor; its file is read-only.
Outputs a separate editable .blend and baked joint samples for Roblox conversion.
The authored Actions remain subject to Studio and player-rig visual review.
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
sword["status"] = "Original training sword; paired Actions reviewed in Blender."
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
    "p": (-0.35, -0.65, 3.68), "angles": (105, -35, 8),
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
               body=(-2, 0, -27), pelvis=(0, 0, -15), root=(-0.05, 0.09, -0.29),
               lf=(0.64, -0.18, 0), rf=(-0.65, 0.55, 0))
R1_CONTACT = pose(p=(0.42, -1.13, 4.08), angles=(93, 55, 8),
                  body=(15, 0, 23), pelvis=(1, 0, 12), root=(0.04, -0.16, -0.30),
                  lf=(0.64, -0.85, 0), rf=(-0.65, 0.98, 0))
R1_END = pose(p=(0.53, -0.63, 3.95), angles=(113, 91, 22),
              body=(12, 0, 29), pelvis=(0, 0, 15), root=(0.07, -0.12, -0.27),
              lf=(0.64, -0.85, 0), rf=(-0.65, 0.88, 0))
R2_WIND = pose(p=(-0.95, -0.42, 5.08), angles=(-44, -29, -4),
               body=(-12, 0, -24), pelvis=(-3, 0, -14), root=(-0.07, 0.11, -0.40),
               lf=(0.64, -0.18, 0), rf=(-0.65, 0.65, 0))
R2_CONTACT = pose(p=(0.02, -1.20, 4.10), angles=(100, 8, 3),
                  body=(22, 0, 14), pelvis=(5, 0, 11), root=(0.03, -0.27, -0.44),
                  lf=(0.64, -0.90, 0), rf=(-0.65, 1.08, 0))
R2_END = pose(p=(0.20, -1.03, 3.54), angles=(150, 12, 2),
              body=(27, 0, 17), pelvis=(6, 0, 13), root=(0.05, -0.21, -0.43),
              lf=(0.64, -0.90, 0), rf=(-0.65, 1.08, 0))

# Original R15 medium-roll reconstruction. The inspected DS3 footage did not
# expose reliable source frames for a roll, so these are authored project poses.
ROLL_CROUCH = pose(root=(0, 0, -0.62), body=(37, 0, -10), pelvis=(18, 0, -6),
                   lf=(0.54, 0.00, 0), rf=(-0.54, 0.00, 0),
                   p=(-1.00, -0.60, 3.56), angles=(90, 0, 0),
                   left_hand=(0.18, -0.45, -0.48), head=(16, 0, 0))
ROLL_PREP = pose(root=(0, 0, -0.40), body=(22, 0, -9), pelvis=(10, 0, -4),
                 lf=(0.59, -0.12, 0), rf=(-0.59, 0.15, 0),
                 p=(-.95, -0.68, 3.83), angles=(100, -15, 8), left_hand=(0.30, -0.33, -0.80),
                 head=(5, 0, 3))
ROLL_TUCK = pose(root=(0, 0, -0.73), body=(67, 0, -12), pelvis=(34, 0, -8),
                 lf=(0.35, 0.08, 1.48), rf=(-0.35, 0.08, 1.48),
                 p=(-.95, -0.45, 3.00), angles=(90, 0, 0),
                 left_hand=(0.10, -0.48, -0.28), head=(28, 0, 0))
ROLL_MID = pose(root=(0, 0, -0.69), body=(53, 0, -11), pelvis=(27, 0, -7),
                lf=(0.44, 0.04, 0.70), rf=(-0.44, 0.04, 0.70),
                p=(-1.00, -0.47, 3.28), angles=(90, 0, 0), left_hand=(0.13, -0.46, -0.38),
                head=(23, 0, 0))


def roll_clip(name, axis):
    # Turn the blade toward the roll path without twisting the wrist through
    # more than its usable range during the short takeoff and landing.
    neutral_yaw = NEUTRAL["angles"][1]
    raw_yaw = math.degrees(math.atan2(axis[0], -axis[1]))
    # Keep the blade approximately parallel to the tumble axis to avoid driving
    # it into the floor. Right roll uses the opposite axis direction so it points
    # away from the chest without a 180-degree wrist turn.
    blade_yaw = raw_yaw - 180 if name == "RollRight" else neutral_yaw + max(-75, min(75, raw_yaw - neutral_yaw))
    def at(t, posture, angle):
        value = posture.copy()
        if 0 < t < 25:
            if t <= 6:
                blend = min(1.0, t / 6)
            elif t >= 18:
                blend = max(0.0, (25 - t) / 7)
            else:
                blend = 1.0
            neutral_yaw = NEUTRAL["angles"][1]
            value["angles"] = (NEUTRAL["angles"][0] + (90 - NEUTRAL["angles"][0]) * blend,
                               neutral_yaw + (blade_yaw - neutral_yaw) * blend,
                               8 * (1 - blend))
        value["tumble"] = angle
        return (t / 30, value)
    return dict(name=name, duration=25 / 30, loop=False, priority="Action",
                axis=axis, markers={"IFrameStart": 5 / 30,
                                    "IFrameEnd": 16 / 30,
                                    "RecoveryEnd": 25 / 30},
                keys=[at(0, NEUTRAL, 0), at(2, ROLL_PREP, 0),
                      at(4, ROLL_CROUCH, 18), at(6, ROLL_MID, 58),
                      at(9, ROLL_TUCK, 112), at(12, ROLL_TUCK, 177),
                      at(15, ROLL_TUCK, 242), at(18, ROLL_MID, 302),
                      at(21, ROLL_CROUCH, 348), at(23, ROLL_PREP, 358),
                      at(25, NEUTRAL, 360)])

GUARD = pose(p=(-0.42, -0.92, 4.18), angles=(26, -18, 8),
             body=(8, 0, -14), pelvis=(0, 0, -9), root=(0, 0.06, -0.28),
             lf=(0.62, -0.48, 0), rf=(-0.62, 0.58, 0), left_hand=(0.40, -0.34, -0.76))
CLIPS = [
    dict(name="CombatIdle", duration=2.0, loop=True, priority="Idle", markers={},
         keys=[(0, NEUTRAL), (0.5, pose(body=(7, 0, -8), p=(-0.35, -0.65, 3.70))),
               (1, pose(body=(6, 0, -8), p=(-0.35, -0.65, 3.68))),
               (1.5, pose(body=(5, 0, -8), p=(-0.35, -0.65, 3.66))), (2, NEUTRAL)]),
    dict(name="SwordR1_1", duration=28/30, loop=False, priority="Action",
         markers={"AttackStart": 0, "HitStart": 9/30, "HitEnd": 14/30,
                  "ComboOpen": 16/30, "ComboClose": 22/30, "RecoveryEnd": 28/30},
         keys=[(0, NEUTRAL), (0.08, pose(body=(4, 0, -12))),
               (0.16, R1_WIND), (0.23, R1_WIND),
               (0.30, pose(p=(-0.40, -0.86, 4.28), angles=(83, -48, -6),
                           body=(6, 0, -6), pelvis=(0, 0, -3), root=(0, -0.05, -0.32),
                           lf=(0.64, -0.45, 0.18), rf=(-0.65, 0.95, 0))),
               (0.38, R1_CONTACT), (0.46, R1_END), (0.70, R1_END),
               (0.82, pose(p=(0.27, -0.72, 4.01), angles=(82, 56, 12),
                           body=(7, 0, 13), pelvis=(0, 0, 7),
                           lf=(0.64, -0.72, 0), rf=(-0.65, 0.78, 0.22))),
               (28/30, NEUTRAL)]),
    dict(name="SwordR1_2", duration=29/30, loop=False, priority="Action",
         markers={"AttackStart": 0, "HitStart": 8/30, "HitEnd": 14/30,
                  "ComboOpen": 16/30, "ComboClose": 23/30, "RecoveryEnd": 29/30},
         keys=[(0, R1_END), (0.09, pose(p=(0.68, -0.41, 4.12), angles=(72, 115, 25),
                                      body=(2, 0, 31), pelvis=(0, 0, 13),
                                      lf=(0.64, -0.72, 0), rf=(-0.65, 0.90, 0))),
               (0.18, pose(p=(0.67, -0.32, 4.31), angles=(70, 124, 28),
                           body=(0, 0, 37), pelvis=(0, 0, 17), root=(0.08, 0.02, -0.29),
                           lf=(0.64, -0.20, 0), rf=(-0.65, 0.72, 0.20))),
               (0.27, pose(p=(0.31, -0.93, 4.15), angles=(87, 55, 12),
                           body=(9, 0, 13), pelvis=(0, 0, 5), root=(0, -0.07, -0.31),
                           lf=(0.64, 0.25, 0), rf=(-0.65, 0.02, 0.28))),
               (0.36, pose(p=(-0.30, -1.05, 3.97), angles=(98, -40, -11),
                           body=(13, 0, -20), pelvis=(0, 0, -8), root=(-0.05, -0.16, -0.31),
                           lf=(0.64, 0.65, 0), rf=(-0.65, -0.60, 0))),
               (0.45, pose(p=(-0.62, -0.80, 3.98), angles=(109, -108, -20),
                           body=(9, 0, -30), pelvis=(0, 0, -15), root=(-0.07, -0.11, -0.27),
                           lf=(0.64, 0.75, 0), rf=(-0.65, -0.65, 0))),
               (0.62, pose(p=(-0.60, -0.80, 4.00), angles=(104, -101, -16),
                           body=(8, 0, -22), lf=(0.64, 0.75, 0),
                           rf=(-0.65, -0.65, 0))),
               (0.78, pose(p=(-0.34, -0.64, 4.02), angles=(74, -52, -8),
                           body=(5, 0, -10), lf=(0.64, 0.20, 0.20),
                           rf=(-0.65, -0.42, 0))), (29/30, NEUTRAL)]),
    dict(name="SwordR2", duration=43/30, loop=False, priority="Action",
         markers={"AttackStart": 0, "HitStart": 17/30, "HitEnd": 25/30,
                  "RecoveryEnd": 43/30},
         keys=[(0, NEUTRAL), (0.14, pose(root=(0, 0, -0.34), body=(0, 0, -13))),
               (0.32, R2_WIND), (0.47, R2_WIND),
               (0.58, pose(p=(-0.18, -0.63, 5.02), angles=(15, -8, 0),
                           body=(3, 0, -8), pelvis=(0, 0, -4), root=(0, -0.09, -0.41),
                           lf=(0.64, -0.50, 0.18), rf=(-0.65, 1.05, 0))),
               (0.69, R2_CONTACT), (0.82, R2_END), (1.06, R2_END),
               (1.25, pose(p=(0.07, -0.89, 3.88), angles=(110, 8, 2),
                           body=(11, 0, 5), root=(0, -0.06, -0.29),
                           lf=(0.64, -0.55, 0), rf=(-0.65, 0.75, 0.22))),
               (43/30, NEUTRAL)]),
    roll_clip("RollForward", (0.87, -0.49, 0)),
    roll_clip("RollBackward", (-0.87, 0.49, 0)),
    roll_clip("RollLeft", (0.57, -0.82, 0)),
    roll_clip("RollRight", (0.57, 0.82, 0)),
    dict(name="Block", duration=1.6, loop=True, priority="Action", markers={},
         keys=[(0, GUARD), (.4, pose(**{**GUARD, "body": (9, 0, -14), "p": (-.42, -.92, 4.20)})),
               (.8, GUARD), (1.2, pose(**{**GUARD, "body": (7, 0, -14), "p": (-.42, -.92, 4.16)})), (1.6, GUARD)]),
    dict(name="Parry", duration=.9, loop=False, priority="Action",
         markers={"ParryActiveStart": .18, "ParryActiveEnd": .34, "RecoveryEnd": .9},
         keys=[(0, NEUTRAL), (.1, GUARD),
               (.2, pose(p=(-.52, -.95, 4.38), angles=(42, -66, -6), body=(4, 0, -22), pelvis=(0, 0, -10), root=(0, .03, -.28))),
               (.3, pose(p=(.32, -1.10, 4.30), angles=(34, 50, 12), body=(10, 0, 18), pelvis=(0, 0, 9), root=(.03, -.08, -.30))),
               (.4, pose(p=(.52, -.72, 4.24), angles=(43, 74, 12), body=(9, 0, 23), pelvis=(0, 0, 12))),
               (.6, pose(p=(.24, -.64, 4.12), angles=(66, 36, 10), body=(6, 0, 10))), (.9, NEUTRAL)]),
    dict(name="Stagger", duration=20/30, loop=False, priority="Action",
         markers={"RecoveryEnd": 20/30},
         keys=[(0, NEUTRAL), (.1, pose(body=(-16, 3, -5), pelvis=(-5, 0, -3), root=(0, .10, -.32),
                                    p=(-.55, -.38, 3.53), angles=(118, -54, 10), head=(9, 0, 2))),
               (.23, pose(body=(-9, -2, -6), pelvis=(-2, 0, -2), root=(0, .06, -.29), p=(-.43, -.46, 3.55), angles=(111, -45, 8))),
               (.43, pose(body=(5, 0, -9), root=(0, 0, -.25))), (20/30, NEUTRAL)]),
    dict(name="GuardBroken", duration=35/30, loop=False, priority="Action",
         markers={"RecoveryEnd": 35/30},
         keys=[(0, GUARD), (.13, pose(body=(-19, 0, -7), pelvis=(-7, 0, -4), root=(0, .14, -.35),
                                   p=(-.55, -.25, 3.70), angles=(133, -60, 16), head=(10, 0, 2))),
               (.3, pose(body=(25, 0, -8), pelvis=(9, 0, -4), root=(0, -.05, -.56),
                                  p=(-.56, -.62, 3.05), angles=(148, -35, 5), head=(18, 0, 2))),
               (.73, pose(body=(21, 0, -8), pelvis=(6, 0, -4), root=(0, 0, -.47),
                                   p=(-.48, -.61, 3.18), angles=(140, -35, 5), head=(12, 0, 2))),
               (.96, pose(body=(11, 0, -8), root=(0, 0, -.30))), (35/30, NEUTRAL)]),
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
current_pose_label = ""


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
        if over > 0.04:
            print("LEG_OVER", current_pose_label, side, round(over, 4), flush=True)
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
target_data = json.loads((HERE / "assets/blender/rig/R15_standard_joint_schema.json").read_text())
target_joints = {joint["name"]: joint for joint in target_data["joints"]}


def matrix_of(values):
    m = Matrix.Identity(4)
    m.translation = Vector(values[:3])
    for r in range(3):
        for c in range(3):
            m[r][c] = values[3+r*3+c]
    return m


rests = {joint["name"]: matrix_of(joint["rest"]) for joint in joints}
rests["HumanoidRootPart"] = matrix_of(rig_data["rootRest"])
target_rests = {joint["name"]: matrix_of(joint["rest"]) for joint in target_data["joints"]}
target_rests["HumanoidRootPart"] = matrix_of(target_data["rootRest"])
bones = {joint["name"]: converted(rig.matrix_world @ rig.data.bones[joint["name"]].matrix_local)
         for joint in joints}
body_parts = [bpy.data.objects[name] for name in rig_data["bodyNames"]]


def rotation_matrix(matrix):
    return matrix.to_quaternion().to_matrix().to_4x4()


def box_floor(matrix, size):
    return min((matrix @ Vector((x * size[0] / 2, y * size[1] / 2, z * size[2] / 2))).y
               for x in (-1, 1) for y in (-1, 1) for z in (-1, 1))


target_floor = min(box_floor(target_rests[name], target_joints[name]["size"]) for name in target_joints)


def retarget_standard(posed, ground_clearance):
    # Donor C0/C1 frames have imported FBX rotations. Exporting their Transform
    # directly rotates a standard R15 joint around the wrong axes. Preserve the
    # posed part-relative rotation, then express it in the target joint frame.
    transforms = {}
    target_posed = {"HumanoidRootPart": target_rests["HumanoidRootPart"]}
    for joint in joints:
        name, parent = joint["name"], joint["parent"]
        target = target_joints[name]
        assert target["parent"] == parent
        c0, c1 = matrix_of(target["c0"]), matrix_of(target["c1"])
        source_rest_local = rotation_matrix(rests[parent]).inverted() @ rotation_matrix(rests[name])
        target_rest_local = rotation_matrix(target_rests[parent]).inverted() @ rotation_matrix(target_rests[name])
        source_local = rotation_matrix(posed[parent]).inverted() @ rotation_matrix(posed[name])
        desired_local = target_rest_local @ source_rest_local.inverted() @ source_local
        value = rotation_matrix(c0).inverted() @ desired_local @ rotation_matrix(c1)
        if name == "LowerTorso":
            delta = posed[name].translation - rests[name].translation
            value.translation = rotation_matrix(c0).inverted().to_3x3() @ delta
        target_posed[name] = target_posed[parent] @ c0 @ value @ c1.inverted()
        expected = rotation_matrix(target_posed[parent]) @ desired_local
        error = expected.to_quaternion().rotation_difference(target_posed[name].to_quaternion()).angle
        assert error < 0.0001, (name, error)
        transforms[name] = value
    body_minimum = min(box_floor(target_posed[name], target_joints[name]["size"]) for name in target_joints)
    sword_center = target_posed["RightHand"] @ weapon_hilt @ Matrix.Translation(Vector((0, 1.195 * 0.68, 0)))
    sword_minimum = box_floor(sword_center, (1.51340294 * 0.62, 4.71 * 0.68, 0.37736732 * 0.86))
    lift = max(target_floor + max(ground_clearance, 0.03) - body_minimum,
               target_floor + 0.01 - sword_minimum)
    root_c0 = matrix_of(target_joints["LowerTorso"]["c0"])
    transforms["LowerTorso"].translation += rotation_matrix(root_c0).inverted().to_3x3() @ Vector((0, lift, 0))
    return {name: cframe(value) for name, value in transforms.items()}


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


def sword_floor():
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated = sword.evaluated_get(graph)
    mesh = evaluated.to_mesh()
    floor = min((evaluated.matrix_world @ vertex.co).z for vertex in mesh.vertices)
    evaluated.to_mesh_clear()
    return floor


def stabilize_floor(frame_count, target_floor, spread_frames, include_sword, grounded_roll=False):
    # Semantic poses clear the floor, but joint/rig interpolation can dip
    # between them. Bake a smoothed correction at the export sampling rate.
    sample_count = (frame_count - 1) * 2 + 1
    spread_frames *= 2
    sampled = []
    for index in range(sample_count):
        frame = 1 + index / 2
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        body_minimum = body_floor()
        sword_minimum = sword_floor() if include_sword else math.inf
        minimum = min(body_minimum, sword_minimum)
        needed = max(0.0, target_floor - minimum)
        sampled.append((rig.location.z, prop.location.z, needed, body_minimum, sword_minimum))
    correction = []
    for index in range(sample_count):
        correction.append(max(sampled[neighbor][2] * max(0.0, 1.0 - abs(index - neighbor) / spread_frames)
                              for neighbor in range(max(0, index - spread_frames + 1),
                                                    min(sample_count, index + spread_frames))))
    correction[0] = 0.0
    correction[-1] = 0.0
    for index, lift in enumerate(correction):
        if grounded_roll and 14 <= index <= 38:
            # The inverted body must pass close to the ground. The sword can
            # limit the downward adjustment so its edge never cuts the floor.
            body_clearance = sampled[index][3] + lift
            sword_clearance = sampled[index][4] + lift
            sink = min(max(0.0, body_clearance - 0.06),
                       max(0.0, sword_clearance - target_floor))
            lift -= sink
        frame = 1 + index / 2
        scene.frame_set(int(frame), subframe=frame % 1)
        rig.location.z = sampled[index][0] + lift
        prop.location.z = sampled[index][1] + lift
        rig.keyframe_insert("location", frame=frame, group="Floor clearance")
        prop.keyframe_insert("location", frame=frame, group="Floor clearance")
    print("FLOOR_CORRECTION", round(max(correction), 4), flush=True)


def clamp_location_curves(animated_action):
    # Foot targets and floor correction must not overshoot their keyed contacts.
    for layer in animated_action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for curve in channelbag.fcurves:
                    if curve.data_path == "location" or curve.data_path.endswith(".location"):
                        for key in curve.keyframe_points:
                            key.handle_left_type = "AUTO_CLAMPED"
                            key.handle_right_type = "AUTO_CLAMPED"
                        curve.update()


rig.matrix_world = Matrix.Identity(4)
pose_at(NEUTRAL)
bpy.context.view_layer.update()
neutral_hand = converted(rig.matrix_world @ rig.pose.bones["RightHand"].matrix) @ bones["RightHand"].inverted() @ rests["RightHand"]
weapon_hilt = neutral_hand.inverted() @ converted(prop.matrix_world)
anchor = bpy.data.objects.new("Sword grip / rigid hand anchor", None)
scene.collection.objects.link(anchor)
anchor.parent = rig
anchor.parent_type = "BONE"
anchor.parent_bone = "RightHand"
anchor.matrix_parent_inverse = Matrix.Identity(4)
bone_parent = rig.matrix_world @ rig.pose.bones["RightHand"].matrix @ Matrix.Translation(Vector((0, rig.data.bones["RightHand"].length, 0)))
anchor.matrix_basis = bone_parent.inverted() @ prop.matrix_world
prop_constraint = prop.constraints.new("COPY_TRANSFORMS")
prop_constraint.name = "Rigid sword grip / source of truth"
prop_constraint.target = anchor
prop_constraint.owner_space = "WORLD"
prop_constraint.target_space = "WORLD"
prop_constraint.mute = True
weapon_config = {
    "sourceMeshId": "rbxassetid://139047510233988",
    "meshScale": [0.62, 0.68, 0.86],
    "handToHilt": cframe(weapon_hilt),
    "sourceGrip": [0, -1.195, 0],
}
(HERE / "assets/weapon/weapon_grip.json").write_text(json.dumps(weapon_config, indent=2))
grip_values = ", ".join(str(value) for value in weapon_config["handToHilt"])
(HERE / "src/shared/WeaponVisualConfig.luau").write_text(
    "-- Generated from the Blender hand part frame, not the bone frame.\n"
    "return {\n    MeshId = \"rbxassetid://139047510233988\",\n"
    "    MeshScale = Vector3.new(0.62, 0.68, 0.86),\n"
    f"    HandToHilt = CFrame.new({grip_values}),\n"
    "    SourceGrip = CFrame.new(0, -1.195, 0),\n}\n")


def match_prop_to_hand(frame_count):
    previous = None
    for index in range(frame_count):
        scene.frame_set(index + 1)
        bpy.context.view_layer.update()
        hand = converted(rig.matrix_world @ rig.pose.bones["RightHand"].matrix) @ bones["RightHand"].inverted() @ rests["RightHand"]
        prop.matrix_world = AXIS.inverted() @ (hand @ weapon_hilt) @ AXIS
        if previous and prop.rotation_quaternion.dot(previous) < 0:
            prop.rotation_quaternion.negate()
        previous = prop.rotation_quaternion.copy()
        prop.keyframe_insert("location", frame=index + 1, group="Hand attachment bake")
        prop.keyframe_insert("rotation_quaternion", frame=index + 1, group="Hand attachment bake")


for clip in CLIPS:
    prop_constraint.mute = True
    name = clip["name"]
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action["loop"] = clip["loop"]
    action["status"] = "ITERATED_REQUIRES_STUDIO_QA"
    rig.animation_data.action = action
    prop_action = bpy.data.actions.new("PROP__"+name)
    prop_action.use_fake_user = True
    prop.animation_data.action = prop_action
    prev_rotation = {}
    prev_object_rotation = None
    prev_prop_rotation = None
    for time, authored_pose in clip["keys"]:
        current_pose_label = f"{name}:{time:.3f}"
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
        rig.keyframe_insert("location", frame=frame, group="Root placement")
        rig.keyframe_insert("rotation_quaternion", frame=frame, group="Root placement")
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
    match_prop_to_hand(round(clip["duration"] * 30) + 1)
    prop_constraint.mute = False
    if name.startswith("Roll"):
        stabilize_floor(round(clip["duration"] * 30) + 1, 0.015, 4, True, True)
    elif not clip["loop"]:
        stabilize_floor(round(clip["duration"] * 30) + 1, 0.003, 2, False)
    clamp_location_curves(action)
    clamp_location_curves(prop_action)
    # Bake from the editable Blender Action, not from the authoring pose table.
    frames = []
    for index in range(round(clip["duration"]*60)+1):
        frame = 1 + index / 2
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        posed = {"HumanoidRootPart": rests["HumanoidRootPart"]}
        for joint in joints:
            n = joint["name"]
            posed[n] = converted(rig.matrix_world @ rig.pose.bones[n].matrix) @ bones[n].inverted() @ rests[n]
        clearance = body_floor()
        transforms = retarget_standard(posed, clearance)
        frames.append({"time": index/60, "poses": transforms, "groundClearance": round(clearance, 7)})
    output = {"name": name, "rig": "R15", "duration": clip["duration"],
              "loop": clip["loop"], "priority": clip["priority"],
              "markers": clip["markers"], "frames": frames,
              "sourceBlend": OUT_BLEND.relative_to(ROOT).as_posix(),
              "status": "ITERATED_REQUIRES_STUDIO_QA", "exportProfile": "R15Standard",
              "jointSchema": "combat/assets/blender/rig/R15_standard_joint_schema.json", "sampleRate": 60,
              "authoredHipHeight": 2.192423105239868}
    (OUT_DATA / (name+".json")).write_text(json.dumps(output, separators=(",", ":")))
    print("AUTHORED", name, len(frames), flush=True)

rig.animation_data.action = bpy.data.actions["CombatIdle"]
prop.animation_data.action = bpy.data.actions["PROP__CombatIdle"]
scene.frame_set(1)
scene["source_status"] = "Straight sword iteration; live R15, transition and gameplay QA pending."
bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
print("OUTPUT", str(OUT_BLEND), "max_leg_extension", max_leg_extension,
      "max_grip_error", max_grip_error, flush=True)
