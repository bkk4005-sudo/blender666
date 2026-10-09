import bpy
from pathlib import Path
from mathutils import Matrix,Vector
root=Path(__file__).resolve().parent
s=bpy.context.scene; sword=bpy.data.objects['AshenOath_Greatsword']; prop=sword.parent
for o in bpy.context.selected_objects: o.select_set(False)
for track in prop.animation_data.nla_tracks: track.mute=True
prop.animation_data.action=None; prop.matrix_world=Matrix.Identity(4)
sword.select_set(True); bpy.context.view_layer.objects.active=sword
for slot in sword.material_slots: slot.material=slot.material.copy(); slot.material.name='Sword / '+slot.material.name
s.render.engine='CYCLES'; s.cycles.samples=16; s.cycles.device='CPU'; s.render.bake.margin=12
images={}
for kind in ['Color','Metalness','Roughness','Normal']:
    im=bpy.data.images.new('AshenOath_'+kind,width=2048,height=2048,alpha=False)
    im.colorspace_settings.name='sRGB' if kind=='Color' else 'Non-Color'; images[kind]=im
    saved=[]
    for mat in sword.data.materials:
        ns=mat.node_tree.nodes; links=mat.node_tree.links
        node=ns.new('ShaderNodeTexImage'); node.image=im; node.name='Baked '+kind; ns.active=node
        for n in ns: n.select=False
        node.select=True
        if kind in ['Color','Metalness']:
            bs=ns.get('Principled BSDF'); out=ns.get('Material Output'); orig=out.inputs['Surface'].links[0].from_socket
            em=ns.new('ShaderNodeEmission')
            val=bs.inputs['Base Color'].default_value[:] if kind=='Color' else (bs.inputs['Metallic'].default_value,)*3+(1,)
            em.inputs['Color'].default_value=val; links.new(em.outputs[0],out.inputs['Surface']); saved.append((mat,em,orig,out))
    bpy.ops.object.bake(type={'Color':'EMIT','Metalness':'EMIT','Roughness':'ROUGHNESS','Normal':'NORMAL'}[kind])
    for mat,em,orig,out in saved: mat.node_tree.links.new(orig,out.inputs['Surface']); mat.node_tree.nodes.remove(em)
    im.filepath_raw=str(root/'textures'/('AshenOath_'+kind+'.png')); im.file_format='PNG'; im.save(); im.pack()
    print('BAKED_MAP',kind,flush=True)
for mat in sword.data.materials:
    ns=mat.node_tree.nodes; links=mat.node_tree.links; bs=ns.get('Principled BSDF')
    for kind,input_name in [('Color','Base Color'),('Metalness','Metallic'),('Roughness','Roughness')]: links.new(ns['Baked '+kind].outputs['Color'],bs.inputs[input_name])
    normal=ns.new('ShaderNodeNormalMap'); links.new(ns['Baked Normal'].outputs['Color'],normal.inputs['Color']); links.new(normal.outputs['Normal'],bs.inputs['Normal'])
bpy.ops.export_scene.fbx(filepath=str(root/'exports'/'AshenOath_Greatsword.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_UNITS',bake_anim=False,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True)
s.render.engine='BLENDER_EEVEE'
for track in prop.animation_data.nla_tracks: track.mute=False
s.frame_set(75); s.camera=bpy.data.objects['Camera / choreography']; s.render.resolution_x=1200; s.render.resolution_y=1200
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
s.render.filepath=str(root/'previews'/'01_ready_stance.png'); bpy.ops.render.render(write_still=True)
# Product render: same asset, isolated without the display mannequin.
for track in prop.animation_data.nla_tracks: track.mute=True
prop.matrix_world=Matrix.Translation((0,0,1.22))
for o in bpy.data.collections['02 / Standard R15 skeleton and original display mannequin'].objects: o.hide_render=True
cam=bpy.data.objects['Camera / weapon']; cam.location=(4,-11,5); cam.rotation_euler=(Vector((0,0,2.5))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=6.3
s.camera=cam; s.render.resolution_x=1600; s.render.resolution_y=1600; s.render.filepath=str(root/'previews'/'02_sword_detail.png'); bpy.ops.render.render(write_still=True)
