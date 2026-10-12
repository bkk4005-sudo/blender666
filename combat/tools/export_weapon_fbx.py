"""Export only the scaled original straight-sword training prop from Blender."""
import bpy
from pathlib import Path

root = Path(__file__).resolve().parents[2]
blend = root / "combat/assets/blender/animations/StraightSword_R15.blend"
out = root / "combat/assets/weapon/StraightSword_Prototype.fbx"
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(blend))
source = bpy.data.objects["StraightSword_Prototype"]
export_object = source.copy()
export_object.data = source.data.copy()
bpy.context.scene.collection.objects.link(export_object)
export_object.parent = None
export_object.matrix_world.identity()
export_object.scale = source.scale.copy()
export_object.name = "StraightSword_Prototype"
bpy.ops.object.select_all(action="DESELECT")
export_object.select_set(True)
bpy.context.view_layer.objects.active = export_object
bpy.ops.export_scene.fbx(filepath=str(out), use_selection=True, object_types={"MESH"},
                         axis_forward="-Z", axis_up="Y", global_scale=1,
                         apply_unit_scale=True, bake_anim=False, use_mesh_modifiers=True,
                         mesh_smooth_type="FACE")
print("EXPORTED", out, out.stat().st_size)
