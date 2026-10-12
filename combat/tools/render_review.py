"""Render fixed camera checks from the editable Blender Action file."""
import bpy
import os
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
blend = root / "combat/assets/blender/animations/StraightSword_R15.blend"
out = root / "combat/review"
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(blend))
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = 800
scene.render.resolution_y = 600
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
rig = bpy.data.objects["R15_Combat_Rig"]
prop = bpy.data.objects["Sword motion / paired PROP actions"]
checks = {
    "CombatIdle": [1],
    "SwordR1_1": [1, 6, 12, 22, 29],
    "SwordR1_2": [1, 6, 12, 24, 30],
    "SwordR2": [1, 15, 22, 33, 44],
    "RollForward": [1, 5, 10, 13, 16, 19, 22, 26],
    "RollBackward": [1, 5, 10, 13, 16, 19, 22, 26],
    "RollLeft": [1, 5, 10, 13, 16, 19, 22, 26],
    "RollRight": [1, 5, 10, 13, 16, 19, 22, 26],
}
only_clip = os.environ.get("COMBAT_REVIEW_CLIP")
if only_clip:
    checks = {only_clip: checks[only_clip]}
specific_frames = os.environ.get("COMBAT_REVIEW_FRAMES")
if specific_frames:
    frames = [int(value) for value in specific_frames.split(",")]
    checks = {clip: frames for clip in checks}

camera_options = {
    "front": bpy.data.objects["Camera / front"],
    "side": bpy.data.objects["Camera / choreography"],
}
for slug, position in {"back": (0, 18, 5), "gameplay": (2, 10, 5.5)}.items():
    camera_data = bpy.data.cameras.new("Review " + slug)
    camera = bpy.data.objects.new("Review " + slug, camera_data)
    scene.collection.objects.link(camera)
    camera.location = position
    camera.rotation_euler = (Vector((0, 0, 3.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO" if slug == "back" else "PERSP"
    if slug == "back": camera_data.ortho_scale = 8
    else: camera_data.lens = 42
    camera_options[slug] = camera
selected_cameras = os.environ.get("COMBAT_REVIEW_CAMERAS", "front,side,back,gameplay").split(",")
for camera_slug in selected_cameras:
    scene.camera = camera_options[camera_slug]
    for clip, frames in checks.items():
        rig.animation_data.action = bpy.data.actions[clip]
        prop.animation_data.action = bpy.data.actions["PROP__" + clip]
        for frame in frames:
            scene.frame_set(frame)
            scene.render.filepath = str(out / f"{clip}_{camera_slug}_{frame:02d}.png")
            bpy.ops.render.render(write_still=True)
            print("RENDERED", scene.render.filepath, flush=True)
