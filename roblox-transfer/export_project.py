"""Read-only Blender export for Roblox Studio migration. Never saves source .blend files."""
import bpy, json, hashlib, math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'roblox-transfer' / 'export'
OUT.mkdir(parents=True, exist_ok=True)
AXIS = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
MAX_TRIANGLES = 18000

def vec(v):
    return [round(float(x), 7) for x in v]

def cf(m):
    return vec(m.translation) + [round(float(m[r][c]), 8) for r in range(3) for c in range(3)]

def converted(m):
    return AXIS @ m @ AXIS.inverted()

def write(name, value):
    (OUT / name).write_text(json.dumps(value, separators=(',', ':'), ensure_ascii=False), encoding='utf-8')

def material(m):
    p = m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
    return {'name': m.name, 'color': vec(m.diffuse_color[:3]),
            'roughness': float(p.inputs['Roughness'].default_value) if p else .8,
            'metalness': float(p.inputs['Metallic'].default_value) if p else 0,
            'emission': float(p.inputs['Emission Strength'].default_value) if p else 0,
            'procedural': any(n.type == 'TEX_NOISE' for n in m.node_tree.nodes) if m.use_nodes else False}

mesh_index = []
def export_mesh(ob, category, transform=None):
    deps = bpy.context.evaluated_depsgraph_get()
    evaluated = ob.evaluated_get(deps)
    me = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=deps)
    me.calc_loop_triangles()
    # Mesh data is in the source's local space. Center it for stable Roblox bounds.
    positions = [AXIS @ v.co for v in me.vertices]
    minimum = Vector(tuple(min(v[k] for v in positions) for k in range(3)))
    maximum = Vector(tuple(max(v[k] for v in positions) for k in range(3)))
    center = (minimum + maximum) * .5
    part_rest = Matrix.Translation(center)
    world = converted(transform if transform is not None else ob.matrix_world)
    world_center = world @ part_rest
    for chunk_idx, start in enumerate(range(0, len(me.loop_triangles), MAX_TRIANGLES)):
        triangles = me.loop_triangles[start:start+MAX_TRIANGLES]
        ids = sorted({i for t in triangles for i in t.vertices})
        remap = {old: new+1 for new, old in enumerate(ids)}
        vertices = [vec(positions[i] - center) for i in ids]
        faces, normals, uvs, materials = [], [], [], []
        uv_layer = me.uv_layers.active
        for t in triangles:
            faces.append([remap[i] for i in t.vertices])
            normals.append([vec(AXIS.to_3x3() @ me.corner_normals[i].vector) for i in t.loops])
            uvs.append([vec(uv_layer.data[i].uv) if uv_layer else [0, 0] for i in t.loops])
            materials.append(t.material_index+1)
        key = f'mesh_{len(mesh_index):04d}'
        data = {'id': key, 'name': ob.name, 'chunk': chunk_idx+1,
                'category': category, 'collection': ob.users_collection[0].name if ob.users_collection else '',
                'vertices': vertices, 'faces': faces, 'normals': normals, 'uvs': uvs,
                'faceMaterials': materials, 'materials': [material(m) for m in me.materials if m],
                'cframe': cf(world_center), 'center': vec(center),
                'source': bpy.data.filepath, 'sourceObject': ob.name}
        write(key + '.json', data)
        mesh_index.append({k: data[k] for k in ['id', 'name', 'chunk', 'category', 'collection', 'cframe', 'center']})
        mesh_index[-1].update(vertices=len(vertices), triangles=len(faces))
    evaluated.to_mesh_clear()
    return world_center

scene_path = ROOT / 'AshenColiseum' / 'AshenColiseum.blend'
bpy.ops.wm.open_mainfile(filepath=str(scene_path))
map_objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for ob in map_objects:
    export_mesh(ob, 'Map')
helpers = []
for ob in bpy.context.scene.objects:
    if ob.type == 'EMPTY':
        helpers.append({'name': ob.name, 'cframe': cf(converted(ob.matrix_world)), 'displaySize': ob.empty_display_size})
lights = [{'name': o.name, 'type': o.data.type, 'cframe': cf(converted(o.matrix_world)),
           'color': vec(o.data.color), 'energy': o.data.energy, 'radius': getattr(o.data, 'shadow_soft_size', 1)}
          for o in bpy.context.scene.objects if o.type == 'LIGHT']
cameras = [{'name': o.name, 'cframe': cf(converted(o.matrix_world)), 'lens': o.data.lens,
            'type': o.data.type, 'orthoScale': o.data.ortho_scale}
           for o in bpy.context.scene.objects if o.type == 'CAMERA']
write('map_metadata.json', {'helpers': helpers, 'lights': lights, 'cameras': cameras, 'meshObjects': len(map_objects)})
# Standard importer fallback, retaining all evaluated geometry and material groupings.
bpy.ops.object.select_all(action='DESELECT')
for ob in map_objects: ob.select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT / 'AshenColiseum.fbx'), use_selection=True,
    object_types={'MESH'}, axis_forward='-Z', axis_up='Y', global_scale=1,
    apply_unit_scale=True, bake_anim=False, use_mesh_modifiers=True, mesh_smooth_type='FACE')

weapon_root = ROOT / 'AshenColiseum' / 'Weapons' / 'AshenGreatsword'
bpy.ops.wm.open_mainfile(filepath=str(weapon_root / 'AshenOath_R15.blend'))
rig = bpy.data.objects['R15_AshenOath']
prop = bpy.data.objects['Sword motion / paired PROP actions']
for ob in [rig, prop]:
    ob.animation_data.action = None
    for track in ob.animation_data.nla_tracks: track.mute = True
for pb in rig.pose.bones: pb.matrix_basis = Matrix.Identity(4)
prop.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()
sword = bpy.data.objects['AshenOath_Greatsword']
sword_rest = export_mesh(sword, 'Weapon', Matrix.Identity(4))
body_names = [b.name for b in rig.data.bones if b.name not in ['Root', 'HumanoidRootNode']]
rests, bones = {}, {}
for n in body_names:
    ob = bpy.data.objects[n]
    rests[n] = export_mesh(ob, 'Mannequin')
    bones[n] = converted(rig.matrix_world @ rig.data.bones[n].matrix_local)
rests['HumanoidRootPart'] = Matrix.Translation((0, 3.13, 0))
parents = {}
joints = []
for n in body_names:
    b = rig.data.bones[n]
    parent = b.parent.name if b.parent and b.parent.name in body_names else 'HumanoidRootPart'
    parents[n] = parent
    joints.append({'name': n, 'parent': parent, 'c0': cf(rests[parent].inverted() @ bones[n]),
                   'c1': cf(rests[n].inverted() @ bones[n]), 'rest': cf(rests[n])})
write('rig.json', {'bodyNames': body_names, 'joints': joints, 'rootRest': cf(rests['HumanoidRootPart']),
                  'weaponRest': cf(sword_rest)})
manifest = json.loads((weapon_root / 'animation_manifest.json').read_text(encoding='utf-8'))
for clip in manifest:
    rig.animation_data.action = bpy.data.actions[clip['name']]
    prop.animation_data.action = bpy.data.actions['PROP__' + clip['name']]
    frames = []
    for frame in range(1, clip['frames']+1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        posed = {'HumanoidRootPart': rests['HumanoidRootPart']}
        for n in body_names:
            posed[n] = converted(rig.matrix_world @ rig.pose.bones[n].matrix) @ bones[n].inverted() @ rests[n]
        transforms = {}
        for j in joints:
            n, parent = j['name'], j['parent']
            c0 = rests[parent].inverted() @ bones[n]
            c1 = rests[n].inverted() @ bones[n]
            transforms[n] = cf(c0.inverted() @ posed[parent].inverted() @ posed[n] @ c1)
        frames.append({'time': (frame-1)/30, 'poses': transforms,
                       'prop': cf(converted(prop.matrix_world))})
    write('animation_' + clip['name'] + '.json', {'name': clip['name'], 'loop': clip['loop'],
          'duration': clip['duration_exported'], 'events': clip['events'], 'kind': clip['kind'], 'frames': frames})
    print('ANIMATION_EXPORTED', clip['name'], len(frames), flush=True)

inventory = []
for path in ROOT.rglob('*'):
    if not path.is_file() or '.git' in path.parts or 'roblox-transfer' in path.parts: continue
    relative = path.relative_to(ROOT).as_posix()
    data = path.read_bytes()
    inventory.append({'path': relative, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
write('repository_inventory.json', inventory)
write('project.json', {'axisConversion': 'Roblox (-BlenderX, BlenderZ, BlenderY); scale 1:1',
      'meshes': mesh_index, 'animations': [c['name'] for c in manifest],
      'mapMeshObjects': len(map_objects), 'sourceFiles': len(inventory),
      'totalTriangles': sum(m['triangles'] for m in mesh_index)})
print('EXPORT_COMPLETE', len(mesh_index), 'meshes', len(manifest), 'clips', flush=True)
