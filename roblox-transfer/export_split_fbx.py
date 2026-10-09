"""Create importer-ready map FBX from exact, evaluated geometry chunks."""
import bpy, json
from pathlib import Path
from mathutils import Matrix, Vector
root = Path(__file__).resolve().parent / 'export'
axis = Matrix(((-1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1)))
bpy.ops.wm.read_factory_settings(use_empty=True)
project = json.loads((root/'project.json').read_text(encoding='utf-8'))
materials = {}
for entry in project['meshes']:
    if entry['category'] != 'Map': continue
    d = json.loads((root/(entry['id']+'.json')).read_text(encoding='utf-8'))
    me = bpy.data.meshes.new(d['id'])
    me.from_pydata([tuple(axis.inverted().to_3x3() @ Vector(v)) for v in d['vertices']], [],
                  [tuple(i-1 for i in f) for f in d['faces']])
    me.update()
    for m in d['materials']:
        if m['name'] not in materials:
            mat = bpy.data.materials.new(m['name'])
            mat.diffuse_color = (*m['color'],1)
            mat.use_nodes = True
            bs = mat.node_tree.nodes.get('Principled BSDF')
            bs.inputs['Base Color'].default_value = (*m['color'],1)
            bs.inputs['Metallic'].default_value = m['metalness']
            bs.inputs['Roughness'].default_value = m['roughness']
            materials[m['name']] = mat
        me.materials.append(materials[m['name']])
    uv = me.uv_layers.new(name='UVMap')
    normals = []
    for i,p in enumerate(me.polygons):
        p.material_index = d['faceMaterials'][i]-1
        p.use_smooth = True
        for k, loop in enumerate(p.loop_indices):
            uv.data[loop].uv = d['uvs'][i][k]
            normals.append(tuple(axis.inverted().to_3x3() @ Vector(d['normals'][i][k])))
    me.normals_split_custom_set(normals)
    ob = bpy.data.objects.new(d['id'],me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = axis.inverted().to_3x3() @ Vector(d['center'])
    ob['source_name'] = d['name']
    ob['source_collection'] = d['collection']
    ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(root/'AshenColiseum_Studio.fbx'),use_selection=True,
    object_types={'MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,
    bake_anim=False,use_mesh_modifiers=False,mesh_smooth_type='FACE')
print('SPLIT_FBX_COMPLETE',flush=True)
