"""Bake original procedural map materials into PBR atlases for the Studio importer."""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Matrix, Vector
root = Path(__file__).resolve().parent / 'export'
axis = Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
inverse = axis.inverted().to_3x3()
project = json.loads((root/'project.json').read_text(encoding='utf-8'))
body_mode='--body' in sys.argv
color_only='--color-only' in sys.argv
source_file=root.parent.parent/'AshenColiseum'/'AshenColiseum.blend'
if body_mode: source_file=root.parent.parent/'AshenColiseum'/'Weapons'/'AshenGreatsword'/'AshenOath_R15.blend'
bpy.ops.wm.open_mainfile(filepath=str(source_file))
source_materials = {m.name:m for m in bpy.data.materials}
for ob in list(bpy.data.objects): bpy.data.objects.remove(ob,do_unlink=True)
scene = bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.cycles.device='CPU'
scene.render.bake.margin=6
texture_dir=root/(('quality_body_textures' if body_mode else 'quality_map_textures') if color_only else ('body_textures' if body_mode else 'map_textures'));texture_dir.mkdir(exist_ok=True)
groups={}
for e in project['meshes']:
    if e['category']==('Mannequin' if body_mode else 'Map'): groups.setdefault(e['collection'],[]).append(e)
export_objects=[]
for group_idx,(district,entries) in enumerate(groups.items()):
    verts=[];faces=[];normals=[];material_indices=[];slices=[];mats=[];mat_lookup={}
    for entry in entries:
        d=json.loads((root/(entry['id']+'.json')).read_text(encoding='utf-8'))
        offset=len(verts);first=len(faces);center=Vector(d['center'])
        verts.extend(tuple(inverse@(Vector(v)+center)) for v in d['vertices'])
        for mat in d['materials']:
            if mat['name'] not in mat_lookup:
                mat_lookup[mat['name']]=len(mats);mats.append(source_materials[mat['name']].copy())
        for i,f in enumerate(d['faces']):
            faces.append(tuple(offset+v-1 for v in f))
            material_indices.append(mat_lookup[d['materials'][d['faceMaterials'][i]-1]['name']])
            normals.extend(tuple(inverse@Vector(n)) for n in d['normals'][i])
        slices.append((entry,d,first,len(faces)))
    me=bpy.data.meshes.new('Bake '+district);me.from_pydata(verts,[],faces);me.update()
    for mat in mats:me.materials.append(mat)
    for p,index in zip(me.polygons,material_indices):p.material_index=index;p.use_smooth=True
    me.normals_split_custom_set(normals)
    ob=bpy.data.objects.new('Bake '+district,me);scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.1519,island_margin=.003)
    bpy.ops.object.mode_set(mode='OBJECT')
    images={}
    for channel in (['Color'] if color_only else ['Color','Normal','Roughness','Metalness']):
        im=bpy.data.images.new(f'District_{group_idx:02d}_{channel}',width=2048,height=2048,alpha=False)
        im.colorspace_settings.name='sRGB' if channel=='Color' else 'Non-Color'
        images[channel]=im;saved=[]
        for mat in mats:
            ns=mat.node_tree.nodes;links=mat.node_tree.links
            node=ns.new('ShaderNodeTexImage');node.image=im;ns.active=node
            for n in ns:n.select=False
            node.select=True
            if channel in ('Color','Metalness'):
                bs=ns.get('Principled BSDF');out=ns.get('Material Output');original=out.inputs['Surface'].links[0].from_socket
                em=ns.new('ShaderNodeEmission')
                if channel=='Color':
                    base=bs.inputs['Base Color']
                    if base.is_linked: links.new(base.links[0].from_socket,em.inputs['Color'])
                    else: em.inputs['Color'].default_value=base.default_value
                else:
                    value=bs.inputs['Metallic'].default_value;em.inputs['Color'].default_value=(value,value,value,1)
                links.new(em.outputs[0],out.inputs['Surface']);saved.append((mat,em,original,out))
        scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True
        bpy.ops.object.bake(type={'Color':'EMIT','Normal':'NORMAL','Roughness':'ROUGHNESS','Metalness':'EMIT'}[channel])
        for mat,em,original,out in saved:mat.node_tree.links.new(original,out.inputs['Surface']);mat.node_tree.nodes.remove(em)
        im.filepath_raw=str(texture_dir/(im.name+'.png'));im.file_format='PNG';im.save()
        print('BAKED',district,channel,flush=True)
    if color_only:
        bpy.data.objects.remove(ob,do_unlink=True)
        continue
    atlas=bpy.data.materials.new(f'District_{group_idx:02d}_PBR');atlas.use_nodes=True
    bs=atlas.node_tree.nodes.get('Principled BSDF');links=atlas.node_tree.links
    for channel,target in [('Color','Base Color'),('Metalness','Metallic'),('Roughness','Roughness')]:
        n=atlas.node_tree.nodes.new('ShaderNodeTexImage');n.image=images[channel];links.new(n.outputs['Color'],bs.inputs[target])
    n=atlas.node_tree.nodes.new('ShaderNodeTexImage');n.image=images['Normal'];nm=atlas.node_tree.nodes.new('ShaderNodeNormalMap')
    links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    uv_layer=me.uv_layers.active
    for entry,d,first,end in slices:
        chunk=bpy.data.meshes.new(entry['id']);chunk.from_pydata([tuple(inverse@(Vector(v)+Vector(d['center']))) for v in d['vertices']],[],[tuple(v-1 for v in f) for f in d['faces']]);chunk.update()
        chunk.materials.append(atlas);uv=chunk.uv_layers.new(name='UVMap');ns=[]
        for p in chunk.polygons:
            p.use_smooth=True
            source=me.polygons[first+p.index]
            for k,loop in enumerate(p.loop_indices):
                uv.data[loop].uv=uv_layer.data[source.loop_indices[k]].uv
                ns.append(tuple(inverse@Vector(d['normals'][p.index][k])))
        chunk.normals_split_custom_set(ns)
        part=bpy.data.objects.new(entry['id'],chunk);scene.collection.objects.link(part);export_objects.append(part)
    bpy.data.objects.remove(ob,do_unlink=True)
    print('DISTRICT_COMPLETE',district,flush=True)
if color_only:
    print('BASE_COLOR_CORRECTION_COMPLETE',len(groups),flush=True)
    sys.exit(0)
bpy.ops.object.select_all(action='DESELECT')
for ob in export_objects:ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(root/('AshenOath_Mannequin_Studio.fbx' if body_mode else 'AshenColiseum_PBR_Studio.fbx')),use_selection=True,object_types={'MESH'},
    axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,bake_anim=False,use_mesh_modifiers=False,
    mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True)
print('MAP_PBR_FBX_COMPLETE',len(export_objects),flush=True)
