"""Smaller render batches of the exact authored arcade; no changes to design."""
import bpy,json
from pathlib import Path
from mathutils import Matrix,Vector
root=Path(__file__).resolve().parent/'export'
axis=Matrix(((-1,0,0),(0,0,1),(0,1,0)));inv=axis.inverted()
bpy.ops.wm.read_factory_settings(use_empty=True)
project=json.loads((root/'project.json').read_text(encoding='utf-8'))
manifest=[]
for e in project['meshes']:
    if e['category']!='Map' or 'double arcade' not in e['collection']:continue
    d=json.loads((root/(e['id']+'.json')).read_text(encoding='utf-8'))
    for first in range(0,len(d['faces']),4500):
        faces=d['faces'][first:first+4500]
        ids=sorted({v for f in faces for v in f});remap={v:i for i,v in enumerate(ids)}
        verts=[]
        for i in ids:
            v=inv@(Vector(d['vertices'][i-1])+Vector(d['center']))
            verts.append((v.x*2,v.y*2,v.z))
        name=f"arcade_{len(manifest):03d}"
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],[tuple(remap[v] for v in f) for f in faces]);mesh.update()
        ob=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(ob)
        manifest.append(dict(name=name,sourceKey=e['id'],sourceObject=e['name'],collection=e['collection'],triangles=len(faces)))
bpy.ops.export_scene.fbx(filepath=str(root/'AshenArcade_Fixed.fbx'),use_selection=False,object_types={'MESH'},
    axis_forward='-Z',axis_up='Y',global_scale=1,apply_unit_scale=True,bake_anim=False,use_mesh_modifiers=False,mesh_smooth_type='FACE')
(root/'arcade_repair.json').write_text(json.dumps(manifest,separators=(',',':')),encoding='utf-8')
print('ARCADE_REPAIR_EXPORT',len(manifest),sum(x['triangles'] for x in manifest),flush=True)
