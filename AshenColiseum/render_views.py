import bpy
from pathlib import Path
root=Path(__file__).resolve().parent
s=bpy.context.scene
for cam,filename in [('Camera / coliseum interior','02_coliseum_interior.png'),('Camera / fallen kings court','03_duel_court.png'),('Camera / four courts plan','04_plan.png')]:
    s.camera=bpy.data.objects[cam]
    s.render.resolution_x=1800
    s.render.resolution_y=1200 if filename!='04_plan.png' else 1800
    s.render.filepath=str(root/'renders'/filename)
    bpy.ops.render.render(write_still=True)
